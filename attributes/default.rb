# frozen_string_literal: true

#
# Cookbook:: zabbix
# Attributes:: default
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

# General Zabbix attributes
default['zabbix']['version'] = '6.4'
default['zabbix']['api_version'] = '6.4.0'
default['zabbix']['dir'] = '/etc/zabbix'
default['zabbix']['log_dir'] = '/var/log/zabbix'
default['zabbix']['run_dir'] = '/var/run/zabbix'
default['zabbix']['socket_dir'] = '/var/run/zabbix'
default['zabbix']['install_dir'] = '/opt/zabbix'
default['zabbix']['external_dir'] = '/usr/lib/zabbix/externalscripts'
default['zabbix']['alert_dir'] = '/usr/lib/zabbix/alertscripts'
default['zabbix']['tmp_dir'] = '/tmp/zabbix'
default['zabbix']['home_dir'] = '/var/lib/zabbix'
default['zabbix']['user'] = 'zabbix'
default['zabbix']['group'] = 'zabbix'
default['zabbix']['timeout'] = 30

# Agent specific attributes
default['zabbix']['agent']['enabled'] = true
default['zabbix']['agent']['version'] = node['zabbix']['version']
default['zabbix']['agent']['branch'] = 'main'
default['zabbix']['agent']['install_method'] = 'package'
default['zabbix']['agent']['servers'] = ['127.0.0.1']
default['zabbix']['agent']['servers_active'] = ['127.0.0.1']
default['zabbix']['agent']['hostname'] = node['fqdn']
default['zabbix']['agent']['include_dir'] = '/etc/zabbix/zabbix_agentd.d'
default['zabbix']['agent']['config_file'] = '/etc/zabbix/zabbix_agentd.conf'
default['zabbix']['agent']['pid_file'] = '/var/run/zabbix/zabbix_agentd.pid'
default['zabbix']['agent']['log_file'] = '/var/log/zabbix/zabbix_agentd.log'
default['zabbix']['agent']['log_level'] = 3
default['zabbix']['agent']['enable_remote_commands'] = 1
default['zabbix']['agent']['listen_port'] = 10050
default['zabbix']['agent']['timeout'] = 30
default['zabbix']['agent']['tls_connect'] = 'unencrypted'
default['zabbix']['agent']['tls_accept'] = 'unencrypted'
default['zabbix']['agent']['tls_psk_identity'] = nil
default['zabbix']['agent']['tls_psk_file'] = nil
default['zabbix']['agent']['tls_cert_file'] = nil
default['zabbix']['agent']['tls_key_file'] = nil
default['zabbix']['agent']['tls_ca_file'] = nil

# Server specific attributes
default['zabbix']['server']['enabled'] = false
default['zabbix']['server']['version'] = node['zabbix']['version']
default['zabbix']['server']['branch'] = 'main'
default['zabbix']['server']['install_method'] = 'package'
default['zabbix']['server']['config_file'] = '/etc/zabbix/zabbix_server.conf'
default['zabbix']['server']['pid_file'] = '/var/run/zabbix/zabbix_server.pid'
default['zabbix']['server']['log_file'] = '/var/log/zabbix/zabbix_server.log'
default['zabbix']['server']['log_level'] = 3
default['zabbix']['server']['housekeeping_frequency'] = 1
default['zabbix']['server']['max_housekeeper_delete'] = 5000
default['zabbix']['server']['problem_housekeeper_frequency'] = 60
default['zabbix']['server']['sender_frequency'] = 30
default['zabbix']['server']['unreachable_period'] = 45
default['zabbix']['server']['unavailable_delay'] = 60
default['zabbix']['server']['unreachable_delay'] = 15
default['zabbix']['server']['alert_scripts_path'] = '/usr/lib/zabbix/alertscripts'
default['zabbix']['server']['external_scripts'] = '/usr/lib/zabbix/externalscripts'
default['zabbix']['server']['listen_port'] = 10051
default['zabbix']['server']['timeout'] = 30
default['zabbix']['server']['debug_level'] = 3
default['zabbix']['server']['start_pollers'] = 5
default['zabbix']['server']['start_ipmi_pollers'] = 0
default['zabbix']['server']['start_trappers'] = 5
default['zabbix']['server']['start_pingers'] = 1
default['zabbix']['server']['start_discoverers'] = 1
default['zabbix']['server']['cache_size'] = '32M'
default['zabbix']['server']['tls_cert_file'] = nil
default['zabbix']['server']['tls_key_file'] = nil
default['zabbix']['server']['tls_ca_file'] = nil

# Database specific attributes
default['zabbix']['server']['database']['type'] = 'postgresql'
default['zabbix']['server']['database']['host'] = '127.0.0.1'
default['zabbix']['server']['database']['port'] = 5432
default['zabbix']['server']['database']['name'] = 'zabbix'
default['zabbix']['server']['database']['user'] = 'zabbix'
default['zabbix']['server']['database']['password'] = 'zabbix'
default['zabbix']['server']['database']['schema'] = nil
default['zabbix']['server']['database']['socket'] = nil
default['zabbix']['server']['database']['encryption'] = 0
default['zabbix']['server']['database']['cert'] = nil
default['zabbix']['server']['database']['key'] = nil
default['zabbix']['server']['database']['key_password'] = nil
default['zabbix']['server']['database']['ca_cert'] = nil
default['zabbix']['server']['database']['cipher_list'] = nil
default['zabbix']['server']['database']['tls_connect'] = 'required'

# Web frontend attributes
default['zabbix']['web']['enabled'] = false
default['zabbix']['web']['version'] = node['zabbix']['version']
default['zabbix']['web']['branch'] = 'main'
default['zabbix']['web']['install_method'] = 'package'
default['zabbix']['web']['server'] = 'nginx'
default['zabbix']['web']['fqdn'] = node['fqdn']
default['zabbix']['web']['aliases'] = ['zabbix']
default['zabbix']['web']['port'] = 80
default['zabbix']['web']['max_size_bytes'] = '16M'
default['zabbix']['web']['max_execution_time'] = 300
default['zabbix']['web']['memory_limit'] = '128M'
default['zabbix']['web']['post_max_size'] = '16M'
default['zabbix']['web']['upload_max_filesize'] = '2M'
default['zabbix']['web']['max_input_time'] = 300
default['zabbix']['web']['timezone'] = 'UTC'

# Java gateway specific attributes
default['zabbix']['java_gateway']['enabled'] = false
default['zabbix']['java_gateway']['install_method'] = 'package'
default['zabbix']['java_gateway']['listen_ip'] = '0.0.0.0'
default['zabbix']['java_gateway']['listen_port'] = 10052
default['zabbix']['java_gateway']['pid_file'] = '/var/run/zabbix/zabbix_java.pid'
default['zabbix']['java_gateway']['start_pollers'] = 5
default['zabbix']['java_gateway']['timeout'] = 3

# Platform specific attributes
case node['platform_family']
when 'rhel', 'amazon'
  default['zabbix']['repository_uri'] = "https://repo.zabbix.com/zabbix/#{node['zabbix']['version']}/rhel/#{node['platform_version'].to_i}/$basearch/"
  default['zabbix']['repository_key'] = 'https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX-A14FE591'
when 'debian'
  default['zabbix']['repository_uri'] = "https://repo.zabbix.com/zabbix/#{node['zabbix']['version']}/#{node['platform']}/pool/main/z/zabbix"
  default['zabbix']['repository_key'] = 'https://repo.zabbix.com/zabbix-official-repo.key'
end

# Test kitchen specific attributes
default['zabbix']['test-kitchen'] = {
  'hostname_prefix' => 'zabbix',
  'docker_image' => 'rockylinux/rockylinux:8',
  'memory' => '1024',
  'cpus' => 2,
}