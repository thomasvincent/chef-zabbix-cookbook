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

# Create directories for Zabbix
%w(
  dir
  log_dir
  run_dir
  socket_dir
  external_dir
  alert_dir
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

# Install platform-specific dependencies
case node['platform_family']
when 'rhel', 'amazon'
  include_recipe 'yum-epel'

  yum_repository 'zabbix' do
    description "Zabbix Official Repository - #{node['kernel']['machine']}"
    baseurl node['zabbix']['repository_uri']
    gpgkey node['zabbix']['repository_key']
    action :create
    gpgcheck true
  end

  yum_repository 'zabbix-non-supported' do
    description "Zabbix Official Repository non-supported - #{node['kernel']['machine']}"
    baseurl node['zabbix']['repository_uri'].gsub('$basearch', 'non-supported')
    gpgkey node['zabbix']['repository_key']
    action :create
    gpgcheck true
  end

  package %w(
    make
    gcc
    libxml2-devel
    libcurl-devel
    net-snmp-devel
    libevent-devel
    pcre-devel
    OpenIPMI-devel
    openldap-devel
    unixODBC-devel
    java-1.8.0-openjdk-devel
  ) do
    action :install
    only_if { node['zabbix']['server']['install_method'] == 'source' }
  end

when 'debian'
  include_recipe 'apt'

  apt_repository 'zabbix' do
    uri "https://repo.zabbix.com/zabbix/#{node['zabbix']['version']}/#{node['platform']}/"
    components ['main']
    distribution node['lsb']['codename']
    key node['zabbix']['repository_key']
    action :add
  end

  package %w(
    build-essential
    libxml2-dev
    libcurl4-openssl-dev
    snmp-mibs-downloader
    libsnmp-dev
    libevent-dev
    libpcre3-dev
    libssh2-1-dev
    libopenipmi-dev
    libldap2-dev
    unixodbc-dev
    default-jdk
  ) do
    action :install
    only_if { node['zabbix']['server']['install_method'] == 'source' }
  end
end

# Include recipes based on attributes
include_recipe 'zabbix::agent' if node['zabbix']['agent']['enabled']
include_recipe 'zabbix::server' if node['zabbix']['server']['enabled']
include_recipe 'zabbix::web' if node['zabbix']['web']['enabled']
include_recipe 'zabbix::java_gateway' if node['zabbix']['java_gateway']['enabled']

log 'Zabbix installation completed' do
  level :info
end