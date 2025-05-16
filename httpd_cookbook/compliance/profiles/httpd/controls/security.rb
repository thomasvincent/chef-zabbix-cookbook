# encoding: utf-8
# copyright: 2023, Thomas Vincent

title 'Apache HTTP Server Security Controls'

config_file = os.debian? ? '/etc/apache2/apache2.conf' : '/etc/httpd/conf/httpd.conf'
config_dir = os.debian? ? '/etc/apache2' : '/etc/httpd'

control 'httpd-security-1' do
  impact 1.0
  title 'Apache should not leak version information'
  desc 'Apache should be configured to not disclose version information'
  
  describe apache_conf(config_file) do
    its('ServerTokens') { should_not cmp 'Full' }
    its('ServerTokens') { should cmp 'Prod' }
  end
end

control 'httpd-security-2' do
  impact 1.0
  title 'Apache should not expose server signature'
  desc 'Apache should be configured to not display the server signature'
  
  describe apache_conf(config_file) do
    its('ServerSignature') { should cmp 'off' }
  end
end

control 'httpd-security-3' do
  impact 1.0
  title 'Apache should disable directory listings'
  desc 'Directory listings should be disabled unless specifically required'
  
  describe apache_conf(config_file) do
    its('content') { should_not match /<Directory.*Options.*Indexes/m }
  end
end

control 'httpd-security-4' do
  impact 1.0
  title 'Apache should have all required modules'
  desc 'All required security and functionality modules should be enabled'
  
  required_modules = [
    'log_config',
    'logio',
    'headers',
    'ssl'
  ]
  
  required_modules.each do |mod|
    describe apache_conf do
      its('LoadModule') { should include mod }
    end
  end
end

control 'httpd-security-5' do
  impact 1.0
  title 'Apache should limit request size'
  desc 'Apache should limit the size of HTTP requests to prevent DoS attacks'
  
  describe apache_conf(config_file) do
    its('LimitRequestBody') { should be_between(0, 104857600) }  # Max 100MB
  end
end

control 'httpd-security-6' do
  impact 1.0
  title 'Apache log files should have appropriate permissions'
  desc 'Apache log files should be protected from unauthorized access'
  
  log_dir = os.debian? ? '/var/log/apache2' : '/var/log/httpd'
  
  describe directory(log_dir) do
    it { should exist }
    it { should be_directory }
    its('mode') { should cmp '0750' }
  end
end

control 'httpd-security-7' do
  impact 1.0
  title 'Apache should use TLS 1.2 or higher'
  desc 'Apache should be configured to use TLS 1.2 or higher for secure connections'
  
  if os.debian?
    ssl_conf_path = '/etc/apache2/mods-enabled/ssl.conf'
  else
    ssl_conf_path = '/etc/httpd/conf.d/ssl.conf'
  end
  
  only_if('SSL configuration exists') do
    file(ssl_conf_path).exist?
  end
  
  describe apache_conf(ssl_conf_path) do
    its('content') { should match(/SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1/) }
  end
end