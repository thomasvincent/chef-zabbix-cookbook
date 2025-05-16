# frozen_string_literal: true

#
# Cookbook:: zabbix
# Recipe:: java_gateway
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

include_recipe 'zabbix::repository' unless node['zabbix']['java_gateway']['install_method'] == 'source'

case node['zabbix']['java_gateway']['install_method']
when 'package'
  # Install Zabbix Java Gateway package
  package 'zabbix-java-gateway' do
    action :install
    options '--enablerepo=zabbix' if %w(rhel amazon).include? node['platform_family']
  end

when 'source'
  # Required variables for source installation
  version = node['zabbix']['version']
  branch = 'main'
  src_url = "https://github.com/zabbix/zabbix/archive/#{branch}.zip"
  src_dir = "#{Chef::Config[:file_cache_path]}/zabbix-java-gateway-#{version}"
  install_dir = node['zabbix']['install_dir']

  # Requirements for source build
  build_essential 'install_buildtools' do
    action :install
  end

  # Install Java
  package 'java-1.8.0-openjdk-devel' do
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

  # Configure and make Zabbix Java Gateway
  bash 'install_zabbix_java_gateway' do
    cwd src_dir
    code <<-EOH
      ./configure --prefix=#{install_dir} \
                 --enable-java
      make install
    EOH
    not_if { ::File.exist?("#{install_dir}/sbin/zabbix_java") }
  end

  # Create symlinks
  link '/usr/sbin/zabbix_java' do
    to "#{install_dir}/sbin/zabbix_java"
  end

  # Create init script or systemd service file
  if node['init_package'] == 'systemd'
    template '/etc/systemd/system/zabbix-java-gateway.service' do
      source 'zabbix-java-gateway.service.erb'
      owner 'root'
      group 'root'
      mode '0644'
      variables(
        java_gateway_conf: '/etc/zabbix/zabbix_java_gateway.conf'
      )
      notifies :run, 'execute[systemctl-daemon-reload]', :immediately
    end

    execute 'systemctl-daemon-reload' do
      command '/bin/systemctl daemon-reload'
      action :nothing
    end
  else
    template '/etc/init.d/zabbix-java-gateway' do
      source 'zabbix-java-gateway.init.erb'
      owner 'root'
      group 'root'
      mode '0755'
      variables(
        java_gateway_conf: '/etc/zabbix/zabbix_java_gateway.conf'
      )
    end
  end
end

# Create Java Gateway settings file
template '/etc/zabbix/zabbix_java_gateway.conf' do
  source 'zabbix_java_gateway.conf.erb'
  owner 'root'
  group node['zabbix']['group']
  mode '0644'
  variables(
    listen_ip: node['zabbix']['java_gateway']['listen_ip'],
    listen_port: node['zabbix']['java_gateway']['listen_port'],
    pid_file: node['zabbix']['java_gateway']['pid_file'],
    start_pollers: node['zabbix']['java_gateway']['start_pollers'],
    timeout: node['zabbix']['java_gateway']['timeout']
  )
  notifies :restart, 'service[zabbix-java-gateway]', :delayed
end

# Configure and enable the Java Gateway service
service 'zabbix-java-gateway' do
  service_name 'zabbix-java-gateway'
  supports status: true, start: true, stop: true, restart: true
  action [:enable, :start]
end

# Log successful Java Gateway installation
log 'Zabbix Java Gateway installation completed' do
  level :info
end