# InSpec test for httpd cookbook source installation suite

# Check if Apache is installed from source
describe file('/usr/local/apache2/bin/httpd') do
  it { should exist }
  it { should be_executable }
end

# Check if Apache is running and enabled
if os.redhat?
  describe service('httpd') do
    it { should be_enabled }
    it { should be_running }
  end

  # Check version
  describe command('/usr/local/apache2/bin/httpd -v') do
    its('stdout') { should match /2\.4\.57/ }
  end
elsif os.debian?
  describe service('apache2') do
    it { should be_enabled }
    it { should be_running }
  end

  # Check version 
  describe command('/usr/local/apache2/bin/httpd -v') do
    its('stdout') { should match /2\.4\.57/ }
  end
end

# Check if Apache is listening on port 80
describe port(80) do
  it { should be_listening }
  its('protocols') { should include 'tcp' }
end

# Check if the event MPM is configured
describe command('grep -r "event" /usr/local/apache2/conf') do
  its('stdout') { should match /event/ }
end

# Check if Apache serves a proper response
describe http('http://localhost/') do
  its('status') { should eq 200 }
end

# Check log directory
describe file('/usr/local/apache2/logs') do
  it { should be_directory }
end

# Check the document root
describe file('/usr/local/apache2/htdocs') do
  it { should be_directory }
end

# Check that the binary is in the path via the symlink
describe file('/usr/sbin/httpd') do
  it { should be_symlink }
  it { should be_linked_to '/usr/local/apache2/bin/httpd' }
end

# Configuration syntax
describe command('/usr/local/apache2/bin/httpd -t') do
  its('exit_status') { should eq 0 }
  its('stderr') { should match /Syntax OK/ }
end