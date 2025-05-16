# frozen_string_literal: true

unified_mode true

resource_name :zabbix_agent
provides :zabbix_agent

description 'Use the zabbix_agent resource to install and configure Zabbix agent'

# Installation properties
property :version, String,
         default: lazy { node['zabbix']['agent']['version'] },
         description: 'The version of Zabbix agent to install'
         
property :install_method, String,
         equal_to: %w(package source),
         default: 'package',
         description: 'Installation method for Zabbix agent'

# Configuration properties
property :servers, [Array, String],
         default: lazy { node['zabbix']['agent']['servers'] },
         coerce: proc { |v| v.is_a?(String) ? [v] : v },
         description: 'List of Zabbix servers for passive checks'

property :servers_active, [Array, String],
         default: lazy { node['zabbix']['agent']['servers_active'] },
         coerce: proc { |v| v.is_a?(String) ? [v] : v },
         description: 'List of Zabbix servers for active checks'

property :hostname, String,
         default: lazy { node['zabbix']['agent']['hostname'] },
         description: 'Hostname reported by agent to server'

property :include_dir, String,
         default: lazy { node['zabbix']['agent']['include_dir'] },
         description: 'Directory for agent configuration snippets'

property :log_file, String,
         default: lazy { node['zabbix']['agent']['log_file'] },
         description: 'Location of agent log file'

property :log_level, [Integer, String],
         default: lazy { node['zabbix']['agent']['log_level'] },
         description: 'Log level for agent (0-5)'

property :timeout, [Integer, String],
         default: lazy { node['zabbix']['agent']['timeout'] },
         description: 'Timeout for processing checks (1-30)'

property :listen_port, [Integer, String],
         default: lazy { node['zabbix']['agent']['listen_port'] },
         description: 'Port agent listens on for server connections'

property :enable_remote_commands, [Integer, String, TrueClass, FalseClass],
         default: lazy { node['zabbix']['agent']['enable_remote_commands'] },
         coerce: proc { |v| v.is_a?(TrueClass) ? 1 : v.is_a?(FalseClass) ? 0 : v },
         description: 'Enable remote commands (0,1)'

property :tls_connect, String,
         default: lazy { node['zabbix']['agent']['tls_connect'] },
         description: 'TLS connection mode for active checks'

property :tls_accept, String,
         default: lazy { node['zabbix']['agent']['tls_accept'] },
         description: 'TLS connection mode for passive checks'

property :tls_psk_identity, String,
         default: lazy { node['zabbix']['agent']['tls_psk_identity'] },
         description: 'TLS PSK identity string'

property :tls_psk_file, String,
         default: lazy { node['zabbix']['agent']['tls_psk_file'] },
         description: 'Full path to TLS PSK file'

property :tls_cert_file, String,
         default: lazy { node['zabbix']['agent']['tls_cert_file'] },
         description: 'Full path to TLS certificate file'

property :tls_key_file, String,
         default: lazy { node['zabbix']['agent']['tls_key_file'] },
         description: 'Full path to TLS key file'

property :tls_ca_file, String,
         default: lazy { node['zabbix']['agent']['tls_ca_file'] },
         description: 'Full path to TLS CA file'

# service properties
property :service_name, String,
         default: 'zabbix-agent',
         description: 'Name of the agent service'

property :service_provider, [String, Symbol],
         default: lazy { Chef::Platform::ServiceHelpers.service_resource_providers.first },
         description: 'Provider for the agent service'

property :service_enabled, [TrueClass, FalseClass],
         default: true,
         description: 'Enable the agent service'

property :service_auto_start, [TrueClass, FalseClass],
         default: true,
         description: 'Auto-start the agent service'

action_class do
  def create_directories
    # Create directories
    %w(
      dir
      log_dir
      run_dir
      socket_dir
    ).each do |dir|
      directory node['zabbix'][dir] do
        owner node['zabbix']['user']
        group node['zabbix']['group']
        mode '0755'
        recursive true
        action :create
        not_if { ::File.directory?(node['zabbix'][dir]) }
      end
    end

    # Create agent include directory
    directory new_resource.include_dir do
      owner node['zabbix']['user']
      group node['zabbix']['group']
      mode '0755'
      recursive true
      action :create
      not_if { ::File.directory?(new_resource.include_dir) }
    end
  end

  def install_package
    # Install Zabbix agent package
    package 'zabbix-agent' do
      package_name case node['platform_family']
                  when 'rhel', 'amazon'
                    'zabbix-agent'
                  when 'debian'
                    'zabbix-agent'
                  end
      action :install
      options '--enablerepo=zabbix' if %w(rhel amazon).include? node['platform_family']
    end
  end

  def install_from_source
    # Required variables for source installation
    version = new_resource.version
    branch = node['zabbix']['agent']['branch']
    src_url = "https://github.com/zabbix/zabbix/archive/#{branch}.zip"
    src_dir = "#{Chef::Config[:file_cache_path]}/zabbix-agent-#{version}"
    install_dir = node['zabbix']['install_dir']

    # Requirements for source build 
    build_essential 'install_buildtools' do
      action :install
    end

    # Download and extract source
    remote_file "#{Chef::Config[:file_cache_path]}/zabbix-#{branch}.zip" do
      source src_url
      mode '0644'
      action :create
    end

    bash 'extract_zabbix_source' do
      code <<-EOH
        unzip #{Chef::Config[:file_cache_path]}/zabbix-#{branch}.zip -d #{Chef::Config[:file_cache_path]}
        mv #{Chef::Config[:file_cache_path]}/zabbix-#{branch} #{src_dir}
      EOH
      not_if { ::File.exist?(src_dir) }
    end

    # Configure and make Zabbix agent
    bash 'install_zabbix_agent' do
      cwd src_dir
      code <<-EOH
        ./configure --prefix=#{install_dir} \
                   --enable-agent \
                   --enable-ipv6 \
                   --with-openssl \
                   --with-libpcre \
                   --with-libcurl \
                   --with-net-snmp
        make install
      EOH
      not_if { ::File.exist?("#{install_dir}/sbin/zabbix_agentd") }
    end

    # Create symlinks
    link '/usr/sbin/zabbix_agentd' do
      to "#{install_dir}/sbin/zabbix_agentd"
    end

    link '/usr/sbin/zabbix_get' do
      to "#{install_dir}/bin/zabbix_get"
    end

    # Create init script or systemd service file
    if node['init_package'] == 'systemd'
      template '/etc/systemd/system/zabbix-agent.service' do
        source 'zabbix-agent.service.erb'
        owner 'root'
        group 'root'
        mode '0644'
        notifies :run, 'execute[systemctl-daemon-reload]', :immediately
      end

      execute 'systemctl-daemon-reload' do
        command '/bin/systemctl daemon-reload'
        action :nothing
      end
    else
      template '/etc/init.d/zabbix-agent' do
        source 'zabbix-agent.init.erb'
        owner 'root'
        group 'root'
        mode '0755'
      end
    end
  end

  def configure_agent
    # Create agent configuration from template
    template node['zabbix']['agent']['config_file'] do
      source 'zabbix_agentd.conf.erb'
      owner 'root'
      group 'root'
      mode '0640'
      variables(
        servers: new_resource.servers.join(','),
        servers_active: new_resource.servers_active.join(','),
        hostname: new_resource.hostname,
        include_dir: new_resource.include_dir,
        pid_file: node['zabbix']['agent']['pid_file'],
        log_file: new_resource.log_file,
        log_level: new_resource.log_level,
        timeout: new_resource.timeout,
        enable_remote_commands: new_resource.enable_remote_commands,
        listen_port: new_resource.listen_port,
        tls_connect: new_resource.tls_connect,
        tls_accept: new_resource.tls_accept,
        tls_psk_identity: new_resource.tls_psk_identity,
        tls_psk_file: new_resource.tls_psk_file,
        tls_cert_file: new_resource.tls_cert_file,
        tls_key_file: new_resource.tls_key_file,
        tls_ca_file: new_resource.tls_ca_file
      )
      notifies :restart, "service[#{new_resource.service_name}]", :delayed
    end
  end

  def setup_service
    # Configure and manage the agent service
    service new_resource.service_name do
      supports status: true, start: true, stop: true, restart: true
      provider new_resource.service_provider unless new_resource.service_provider.nil?
      action [:enable, :start]
      only_if { new_resource.service_enabled && new_resource.service_auto_start }
    end
  end
end

action :install do
  # Ensure user and group exist
  group node['zabbix']['group'] do
    system true
    action :create
  end

  user node['zabbix']['user'] do
    comment 'Zabbix user'
    gid node['zabbix']['group']
    system true
    shell '/bin/false'
    home node['zabbix']['home_dir']
    action :create
  end

  # Create required directories
  create_directories

  # Install based on method
  case new_resource.install_method
  when 'package'
    install_package
  when 'source'
    install_from_source
  end

  # Configure agent
  configure_agent

  # Setup service
  setup_service
end

action :configure do
  # Only configure without installation
  configure_agent

  # Ensure service is configured
  setup_service
end

action :remove do
  service new_resource.service_name do
    action [:stop, :disable]
    only_if { ::File.exist?("/etc/init.d/#{new_resource.service_name}") || ::File.exist?("/etc/systemd/system/#{new_resource.service_name}.service") }
  end

  package 'zabbix-agent' do
    action :remove
    only_if { new_resource.install_method == 'package' }
  end
end