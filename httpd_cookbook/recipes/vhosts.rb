# frozen_string_literal: true

#
# Cookbook:: httpd
# Recipe:: vhosts
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

# Create the default virtual host if enabled
if node['httpd']['default_vhost']['enabled']
  httpd_vhost 'default' do
    domain node['httpd']['default_vhost']['server_name']
    port node['httpd']['default_vhost']['port']
    server_admin node['httpd']['default_vhost']['server_admin']
    document_root node['httpd']['default_vhost']['document_root']
    directory_options node['httpd']['default_vhost']['directory_options']
    allow_override node['httpd']['default_vhost']['allow_override']
    directory_index node['httpd']['default_vhost']['directory_index']
    error_log node['httpd']['default_vhost']['error_log']
    custom_log node['httpd']['default_vhost']['custom_log']
    priority 000
    enabled true
    action :create
  end
  
  # Create a SSL version of the default virtual host if SSL is enabled
  if node['httpd']['ssl']['enabled'] && node['httpd']['ssl']['certificate'] && node['httpd']['ssl']['certificate_key']
    httpd_vhost 'default-ssl' do
      domain node['httpd']['default_vhost']['server_name']
      port node['httpd']['ssl']['port']
      server_admin node['httpd']['default_vhost']['server_admin']
      document_root node['httpd']['default_vhost']['document_root']
      directory_options node['httpd']['default_vhost']['directory_options']
      allow_override node['httpd']['default_vhost']['allow_override']
      directory_index node['httpd']['default_vhost']['directory_index']
      error_log node['httpd']['default_vhost']['error_log']
      custom_log node['httpd']['default_vhost']['custom_log']
      ssl_enabled true
      ssl_cert node['httpd']['ssl']['certificate']
      ssl_key node['httpd']['ssl']['certificate_key']
      ssl_chain node['httpd']['ssl']['certificate_chain']
      ssl_cipher_suite node['httpd']['ssl']['cipher_suite']
      ssl_protocol node['httpd']['ssl']['protocol']
      ssl_honor_cipher_order node['httpd']['ssl']['honor_cipher_order']
      ssl_session_tickets node['httpd']['ssl']['session_tickets']
      ssl_session_timeout node['httpd']['ssl']['session_timeout']
      ssl_session_cache node['httpd']['ssl']['session_cache']
      priority 001
      enabled true
      action :create
    end
  end
end

# Create custom virtual hosts from attributes
node['httpd']['vhosts'].each do |name, config|
  httpd_vhost name do
    domain config['domain'] || name
    aliases config['aliases'] if config['aliases']
    port config['port'] || node['httpd']['default_vhost']['port']
    ip_address config['ip_address'] if config['ip_address']
    server_admin config['server_admin'] || node['httpd']['default_vhost']['server_admin']
    document_root config['document_root'] || "#{node['httpd']['sites_dir']}/#{name}/public"
    directory_options config['directory_options'] || node['httpd']['default_vhost']['directory_options']
    allow_override config['allow_override'] || node['httpd']['default_vhost']['allow_override']
    directory_index config['directory_index'] || node['httpd']['default_vhost']['directory_index']
    error_log config['error_log'] if config['error_log']
    access_log config['access_log'] if config['access_log']
    custom_log config['custom_log'] if config['custom_log']
    log_format config['log_format'] if config['log_format']
    ssl_enabled config['ssl_enabled'] || false
    ssl_cert config['ssl_cert'] if config['ssl_cert']
    ssl_key config['ssl_key'] if config['ssl_key']
    ssl_chain config['ssl_chain'] if config['ssl_chain']
    ssl_cipher_suite config['ssl_cipher_suite'] || node['httpd']['ssl']['cipher_suite']
    ssl_protocol config['ssl_protocol'] || node['httpd']['ssl']['protocol']
    ssl_honor_cipher_order config['ssl_honor_cipher_order'] || node['httpd']['ssl']['honor_cipher_order']
    ssl_session_tickets config['ssl_session_tickets'] || node['httpd']['ssl']['session_tickets']
    ssl_session_timeout config['ssl_session_timeout'] || node['httpd']['ssl']['session_timeout']
    ssl_session_cache config['ssl_session_cache'] || node['httpd']['ssl']['session_cache']
    hsts_enabled config['hsts_enabled'] || node['httpd']['ssl']['hsts']
    hsts_max_age config['hsts_max_age'] || node['httpd']['ssl']['hsts_max_age']
    hsts_include_subdomains config['hsts_include_subdomains'] || node['httpd']['ssl']['hsts_include_subdomains']
    hsts_preload config['hsts_preload'] || node['httpd']['ssl']['hsts_preload']
    redirect_http_to_https config['redirect_http_to_https'] || node['httpd']['ssl']['auto_redirect_http']
    headers config['headers'] if config['headers']
    custom_directives config['custom_directives'] if config['custom_directives']
    priority config['priority'] || 10
    enable_cgi config['enable_cgi'] || false
    enable_php config['enable_php'] || false
    enable_perl config['enable_perl'] || false
    enable_python config['enable_python'] || false
    directory_configs config['directory_configs'] if config['directory_configs']
    location_configs config['location_configs'] if config['location_configs']
    files_match_configs config['files_match_configs'] if config['files_match_configs']
    proxy_configs config['proxy_configs'] if config['proxy_configs']
    enabled config['enabled'].nil? ? true : config['enabled']
    action :create
  end
end

# Create directory structure for each virtual host's docroot
node['httpd']['vhosts'].each do |name, config|
  docroot = config['document_root'] || "#{node['httpd']['sites_dir']}/#{name}/public"
  directory docroot do
    owner node['httpd']['config']['user']
    group node['httpd']['config']['group']
    mode '0755'
    recursive true
    action :create
  end
  
  # Create an index.html sample if not already present
  file "#{docroot}/index.html" do
    content "<html><body><h1>Welcome to #{name}</h1><p>This is the default page for the #{name} site.</p></body></html>"
    owner node['httpd']['config']['user']
    group node['httpd']['config']['group']
    mode '0644'
    action :create_if_missing
  end
end

log "Apache HTTP Server virtual hosts configuration completed" do
  level :info
end