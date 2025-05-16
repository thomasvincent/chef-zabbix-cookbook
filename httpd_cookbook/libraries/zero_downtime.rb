# frozen_string_literal: true

module Httpd
  module ZeroDowntime
    # Performs a graceful reload of Apache with health checks
    # @param service_name [String] The Apache service name
    # @param pre_check [Proc] An optional proc to run before reloading
    # @param post_check [Proc] An optional proc to run after reloading
    # @param max_attempts [Integer] Maximum number of reload attempts
    # @param wait_time [Integer] Seconds to wait between checks
    # @return [Boolean] True if reload was successful, false otherwise
    def graceful_reload(service_name = nil, pre_check: nil, post_check: nil, max_attempts: 3, wait_time: 5)
      service_name ||= httpd_service_name

      # Run pre-reload check if provided
      if pre_check && !pre_check.call
        Chef::Log.warn("Pre-reload check failed for #{service_name}")
        return false
      end

      # Get current worker PIDs for comparison
      original_pids = httpd_worker_pids

      # Execute graceful reload
      reload_status = false
      max_attempts.times do |attempt|
        Chef::Log.info("Attempting graceful reload of #{service_name} (attempt #{attempt + 1}/#{max_attempts})")
        
        if systemd?
          reload_command = "systemctl reload #{service_name}"
        else
          apache_ctl = platform_family?('debian') ? 'apache2ctl' : 'apachectl'
          reload_command = "#{apache_ctl} graceful"
        end
        
        cmd = shell_out(reload_command)
        reload_status = cmd.exitstatus.zero?
        
        break if reload_status
        
        Chef::Log.warn("Reload attempt #{attempt + 1} failed, waiting #{wait_time}s before retry")
        sleep(wait_time)
      end

      unless reload_status
        Chef::Log.error("Failed to reload #{service_name} after #{max_attempts} attempts")
        return false
      end

      # Allow some time for Apache to spawn new workers
      sleep(wait_time)

      # Check if workers were replaced
      new_pids = httpd_worker_pids
      pids_changed = (original_pids - new_pids).any? || (new_pids - original_pids).any?
      
      unless pids_changed
        Chef::Log.warn("No worker processes were replaced during reload of #{service_name}")
      end

      # Run post-reload check if provided
      if post_check && !post_check.call
        Chef::Log.warn("Post-reload check failed for #{service_name}")
        return false
      end

      Chef::Log.info("Successfully performed zero-downtime reload of #{service_name}")
      true
    end

    # Gets the current Apache worker process PIDs
    # @return [Array<Integer>] Array of worker PIDs
    def httpd_worker_pids
      process_pattern = platform_family?('debian') ? 'apache2' : 'httpd'
      cmd = shell_out("pgrep -f #{process_pattern}")
      
      if cmd.exitstatus.zero?
        cmd.stdout.split("\n").map(&:to_i)
      else
        []
      end
    end

    # Checks if Apache is accepting connections on the specified port
    # @param port [Integer] The port to check
    # @param host [String] The host to check
    # @param path [String] The path to request
    # @param timeout [Integer] Connection timeout in seconds
    # @return [Boolean] True if Apache is accepting connections, false otherwise
    def apache_health_check(port = 80, host = 'localhost', path = '/', timeout = 5)
      require 'socket'
      require 'timeout'

      begin
        Timeout.timeout(timeout) do
          socket = TCPSocket.new(host, port)
          socket.print("HEAD #{path} HTTP/1.1\r\nHost: #{host}\r\nConnection: close\r\n\r\n")
          response = socket.read
          socket.close
          return response.include?('HTTP/1.1 200') || response.include?('HTTP/1.1 301') || 
                 response.include?('HTTP/1.1 302') || response.include?('HTTP/1.1 304')
        end
      rescue => e
        Chef::Log.warn("Health check failed: #{e.message}")
        false
      end
    end

    # Performs a staged rollout of an Apache configuration change
    # @param service_name [String] The Apache service name
    # @param config_path [String] Path to the configuration file being changed
    # @param backup_path [String] Path to back up the original configuration
    # @param rollback_on_failure [Boolean] Whether to roll back if reload fails
    # @param block [Block] The block containing the configuration change
    # @return [Boolean] True if successful, false otherwise
    def staged_rollout(service_name = nil, config_path: nil, backup_path: nil, rollback_on_failure: true, &block)
      service_name ||= httpd_service_name
      
      # Back up current configuration if path provided
      if config_path && backup_path
        directory ::File.dirname(backup_path) do
          recursive true
          action :create
        end
        
        execute "Backing up #{config_path}" do
          command "cp -f #{config_path} #{backup_path}"
          only_if { ::File.exist?(config_path) }
        end
      end
      
      # Define health check for before/after reload
      health_check = -> { apache_health_check }
      
      # Execute the configuration change block
      begin
        yield if block_given?
      rescue => e
        Chef::Log.error("Failed to apply configuration changes: #{e.message}")
        return false
      end
      
      # Validate configuration syntax
      validate_cmd = platform_family?('debian') ? 'apache2ctl -t' : 'httpd -t'
      cmd = shell_out(validate_cmd)
      
      unless cmd.exitstatus.zero?
        Chef::Log.error("Configuration validation failed: #{cmd.stderr}")
        
        if rollback_on_failure && config_path && backup_path && ::File.exist?(backup_path)
          Chef::Log.warn("Rolling back to previous configuration")
          execute "Restoring #{config_path}" do
            command "cp -f #{backup_path} #{config_path}"
          end
        end
        
        return false
      end
      
      # Perform graceful reload with health checks
      success = graceful_reload(service_name, pre_check: health_check, post_check: health_check)
      
      # Roll back if reload failed and rollback is enabled
      if !success && rollback_on_failure && config_path && backup_path && ::File.exist?(backup_path)
        Chef::Log.warn("Reload failed, rolling back to previous configuration")
        execute "Restoring #{config_path}" do
          command "cp -f #{backup_path} #{config_path}"
        end
        
        # Try to reload after rollback
        graceful_reload(service_name)
      end
      
      success
    end
  end
end

Chef::DSL::Recipe.include(Httpd::ZeroDowntime)
Chef::Resource.include(Httpd::ZeroDowntime)