# frozen_string_literal: true

#
# Cookbook:: zabbix
# Recipe:: server
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

include_recipe 'zabbix::repository' unless node['zabbix']['server']['install_method'] == 'source'
include_recipe 'zabbix::database'

# Install Zabbix server package based on installation method and database type
case node['zabbix']['server']['install_method']
when 'package'
  # Select package based on database type
  server_package = case node['zabbix']['server']['database']['type']
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

when 'source'
  # Required variables for source installation
  version = node['zabbix']['server']['version']
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
  db_flags = case node['zabbix']['server']['database']['type']
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

# Create server configuration from template
template node['zabbix']['server']['config_file'] do
  source 'zabbix_server.conf.erb'
  owner 'root'
  group node['zabbix']['group']
  mode '0640'
  variables(
    db_type: node['zabbix']['server']['database']['type'],
    db_host: node['zabbix']['server']['database']['host'],
    db_port: node['zabbix']['server']['database']['port'],
    db_name: node['zabbix']['server']['database']['name'],
    db_user: node['zabbix']['server']['database']['user'],
    db_password: node['zabbix']['server']['database']['password'],
    db_socket: node['zabbix']['server']['database']['socket'],
    db_schema: node['zabbix']['server']['database']['schema'],
    db_tls_connect: node['zabbix']['server']['database']['tls_connect'],
    server_port: node['zabbix']['server']['listen_port'],
    log_file: node['zabbix']['server']['log_file'],
    log_level: node['zabbix']['server']['log_level'],
    pid_file: node['zabbix']['server']['pid_file'],
    timeout: node['zabbix']['server']['timeout'],
    alert_scripts_path: node['zabbix']['server']['alert_scripts_path'],
    external_scripts: node['zabbix']['server']['external_scripts'],
    housekeeping_frequency: node['zabbix']['server']['housekeeping_frequency'],
    max_housekeeper_delete: node['zabbix']['server']['max_housekeeper_delete'],
    problem_housekeeper_frequency: node['zabbix']['server']['problem_housekeeper_frequency'],
    start_pollers: node['zabbix']['server']['start_pollers'],
    start_ipmi_pollers: node['zabbix']['server']['start_ipmi_pollers'],
    start_trappers: node['zabbix']['server']['start_trappers'],
    start_pingers: node['zabbix']['server']['start_pingers'],
    start_discoverers: node['zabbix']['server']['start_discoverers'],
    cache_size: node['zabbix']['server']['cache_size'],
    tls_cert_file: node['zabbix']['server']['tls_cert_file'],
    tls_key_file: node['zabbix']['server']['tls_key_file'],
    tls_ca_file: node['zabbix']['server']['tls_ca_file']
  )
  notifies :restart, 'service[zabbix-server]', :delayed
end

# Configure and enable the Zabbix server service
service 'zabbix-server' do
  service_name 'zabbix-server'
  supports status: true, start: true, stop: true, restart: true
  action [:enable, :start]
end

# Log successful server installation
log 'Zabbix server installation completed' do
  level :info
end