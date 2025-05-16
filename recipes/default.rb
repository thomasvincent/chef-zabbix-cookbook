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
zabbix_agent 'default' do
  action :install
  only_if { node['zabbix']['agent']['enabled'] }
end

# Install Zabbix server if enabled
if node['zabbix']['server']['enabled']
  # Setup database first
  include_recipe 'zabbix::database'
  
  zabbix_server 'default' do
    action :install
  end
end

# Install Zabbix web interface if enabled
zabbix_web 'default' do
  action :install
  only_if { node['zabbix']['web']['enabled'] }
end

# Install Zabbix Java Gateway if enabled
include_recipe 'zabbix::java_gateway' if node['zabbix']['java_gateway']['enabled']

log 'Zabbix installation completed' do
  level :info
end