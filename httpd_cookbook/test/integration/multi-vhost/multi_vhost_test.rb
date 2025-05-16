# InSpec test for httpd cookbook multi-vhost suite

# Include default tests first
require_relative '../default/default_test'

# Check if the default vhost is configured
if os.redhat?
  describe file('/etc/httpd/conf.d/000-default.conf') do
    it { should exist }
    its('content') { should match /ServerName localhost/ }
  end
elsif os.debian?
  describe file('/etc/apache2/sites-enabled/000-default.conf') do
    it { should exist }
    its('content') { should match /ServerName localhost/ }
  end
end

# Check for example.com vhost
if os.redhat?
  describe file('/etc/httpd/conf.d/010-example.com.conf') do
    it { should exist }
    its('content') { should match /ServerName example.com/ }
    its('content') { should match /DocumentRoot "\/var\/www\/example"/ }
    its('content') { should match /<VirtualHost \*:8080>/ }
  end
elsif os.debian?
  describe file('/etc/apache2/sites-enabled/010-example.com.conf') do
    it { should exist }
    its('content') { should match /ServerName example.com/ }
    its('content') { should match /DocumentRoot "\/var\/www\/example"/ }
    its('content') { should match /<VirtualHost \*:8080>/ }
  end
end

# Check for secure.example.com vhost
if os.redhat?
  describe file('/etc/httpd/conf.d/010-secure.example.com.conf') do
    it { should exist }
    its('content') { should match /ServerName secure.example.com/ }
    its('content') { should match /DocumentRoot "\/var\/www\/secure"/ }
    its('content') { should match /SSLEngine on/ }
    its('content') { should match /SSLCertificateFile/ }
    its('content') { should match /SSLCertificateKeyFile/ }
  end
elsif os.debian?
  describe file('/etc/apache2/sites-enabled/010-secure.example.com.conf') do
    it { should exist }
    its('content') { should match /ServerName secure.example.com/ }
    its('content') { should match /DocumentRoot "\/var\/www\/secure"/ }
    its('content') { should match /SSLEngine on/ }
    its('content') { should match /SSLCertificateFile/ }
    its('content') { should match /SSLCertificateKeyFile/ }
  end
end

# Check the document roots
describe directory('/var/www/example') do
  it { should exist }
  it { should be_directory }
  its('owner') { should eq os.redhat? ? 'apache' : 'www-data' }
  its('group') { should eq os.redhat? ? 'apache' : 'www-data' }
end

describe directory('/var/www/secure') do
  it { should exist }
  it { should be_directory }
  its('owner') { should eq os.redhat? ? 'apache' : 'www-data' }
  its('group') { should eq os.redhat? ? 'apache' : 'www-data' }
end

# Check if port 8080 is listening
describe port(8080) do
  it { should be_listening }
  its('protocols') { should include 'tcp' }
end

# Check if Apache is serving the example.com site
describe command('curl -H "Host: example.com" http://localhost:8080/') do
  its('stdout') { should match /Welcome to example.com/ }
  its('exit_status') { should eq 0 }
end

# Check if Apache is serving the secure.example.com site with HTTPS
describe command('curl -k -H "Host: secure.example.com" https://localhost/') do
  its('stdout') { should match /Welcome to secure.example.com/ }
  its('exit_status') { should eq 0 }
end