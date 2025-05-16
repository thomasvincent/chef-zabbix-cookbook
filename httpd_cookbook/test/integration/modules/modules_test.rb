# InSpec test for httpd cookbook modules suite

# Include default tests first
require_relative '../default/default_test'

# Define modules to test
modules_to_test = %w(proxy proxy_http rewrite proxy_balancer lbmethod_byrequests)

# Check if the specified modules are enabled
modules_to_test.each do |mod|
  if os.redhat?
    describe file("/etc/httpd/conf.modules.d/#{mod}.load") do
      it { should exist }
      its('content') { should match /LoadModule #{mod}_module/ }
    end
  elsif os.debian?
    describe file("/etc/apache2/mods-enabled/#{mod}.load") do
      it { should exist }
    end
  end
end

# Check Apache modules with apachectl
describe command(os.redhat? ? 'apachectl -M' : 'apache2ctl -M') do
  modules_to_test.each do |mod|
    its('stdout') { should match /#{mod}_module/ }
  end
end

# Validate system functionality with the modules
# Test rewrite module
if os.redhat?
  describe file('/etc/httpd/conf.d/rewrite-test.conf') do
    it { should exist }
    its('content') { should match /RewriteEngine On/ }
  end
elsif os.debian?
  describe file('/etc/apache2/conf-enabled/rewrite-test.conf') do
    it { should exist }
    its('content') { should match /RewriteEngine On/ }
  end
end

# Test proxy module
if os.redhat?
  describe file('/etc/httpd/conf.d/proxy-test.conf') do
    it { should exist }
    its('content') { should match /ProxyPass/ }
  end
elsif os.debian?
  describe file('/etc/apache2/conf-enabled/proxy-test.conf') do
    it { should exist }
    its('content') { should match /ProxyPass/ }
  end
end

# Check that mod_status is working properly
describe http('http://localhost/server-status?auto') do
  its('status') { should eq 200 }
  its('body') { should match /ServerVersion/ }
end

# Check for proxy balancer configuration
if os.redhat?
  describe file('/etc/httpd/conf.d/proxy-balancer.conf') do
    it { should exist }
    its('content') { should match /BalancerMember/ }
  end
elsif os.debian?
  describe file('/etc/apache2/conf-enabled/proxy-balancer.conf') do
    it { should exist }
    its('content') { should match /BalancerMember/ }
  end
end