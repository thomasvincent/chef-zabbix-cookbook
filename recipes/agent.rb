# frozen_string_literal: true

#
# Cookbook:: zabbix
# Recipe:: agent
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

# Setup repository first
include_recipe 'zabbix::repository' unless node['zabbix']['agent']['install_method'] == 'source'

# Use the custom resource to install and configure Zabbix agent
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
end

# For platforms with SELinux enabled
if platform_family?('rhel', 'fedora', 'amazon')
  # Create SELinux policy for Zabbix agent
  selinux_port '10050' do
    protocol 'tcp'
    secontext 'zabbix_port_t'
    not_if 'getenforce | grep -i disabled'
  end
  
  # Allow Zabbix agent to connect to network
  selinux_boolean 'zabbix_can_network' do
    value true
    not_if 'getenforce | grep -i disabled'
  end
end

log 'Zabbix agent installation completed' do
  level :info
end