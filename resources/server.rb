# frozen_string_literal: true

unified_mode true

resource_name :zabbix_server
provides :zabbix_server

description 'Use the zabbix_server resource to install and configure Zabbix server'

# Installation properties
property :version, String,
         default: lazy { node['zabbix']['server']['version'] },
         description: 'The version of Zabbix server to install'
         
property :install_method, String,
         equal_to: %w(package source),
         default: 'package',
         description: 'Installation method for Zabbix server'

# Database properties
property :database_type, String,
         equal_to: %w(postgresql mysql),
         default: lazy { node['zabbix']['server']['database']['type'] },
         description: 'Type of database to use with Zabbix server'

property :database_host, String,
         default: lazy { node['zabbix']['server']['database']['host'] },
         description: 'Database server hostname'

property :database_port, [Integer, String],
         default: lazy { node['zabbix']['server']['database']['port'] },
         description: 'Database server port'

property :database_name, String,
         default: lazy { node['zabbix']['server']['database']['name'] },
         description: 'Database name for Zabbix server'

property :database_user, String,
         default: lazy { node['zabbix']['server']['database']['user'] },
         description: 'Database username for Zabbix server'

property :database_password, String,
         default: lazy { node['zabbix']['server']['database']['password'] },
         sensitive: true,
         description: 'Database password for Zabbix server'

property :database_socket, String,
         default: lazy { node['zabbix']['server']['database']['socket'] },
         description: 'Database socket path'

property :database_schema, String,
         default: lazy { node['zabbix']['server']['database']['schema'] },
         description: 'Database schema name (PostgreSQL only)'

property :database_tls_connect, String,
         default: lazy { node['zabbix']['server']['database']['tls_connect'] },
         description: 'Database TLS connection mode'

# Configuration properties
property :server_port, [Integer, String],
         default: lazy { node['zabbix']['server']['listen_port'] },
         description: 'Port server listens on'

property :log_file, String,
         default: lazy { node['zabbix']['server']['log_file'] },
         description: 'Location of server log file'

property :log_level, [Integer, String],
         default: lazy { node['zabbix']['server']['log_level'] },
         description: 'Log level for server (0-5)'

property :pid_file, String,
         default: lazy { node['zabbix']['server']['pid_file'] },
         description: 'Location of PID file'

property :timeout, [Integer, String],
         default: lazy { node['zabbix']['server']['timeout'] },
         description: 'Timeout for operations'

property :alert_scripts_path, String,
         default: lazy { node['zabbix']['server']['alert_scripts_path'] },
         description: 'Location of alert scripts'

property :external_scripts_path, String,
         default: lazy { node['zabbix']['server']['external_scripts'] },
         description: 'Location of external scripts'

property :housekeeping_frequency, [Integer, String],
         default: lazy { node['zabbix']['server']['housekeeping_frequency'] },
         description: 'Housekeeping frequency in hours'

property :max_housekeeper_delete, [Integer, String],
         default: lazy { node['zabbix']['server']['max_housekeeper_delete'] },
         description: 'Maximum number of rows to delete per housekeeping cycle'

property :cache_size, String,
         default: lazy { node['zabbix']['server']['cache_size'] },
         description: 'Size of configuration cache'

property :start_pollers, [Integer, String],
         default: lazy { node['zabbix']['server']['start_pollers'] },
         description: 'Number of poller processes to start'

property :start_ipmi_pollers, [Integer, String],
         default: lazy { node['zabbix']['server']['start_ipmi_pollers'] },
         description: 'Number of IPMI poller processes to start'

property :start_trappers, [Integer, String],
         default: lazy { node['zabbix']['server']['start_trappers'] },
         description: 'Number of trapper processes to start'

property :start_pingers, [Integer, String],
         default: lazy { node['zabbix']['server']['start_pingers'] },
         description: 'Number of pinger processes to start'

property :start_discoverers, [Integer, String],
         default: lazy { node['zabbix']['server']['start_discoverers'] },
         description: 'Number of discoverer processes to start'

property :tls_cert_file, String,
         default: lazy { node['zabbix']['server']['tls_cert_file'] },
         description: 'Full path to TLS certificate file'

property :tls_key_file, String,
         default: lazy { node['zabbix']['server']['tls_key_file'] },
         description: 'Full path to TLS key file'

property :tls_ca_file, String,
         default: lazy { node['zabbix']['server']['tls_ca_file'] },
         description: 'Full path to TLS CA file'

# service properties
property :service_name, String,
         default: 'zabbix-server',
         description: 'Name of the server service'

property :service_provider, [String, Symbol],
         default: lazy { Chef::Platform::ServiceHelpers.service_resource_providers.first },
         description: 'Provider for the server service'

property :service_enabled, [TrueClass, FalseClass],
         default: true,
         description: 'Enable the server service'

property :service_auto_start, [TrueClass, FalseClass],
         default: true,
         description: 'Auto-start the server service'

action_class do
  def create_directories
    # Create directories
    %w(
      dir
      log_dir
      run_dir
      socket_dir
      external_dir
      alert_dir
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
  end

  def install_package
    # Select package based on database type
    server_package = case new_resource.database_type
                    when 'postgresql'
                      'zabbix-server-pgsql'
                    when 'mysql'
                      'zabbix-server-mysql'
                    end

    # Install the Zabbix server package
    package server_package do
      action :install
      options '--enablerepo=zabbix' if %w(rhel amazon).include? node['platform_family']
    end
  end

  def install_from_source
    # Required variables for source installation
    version = new_resource.version
    branch = node['zabbix']['server']['branch']
    src_url = "https://github.com/zabbix/zabbix/archive/#{branch}.zip"
    src_dir = "#{Chef::Config[:file_cache_path]}/zabbix-server-#{version}"
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

    # Configure and make Zabbix server
    db_flags = case new_resource.database_type
              when 'postgresql'
                "--with-postgresql=#{node['postgresql']['dir']}"
              when 'mysql'
                "--with-mysql"
              end

    bash 'install_zabbix_server' do
      cwd src_dir
      code <<-EOH
        ./configure --prefix=#{install_dir} \
                   --enable-server \
                   --enable-ipv6 \
                   #{db_flags} \
                   --with-openssl \
                   --with-libpcre \
                   --with-libcurl \
                   --with-net-snmp \
                   --with-openipmi \
                   --with-unixodbc \
                   --with-libxml2 \
                   --with-ssh2
        make install
      EOH
      not_if { ::File.exist?("#{install_dir}/sbin/zabbix_server") }
    end

    # Create symlinks
    link '/usr/sbin/zabbix_server' do
      to "#{install_dir}/sbin/zabbix_server"
    end

    # Create init script or systemd service file
    if node['init_package'] == 'systemd'
      template '/etc/systemd/system/zabbix-server.service' do
        source 'zabbix-server.service.erb'
        owner 'root'
        group 'root'
        mode '0644'
        variables(
          server_conf: node['zabbix']['server']['config_file']
        )
        notifies :run, 'execute[systemctl-daemon-reload]', :immediately
      end

      execute 'systemctl-daemon-reload' do
        command '/bin/systemctl daemon-reload'
        action :nothing
      end
    else
      template '/etc/init.d/zabbix-server' do
        source 'zabbix-server.init.erb'
        owner 'root'
        group 'root'
        mode '0755'
        variables(
          server_conf: node['zabbix']['server']['config_file']
        )
      end
    end
  end

  def configure_server
    # Create server configuration from template
    template node['zabbix']['server']['config_file'] do
      source 'zabbix_server.conf.erb'
      owner 'root'
      group node['zabbix']['group']
      mode '0640'
      variables(
        db_type: new_resource.database_type,
        db_host: new_resource.database_host,
        db_port: new_resource.database_port,
        db_name: new_resource.database_name,
        db_user: new_resource.database_user,
        db_password: new_resource.database_password,
        db_socket: new_resource.database_socket,
        db_schema: new_resource.database_schema,
        db_tls_connect: new_resource.database_tls_connect,
        server_port: new_resource.server_port,
        log_file: new_resource.log_file,
        log_level: new_resource.log_level,
        pid_file: new_resource.pid_file,
        timeout: new_resource.timeout,
        alert_scripts_path: new_resource.alert_scripts_path,
        external_scripts: new_resource.external_scripts_path,
        housekeeping_frequency: new_resource.housekeeping_frequency,
        max_housekeeper_delete: new_resource.max_housekeeper_delete,
        start_pollers: new_resource.start_pollers,
        start_ipmi_pollers: new_resource.start_ipmi_pollers,
        start_trappers: new_resource.start_trappers,
        start_pingers: new_resource.start_pingers,
        start_discoverers: new_resource.start_discoverers,
        cache_size: new_resource.cache_size,
        tls_cert_file: new_resource.tls_cert_file,
        tls_key_file: new_resource.tls_key_file,
        tls_ca_file: new_resource.tls_ca_file
      )
      notifies :restart, "service[#{new_resource.service_name}]", :delayed
    end
  end

  def setup_service
    # Configure and enable the Zabbix server service
    service new_resource.service_name do
      supports status: true, start: true, stop: true, restart: true
      provider new_resource.service_provider unless new_resource.service_provider.nil?
      action [:enable, :start]
      only_if { new_resource.service_enabled && new_resource.service_auto_start }
    end
  end

  def setup_database
    include_recipe 'zabbix::database'
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

  # Set up database
  setup_database

  # Install based on method
  case new_resource.install_method
  when 'package'
    install_package
  when 'source'
    install_from_source
  end

  # Configure server
  configure_server

  # Setup service
  setup_service
end

action :configure do
  # Only configure without installation
  configure_server

  # Ensure service is configured
  setup_service
end

action :remove do
  service new_resource.service_name do
    action [:stop, :disable]
    only_if { ::File.exist?("/etc/init.d/#{new_resource.service_name}") || ::File.exist?("/etc/systemd/system/#{new_resource.service_name}.service") }
  end

  server_package = case new_resource.database_type
                  when 'postgresql'
                    'zabbix-server-pgsql'
                  when 'mysql'
                    'zabbix-server-mysql'
                  end

  package server_package do
    action :remove
    only_if { new_resource.install_method == 'package' }
  end
end