# frozen_string_literal: true

#
# Cookbook:: httpd
# Recipe:: install
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

# Install Apache HTTP Server
httpd_install 'default' do
  version node['httpd']['version']
  mpm node['httpd']['mpm']
  install_method node['httpd']['install_method']
  modules node['httpd']['modules']
  disabled_modules node['httpd']['disabled_modules']
  action :install
end

# Install extra modules
Array(node['httpd']['extra_modules']).each do |mod|
  httpd_module mod do
    action :enable
  end
end