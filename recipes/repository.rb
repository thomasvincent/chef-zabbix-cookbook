# frozen_string_literal: true

#
# Cookbook:: zabbix
# Recipe:: repository
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

# Configure repositories for Zabbix packages
case node['platform_family']
when 'rhel', 'amazon'
  include_recipe 'yum-epel'

  # Create a Zabbix repository
  yum_repository 'zabbix' do
    description "Zabbix Official Repository - #{node['kernel']['machine']}"
    baseurl node['zabbix']['repository_uri']
    gpgkey node['zabbix']['repository_key']
    action :create
    gpgcheck true
  end

  # Create a Zabbix non-supported repository
  yum_repository 'zabbix-non-supported' do
    description "Zabbix Official Repository non-supported - #{node['kernel']['machine']}"
    baseurl node['zabbix']['repository_uri'].gsub('$basearch', 'non-supported')
    gpgkey node['zabbix']['repository_key']
    action :create
    gpgcheck true
  end

when 'debian'
  include_recipe 'apt'

  # Install apt-transport-https for HTTPS repo
  package 'apt-transport-https' do
    action :install
  end

  # Create a Zabbix repository
  apt_repository 'zabbix' do
    uri "https://repo.zabbix.com/zabbix/#{node['zabbix']['version']}/#{node['platform']}/"
    components ['main']
    distribution node['lsb']['codename']
    key node['zabbix']['repository_key']
    action :add
  end

  # Create a Zabbix non-supported repository
  apt_repository 'zabbix-non-supported' do
    uri "https://repo.zabbix.com/zabbix-non-supported/#{node['zabbix']['version']}/#{node['platform']}/"
    components ['main']
    distribution node['lsb']['codename']
    key node['zabbix']['repository_key']
    action :add
  end

  # Update apt cache
  apt_update 'update' do
    action :update
  end
end