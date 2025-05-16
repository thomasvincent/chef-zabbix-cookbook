# encoding: utf-8
# copyright: 2023, Thomas Vincent

title 'Apache HTTP Server Base Controls'

httpd_service_name = os.debian? ? 'apache2' : 'httpd'
config_file = os.debian? ? '/etc/apache2/apache2.conf' : '/etc/httpd/conf/httpd.conf'
config_dir = os.debian? ? '/etc/apache2' : '/etc/httpd'

control 'httpd-1' do
  impact 1.0
  title 'Apache HTTP Server should be installed'
  desc 'Ensure the Apache HTTP Server package is installed'
  
  describe.one do
    describe package('httpd') do
      it { should be_installed }
    end
    
    describe package('apache2') do
      it { should be_installed }
    end
  end
end

control 'httpd-2' do
  impact 1.0
  title 'Apache HTTP Server should be running and enabled'
  desc 'Ensure the Apache HTTP Server service is running and enabled at boot'
  
  describe service(httpd_service_name) do
    it { should be_enabled }
    it { should be_running }
  end
end

control 'httpd-3' do
  impact 1.0
  title 'Apache HTTP Server should be listening on configured ports'
  desc 'Ensure Apache HTTP Server is listening on the ports specified in the configuration'
  
  describe port(80) do
    it { should be_listening }
    its('protocols') { should include 'tcp' }
  end
end

control 'httpd-4' do
  impact 1.0
  title 'Apache HTTP Server configuration should be valid'
  desc 'Ensure the Apache HTTP Server configuration is syntactically valid'
  
  apache_cmd = os.debian? ? 'apache2ctl' : 'httpd'
  describe command("#{apache_cmd} -t") do
    its('exit_status') { should eq 0 }
    its('stderr') { should match(/Syntax OK/) }
  end
end

control 'httpd-5' do
  impact 1.0
  title 'Apache HTTP Server configuration should be owned by root'
  desc 'Ensure Apache HTTP Server configuration files are owned by root'
  
  describe file(config_file) do
    it { should exist }
    it { should be_file }
    its('owner') { should eq 'root' }
  end
end

control 'httpd-6' do
  impact 0.5
  title 'Document root should be properly configured'
  desc 'Ensure the Apache HTTP Server document root is properly configured'
  
  describe directory('/var/www/html') do
    it { should exist }
    it { should be_directory }
  end
end