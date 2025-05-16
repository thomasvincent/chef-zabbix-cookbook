# frozen_string_literal: true

#
# Cookbook:: zabbix
# Recipe:: database
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

# Set up the required database for Zabbix
case node['zabbix']['server']['database']['type']
when 'postgresql'
  # Include PostgreSQL recipes
  include_recipe 'postgresql::server'
  include_recipe 'postgresql::client'

  # Create Zabbix database user
  postgresql_user node['zabbix']['server']['database']['user'] do
    superuser false
    createdb false
    login true
    replication false
    password node['zabbix']['server']['database']['password']
    action :create
  end

  # Create Zabbix database
  postgresql_database node['zabbix']['server']['database']['name'] do
    owner node['zabbix']['server']['database']['user']
    template 'template0'
    encoding 'UTF-8'
    locale 'en_US.UTF-8'
    action :create
  end

  # Only import schema when using PostgreSQL if server is installed
  bash 'import_zabbix_database_schema' do
    user 'postgres'
    code <<-EOH
      psql -U #{node['zabbix']['server']['database']['user']} \
           -d #{node['zabbix']['server']['database']['name']} \
           -f /usr/share/doc/zabbix-server-pgsql*/schema.sql
      psql -U #{node['zabbix']['server']['database']['user']} \
           -d #{node['zabbix']['server']['database']['name']} \
           -f /usr/share/doc/zabbix-server-pgsql*/images.sql
      psql -U #{node['zabbix']['server']['database']['user']} \
           -d #{node['zabbix']['server']['database']['name']} \
           -f /usr/share/doc/zabbix-server-pgsql*/data.sql
    EOH
    sensitive true
    environment 'PGPASSWORD' => node['zabbix']['server']['database']['password']
    not_if "psql -U #{node['zabbix']['server']['database']['user']} \
            -d #{node['zabbix']['server']['database']['name']} \
            -c 'SELECT count(*) FROM users' -t 2>/dev/null | grep -q '[1-9]'",
           environment: { 'PGPASSWORD' => node['zabbix']['server']['database']['password'] }
    only_if 'test -f /usr/sbin/zabbix_server', environment: { 'PATH' => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' }
  end

when 'mysql'
  # Include MySQL recipes
  include_recipe 'mysql::server'
  include_recipe 'mysql::client'

  # Create database connection info as a hash
  mysql_connection_info = {
    host: node['zabbix']['server']['database']['host'],
    username: 'root',
    password: node['mysql']['server_root_password'],
  }

  # Create Zabbix database
  mysql_database node['zabbix']['server']['database']['name'] do
    connection mysql_connection_info
    action :create
    collation 'utf8_bin'
    encoding 'utf8'
  end

  # Create Zabbix database user
  mysql_database_user node['zabbix']['server']['database']['user'] do
    connection mysql_connection_info
    password node['zabbix']['server']['database']['password']
    database_name node['zabbix']['server']['database']['name']
    host '%'
    privileges [:all]
    action [:create, :grant]
  end

  # Import database schema when using MySQL if server is installed
  bash 'import_zabbix_database_schema' do
    code <<-EOH
      mysql -u#{node['zabbix']['server']['database']['user']} \
            -p#{node['zabbix']['server']['database']['password']} \
            -h#{node['zabbix']['server']['database']['host']} \
            #{node['zabbix']['server']['database']['name']} \
            < /usr/share/doc/zabbix-server-mysql*/schema.sql
      mysql -u#{node['zabbix']['server']['database']['user']} \
            -p#{node['zabbix']['server']['database']['password']} \
            -h#{node['zabbix']['server']['database']['host']} \
            #{node['zabbix']['server']['database']['name']} \
            < /usr/share/doc/zabbix-server-mysql*/images.sql
      mysql -u#{node['zabbix']['server']['database']['user']} \
            -p#{node['zabbix']['server']['database']['password']} \
            -h#{node['zabbix']['server']['database']['host']} \
            #{node['zabbix']['server']['database']['name']} \
            < /usr/share/doc/zabbix-server-mysql*/data.sql
    EOH
    sensitive true
    not_if "mysql -u#{node['zabbix']['server']['database']['user']} \
            -p#{node['zabbix']['server']['database']['password']} \
            -h#{node['zabbix']['server']['database']['host']} \
            -e 'SELECT count(*) FROM users' \
            #{node['zabbix']['server']['database']['name']} 2>/dev/null | grep -q '[1-9]'"
    only_if 'test -f /usr/sbin/zabbix_server', environment: { 'PATH' => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' }
  end
end

# Log successful database setup
log 'Zabbix database setup completed' do
  level :info
end