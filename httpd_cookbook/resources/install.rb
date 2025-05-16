# frozen_string_literal: true

unified_mode true

resource_name :httpd_install
provides :httpd_install

description 'Use the httpd_install resource to install Apache HTTP Server'

# Installation properties
property :version, String,
         default: lazy { node['httpd']['version'] },
         description: 'The version of Apache HTTP Server to install'

property :mpm, String,
         equal_to: %w(event worker prefork),
         default: lazy { node['httpd']['mpm'] },
         description: 'MPM module to use'

property :install_method, String,
         equal_to: %w(package source),
         default: lazy { node['httpd']['install_method'] },
         description: 'Installation method for Apache HTTP Server'

property :package_name, String,
         default: lazy { node['httpd']['package_name'] },
         description: 'Package name for Apache HTTP Server'

property :source_url, String,
         default: lazy { node['httpd']['source']['url'] },
         description: 'Source URL for Apache HTTP Server'

property :source_checksum, [String, nil],
         default: lazy { node['httpd']['source']['checksum'] },
         description: 'Source package checksum'

property :source_prefix, String,
         default: lazy { node['httpd']['source']['prefix'] },
         description: 'Installation prefix for source installation'

property :source_configure_options, Array,
         default: lazy { node['httpd']['source']['configure_options'] },
         description: 'Configure options for source installation'

property :source_dependencies, Array,
         default: lazy { node['httpd']['source']['dependencies'] },
         description: 'Dependencies for source installation'

property :modules, Array,
         default: lazy { node['httpd']['modules'] },
         description: 'Modules to enable'

property :disabled_modules, Array,
         default: lazy { node['httpd']['disabled_modules'] },
         description: 'Modules to disable'

action_class do
  def install_deps
    package 'httpd-deps' do
      package_name new_resource.source_dependencies
      action :install
    end
  end

  def install_from_source
    # Create directories
    directory "#{Chef::Config[:file_cache_path]}/httpd" do
      recursive true
      action :create
    end

    # Download source
    remote_file "#{Chef::Config[:file_cache_path]}/httpd/httpd-#{new_resource.version}.tar.gz" do
      source new_resource.source_url
      checksum new_resource.source_checksum if new_resource.source_checksum
      action :create
    end

    # Extract source
    execute 'extract-httpd' do
      command "tar -xzf httpd-#{new_resource.version}.tar.gz"
      cwd "#{Chef::Config[:file_cache_path]}/httpd"
      not_if { ::File.exist?("#{Chef::Config[:file_cache_path]}/httpd/httpd-#{new_resource.version}/configure") }
      action :run
    end

    # Configure and install
    bash 'compile-httpd' do
      cwd "#{Chef::Config[:file_cache_path]}/httpd/httpd-#{new_resource.version}"
      code <<~EOH
        ./configure #{new_resource.source_configure_options.join(' ')}
        make
        make install
      EOH
      not_if { ::File.exist?("#{new_resource.source_prefix}/bin/httpd") }
      action :run
    end

    # Create symbolic links
    link '/usr/sbin/httpd' do
      to "#{new_resource.source_prefix}/bin/httpd"
      only_if { ::File.exist?("#{new_resource.source_prefix}/bin/httpd") }
      action :create
    end
  end

  def install_from_package
    # Install Apache HTTP Server package
    package 'httpd' do
      package_name new_resource.package_name
      action :install
    end

    # Configure MPM module
    template "#{node['httpd']['conf_dir']}/mpm.conf" do
      source 'mpm.conf.erb'
      cookbook 'httpd'
      owner 'root'
      group 'root'
      mode '0644'
      variables(
        mpm: new_resource.mpm,
        server_limit: node['httpd']['performance']['server_limit'],
        max_clients: node['httpd']['performance']['max_clients'],
        max_connections_per_child: node['httpd']['performance']['max_connections_per_child'],
        max_request_workers: node['httpd']['performance']['max_request_workers'],
        start_servers: node['httpd']['performance']['start_servers'],
        min_spare_threads: node['httpd']['performance']['min_spare_threads'],
        max_spare_threads: node['httpd']['performance']['max_spare_threads'],
        thread_limit: node['httpd']['performance']['thread_limit'],
        threads_per_child: node['httpd']['performance']['threads_per_child'],
        prefork_start_servers: node['httpd']['performance']['prefork']['start_servers'],
        prefork_min_spare_servers: node['httpd']['performance']['prefork']['min_spare_servers'],
        prefork_max_spare_servers: node['httpd']['performance']['prefork']['max_spare_servers'],
        prefork_server_limit: node['httpd']['performance']['prefork']['server_limit'],
        prefork_max_clients: node['httpd']['performance']['prefork']['max_clients'],
        prefork_max_requests_per_child: node['httpd']['performance']['prefork']['max_requests_per_child'],
        worker_start_servers: node['httpd']['performance']['worker']['start_servers'],
        worker_min_spare_threads: node['httpd']['performance']['worker']['min_spare_threads'],
        worker_max_spare_threads: node['httpd']['performance']['worker']['max_spare_threads'],
        worker_thread_limit: node['httpd']['performance']['worker']['thread_limit'],
        worker_threads_per_child: node['httpd']['performance']['worker']['threads_per_child'],
        worker_server_limit: node['httpd']['performance']['worker']['server_limit']
      )
      action :create
    end
  end

  def setup_directories
    # Create necessary directories
    %w(
      conf_available_dir
      conf_enabled_dir
      includes_dir
    ).each do |dir|
      directory node['httpd'][dir] do
        owner 'root'
        group 'root'
        mode '0755'
        recursive true
        action :create
      end
    end

    # Create log directory
    directory ::File.dirname(node['httpd']['error_log']) do
      owner node['httpd']['user']
      group node['httpd']['group']
      mode '0755'
      recursive true
      action :create
    end

    # Create run directory
    directory ::File.dirname(node['httpd']['pid_file']) do
      owner node['httpd']['user']
      group node['httpd']['group']
      mode '0755'
      recursive true
      action :create
    end
  end

  def setup_modules
    case node['platform_family']
    when 'rhel', 'fedora', 'amazon'
      # Create modules directory
      directory node['httpd']['mod_dir'] do
        owner 'root'
        group 'root'
        mode '0755'
        recursive true
        action :create
      end

      # Create module configuration files
      new_resource.modules.each do |mod|
        file "#{node['httpd']['mod_dir']}/#{mod}.load" do
          content "LoadModule #{mod}_module #{node['httpd']['libexec_dir']}/mod_#{mod}.so\n"
          owner 'root'
          group 'root'
          mode '0644'
          action :create
          not_if { ::File.exist?("#{node['httpd']['mod_dir']}/#{mod}.load") }
        end
      end

      # Remove disabled modules
      new_resource.disabled_modules.each do |mod|
        file "#{node['httpd']['mod_dir']}/#{mod}.load" do
          action :delete
          only_if { ::File.exist?("#{node['httpd']['mod_dir']}/#{mod}.load") }
        end
      end
    when 'debian'
      # Use a2enmod to enable modules
      new_resource.modules.each do |mod|
        execute "a2enmod #{mod}" do
          command "/usr/sbin/a2enmod #{mod}"
          not_if { ::File.exist?("#{node['httpd']['mod_enabled_dir']}/#{mod}.load") }
          action :run
        end
      end

      # Use a2dismod to disable modules
      new_resource.disabled_modules.each do |mod|
        execute "a2dismod #{mod}" do
          command "/usr/sbin/a2dismod #{mod}"
          only_if { ::File.exist?("#{node['httpd']['mod_enabled_dir']}/#{mod}.load") }
          action :run
        end
      end
    end
  end

  def configure_selinux
    # Only configure SELinux on RHEL platforms if enabled
    if platform_family?('rhel', 'fedora', 'amazon') && node['httpd']['selinux']['enabled']
      # Install SELinux policy package
      package 'policycoreutils-python' do
        package_name platform?('amazon', 'fedora') ? 'policycoreutils-python-utils' : 'policycoreutils-python'
        action :install
      end

      # Set SELinux context for document root
      directory node['httpd']['default_vhost']['document_root'] do
        owner node['httpd']['user']
        group node['httpd']['group']
        mode '0755'
        recursive true
        action :create
      end

      execute 'set-httpd-selinux-context' do
        command "chcon -R -t #{node['httpd']['selinux']['docroot_context']} #{node['httpd']['default_vhost']['document_root']}"
        not_if "ls -ldZ #{node['httpd']['default_vhost']['document_root']} | grep -q #{node['httpd']['selinux']['docroot_context']}"
        action :run
        only_if 'sestatus | grep -q "SELinux status: enabled"'
      end

      # Configure SELinux ports
      node['httpd']['selinux']['ports'].each do |port|
        execute "selinux-port-#{port}" do
          command "semanage port -a -t http_port_t -p tcp #{port}"
          not_if "semanage port -l | grep -w 'http_port_t' | grep -w #{port}"
          action :run
          only_if 'sestatus | grep -q "SELinux status: enabled"'
        end
      end

      # Allow HTTP connections
      if node['httpd']['selinux']['allow_http_connections']
        execute 'selinux-httpd-connections' do
          command 'setsebool -P httpd_can_network_connect_http 1'
          action :run
          only_if 'sestatus | grep -q "SELinux status: enabled"'
          not_if 'getsebool httpd_can_network_connect_http | grep -q "on$"'
        end
      end

      # Allow general network connections
      if node['httpd']['selinux']['allow_network_connect']
        execute 'selinux-httpd-network-connect' do
          command 'setsebool -P httpd_can_network_connect 1'
          action :run
          only_if 'sestatus | grep -q "SELinux status: enabled"'
          not_if 'getsebool httpd_can_network_connect | grep -q "on$"'
        end
      end
    end
  end

  def configure_firewall
    # Only configure firewall if enabled
    if node['httpd']['firewall']['enabled']
      node['httpd']['firewall']['allow_ports'].each do |port|
        firewall_rule "httpd-port-#{port}" do
          port port
          protocol :tcp
          source node['httpd']['firewall']['source_addresses']
          command :allow
          action :create
        end
      end
    end
  end

  def configure_logrotate
    # Only configure logrotate if enabled
    return unless node['httpd']['logrotate']['enabled']

    logrotate_app 'httpd' do
      path case node['platform_family']
           when 'rhel', 'fedora', 'amazon'
             '/var/log/httpd/*.log'
           when 'debian'
             '/var/log/apache2/*.log'
           end
      frequency node['httpd']['logrotate']['frequency']
      rotate node['httpd']['logrotate']['rotate']
      options node['httpd']['logrotate']['options']
      postrotate node['httpd']['logrotate']['postrotate']
      action :enable
    end
  end
end

action :install do
  # Install dependencies if source installation
  install_deps if new_resource.install_method == 'source'

  # Install Apache HTTP Server based on installation method
  case new_resource.install_method
  when 'package'
    install_from_package
  when 'source'
    install_from_source
  end

  # Set up directories
  setup_directories

  # Configure modules
  setup_modules

  # Configure SELinux
  configure_selinux

  # Configure firewall
  configure_firewall

  # Configure logrotate
  configure_logrotate
end

action :remove do
  case new_resource.install_method
  when 'package'
    package 'httpd' do
      package_name new_resource.package_name
      action :remove
    end
  when 'source'
    # No need to remove from source installation
    Chef::Log.info('Removal of source installation is not supported')
  end
end