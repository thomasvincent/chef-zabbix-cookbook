# InSpec test for Zabbix agent installation

title 'Verify Zabbix Agent Installation'

# Check for zabbix user
describe user('zabbix') do
  it { should exist }
  its('groups') { should include 'zabbix' }
end

# Check for zabbix group
describe group('zabbix') do
  it { should exist }
end

# Check for zabbix agent configuration
describe file('/etc/zabbix/zabbix_agentd.conf') do
  it { should exist }
  it { should be_file }
  it { should be_readable.by_user('zabbix') }
  its('mode') { should cmp '0640' }
  its('content') { should match /Server=127.0.0.1/ }
  its('content') { should match /ServerActive=127.0.0.1/ }
  its('content') { should match /Hostname=/ }
end

# Check for agent include directory
describe directory('/etc/zabbix/zabbix_agentd.d') do
  it { should exist }
  it { should be_directory }
  it { should be_owned_by 'zabbix' }
  it { should be_grouped_into 'zabbix' }
  its('mode') { should cmp '0755' }
end

# Check for log directory
describe directory('/var/log/zabbix') do
  it { should exist }
  it { should be_directory }
  it { should be_owned_by 'zabbix' }
  it { should be_grouped_into 'zabbix' }
end

# Check for run/pid directory
describe directory('/var/run/zabbix') do
  it { should exist }
  it { should be_directory }
  it { should be_owned_by 'zabbix' }
  it { should be_grouped_into 'zabbix' }
end

# Check for zabbix agent service
describe service('zabbix-agent') do
  it { should be_installed }
  it { should be_enabled }
  it { should be_running }
end

# Check for zabbix agent port
describe port(10050) do
  it { should be_listening }
end

# Check for zabbix agent process
describe processes('zabbix_agentd') do
  its('users') { should eq ['zabbix'] }
  its('list.length') { should be > 0 }
end

# Check for agent binary
describe file('/usr/sbin/zabbix_agentd') do
  it { should exist }
  it { should be_file }
  it { should be_executable }
end