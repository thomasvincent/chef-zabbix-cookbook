# InSpec test for Zabbix server installation

title 'Verify Zabbix Server Installation'

# Check for zabbix user
describe user('zabbix') do
  it { should exist }
  its('groups') { should include 'zabbix' }
end

# Check for zabbix group
describe group('zabbix') do
  it { should exist }
end

# Check for zabbix server configuration
describe file('/etc/zabbix/zabbix_server.conf') do
  it { should exist }
  it { should be_file }
  it { should be_readable.by_user('zabbix') }
  its('mode') { should cmp '0640' }
  its('content') { should match /ListenPort=10051/ }
  its('content') { should match /DBName=zabbix/ }
  its('content') { should match /DBUser=zabbix/ }
end

# Check the database connection
# This test is conditional based on database type
control 'database-connection' do
  impact 1.0
  title 'Verify database connection'
  
  if command('which psql').exit_status == 0
    describe command("PGPASSWORD=zabbix psql -U zabbix -h 127.0.0.1 -d zabbix -c 'SELECT version();'") do
      its('exit_status') { should eq 0 }
      its('stdout') { should match /PostgreSQL/ }
    end
  elsif command('which mysql').exit_status == 0
    describe command("mysql -u zabbix -pzabbix -h 127.0.0.1 -D zabbix -e 'SELECT version();'") do
      its('exit_status') { should eq 0 }
      its('stdout') { should match /MySQL/ }
    end
  end
end

# Check for zabbix server port
describe port(10051) do
  it { should be_listening }
end

# Check for zabbix server process
describe processes('zabbix_server') do
  its('users') { should eq ['zabbix'] }
  its('list.length') { should be > 0 }
end

# Check for server binary
describe file('/usr/sbin/zabbix_server') do
  it { should exist }
  it { should be_file }
  it { should be_executable }
end

# Check for zabbix web frontend
control 'web-frontend' do
  impact 1.0
  title 'Verify Zabbix web frontend installation'
  
  # Check for web server packages
  if os.debian? || os.ubuntu?
    if file('/etc/apache2').exist?
      describe package('apache2') do
        it { should be_installed }
      end
      describe service('apache2') do
        it { should be_enabled }
        it { should be_running }
      end
    elsif file('/etc/nginx').exist?
      describe package('nginx') do
        it { should be_installed }
      end
      describe service('nginx') do
        it { should be_enabled }
        it { should be_running }
      end
    end
  elsif os.redhat? || os.name == 'amazon'
    if file('/etc/httpd').exist?
      describe package('httpd') do
        it { should be_installed }
      end
      describe service('httpd') do
        it { should be_enabled }
        it { should be_running }
      end
    elsif file('/etc/nginx').exist?
      describe package('nginx') do
        it { should be_installed }
      end
      describe service('nginx') do
        it { should be_enabled }
        it { should be_running }
      end
    end
  end

  # Check for PHP installation
  describe command('php -v') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /PHP/ }
  end

  # Check for Zabbix web frontend files
  describe directory('/usr/share/zabbix') do
    it { should exist }
    it { should be_directory }
  end

  # Check for Zabbix web configuration file
  describe file('/etc/zabbix/web/zabbix.conf.php') do
    it { should exist }
    it { should be_file }
    its('content') { should match /DB\['DATABASE'\] = 'zabbix'/ }
    its('content') { should match /DB\['USER'\] = 'zabbix'/ }
  end
end