# InSpec test for httpd cookbook performance-tuning suite

# Include default tests first
require_relative '../default/default_test'

# Check if the MPM configuration is properly set
if os.redhat?
  describe file('/etc/httpd/mpm.conf') do
    it { should exist }
    its('content') { should match /MaxRequestWorkers\s+400/ }
    its('content') { should match /ThreadsPerChild\s+25/ }
    its('content') { should match /MaxConnectionsPerChild\s+10000/ }
    its('content') { should match /ServerLimit\s+16/ }
    its('content') { should match /ThreadLimit\s+64/ }
  end
elsif os.debian?
  describe file('/etc/apache2/mods-enabled/mpm_event.conf') do
    it { should exist }
    its('content') { should match /MaxRequestWorkers\s+400/ }
    its('content') { should match /ThreadsPerChild\s+25/ }
    its('content') { should match /MaxConnectionsPerChild\s+10000/ }
    its('content') { should match /ServerLimit\s+16/ }
    its('content') { should match /ThreadLimit\s+64/ }
  end
end

# Check Apache config for performance settings
describe command(os.redhat? ? 'apachectl -t -D DUMP_RUN_CFG' : 'apache2ctl -t -D DUMP_RUN_CFG') do
  its('stdout') { should match /ServerLimit\s+16/ }
  its('stdout') { should match /MaxRequestWorkers\s+400/ }
  its('stdout') { should match /ThreadsPerChild\s+25/ }
  its('stdout') { should match /ThreadLimit\s+64/ }
end

# Check for the HTTP/2 module if enabled
describe command(os.redhat? ? 'apachectl -M' : 'apache2ctl -M') do
  its('stdout') { should match /http2_module/ }
end

# Check if the socket buffer sizes are properly configured
describe kernel_parameter('net.core.rmem_max') do
  its('value') { should be >= 16777216 }
end

describe kernel_parameter('net.core.wmem_max') do
  its('value') { should be >= 16777216 }
end

# Verify system is configured for high concurrency
describe file('/proc/sys/fs/file-max') do
  its('content') { should match /[0-9]{6,}/ } # Should be at least 6 digits (100000+)
end

# Check if Apache is handling connections properly with the tuning
describe http('http://localhost/') do
  its('status') { should eq 200 }
end

# Check systemd overrides for Apache
if os.linux? && os.release.to_f >= 7
  systemd_service_name = os.redhat? ? 'httpd.service' : 'apache2.service'
  describe file("/etc/systemd/system/#{systemd_service_name}.d/override.conf") do
    it { should exist }
    its('content') { should match /LimitNOFILE=65536/ }
  end
end