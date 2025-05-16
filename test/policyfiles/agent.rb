name 'agent'

default_source :supermarket

cookbook 'zabbix', path: '../../'
cookbook 'apt'
cookbook 'yum-epel'
cookbook 'build-essential'

run_list 'zabbix::agent'

default['zabbix']['agent']['enabled'] = true
default['zabbix']['agent']['servers'] = ['127.0.0.1']
default['zabbix']['agent']['servers_active'] = ['127.0.0.1']
default['zabbix']['server']['enabled'] = false
default['zabbix']['web']['enabled'] = false
default['zabbix']['java_gateway']['enabled'] = false