# Zabbix Cookbook

[![Chef Cookbook](https://img.shields.io/cookbook/v/zabbix.svg)](https://supermarket.chef.io/cookbooks/zabbix)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

This cookbook installs and configures Zabbix components including the agent, server, frontend, and database backend. It focuses on best practices for Chef 18+ and maintainability.

## Requirements

### Platforms

- Ubuntu 20.04+
- Debian 11+
- CentOS 8+
- RHEL 8+
- Amazon Linux 2+

### Chef

- Chef 18.0+

### Cookbooks

- poise: ~> 2.8
- build-essential: ~> 8.0
- yum-epel: ~> 4.0
- apt: ~> 7.0
- postgresql: ~> 11.0
- mysql: ~> 10.0
- nginx: ~> 13.0
- apache2: ~> 8.0

## Attributes

See `attributes/default.rb` for default values.

### General

- `node['zabbix']['version']` - Zabbix version to install
- `node['zabbix']['api_version']` - Zabbix API version
- `node['zabbix']['dir']` - Directory for Zabbix configuration

### Agent specific

- `node['zabbix']['agent']['install_method']` - Agent installation method ('package' or 'source')
- `node['zabbix']['agent']['servers']` - Array of Zabbix servers
- `node['zabbix']['agent']['include_dir']` - Include directory for agent configuration

### Server specific

- `node['zabbix']['server']['install_method']` - Server installation method ('package' or 'source')
- `node['zabbix']['server']['database']['type']` - Database type ('mysql' or 'postgresql')
- `node['zabbix']['server']['database']['host']` - Database host
- `node['zabbix']['server']['database']['port']` - Database port
- `node['zabbix']['server']['database']['name']` - Database name
- `node['zabbix']['server']['database']['user']` - Database username
- `node['zabbix']['server']['database']['password']` - Database password

### Web specific

- `node['zabbix']['web']['install_method']` - Web installation method
- `node['zabbix']['web']['server']` - Web server ('nginx' or 'apache')
- `node['zabbix']['web']['fqdn']` - Web frontend FQDN

## Resources

### zabbix_agent

Installs and configures Zabbix agent.

```ruby
zabbix_agent 'install' do
  servers ['zabbix-server.example.com']
  action :install
end
```

### zabbix_server

Installs and configures Zabbix server.

```ruby
zabbix_server 'install' do
  database_type 'postgresql'
  database_host 'localhost'
  action :install
end
```

### zabbix_web

Installs and configures Zabbix web frontend.

```ruby
zabbix_web 'install' do
  server 'nginx'
  fqdn 'zabbix.example.com'
  action :install
end
```

## Usage

### zabbix::default

Include this recipe to install all components based on node attributes.

```ruby
include_recipe 'zabbix::default'
```

### zabbix::agent

Include this recipe to install only the Zabbix agent.

```ruby
include_recipe 'zabbix::agent'
```

### zabbix::server

Include this recipe to install only the Zabbix server.

```ruby
include_recipe 'zabbix::server'
```

### zabbix::web

Include this recipe to install only the Zabbix web frontend.

```ruby
include_recipe 'zabbix::web'
```

### zabbix::database

Include this recipe to install and configure the database for Zabbix.

```ruby
include_recipe 'zabbix::database'
```

## Testing

This cookbook uses Test Kitchen for integration tests. You can run the tests using:

```
kitchen test
```

## License and Authors

License: Apache 2.0

Author: Thomas Vincent (<thomasvincent@example.com>)