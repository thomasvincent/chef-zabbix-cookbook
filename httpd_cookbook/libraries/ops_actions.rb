# frozen_string_literal: true

module Httpd
  module OpsActions
    # Create a backup of all Apache configuration files
    # @param backup_dir [String] Directory to store backups
    # @param label [String] Optional label to add to backup filename
    # @return [String] Path to the backup archive
    def backup_config(backup_dir = '/var/backups/httpd', label = nil)
      require 'fileutils'
      require 'time'
      
      # Create backup directory if it doesn't exist
      FileUtils.mkdir_p(backup_dir) unless Dir.exist?(backup_dir)
      
      # Determine Apache config directory
      config_dir = case node['platform_family']
                  when 'debian'
                    '/etc/apache2'
                  when 'rhel', 'fedora', 'amazon'
                    '/etc/httpd'
                  when 'suse'
                    '/etc/apache2'
                  else
                    '/etc/httpd'
                  end
      
      # Generate backup filename with timestamp
      timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
      label_suffix = label ? "-#{label}" : ''
      backup_file = "#{backup_dir}/apache-config-#{timestamp}#{label_suffix}.tar.gz"
      
      # Create tar.gz archive of configuration directory
      cmd = shell_out("tar -czf #{backup_file} -C #{::File.dirname(config_dir)} #{::File.basename(config_dir)}")
      
      unless cmd.exitstatus.zero?
        Chef::Log.error("Failed to create backup archive: #{cmd.stderr}")
        return nil
      end
      
      # Add metadata file with information about the backup
      metadata = {
        'timestamp' => timestamp,
        'hostname' => node['hostname'],
        'platform' => node['platform'],
        'platform_version' => node['platform_version'],
        'apache_version' => apache_version,
        'config_dir' => config_dir
      }
      
      metadata_file = "#{backup_dir}/apache-config-#{timestamp}#{label_suffix}.json"
      file metadata_file do
        content JSON.pretty_generate(metadata)
        mode '0644'
      end
      
      Chef::Log.info("Apache configuration backed up to #{backup_file}")
      backup_file
    end
    
    # Restore Apache configuration from a backup
    # @param backup_file [String] Path to the backup archive
    # @param force [Boolean] Whether to restore even if checksum differs
    # @return [Boolean] True if restored successfully, false otherwise
    def restore_config(backup_file, force = false)
      unless ::File.exist?(backup_file)
        Chef::Log.error("Backup file not found: #{backup_file}")
        return false
      end
      
      # Determine Apache config directory
      config_dir = case node['platform_family']
                  when 'debian'
                    '/etc/apache2'
                  when 'rhel', 'fedora', 'amazon'
                    '/etc/httpd'
                  when 'suse'
                    '/etc/apache2'
                  else
                    '/etc/httpd'
                  end
      
      # Create temporary directory for extraction
      require 'tmpdir'
      temp_dir = Dir.mktmpdir('apache-restore')
      
      begin
        # Extract archive to temporary directory
        cmd = shell_out("tar -xzf #{backup_file} -C #{temp_dir}")
        
        unless cmd.exitstatus.zero?
          Chef::Log.error("Failed to extract backup archive: #{cmd.stderr}")
          return false
        end
        
        # Verify platform compatibility
        metadata_file = backup_file.sub('.tar.gz', '.json')
        if ::File.exist?(metadata_file)
          metadata = JSON.parse(::File.read(metadata_file))
          
          unless force
            if metadata['platform'] != node['platform'] || 
               metadata['platform_version'].to_i != node['platform_version'].to_i
              Chef::Log.warn("Platform mismatch: backup from #{metadata['platform']} #{metadata['platform_version']}, " +
                            "current platform is #{node['platform']} #{node['platform_version']}")
              Chef::Log.warn("Use force=true to override this check")
              return false
            end
          end
        end
        
        # Stop Apache service
        service_name = httpd_service_name
        service service_name do
          action :stop
        end
        
        # Backup current configuration before overwriting
        backup_dir = ::File.dirname(backup_file)
        current_backup = backup_config(backup_dir, 'pre-restore')
        
        # Copy extracted files to Apache config directory
        extracted_config = ::File.join(temp_dir, ::File.basename(config_dir))
        if ::File.directory?(extracted_config)
          FileUtils.rm_rf(config_dir)
          FileUtils.cp_r(extracted_config, ::File.dirname(config_dir))
          FileUtils.chmod_R(0755, config_dir)
          
          # Fix ownership
          user = node['platform_family'] == 'debian' ? 'www-data' : 'apache'
          group = node['platform_family'] == 'debian' ? 'www-data' : 'apache'
          
          cmd = shell_out("chown -R root:root #{config_dir}")
          unless cmd.exitstatus.zero?
            Chef::Log.warn("Failed to change ownership of config directory: #{cmd.stderr}")
          end
        else
          Chef::Log.error("Expected configuration directory not found in backup: #{extracted_config}")
          return false
        end
        
        # Validate configuration
        validate_cmd = node['platform_family'] == 'debian' ? 'apache2ctl -t' : 'httpd -t'
        cmd = shell_out(validate_cmd)
        
        unless cmd.exitstatus.zero?
          Chef::Log.error("Restored configuration has syntax errors: #{cmd.stderr}")
          Chef::Log.info("Rolling back to previous configuration")
          
          # Roll back to previous configuration
          restore_config(current_backup, true) if current_backup
          
          return false
        end
        
        # Start Apache service
        service service_name do
          action :start
        end
        
        Chef::Log.info("Apache configuration restored successfully from #{backup_file}")
        true
      ensure
        # Clean up temporary directory
        FileUtils.remove_entry(temp_dir) if temp_dir && ::File.directory?(temp_dir)
      end
    end
    
    # Implement blue-green deployment for Apache configuration
    # @param config_dir [String] Base configuration directory
    # @param blue_dir [String] Blue environment directory
    # @param green_dir [String] Green environment directory
    # @param block [Block] Block to execute to prepare the inactive environment
    # @return [Symbol] :blue or :green indicating which environment is now active
    def blue_green_deployment(config_dir = nil, blue_dir = nil, green_dir = nil, &block)
      config_dir ||= case node['platform_family']
                    when 'debian'
                      '/etc/apache2'
                    when 'rhel', 'fedora', 'amazon'
                      '/etc/httpd'
                    else
                      '/etc/httpd'
                    end
      
      blue_dir ||= "#{config_dir}-blue"
      green_dir ||= "#{config_dir}-green"
      
      # Determine which environment is currently active
      if ::File.symlink?(config_dir)
        active_env = ::File.readlink(config_dir) == blue_dir ? :blue : :green
      else
        # If config_dir is a regular directory, we need to initialize blue-green
        unless ::File.directory?(blue_dir)
          FileUtils.mkdir_p(blue_dir)
          FileUtils.cp_r(Dir["#{config_dir}/*"], blue_dir)
        end
        
        active_env = :blue
      end
      
      # Set inactive environment
      inactive_env = active_env == :blue ? :green : :blue
      inactive_dir = inactive_env == :blue ? blue_dir : green_dir
      
      # Ensure inactive environment directory exists
      FileUtils.mkdir_p(inactive_dir) unless ::File.directory?(inactive_dir)
      
      # Copy contents from active to inactive if inactive is empty
      active_dir = active_env == :blue ? blue_dir : green_dir
      if Dir["#{inactive_dir}/*"].empty?
        FileUtils.cp_r(Dir["#{active_dir}/*"], inactive_dir)
      end
      
      # Execute block to prepare inactive environment
      if block_given?
        # Set environment variables for the block to use
        ENV['HTTPD_INACTIVE_ENV'] = inactive_env.to_s
        ENV['HTTPD_INACTIVE_DIR'] = inactive_dir
        
        yield(inactive_env, inactive_dir)
      end
      
      # Validate the inactive environment configuration
      if node['platform_family'] == 'debian'
        validate_cmd = "APACHE_CONFDIR=#{inactive_dir} apache2ctl -t"
      else
        validate_cmd = "httpd -t -c \"ServerRoot #{inactive_dir}\""
      end
      
      cmd = shell_out(validate_cmd)
      unless cmd.exitstatus.zero?
        Chef::Log.error("Inactive environment configuration has syntax errors: #{cmd.stderr}")
        return active_env # Return current active env since switch was not made
      end
      
      # Back up current active environment
      backup_label = "before-#{inactive_env}-switch"
      backup_config(nil, backup_label)
      
      # Stop Apache service
      service_name = httpd_service_name
      service service_name do
        action :stop
      end
      
      # Switch to inactive environment
      if ::File.symlink?(config_dir)
        FileUtils.rm(config_dir)
      else
        FileUtils.mv(config_dir, "#{config_dir}-original-#{Time.now.to_i}")
      end
      
      FileUtils.ln_s(inactive_dir, config_dir)
      
      # Start Apache service
      service service_name do
        action :start
      end
      
      # Verify Apache started successfully
      is_running = false
      3.times do |i|
        sleep(2)
        status_cmd = shell_out("systemctl is-active #{service_name} || service #{service_name} status")
        is_running = status_cmd.exitstatus.zero?
        break if is_running
      end
      
      unless is_running
        Chef::Log.error("Failed to start Apache with the new configuration")
        
        # Roll back to previous configuration
        service service_name do
          action :stop
        end
        
        FileUtils.rm(config_dir)
        FileUtils.ln_s(active_dir, config_dir)
        
        service service_name do
          action :start
        end
        
        return active_env # Return original active env since switch failed
      end
      
      # Return the new active environment
      inactive_env
    end
    
    # Get the current Apache version
    # @return [String] Apache version string
    def apache_version
      cmd = if node['platform_family'] == 'debian'
              shell_out('apache2 -v')
            else
              shell_out('httpd -v')
            end
      
      if cmd.exitstatus.zero?
        match = cmd.stdout.match(/version: Apache\/(\d+\.\d+\.\d+)/i)
        match ? match[1] : 'unknown'
      else
        'unknown'
      end
    end
  end
end

Chef::DSL::Recipe.include(Httpd::OpsActions)
Chef::Resource.include(Httpd::OpsActions)