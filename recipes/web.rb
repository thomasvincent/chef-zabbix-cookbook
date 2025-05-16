# frozen_string_literal: true

#
# Cookbook:: zabbix
# Recipe:: web
#
# Copyright:: 2023, Thomas Vincent
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include_recipe 'zabbix::repository' unless node['zabbix']['web']['install_method'] == 'source'

# Install Zabbix frontend package based on database type
case node['zabbix']['web']['install_method']
when 'package'
  # Select package based on database type
  web_package = case node['zabbix']['server']['database']['type']
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

  # Install PHP and web server packages for frontend
  case node['zabbix']['web']['server']
  when 'apache'
    include_recipe 'apache2'
    include_recipe 'apache2::mod_php'

    package 'zabbix-apache-conf' do
      action :install
      options '--enablerepo=zabbix' if %w(rhel amazon).include? node['platform_family']
    end

    # Configure Apache virtual host
    web_app 'zabbix' do
      template 'zabbix-apache.conf.erb'
      server_name node['zabbix']['web']['fqdn']
      server_aliases node['zabbix']['web']['aliases']
      docroot '/usr/share/zabbix'
      port node['zabbix']['web']['port']
    end

  when 'nginx'
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
        max_execution_time: node['zabbix']['web']['max_execution_time'],
        memory_limit: node['zabbix']['web']['memory_limit'],
        post_max_size: node['zabbix']['web']['post_max_size'],
        upload_max_filesize: node['zabbix']['web']['upload_max_filesize'],
        max_input_time: node['zabbix']['web']['max_input_time']
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
        server_name: node['zabbix']['web']['fqdn'],
        server_aliases: node['zabbix']['web']['aliases'],
        docroot: '/usr/share/zabbix',
        port: node['zabbix']['web']['port']
      )
      notifies :reload, 'service[nginx]', :delayed
    end

    # Enable Nginx virtual host
    nginx_site 'zabbix' do
      action :enable
    end
  end
end

# Create PHP configuration
template '/etc/zabbix/web/zabbix.conf.php' do
  source 'zabbix.conf.php.erb'
  owner 'root'
  group 'apache'
  mode '0640'
  variables(
    db_type: node['zabbix']['server']['database']['type'],
    db_host: node['zabbix']['server']['database']['host'],
    db_port: node['zabbix']['server']['database']['port'],
    db_name: node['zabbix']['server']['database']['name'],
    db_user: node['zabbix']['server']['database']['user'],
    db_password: node['zabbix']['server']['database']['password'],
    server_host: node['zabbix']['agent']['hostname'],
    server_name: node['fqdn'],
    server_port: node['zabbix']['server']['listen_port'],
    timezone: node['zabbix']['web']['timezone']
  )
end

# Log successful web frontend installation
log 'Zabbix web frontend installation completed' do
  level :info
end