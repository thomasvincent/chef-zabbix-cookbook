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

unified_mode true

# Setup repository
include_recipe 'zabbix::repository' unless node['zabbix']['server']['install_method'] == 'source'

# Setup database first
include_recipe 'zabbix::database'

# Use the custom resource to install and configure Zabbix server
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

# For platforms with SELinux enabled
if platform_family?('rhel', 'fedora', 'amazon')
  # Configure SELinux for Zabbix server
  selinux_port '10051' do
    protocol 'tcp'
    secontext 'zabbix_port_t'
    not_if 'getenforce | grep -i disabled'
  end
  
  selinux_boolean 'zabbix_can_network' do
    value true
    not_if 'getenforce | grep -i disabled'
  end
  
  # Allow Zabbix server to connect to database
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

log 'Zabbix server installation completed' do
  level :info
end