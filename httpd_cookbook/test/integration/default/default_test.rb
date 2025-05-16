# InSpec test for httpd cookbook default suite

# Check if Apache is installed
describe package('httpd'), :if => os.redhat? do
  it { should be_installed }
end

describe package('apache2'), :if => os.debian? do
  it { should be_installed }
end

# Check if Apache is running and enabled
describe service('httpd'), :if => os.redhat? do
  it { should be_enabled }
  it { should be_running }
end

describe service('apache2'), :if => os.debian? do
  it { should be_enabled }
  it { should be_running }
end

# Check if Apache is listening on port 80
describe port(80) do
  it { should be_listening }
  its('protocols') { should include 'tcp' }
end

# Check if the default Apache site is present
describe file('/etc/httpd/conf.d/000-default.conf'), :if => os.redhat? do
  it { should exist }
end

describe file('/etc/apache2/sites-enabled/000-default.conf'), :if => os.debian? do
  it { should exist }
end

# Check if basic modules are enabled
%w(alias auth_basic authn_core authn_file authz_host authz_user autoindex deflate dir env filter mime reqtimeout setenvif status).each do |mod|
  describe file("/etc/httpd/conf.modules.d/#{mod}.load"), :if => os.redhat? do
    it { should exist }
  end
  
  describe file("/etc/apache2/mods-enabled/#{mod}.load"), :if => os.debian? do
    it { should exist }
  end
end

# Check if Apache serves a proper response
describe http('http://localhost/') do
  its('status') { should eq 200 }
  its('body') { should match /Welcome/ }
end

# Check log directory permissions
describe file('/var/log/httpd'), :if => os.redhat? do
  it { should be_directory }
  it { should be_owned_by 'root' }
  its('group') { should eq 'root' }
  its('mode') { should cmp '0755' }
end

describe file('/var/log/apache2'), :if => os.debian? do
  it { should be_directory }
  it { should be_owned_by 'root' }
  its('group') { should eq 'adm' }
  its('mode') { should cmp '0755' }
end

# Check the document root permissions
describe file('/var/www/html') do
  it { should be_directory }
  it { should be_owned_by os.redhat? ? 'apache' : 'www-data' }
  its('group') { should eq os.redhat? ? 'apache' : 'www-data' }
  its('mode') { should cmp '0755' }
end

# Configuration syntax
describe command(os.redhat? ? 'apachectl -t' : 'apache2ctl -t') do
  its('exit_status') { should eq 0 }
  its('stderr') { should match /Syntax OK/ }
end