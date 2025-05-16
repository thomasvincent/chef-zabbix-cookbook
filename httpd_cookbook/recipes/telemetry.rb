# frozen_string_literal: true

#
# Cookbook:: httpd
# Recipe:: telemetry
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

return unless node['httpd']['telemetry']['enabled']

# Configure Prometheus exporter if enabled
if node['httpd']['telemetry']['prometheus']['enabled']
  # Allow server-status access for telemetry
  node.default['httpd']['security']['disable_server_status'] = false
  node.default['httpd']['monitoring']['restricted_access'] = true
  node.default['httpd']['monitoring']['allowed_ips'] = node['httpd']['telemetry']['prometheus']['allow_ips']

  # Configure the Prometheus exporter
  configure_prometheus_exporter(
    nil,
    node['httpd']['telemetry']['prometheus']['scrape_uri'],
    node['httpd']['telemetry']['prometheus']['telemetry_path'],
    node['httpd']['telemetry']['prometheus']['metrics']
  )
end

# Configure Grafana dashboard if enabled
if node['httpd']['telemetry']['grafana']['enabled'] && node['httpd']['telemetry']['prometheus']['enabled']
  configure_grafana_dashboard(
    node['httpd']['telemetry']['grafana']['url'],
    node['httpd']['telemetry']['grafana']['datasource'],
    node['httpd']['telemetry']['grafana']['api_key']
  )
end