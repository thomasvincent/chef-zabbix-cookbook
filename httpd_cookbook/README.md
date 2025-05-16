# HTTPD Cookbook

[![Cookbook Version](https://img.shields.io/cookbook/v/httpd.svg)](https://supermarket.chef.io/cookbooks/httpd)
[![Build Status](https://img.shields.io/github/workflow/status/thomasvincent/httpd-cookbook/ci)](https://github.com/thomasvincent/httpd-cookbook/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A modern, advanced Chef cookbook to install and configure Apache HTTP Server with comprehensive functionality.

## Requirements

### Platforms

- Ubuntu 20.04+
- Debian 11+
- CentOS Stream 8+
- Red Hat Enterprise Linux 8+
- Amazon Linux 2+
- Rocky Linux 8+
- AlmaLinux 8+
- Fedora 35+

### Chef

- Chef 18.0+

### Dependencies

- `selinux` - For SELinux configuration on RHEL-family systems
- `firewall` - For managing firewall rules
- `logrotate` - For managing log rotation
- `opensslv3` - For modern SSL configurations
- `system` - For system-level configurations
- `poise` - For advanced custom resources

## Features

- Apache installation from OS packages or source
- Multi-MPM support (event, worker, prefork)
- Modular configuration with smart default settings
- TLS/SSL support with modern cipher configurations
- Virtual host management with template flexibility
- Advanced logging options
- Performance tuning based on system resources
- SELinux and AppArmor integration
- HTTP/2 and HTTP/3 support
- Full integration test coverage with InSpec
- Health check and monitoring integration
- Zero Downtime Deployment pattern with graceful reloads
- Ops Actions pattern for backup/restore and blue-green deployments
- Telemetry integration with Prometheus and Grafana

## Custom Resources

### httpd_install

Install Apache HTTP Server.

```ruby
httpd_install 'default' do
  version '2.4.57'
  mpm 'event'
  install_method 'package'
  action :install
end
```

Properties:
- `version` - Apache version to install
- `mpm` - MPM to use (event, worker, prefork)
- `install_method` - Installation method (package, source)
- `package_name` - Package name, if using package installation
- `source_url` - Source URL, if using source installation
- `checksum` - Checksum for source package

### httpd_config

Create Apache configuration snippets.

```ruby
httpd_config 'security' do
  source 'security.conf.erb'
  cookbook 'httpd'
  notifies :restart, 'httpd_service[default]'
  action :create
end
```

Properties:
- `source` - Template source
- `cookbook` - Cookbook containing the template
- `variables` - Variables to pass to the template
- `config_name` - Name of the configuration file (defaults to resource name)

### httpd_module

Enable or disable Apache modules.

```ruby
httpd_module 'ssl' do
  action :enable
end

httpd_module 'status' do
  configuration <<~EOL
    <Location "/server-status">
      SetHandler server-status
      Require local
    </Location>
  EOL
  action :enable
end
```

Properties:
- `module_name` - Module name (defaults to resource name)
- `configuration` - Configuration for the module
- `install_package` - Whether to install package for the module

### httpd_vhost

Configure Apache virtual hosts.

```ruby
httpd_vhost 'example.com' do
  port 80
  document_root '/var/www/example.com'
  action :create
end

httpd_vhost 'secure.example.com' do
  port 443
  document_root '/var/www/secure.example.com'
  ssl_enabled true
  ssl_cert '/etc/ssl/certs/example.com.crt'
  ssl_key '/etc/ssl/private/example.com.key'
  action :create
end
```

Properties:
- `domain` - Domain name (defaults to resource name)
- `port` - Port to listen on
- `document_root` - Document root directory
- `server_admin` - Server admin email
- `error_log` - Error log path
- `access_log` - Access log path
- `ssl_enabled` - Whether to enable SSL
- `ssl_cert` - SSL certificate path
- `ssl_key` - SSL key path
- `ssl_chain` - SSL chain path
- `redirect_http_to_https` - Whether to redirect HTTP to HTTPS
- `custom_directives` - Custom Apache directives to include

### httpd_service

Manage the Apache service.

```ruby
httpd_service 'default' do
  action [:enable, :start]
end
```

Properties:
- `service_name` - Service name
- `restart_command` - Command to restart the service
- `reload_command` - Command to reload the service
- `supports` - Service supports hash

## Attributes

See the [attributes file](attributes/default.rb) for default values.

### General

- `node['httpd']['version']` - Apache version
- `node['httpd']['install_method']` - Installation method
- `node['httpd']['service_name']` - Service name
- `node['httpd']['root_dir']` - Root directory
- `node['httpd']['conf_dir']` - Configuration directory

### MPM

- `node['httpd']['mpm']` - Multi-Processing Module to use

### Security

- `node['httpd']['security']['server_tokens']` - ServerTokens directive
- `node['httpd']['security']['server_signature']` - ServerSignature directive
- `node['httpd']['security']['trace_enable']` - TraceEnable directive

### Performance

- `node['httpd']['performance']['start_servers']` - StartServers directive
- `node['httpd']['performance']['min_spare_threads']` - MinSpareThreads directive
- `node['httpd']['performance']['max_spare_threads']` - MaxSpareThreads directive
- `node['httpd']['performance']['thread_limit']` - ThreadLimit directive
- `node['httpd']['performance']['threads_per_child']` - ThreadsPerChild directive
- `node['httpd']['performance']['max_request_workers']` - MaxRequestWorkers directive
- `node['httpd']['performance']['max_connections_per_child']` - MaxConnectionsPerChild directive

### Telemetry

- `node['httpd']['telemetry']['enabled']` - Enable telemetry functionality
- `node['httpd']['telemetry']['prometheus']['enabled']` - Enable Prometheus exporter
- `node['httpd']['telemetry']['prometheus']['scrape_uri']` - URI to scrape for metrics
- `node['httpd']['telemetry']['prometheus']['telemetry_path']` - Path where metrics will be exposed
- `node['httpd']['telemetry']['prometheus']['metrics']` - Metrics to collect
- `node['httpd']['telemetry']['prometheus']['allow_ips']` - IPs allowed to access metrics
- `node['httpd']['telemetry']['grafana']['enabled']` - Enable Grafana dashboard
- `node['httpd']['telemetry']['grafana']['url']` - Grafana URL
- `node['httpd']['telemetry']['grafana']['datasource']` - Prometheus datasource name
- `node['httpd']['telemetry']['grafana']['api_key']` - Grafana API key

## Recipes

- `default.rb` - Calls other recipes
- `install.rb` - Installs Apache
- `configure.rb` - Basic configuration
- `modules.rb` - Enables default modules
- `service.rb` - Sets up service
- `vhosts.rb` - Configures virtual hosts from attributes
- `security.rb` - Applies security hardening
- `telemetry.rb` - Configures Prometheus and Grafana integration

## Usage

### Basic

Include `httpd` in your node's `run_list`:

```json
{
  "run_list": [
    "recipe[httpd::default]"
  ]
}
```

### Advanced

Configure attributes in a role or wrapper cookbook:

```ruby
default_attributes = {
  'httpd' => {
    'mpm' => 'event',
    'performance' => {
      'max_request_workers' => 400,
      'threads_per_child' => 25
    },
    'telemetry' => {
      'enabled' => true,
      'prometheus' => {
        'enabled' => true,
        'scrape_uri' => '/server-status?auto',
        'telemetry_path' => '/metrics',
        'metrics' => %w(connections scoreboard cpu requests)
      },
      'grafana' => {
        'enabled' => true,
        'url' => 'http://grafana.example.com:3000',
        'datasource' => 'Prometheus'
      }
    },
    'vhosts' => {
      'example.com' => {
        'port' => 80,
        'document_root' => '/var/www/example.com'
      },
      'secure.example.com' => {
        'port' => 443,
        'document_root' => '/var/www/secure.example.com',
        'ssl_enabled' => true,
        'ssl_cert' => '/etc/ssl/certs/secure.example.com.crt',
        'ssl_key' => '/etc/ssl/private/secure.example.com.key'
      }
    }
  }
}
```

## Testing

This cookbook uses:

- ChefSpec for unit testing
- InSpec for integration testing
- Test Kitchen for platform testing
- GitHub Actions for CI/CD

```bash
# Run all tests
delivery local all

# Run unit tests
chef exec rspec

# Run integration tests
kitchen test
```

## License

Apache 2.0

## Author

Thomas Vincent (<thomasvincent@example.com>)