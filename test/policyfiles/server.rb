name 'server'

default_source :supermarket

cookbook 'zabbix', path: '../../'
cookbook 'apt'
cookbook 'yum-epel'
cookbook 'build-essential'
cookbook 'postgresql'
cookbook 'mysql'
cookbook 'apache2'
cookbook 'nginx'

run_list 'zabbix::server', 'zabbix::web', 'zabbix::agent'

default['zabbix']['agent']['enabled'] = true
default['zabbix']['agent']['servers'] = ['127.0.0.1']
default['zabbix']['agent']['servers_active'] = ['127.0.0.1']
default['zabbix']['server']['enabled'] = true
default['zabbix']['web']['enabled'] = true

# PostgreSQL attributes
default['postgresql']['version'] = '14'
default['postgresql']['enable_pgdg_apt'] = true
default['postgresql']['config']['listen_addresses'] = '*'

# MySQL attributes
default['mysql']['service_name'] = 'default'
default['mysql']['version'] = '8.0'
default['mysql']['bind_address'] = '0.0.0.0'

# Web server attributes
default['apache2']['listen_ports'] = ['80']
default['nginx']['default_site_enabled'] = false