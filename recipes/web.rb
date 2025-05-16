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

unified_mode true

# Setup repository
include_recipe 'zabbix::repository' unless node['zabbix']['web']['install_method'] == 'source'

# Use the custom resource to install and configure Zabbix web interface
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

# For platforms with SELinux enabled
if platform_family?('rhel', 'fedora', 'amazon')
  # Configure SELinux for web server
  case node['zabbix']['web']['server']
  when 'apache'
    selinux_boolean 'httpd_can_connect_zabbix' do
      value true
      not_if 'getenforce | grep -i disabled'
    end
    
    selinux_boolean 'httpd_can_network_connect_db' do
      value true
      not_if 'getenforce | grep -i disabled'
    end
    
    selinux_port '80' do
      protocol 'tcp'
      secontext 'http_port_t'
      not_if 'getenforce | grep -i disabled'
    end
    
    selinux_port '443' do
      protocol 'tcp'
      secontext 'http_port_t'
      not_if 'getenforce | grep -i disabled'
    end
  when 'nginx'
    selinux_boolean 'httpd_can_connect_zabbix' do
      value true
      not_if 'getenforce | grep -i disabled'
    end
    
    selinux_boolean 'httpd_can_network_connect_db' do
      value true
      not_if 'getenforce | grep -i disabled'
    end
    
    selinux_port '80' do
      protocol 'tcp'
      secontext 'http_port_t'
      not_if 'getenforce | grep -i disabled'
    end
    
    selinux_port '443' do
      protocol 'tcp'
      secontext 'http_port_t'
      not_if 'getenforce | grep -i disabled'
    end
  end
end

log 'Zabbix web frontend installation completed' do
  level :info
end