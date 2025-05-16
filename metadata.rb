name 'zabbix'
maintainer 'Thomas Vincent'
maintainer_email 'thomasvincent@example.com'
license 'Apache-2.0'
description 'Installs and configures Zabbix'
version '1.0.0'
chef_version '>= 18.0'
source_url 'https://github.com/thomasvincent/chef-zabbix-cookbook'
issues_url 'https://github.com/thomasvincent/chef-zabbix-cookbook/issues'

supports 'ubuntu', '>= 20.04'
supports 'debian', '>= 11.0'
supports 'centos', '>= 8.0'
supports 'redhat', '>= 8.0'
supports 'amazon', '>= 2.0'

depends 'poise', '~> 2.8'
depends 'build-essential', '~> 8.0'
depends 'yum-epel', '~> 4.0'
depends 'apt', '~> 7.0'
depends 'postgresql', '~> 11.0'
depends 'mysql', '~> 10.0'
depends 'nginx', '~> 13.0'
depends 'apache2', '~> 8.0'

provides 'zabbix::default'
provides 'zabbix::agent'
provides 'zabbix::server'
provides 'zabbix::web'
provides 'zabbix::database'

config_options %w(
  service_name
  service_provider
  agent_version
  server_version
  web_version
  database_type
  database_name
  database_user
  database_password
  server_host
  server_port
)