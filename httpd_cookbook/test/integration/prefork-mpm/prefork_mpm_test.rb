# InSpec test for httpd cookbook prefork-mpm suite

# Include default tests first
require_relative '../default/default_test'

# Check that the prefork MPM is configured
if os.redhat?
  describe file('/etc/httpd/conf.modules.d/00-mpm.conf') do
    it { should exist }
    its('content') { should match /LoadModule mpm_prefork_module/ }
    its('content') { should_not match /LoadModule mpm_event_module/ }
    its('content') { should_not match /LoadModule mpm_worker_module/ }
  end
  
  describe file('/etc/httpd/mpm.conf') do
    it { should exist }
    its('content') { should match /ServerLimit/ }
    its('content') { should match /StartServers/ }
    its('content') { should match /MinSpareServers/ }
    its('content') { should match /MaxSpareServers/ }
    its('content') { should match /MaxRequestWorkers/ }
    its('content') { should match /MaxConnectionsPerChild/ }
  end
elsif os.debian?
  describe file('/etc/apache2/mods-enabled/mpm_prefork.load') do
    it { should exist }
  end
  
  describe file('/etc/apache2/mods-enabled/mpm_event.load') do
    it { should_not exist }
  end
  
  describe file('/etc/apache2/mods-enabled/mpm_worker.load') do
    it { should_not exist }
  end
  
  describe file('/etc/apache2/mods-enabled/mpm_prefork.conf') do
    it { should exist }
    its('content') { should match /ServerLimit/ }
    its('content') { should match /StartServers/ }
    its('content') { should match /MinSpareServers/ }
    its('content') { should match /MaxSpareServers/ }
    its('content') { should match /MaxRequestWorkers/ }
    its('content') { should match /MaxConnectionsPerChild/ }
  end
end

# Check if Apache is using the prefork MPM
describe command(os.redhat? ? 'httpd -V' : 'apache2 -V') do
  its('stdout') { should match /Server MPM:.*prefork/i }
end

# Ensure the correct child processes are running
describe command('ps -ef | grep apache | grep -v grep | wc -l') do
  its('stdout') { should match /[2-9]/ } # Should have at least 2 processes
end

# Check that Apache is handling requests properly with prefork
describe http('http://localhost/') do
  its('status') { should eq 200 }
end