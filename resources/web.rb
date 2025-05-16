# frozen_string_literal: true

unified_mode true

resource_name :zabbix_web
provides :zabbix_web

description 'Use the zabbix_web resource to install and configure Zabbix web interface'

# Installation properties
property :version, String,
         default: lazy { node['zabbix']['web']['version'] },
         description: 'The version of Zabbix web interface to install'

property :install_method, String,
         equal_to: %w(package source),
         default: 'package',
         description: 'Installation method for Zabbix web interface'

# Web server properties
property :server_type, String,
         equal_to: %w(apache nginx),
         default: lazy { node['zabbix']['web']['server'] },
         description: 'Web server to use with Zabbix web interface'

property :fqdn, String,
         default: lazy { node['zabbix']['web']['fqdn'] },
         description: 'FQDN for the Zabbix web interface'

property :aliases, Array,
         default: lazy { node['zabbix']['web']['aliases'] },
         description: 'Server aliases for the Zabbix web interface'

property :port, [Integer, String],
         default: lazy { node['zabbix']['web']['port'] },
         description: 'Port for the web server to listen on'

# PHP properties
property :max_execution_time, [Integer, String],
         default: lazy { node['zabbix']['web']['max_execution_time'] },
         description: 'Maximum execution time for PHP'

property :memory_limit, String,
         default: lazy { node['zabbix']['web']['memory_limit'] },
         description: 'Memory limit for PHP'

property :post_max_size, String,
         default: lazy { node['zabbix']['web']['post_max_size'] },
         description: 'Maximum POST size for PHP'

property :upload_max_filesize, String,
         default: lazy { node['zabbix']['web']['upload_max_filesize'] },
         description: 'Maximum file upload size for PHP'

property :max_input_time, [Integer, String],
         default: lazy { node['zabbix']['web']['max_input_time'] },
         description: 'Maximum input time for PHP'

property :timezone, String,
         default: lazy { node['zabbix']['web']['timezone'] },
         description: 'Timezone for PHP'

# Database connection properties
property :database_type, String,
         equal_to: %w(postgresql mysql),
         default: lazy { node['zabbix']['server']['database']['type'] },
         description: 'Type of database to use with Zabbix web interface'

property :database_host, String,
         default: lazy { node['zabbix']['server']['database']['host'] },
         description: 'Database server hostname'

property :database_port, [Integer, String],
         default: lazy { node['zabbix']['server']['database']['port'] },
         description: 'Database server port'

property :database_name, String,
         default: lazy { node['zabbix']['server']['database']['name'] },
         description: 'Database name for Zabbix web interface'

property :database_user, String,
         default: lazy { node['zabbix']['server']['database']['user'] },
         description: 'Database username for Zabbix web interface'

property :database_password, String,
         default: lazy { node['zabbix']['server']['database']['password'] },
         sensitive: true,
         description: 'Database password for Zabbix web interface'

property :server_host, String,
         default: lazy { node['zabbix']['agent']['hostname'] },
         description: 'Zabbix server hostname'

property :server_name, String,
         default: lazy { node['fqdn'] },
         description: 'Display name for Zabbix server'

property :server_port, [Integer, String],
         default: lazy { node['zabbix']['server']['listen_port'] },
         description: 'Zabbix server port'

action_class do
  def install_web_package
    # Select package based on database type
    web_package = case new_resource.database_type
                when 'postgresql'
                  'zabbix-web-pgsql'
                when 'mysql'
                  'zabbix-web-mysql'
                end

    # Install Zabbix web frontend package
    package web_package do
      action :install
      options '--enablerepo=zabbix' if %w(rhel amazon).include? node['platform_family']
    end

    # Install PHP packages if needed
    case node['platform_family']
    when 'rhel', 'amazon'
      package %w(php php-gd php-bcmath php-mbstring php-xml php-ldap php-json) do
        action :install
      end
    when 'debian'
      package %w(php php-gd php-bcmath php-mbstring php-xml php-ldap php-json) do
        action :install
      end
    end
  end

  def configure_apache
    include_recipe 'apache2'
    include_recipe 'apache2::mod_php'

    package 'zabbix-apache-conf' do
      action :install
      options '--enablerepo=zabbix' if %w(rhel amazon).include? node['platform_family']
    end

    # Configure Apache virtual host
    web_app 'zabbix' do
      template 'zabbix-apache.conf.erb'
      server_name new_resource.fqdn
      server_aliases new_resource.aliases
      docroot '/usr/share/zabbix'
      port new_resource.port
    end
  end

  def configure_nginx
    include_recipe 'nginx'

    # Install PHP-FPM for Nginx
    case node['platform_family']
    when 'rhel', 'amazon'
      package %w(php-fpm php-cli)
    when 'debian'
      package %w(php-fpm php-cli)
    end

    # Configure PHP-FPM
    template '/etc/php-fpm.d/zabbix.conf' do
      source 'zabbix-php-fpm.conf.erb'
      owner 'root'
      group 'root'
      mode '0644'
      variables(
        user: node['nginx']['user'],
        group: node['nginx']['group'],
        max_execution_time: new_resource.max_execution_time,
        memory_limit: new_resource.memory_limit,
        post_max_size: new_resource.post_max_size,
        upload_max_filesize: new_resource.upload_max_filesize,
        max_input_time: new_resource.max_input_time
      )
      notifies :restart, 'service[php-fpm]', :delayed
    end

    # Enable and start PHP-FPM service
    service 'php-fpm' do
      action [:enable, :start]
    end

    # Configure Nginx virtual host
    template "#{node['nginx']['dir']}/sites-available/zabbix" do
      source 'zabbix-nginx.conf.erb'
      owner 'root'
      group 'root'
      mode '0644'
      variables(
        server_name: new_resource.fqdn,
        server_aliases: new_resource.aliases,
        docroot: '/usr/share/zabbix',
        port: new_resource.port
      )
      notifies :reload, 'service[nginx]', :delayed
    end

    # Enable Nginx virtual host
    nginx_site 'zabbix' do
      action :enable
    end
  end

  def configure_php
    # Ensure directory exists
    directory '/etc/zabbix/web' do
      owner 'root'
      group 'apache'
      mode '0750'
      recursive true
      action :create
    end
    
    # Create PHP configuration
    template '/etc/zabbix/web/zabbix.conf.php' do
      source 'zabbix.conf.php.erb'
      owner 'root'
      group case new_resource.server_type
            when 'apache'
              'apache'
            when 'nginx'
              'nginx'
            end
      mode '0640'
      variables(
        db_type: new_resource.database_type,
        db_host: new_resource.database_host,
        db_port: new_resource.database_port,
        db_name: new_resource.database_name,
        db_user: new_resource.database_user,
        db_password: new_resource.database_password,
        server_host: new_resource.server_host,
        server_name: new_resource.server_name,
        server_port: new_resource.server_port,
        timezone: new_resource.timezone
      )
    end
  end
end

action :install do
  # Install packages
  install_web_package

  # Configure web server
  case new_resource.server_type
  when 'apache'
    configure_apache
  when 'nginx'
    configure_nginx
  end

  # Configure PHP
  configure_php
end

action :configure do
  # Configure web server
  case new_resource.server_type
  when 'apache'
    configure_apache
  when 'nginx'
    configure_nginx
  end

  # Configure PHP
  configure_php
end

action :remove do
  web_package = case new_resource.database_type
               when 'postgresql'
                 'zabbix-web-pgsql'
               when 'mysql'
                 'zabbix-web-mysql'
               end

  package web_package do
    action :remove
  end

  # Clean up configuration
  file '/etc/zabbix/web/zabbix.conf.php' do
    action :delete
  end

  # Remove web server configurations
  case new_resource.server_type
  when 'apache'
    apache_site 'zabbix' do
      action :disable
    end
  when 'nginx'
    nginx_site 'zabbix' do
      action :disable
    end
  end
end