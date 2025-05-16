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

include_recipe 'zabbix::repository' unless node['zabbix']['agent']['install_method'] == 'source'

# Install package based on installation method
case node['zabbix']['agent']['install_method']
when 'package'
  # Install Zabbix agent package
  package 'zabbix-agent' do
    package_name case node['platform_family']
                when 'rhel', 'amazon'
                  'zabbix-agent'
                when 'debian'
                  'zabbix-agent'
                end
    action :install
    options '--enablerepo=zabbix' if %w(rhel amazon).include? node['platform_family']
  end

when 'source'
  # Required variables for source installation
  version = node['zabbix']['agent']['version']
  branch = node['zabbix']['agent']['branch']
  src_url = "https://github.com/zabbix/zabbix/archive/#{branch}.zip"
  src_dir = "#{Chef::Config[:file_cache_path]}/zabbix-agent-#{version}"
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

  # Configure and make Zabbix agent
  bash 'install_zabbix_agent' do
    cwd src_dir
    code <<-EOH
      ./configure --prefix=#{install_dir} \
                 --enable-agent \
                 --enable-ipv6 \
                 --with-openssl \
                 --with-libpcre \
                 --with-libcurl \
                 --with-net-snmp
      make install
    EOH
    not_if { ::File.exist?("#{install_dir}/sbin/zabbix_agentd") }
  end

  # Create symlinks
  link '/usr/sbin/zabbix_agentd' do
    to "#{install_dir}/sbin/zabbix_agentd"
  end

  link '/usr/sbin/zabbix_get' do
    to "#{install_dir}/bin/zabbix_get"
  end

  # Create init script or systemd service file
  if node['init_package'] == 'systemd'
    template '/etc/systemd/system/zabbix-agent.service' do
      source 'zabbix-agent.service.erb'
      owner 'root'
      group 'root'
      mode '0644'
      notifies :run, 'execute[systemctl-daemon-reload]', :immediately
    end

    execute 'systemctl-daemon-reload' do
      command '/bin/systemctl daemon-reload'
      action :nothing
    end
  else
    template '/etc/init.d/zabbix-agent' do
      source 'zabbix-agent.init.erb'
      owner 'root'
      group 'root'
      mode '0755'
    end
  end
end

# Create agent include directory if it doesn't exist
directory node['zabbix']['agent']['include_dir'] do
  owner node['zabbix']['user']
  group node['zabbix']['group']
  mode '0755'
  recursive true
  action :create
end

# Create agent configuration from template
template node['zabbix']['agent']['config_file'] do
  source 'zabbix_agentd.conf.erb'
  owner 'root'
  group 'root'
  mode '0640'
  variables(
    servers: node['zabbix']['agent']['servers'].join(','),
    servers_active: node['zabbix']['agent']['servers_active'].join(','),
    hostname: node['zabbix']['agent']['hostname'],
    include_dir: node['zabbix']['agent']['include_dir'],
    pid_file: node['zabbix']['agent']['pid_file'],
    log_file: node['zabbix']['agent']['log_file'],
    log_level: node['zabbix']['agent']['log_level'],
    timeout: node['zabbix']['agent']['timeout'],
    enable_remote_commands: node['zabbix']['agent']['enable_remote_commands'],
    listen_port: node['zabbix']['agent']['listen_port'],
    tls_connect: node['zabbix']['agent']['tls_connect'],
    tls_accept: node['zabbix']['agent']['tls_accept'],
    tls_psk_identity: node['zabbix']['agent']['tls_psk_identity'],
    tls_psk_file: node['zabbix']['agent']['tls_psk_file'],
    tls_cert_file: node['zabbix']['agent']['tls_cert_file'],
    tls_key_file: node['zabbix']['agent']['tls_key_file'],
    tls_ca_file: node['zabbix']['agent']['tls_ca_file']
  )
  notifies :restart, 'service[zabbix-agent]', :delayed
end

# Configure and enable the agent service
service 'zabbix-agent' do
  service_name 'zabbix-agent'
  supports status: true, start: true, stop: true, restart: true
  action [:enable, :start]
end

# Log successful agent installation
log 'Zabbix agent installation completed' do
  level :info
end