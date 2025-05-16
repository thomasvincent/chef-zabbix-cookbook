# frozen_string_literal: true

#
# Cookbook:: zabbix
# Recipe:: default
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

# frozen_string_literal: true

#
# Cookbook:: zabbix
# Recipe:: default
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

unified_mode true

# Setup repository
include_recipe 'zabbix::repository'

# Create the Zabbix user and group
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

# Create base directories for Zabbix
%w(
  dir
  log_dir
  run_dir
  socket_dir
  tmp_dir
  home_dir
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

# Setup SELinux if enabled
if platform_family?('rhel', 'fedora', 'amazon')
  selinux_install 'zabbix' do
    action :install
    not_if 'getenforce | grep -i disabled'
  end
  
  selinux_fcontext '/etc/zabbix(/.*)?' do
    secontext 'etc_t'
    not_if 'getenforce | grep -i disabled'
  end
  
  selinux_fcontext '/var/log/zabbix(/.*)?' do
    secontext 'zabbix_log_t'
    not_if 'getenforce | grep -i disabled'
  end
  
  selinux_fcontext '/var/run/zabbix(/.*)?' do
    secontext 'zabbix_var_run_t'
    not_if 'getenforce | grep -i disabled'
  end
end

# Install Zabbix agent if enabled
zabbix_agent 'zabbix_agent' do
  version node['zabbix']['agent']['version']
  install_method node['zabbix']['agent']['install_method']
  servers node['zabbix']['agent']['servers']
  servers_active node['zabbix']['agent']['servers_active']
  hostname node['zabbix']['agent']['hostname']
  include_dir node['zabbix']['agent']['include_dir']
  log_file node['zabbix']['agent']['log_file']
  log_level node['zabbix']['agent']['log_level']
  timeout node['zabbix']['agent']['timeout']
  listen_port node['zabbix']['agent']['listen_port']
  enable_remote_commands node['zabbix']['agent']['enable_remote_commands']
  tls_connect node['zabbix']['agent']['tls_connect']
  tls_accept node['zabbix']['agent']['tls_accept']
  tls_psk_identity node['zabbix']['agent']['tls_psk_identity']
  tls_psk_file node['zabbix']['agent']['tls_psk_file']
  tls_cert_file node['zabbix']['agent']['tls_cert_file']
  tls_key_file node['zabbix']['agent']['tls_key_file']
  tls_ca_file node['zabbix']['agent']['tls_ca_file']
  service_name 'zabbix-agent'
  service_enabled true
  service_auto_start true
  action :install
  only_if { node['zabbix']['agent']['enabled'] }
end

# Setup database and install Zabbix server if enabled
if node['zabbix']['server']['enabled']
  # Setup database first
  include_recipe 'zabbix::database'
  
  # Install and configure Zabbix server
  zabbix_server 'zabbix_server' do
    version node['zabbix']['server']['version']
    install_method node['zabbix']['server']['install_method']
    database_type node['zabbix']['server']['database']['type']
    database_host node['zabbix']['server']['database']['host']
    database_port node['zabbix']['server']['database']['port']
    database_name node['zabbix']['server']['database']['name']
    database_user node['zabbix']['server']['database']['user']
    database_password node['zabbix']['server']['database']['password']
    database_socket node['zabbix']['server']['database']['socket']
    database_schema node['zabbix']['server']['database']['schema']
    database_tls_connect node['zabbix']['server']['database']['tls_connect']
    server_port node['zabbix']['server']['listen_port']
    log_file node['zabbix']['server']['log_file']
    log_level node['zabbix']['server']['log_level']
    pid_file node['zabbix']['server']['pid_file']
    timeout node['zabbix']['server']['timeout']
    alert_scripts_path node['zabbix']['server']['alert_scripts_path']
    external_scripts_path node['zabbix']['server']['external_scripts']
    housekeeping_frequency node['zabbix']['server']['housekeeping_frequency']
    max_housekeeper_delete node['zabbix']['server']['max_housekeeper_delete']
    cache_size node['zabbix']['server']['cache_size']
    start_pollers node['zabbix']['server']['start_pollers']
    start_ipmi_pollers node['zabbix']['server']['start_ipmi_pollers']
    start_trappers node['zabbix']['server']['start_trappers']
    start_pingers node['zabbix']['server']['start_pingers']
    start_discoverers node['zabbix']['server']['start_discoverers']
    tls_cert_file node['zabbix']['server']['tls_cert_file']
    tls_key_file node['zabbix']['server']['tls_key_file']
    tls_ca_file node['zabbix']['server']['tls_ca_file']
    service_name 'zabbix-server'
    service_enabled true
    service_auto_start true
    action :install
  end
end

# Install Zabbix web interface if enabled
if node['zabbix']['web']['enabled']
  zabbix_web 'zabbix_web' do
    version node['zabbix']['web']['version']
    install_method node['zabbix']['web']['install_method']
    server_type node['zabbix']['web']['server']
    fqdn node['zabbix']['web']['fqdn']
    aliases node['zabbix']['web']['aliases']
    port node['zabbix']['web']['port']
    max_execution_time node['zabbix']['web']['max_execution_time']
    memory_limit node['zabbix']['web']['memory_limit']
    post_max_size node['zabbix']['web']['post_max_size']
    upload_max_filesize node['zabbix']['web']['upload_max_filesize']
    max_input_time node['zabbix']['web']['max_input_time']
    timezone node['zabbix']['web']['timezone']
    database_type node['zabbix']['server']['database']['type']
    database_host node['zabbix']['server']['database']['host']
    database_port node['zabbix']['server']['database']['port']
    database_name node['zabbix']['server']['database']['name']
    database_user node['zabbix']['server']['database']['user']
    database_password node['zabbix']['server']['database']['password']
    server_host node['zabbix']['agent']['hostname']
    server_name node['fqdn']
    server_port node['zabbix']['server']['listen_port']
    action :install
  end
end

# Install Zabbix Java Gateway if enabled
include_recipe 'zabbix::java_gateway' if node['zabbix']['java_gateway']['enabled']

# Configure SELinux for appropriate Zabbix components
if platform_family?('rhel', 'fedora', 'amazon')
  # Configure agent SELinux if enabled
  if node['zabbix']['agent']['enabled']
    selinux_port '10050' do
      protocol 'tcp'
      secontext 'zabbix_port_t'
      not_if 'getenforce | grep -i disabled'
    end
  end

  # Configure server SELinux if enabled
  if node['zabbix']['server']['enabled']
    selinux_port '10051' do
      protocol 'tcp'
      secontext 'zabbix_port_t'
      not_if 'getenforce | grep -i disabled'
    end
    
    selinux_boolean 'zabbix_can_network' do
      value true
      not_if 'getenforce | grep -i disabled'
    end
    
    # Database configuration
    case node['zabbix']['server']['database']['type']
    when 'postgresql'
      selinux_port '5432' do
        protocol 'tcp'
        secontext 'postgresql_port_t'
        not_if 'getenforce | grep -i disabled'
      end
    when 'mysql'
      selinux_port '3306' do
        protocol 'tcp'
        secontext 'mysqld_port_t'
        not_if 'getenforce | grep -i disabled'
      end
    end
  end

  # Configure web SELinux if enabled
  if node['zabbix']['web']['enabled']
    selinux_boolean 'httpd_can_connect_zabbix' do
      value true
      not_if 'getenforce | grep -i disabled'
    end
    
    selinux_boolean 'httpd_can_network_connect_db' do
      value true
      not_if 'getenforce | grep -i disabled'
    end
  end
end

log 'Zabbix installation completed' do
  level :info
end