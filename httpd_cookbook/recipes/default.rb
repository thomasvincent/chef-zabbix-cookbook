# frozen_string_literal: true

#
# Cookbook:: httpd
# Recipe:: default
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

# Include other recipes
include_recipe 'httpd::install'
include_recipe 'httpd::configure'
include_recipe 'httpd::vhosts'
include_recipe 'httpd::telemetry'
include_recipe 'httpd::service'