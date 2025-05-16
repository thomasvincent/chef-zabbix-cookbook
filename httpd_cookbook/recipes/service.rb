# frozen_string_literal: true

#
# Cookbook:: httpd
# Recipe:: service
#
# Copyright:: 2023-2025, Thomas Vincent
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

# Create httpd service
httpd_service node['httpd']['service_name'] do
  service_name node['httpd']['service_name']
  keep_alive node['httpd']['config']['keep_alive']
  keep_alive_timeout node['httpd']['config']['keep_alive_timeout']
  max_keepalive_requests node['httpd']['config']['keep_alive_requests']
  timeout node['httpd']['config']['timeout']
  listen node['httpd']['config']['listen']
  log_level node['httpd']['config']['log_level']
  enable_http2 node['httpd']['config']['enable_http2']
  server_tokens node['httpd']['security']['server_tokens']
  server_signature node['httpd']['security']['server_signature']
  trace_enable node['httpd']['security']['trace_enable']
  action :create
end

# Create systemd service override for better reliability
if %w(rhel fedora amazon debian).include?(node['platform_family'])
  directory "/etc/systemd/system/#{node['httpd']['service_name']}.service.d" do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
    action :create
  end

  template "/etc/systemd/system/#{node['httpd']['service_name']}.service.d/override.conf" do
    source 'systemd-override.conf.erb'
    owner 'root'
    group 'root'
    mode '0644'
    variables(
      timeout_start_sec: 600,
      timeout_stop_sec: 600,
      restart_sec: 10,
      limit_nofile: 65536,
      memory_limit: nil,
      cpu_quota: nil
    )
    notifies :run, 'execute[systemctl-daemon-reload]', :immediately
    action :create
  end

  execute 'systemctl-daemon-reload' do
    command 'systemctl daemon-reload'
    action :nothing
  end
end

# Configure logrotate for httpd logs
if node['httpd']['logrotate']['enabled']
  template "/etc/logrotate.d/#{node['httpd']['service_name']}" do
    source 'logrotate.conf.erb'
    cookbook 'httpd'
    owner 'root'
    group 'root'
    mode '0644'
    variables(
      service_name: node['httpd']['service_name'],
      log_dir: ::File.dirname(node['httpd']['error_log']),
      log_pattern: "#{::File.dirname(node['httpd']['error_log'])}/*.log",
      rotate: node['httpd']['logrotate']['rotate'],
      frequency: node['httpd']['logrotate']['frequency'],
      options: node['httpd']['logrotate']['options'],
      postrotate: node['httpd']['logrotate']['postrotate']
    )
    action :create
  end
end

# Start and enable httpd service
service node['httpd']['service_name'] do
  service_name node['httpd']['service_name']
  supports status: true, restart: true, reload: true
  action [:enable, :start]
end

log "Apache HTTP Server service configured and started" do
  level :info
end