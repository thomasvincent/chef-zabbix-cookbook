# InSpec test for httpd cookbook SSL suite

# Include all the basic tests first
require_relative '../default/default_test'

# Check if SSL is enabled
describe port(443) do
  it { should be_listening }
  its('protocols') { should include 'tcp' }
end

# Check that the SSL module is enabled
describe file('/etc/httpd/conf.modules.d/ssl.load'), :if => os.redhat? do
  it { should exist }
end

describe file('/etc/apache2/mods-enabled/ssl.load'), :if => os.debian? do
  it { should exist }
end

# Check for SSL configuration
describe file('/etc/httpd/conf.d/ssl.conf'), :if => os.redhat? do
  it { should exist }
  its('content') { should match /SSLEngine on/ }
end

describe file('/etc/apache2/sites-enabled/001-default-ssl.conf'), :if => os.debian? do
  it { should exist }
  its('content') { should match /SSLEngine on/ }
end

# Check for HTTPS redirect
describe http('http://localhost/') do
  its('status') { should be_in [301, 302] }
  its('headers.Location') { should match /^https:\/\// }
end

# Check HTTPS response (using curl since InSpec http resource doesn't support SSL verification skipping)
describe command('curl -k -s -o /dev/null -w "%{http_code}" https://localhost/') do
  its('stdout') { should eq '200' }
end

# Check SSL certificate 
describe file('/etc/pki/tls/certs/localhost.crt'), :if => os.redhat? do
  it { should exist }
end

describe file('/etc/ssl/certs/localhost.crt'), :if => os.debian? do
  it { should exist }
end

# Check SSL key
describe file('/etc/pki/tls/private/localhost.key'), :if => os.redhat? do
  it { should exist }
  it { should_not be_readable.by('others') }
end

describe file('/etc/ssl/private/localhost.key'), :if => os.debian? do
  it { should exist }
  it { should_not be_readable.by('others') }
end