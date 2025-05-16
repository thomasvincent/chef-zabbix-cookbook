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

unified_mode true

# Set up the required database for Zabbix
case node['zabbix']['server']['database']['type']
when 'postgresql'
  # Include PostgreSQL recipes
  include_recipe 'postgresql::server'
  include_recipe 'postgresql::client'

  # Create Zabbix database user with modern resource
  postgresql_database_user node['zabbix']['server']['database']['user'] do
    conn_validator_include_password true
    password node['zabbix']['server']['database']['password']
    database_name node['zabbix']['server']['database']['name']
    action :create
  end

  # Create Zabbix database with modern resource
  postgresql_database node['zabbix']['server']['database']['name'] do
    template 'template0'
    owner node['zabbix']['server']['database']['user']
    encoding 'UTF-8'
    locale 'en_US.UTF-8'
    action :create
  end

  # Grant privileges to user
  postgresql_access 'zabbix_local' do
    access_type 'host'
    access_db node['zabbix']['server']['database']['name']
    access_user node['zabbix']['server']['database']['user']
    access_addr '127.0.0.1/32'
    access_method 'md5'
  end

  # Import schema with more robust error handling
  ruby_block 'import_zabbix_pgsql_schema' do
    block do
      # Find schema files
      schema_file = Dir.glob('/usr/share/doc/zabbix-server-pgsql*/schema.sql').first
      images_file = Dir.glob('/usr/share/doc/zabbix-server-pgsql*/images.sql').first
      data_file = Dir.glob('/usr/share/doc/zabbix-server-pgsql*/data.sql').first

      if schema_file && images_file && data_file
        # Set environment for psql
        env = { 'PGPASSWORD' => node['zabbix']['server']['database']['password'] }
        
        # Check if schema already imported
        cmd = Mixlib::ShellOut.new(
          "psql -U #{node['zabbix']['server']['database']['user']} " \
          "-h #{node['zabbix']['server']['database']['host']} " \
          "-d #{node['zabbix']['server']['database']['name']} " \
          "-c 'SELECT count(*) FROM information_schema.tables " \
          "WHERE table_schema = ''public'' AND table_name = ''users'';' -t",
          environment: env
        )
        cmd.run_command
        tables_exist = cmd.stdout.strip.to_i > 0

        unless tables_exist
          # Import schema
          cmd = Mixlib::ShellOut.new(
            "psql -U #{node['zabbix']['server']['database']['user']} " \
            "-h #{node['zabbix']['server']['database']['host']} " \
            "-d #{node['zabbix']['server']['database']['name']} " \
            "-f #{schema_file}",
            environment: env
          )
          cmd.run_command
          unless cmd.exitstatus.zero?
            Chef::Log.error("Failed to import schema: #{cmd.stderr}")
            raise "Failed to import Zabbix PostgreSQL schema"
          end

          # Import images
          cmd = Mixlib::ShellOut.new(
            "psql -U #{node['zabbix']['server']['database']['user']} " \
            "-h #{node['zabbix']['server']['database']['host']} " \
            "-d #{node['zabbix']['server']['database']['name']} " \
            "-f #{images_file}",
            environment: env
          )
          cmd.run_command
          unless cmd.exitstatus.zero?
            Chef::Log.error("Failed to import images: #{cmd.stderr}")
            raise "Failed to import Zabbix PostgreSQL images"
          end

          # Import data
          cmd = Mixlib::ShellOut.new(
            "psql -U #{node['zabbix']['server']['database']['user']} " \
            "-h #{node['zabbix']['server']['database']['host']} " \
            "-d #{node['zabbix']['server']['database']['name']} " \
            "-f #{data_file}",
            environment: env
          )
          cmd.run_command
          unless cmd.exitstatus.zero?
            Chef::Log.error("Failed to import data: #{cmd.stderr}")
            raise "Failed to import Zabbix PostgreSQL data"
          end

          Chef::Log.info('Zabbix PostgreSQL database schema imported successfully')
        else
          Chef::Log.info('Zabbix PostgreSQL database schema already exists')
        end
      else
        Chef::Log.warn('Zabbix PostgreSQL schema files not found')
      end
    end
    action :run
    only_if "test -f /usr/sbin/zabbix_server", environment: { 'PATH' => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' }
  end

when 'mysql'
  # Include MySQL recipes
  include_recipe 'mysql::server'
  include_recipe 'mysql::client'

  # Create database with modern resource
  mysql_database node['zabbix']['server']['database']['name'] do
    host node['zabbix']['server']['database']['host']
    user 'root'
    password node['mysql']['server_root_password']
    collation 'utf8_bin'
    encoding 'utf8'
    action :create
  end

  # Create user with modern resource
  mysql_user node['zabbix']['server']['database']['user'] do
    host '%'
    password node['zabbix']['server']['database']['password']
    action :create
  end

  # Grant privileges with modern resource
  mysql_database_user node['zabbix']['server']['database']['user'] do
    connection(
      host: node['zabbix']['server']['database']['host'],
      username: 'root',
      password: node['mysql']['server_root_password']
    )
    password node['zabbix']['server']['database']['password']
    database_name node['zabbix']['server']['database']['name']
    host '%'
    privileges [:all]
    action :grant
  end

  # Import schema with more robust error handling
  ruby_block 'import_zabbix_mysql_schema' do
    block do
      # Find schema files
      schema_file = Dir.glob('/usr/share/doc/zabbix-server-mysql*/schema.sql').first
      images_file = Dir.glob('/usr/share/doc/zabbix-server-mysql*/images.sql').first
      data_file = Dir.glob('/usr/share/doc/zabbix-server-mysql*/data.sql').first

      if schema_file && images_file && data_file
        # Check if schema already imported
        cmd = Mixlib::ShellOut.new(
          "mysql -u#{node['zabbix']['server']['database']['user']} " \
          "-p#{node['zabbix']['server']['database']['password']} " \
          "-h#{node['zabbix']['server']['database']['host']} " \
          "-e 'SELECT COUNT(*) FROM information_schema.tables " \
          "WHERE table_schema=\"#{node['zabbix']['server']['database']['name']}\" " \
          "AND table_name=\"users\";'"
        )
        cmd.run_command
        tables_exist = cmd.stdout.strip.to_i > 0

        unless tables_exist
          # Import schema
          cmd = Mixlib::ShellOut.new(
            "mysql -u#{node['zabbix']['server']['database']['user']} " \
            "-p#{node['zabbix']['server']['database']['password']} " \
            "-h#{node['zabbix']['server']['database']['host']} " \
            "#{node['zabbix']['server']['database']['name']} < #{schema_file}"
          )
          cmd.run_command
          unless cmd.exitstatus.zero?
            Chef::Log.error("Failed to import schema: #{cmd.stderr}")
            raise "Failed to import Zabbix MySQL schema"
          end

          # Import images
          cmd = Mixlib::ShellOut.new(
            "mysql -u#{node['zabbix']['server']['database']['user']} " \
            "-p#{node['zabbix']['server']['database']['password']} " \
            "-h#{node['zabbix']['server']['database']['host']} " \
            "#{node['zabbix']['server']['database']['name']} < #{images_file}"
          )
          cmd.run_command
          unless cmd.exitstatus.zero?
            Chef::Log.error("Failed to import images: #{cmd.stderr}")
            raise "Failed to import Zabbix MySQL images"
          end

          # Import data
          cmd = Mixlib::ShellOut.new(
            "mysql -u#{node['zabbix']['server']['database']['user']} " \
            "-p#{node['zabbix']['server']['database']['password']} " \
            "-h#{node['zabbix']['server']['database']['host']} " \
            "#{node['zabbix']['server']['database']['name']} < #{data_file}"
          )
          cmd.run_command
          unless cmd.exitstatus.zero?
            Chef::Log.error("Failed to import data: #{cmd.stderr}")
            raise "Failed to import Zabbix MySQL data"
          end

          Chef::Log.info('Zabbix MySQL database schema imported successfully')
        else
          Chef::Log.info('Zabbix MySQL database schema already exists')
        end
      else
        Chef::Log.warn('Zabbix MySQL schema files not found')
      end
    end
    action :run
    sensitive true
    only_if "test -f /usr/sbin/zabbix_server", environment: { 'PATH' => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' }
  end
end

# Log successful database setup
log 'Zabbix database setup completed' do
  level :info
end