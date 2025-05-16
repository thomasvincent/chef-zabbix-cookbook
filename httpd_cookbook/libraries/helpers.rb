# frozen_string_literal: true

module Httpd
  module Helpers
    # Check if systemd is in use
    def systemd?
      ::File.directory?('/run/systemd/system') || ::File.directory?('/sys/fs/cgroup/systemd')
    end

    # Get system memory in MB with better error handling
    def system_memory_mb
      if node['memory'] && node['memory']['total']
        node['memory']['total'].to_i / 1024
      else
        Chef::Log.warn('Could not determine system memory, using default value')
        2048 # Default to 2GB if memory info not available
      end
    rescue StandardError => e
      Chef::Log.warn("Error calculating system memory: #{e.message}")
      2048 # Default to 2GB on error
    end

    # Calculate optimal MaxRequestWorkers based on system memory
    def calculate_max_request_workers
      # For systems with limited memory, we reduce the MaxRequestWorkers
      # Apache docs suggest 150 active httpd processes is adequate for a busy server
      mem = system_memory_mb
      
      # Use a more precise algorithm based on RAM, but with good defaults
      case
      when mem < 1024 # Less than 1GB RAM
        [15, (mem / 10).to_i].max
      when mem < 4096 # 1-4GB RAM
        [40, (mem / 15).to_i].max
      when mem < 16384 # 4-16GB RAM
        [100, (mem / 20).to_i].max
      else # More than 16GB RAM
        [250, (mem / 40).to_i].max
      end
    rescue StandardError => e
      Chef::Log.warn("Error calculating MaxRequestWorkers: #{e.message}. Using default value.")
      150 # Reasonable default if calculation fails
    end

    # Calculate optimal ThreadsPerChild based on CPU count
    def calculate_threads_per_child
      # Default to 25 threads per child, but adjust based on CPU count
      cpu_count = cpu_cores
      
      # For low CPU systems, reduce ThreadsPerChild
      case 
      when cpu_count <= 2
        [8, cpu_count * 4].min
      when cpu_count <= 4
        [16, cpu_count * 4].min
      when cpu_count <= 8
        25
      else
        # For high CPU systems, increase ThreadsPerChild
        [50, cpu_count * 6].min
      end
    rescue StandardError => e
      Chef::Log.warn("Error calculating ThreadsPerChild: #{e.message}. Using default value.")
      25 # Reasonable default if calculation fails
    end

    # Get number of CPU cores with better error handling
    def cpu_cores
      if node['cpu'] && node['cpu']['total']
        node['cpu']['total'].to_i
      else
        Chef::Log.warn('Could not determine CPU count, using default value')
        2 # Default to 2 cores if CPU info not available
      end
    rescue StandardError => e
      Chef::Log.warn("Error determining CPU count: #{e.message}")
      2 # Default to 2 cores on error
    end

    # Calculate optimal ServerLimit based on max_request_workers and threads_per_child
    def calculate_server_limit(max_request_workers, threads_per_child)
      # Calculate ServerLimit with a small buffer
      ((max_request_workers / threads_per_child.to_f) * 1.1).ceil
    rescue ZeroDivisionError
      Chef::Log.warn('ThreadsPerChild is zero! Using default ServerLimit')
      16 # Reasonable default
    rescue StandardError => e
      Chef::Log.warn("Error calculating ServerLimit: #{e.message}. Using default value.")
      16 # Reasonable default if calculation fails
    end

    # Create module configuration filename based on platform
    def module_config_name(module_name)
      case node['platform_family']
      when 'rhel', 'fedora', 'amazon'
        # RHEL/CentOS/Fedora use 00-NAME.conf in modules.d
        "00-#{module_name}.conf"
      when 'debian'
        # Debian/Ubuntu use NAME.conf in mods-available
        "#{module_name}.conf"
      when 'suse'
        # SUSE uses NAME.conf in conf.d
        "#{module_name}.conf"
      when 'arch'
        # Arch uses NAME.conf in conf.d
        "#{module_name}.conf"
      else
        "#{module_name}.conf"
      end
    end

    # Generate Apache version properties from node attributes
    def apache_version_properties
      {
        major: node['httpd']['version'].split('.')[0],
        minor: node['httpd']['version'].split('.')[1],
        patch: node['httpd']['version'].split('.')[2],
        full: node['httpd']['version']
      }
    rescue StandardError => e
      Chef::Log.warn("Error determining Apache version: #{e.message}. Using default values.")
      { major: '2', minor: '4', patch: '0', full: '2.4.0' }
    end

    # Check if the Apache version is 2.4+
    def apache_24?
      version = apache_version_properties
      (version[:major].to_i == 2 && version[:minor].to_i >= 4) || version[:major].to_i > 2
    end

    # Get appropriate HTTP/2 module name based on Apache version
    def http2_module_name
      apache_24? ? 'http2' : nil # HTTP/2 is only supported in Apache 2.4+
    end

    # Safe file existence check with proper error handling
    def file_exist?(path)
      ::File.exist?(path)
    rescue StandardError => e
      Chef::Log.warn("Error checking if file exists at #{path}: #{e.message}")
      false
    end

    # Safe directory existence check with proper error handling
    def directory_exist?(path)
      ::File.directory?(path)
    rescue StandardError => e
      Chef::Log.warn("Error checking if directory exists at #{path}: #{e.message}")
      false
    end

    # Get default configuration file path for Apache
    def default_config_path
      case node['platform_family']
      when 'debian'
        '/etc/apache2/apache2.conf'
      when 'rhel', 'fedora', 'amazon'
        '/etc/httpd/conf/httpd.conf'
      when 'suse'
        '/etc/apache2/httpd.conf'
      when 'arch'
        '/etc/httpd/conf/httpd.conf'
      else
        '/etc/httpd/conf/httpd.conf'
      end
    end

    # Additional helper to setup SELinux for httpd
    def setup_selinux_for_httpd(ports = [80, 443])
      return unless platform_family?('rhel', 'fedora', 'amazon')
      return unless node['httpd']['selinux'] && node['httpd']['selinux']['enabled']
      
      # First check if SELinux is actually enabled
      selinux_enabled = shell_out!('getenforce').stdout.strip != 'Disabled' rescue false
      return unless selinux_enabled
      
      # Install required packages for SELinux management
      package_name = platform?('amazon', 'fedora') ? 'policycoreutils-python-utils' : 'policycoreutils-python'
      package package_name do
        action :install
      end
      
      # Add ports to SELinux http port type
      Array(ports).each do |port|
        execute "selinux-port-#{port}" do
          command "semanage port -a -t http_port_t -p tcp #{port}"
          not_if "semanage port -l | grep -w 'http_port_t' | grep -w #{port}"
          action :run
        end
      end
      
      true
    rescue StandardError => e
      Chef::Log.warn("Error setting up SELinux for httpd: #{e.message}")
      false
    end
    
    # Get correct service name for platform
    def httpd_service_name
      case node['platform_family']
      when 'debian' 
        'apache2'
      when 'rhel', 'fedora', 'amazon'
        'httpd'
      when 'suse'
        'apache2'
      when 'arch'
        'httpd'
      else
        'httpd'
      end
    end
  end
end

Chef::DSL::Recipe.include(Httpd::Helpers)
Chef::Resource.include(Httpd::Helpers)