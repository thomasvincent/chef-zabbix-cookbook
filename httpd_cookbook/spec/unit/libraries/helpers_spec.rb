require 'spec_helper'
require_relative '../../../libraries/helpers'

describe Httpd::Helpers do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '20.04') do |node|
      node.default['memory']['total'] = '4096000kB'
      node.default['cpu']['total'] = 4
      node.default['httpd']['version'] = '2.4.57'
    end
  end
  
  let(:subject) { Object.new.extend(Httpd::Helpers) }
  
  before do
    allow(subject).to receive(:node).and_return(chef_run.node)
    allow(subject).to receive(:platform_family?).and_return(false)
    allow(subject).to receive(:platform_family?).with('debian').and_return(chef_run.node['platform_family'] == 'debian')
    allow(subject).to receive(:platform_family?).with('rhel').and_return(chef_run.node['platform_family'] == 'rhel')
    allow(subject).to receive(:platform?).and_return(false)
    allow(subject).to receive(:shell_out!).and_return(double('shellout', stdout: "Enforcing\n"))
  end
  
  describe '#systemd?' do
    it 'returns true when systemd is detected' do
      allow(::File).to receive(:directory?).with('/run/systemd/system').and_return(true)
      allow(::File).to receive(:directory?).with('/sys/fs/cgroup/systemd').and_return(false)
      expect(subject.systemd?).to be true
    end
    
    it 'returns false when systemd is not detected' do
      allow(::File).to receive(:directory?).with('/run/systemd/system').and_return(false)
      allow(::File).to receive(:directory?).with('/sys/fs/cgroup/systemd').and_return(false)
      expect(subject.systemd?).to be false
    end
  end
  
  describe '#system_memory_mb' do
    it 'correctly calculates system memory in MB' do
      expect(subject.system_memory_mb).to eq(4000)
    end
    
    it 'returns default value when memory information is not available' do
      allow(subject).to receive(:node).and_return({})
      expect(subject.system_memory_mb).to eq(2048)
    end
    
    it 'handles errors gracefully' do
      allow(subject).to receive(:node).and_raise(StandardError.new('Test error'))
      expect(subject.system_memory_mb).to eq(2048)
    end
  end
  
  describe '#calculate_max_request_workers' do
    it 'calculates correct value for systems with 4GB RAM' do
      allow(subject).to receive(:system_memory_mb).and_return(4000)
      expect(subject.calculate_max_request_workers).to eq(266)
    end
    
    it 'calculates correct value for systems with 1GB RAM' do
      allow(subject).to receive(:system_memory_mb).and_return(1000)
      expect(subject.calculate_max_request_workers).to eq(66)
    end
    
    it 'calculates correct value for systems with 16GB RAM' do
      allow(subject).to receive(:system_memory_mb).and_return(16000)
      expect(subject.calculate_max_request_workers).to eq(400)
    end
    
    it 'handles errors gracefully' do
      allow(subject).to receive(:system_memory_mb).and_raise(StandardError.new('Test error'))
      expect(subject.calculate_max_request_workers).to eq(150)
    end
  end
  
  describe '#calculate_threads_per_child' do
    it 'calculates correct value for systems with 4 CPUs' do
      allow(subject).to receive(:cpu_cores).and_return(4)
      expect(subject.calculate_threads_per_child).to eq(16)
    end
    
    it 'calculates correct value for systems with 2 CPUs' do
      allow(subject).to receive(:cpu_cores).and_return(2)
      expect(subject.calculate_threads_per_child).to eq(8)
    end
    
    it 'calculates correct value for systems with 8 CPUs' do
      allow(subject).to receive(:cpu_cores).and_return(8)
      expect(subject.calculate_threads_per_child).to eq(25)
    end
    
    it 'calculates correct value for systems with 16 CPUs' do
      allow(subject).to receive(:cpu_cores).and_return(16)
      expect(subject.calculate_threads_per_child).to eq(50)
    end
    
    it 'handles errors gracefully' do
      allow(subject).to receive(:cpu_cores).and_raise(StandardError.new('Test error'))
      expect(subject.calculate_threads_per_child).to eq(25)
    end
  end
  
  describe '#cpu_cores' do
    it 'correctly reports CPU core count' do
      expect(subject.cpu_cores).to eq(4)
    end
    
    it 'returns default value when CPU information is not available' do
      allow(subject).to receive(:node).and_return({})
      expect(subject.cpu_cores).to eq(2)
    end
    
    it 'handles errors gracefully' do
      allow(subject).to receive(:node).and_raise(StandardError.new('Test error'))
      expect(subject.cpu_cores).to eq(2)
    end
  end
  
  describe '#calculate_server_limit' do
    it 'calculates correct value based on max_request_workers and threads_per_child' do
      expect(subject.calculate_server_limit(400, 25)).to eq(18)
    end
    
    it 'handles zero threads_per_child' do
      expect(subject.calculate_server_limit(400, 0)).to eq(16)
    end
    
    it 'handles errors gracefully' do
      expect(subject.calculate_server_limit(nil, nil)).to eq(16)
    end
  end
  
  describe '#module_config_name' do
    it 'returns correct value for rhel family' do
      allow(subject).to receive(:platform_family?).with('rhel').and_return(true)
      expect(subject.module_config_name('ssl')).to eq('00-ssl.conf')
    end
    
    it 'returns correct value for debian family' do
      allow(subject).to receive(:platform_family?).with('debian').and_return(true)
      expect(subject.module_config_name('ssl')).to eq('ssl.conf')
    end
    
    it 'returns correct value for suse family' do
      allow(subject).to receive(:platform_family?).with('suse').and_return(true)
      expect(subject.module_config_name('ssl')).to eq('ssl.conf')
    end
  end
  
  describe '#apache_version_properties' do
    it 'correctly parses version string' do
      result = subject.apache_version_properties
      expect(result[:major]).to eq('2')
      expect(result[:minor]).to eq('4')
      expect(result[:patch]).to eq('57')
      expect(result[:full]).to eq('2.4.57')
    end
    
    it 'handles errors gracefully' do
      allow(subject).to receive(:node).and_return({})
      result = subject.apache_version_properties
      expect(result[:major]).to eq('2')
      expect(result[:minor]).to eq('4')
      expect(result[:patch]).to eq('0')
      expect(result[:full]).to eq('2.4.0')
    end
  end
  
  describe '#apache_24?' do
    it 'returns true for Apache 2.4' do
      allow(subject).to receive(:apache_version_properties).and_return({
        major: '2',
        minor: '4',
        patch: '57',
        full: '2.4.57'
      })
      expect(subject.apache_24?).to be true
    end
    
    it 'returns false for Apache 2.2' do
      allow(subject).to receive(:apache_version_properties).and_return({
        major: '2',
        minor: '2',
        patch: '34',
        full: '2.2.34'
      })
      expect(subject.apache_24?).to be false
    end
    
    it 'returns true for Apache 3.0' do
      allow(subject).to receive(:apache_version_properties).and_return({
        major: '3',
        minor: '0',
        patch: '0',
        full: '3.0.0'
      })
      expect(subject.apache_24?).to be true
    end
  end
  
  describe '#http2_module_name' do
    it 'returns http2 for Apache 2.4' do
      allow(subject).to receive(:apache_24?).and_return(true)
      expect(subject.http2_module_name).to eq('http2')
    end
    
    it 'returns nil for Apache 2.2' do
      allow(subject).to receive(:apache_24?).and_return(false)
      expect(subject.http2_module_name).to be_nil
    end
  end
  
  describe '#file_exist?' do
    it 'returns true when file exists' do
      allow(::File).to receive(:exist?).with('/etc/httpd/conf/httpd.conf').and_return(true)
      expect(subject.file_exist?('/etc/httpd/conf/httpd.conf')).to be true
    end
    
    it 'returns false when file does not exist' do
      allow(::File).to receive(:exist?).with('/etc/httpd/conf/missing.conf').and_return(false)
      expect(subject.file_exist?('/etc/httpd/conf/missing.conf')).to be false
    end
    
    it 'handles errors gracefully' do
      allow(::File).to receive(:exist?).and_raise(StandardError.new('Test error'))
      expect(subject.file_exist?('/etc/httpd/conf/error.conf')).to be false
    end
  end
  
  describe '#directory_exist?' do
    it 'returns true when directory exists' do
      allow(::File).to receive(:directory?).with('/etc/httpd/conf').and_return(true)
      expect(subject.directory_exist?('/etc/httpd/conf')).to be true
    end
    
    it 'returns false when directory does not exist' do
      allow(::File).to receive(:directory?).with('/etc/httpd/missing').and_return(false)
      expect(subject.directory_exist?('/etc/httpd/missing')).to be false
    end
    
    it 'handles errors gracefully' do
      allow(::File).to receive(:directory?).and_raise(StandardError.new('Test error'))
      expect(subject.directory_exist?('/etc/httpd/error')).to be false
    end
  end
  
  describe '#default_config_path' do
    it 'returns correct path for debian' do
      allow(subject).to receive(:platform_family?).with('debian').and_return(true)
      expect(subject.default_config_path).to eq('/etc/apache2/apache2.conf')
    end
    
    it 'returns correct path for rhel' do
      allow(subject).to receive(:platform_family?).with('debian').and_return(false)
      allow(subject).to receive(:platform_family?).with('rhel').and_return(true)
      expect(subject.default_config_path).to eq('/etc/httpd/conf/httpd.conf')
    end
  end
  
  describe '#httpd_service_name' do
    it 'returns apache2 for debian' do
      allow(subject).to receive(:platform_family?).with('debian').and_return(true)
      expect(subject.httpd_service_name).to eq('apache2')
    end
    
    it 'returns httpd for rhel' do
      allow(subject).to receive(:platform_family?).with('debian').and_return(false)
      allow(subject).to receive(:platform_family?).with('rhel').and_return(true)
      expect(subject.httpd_service_name).to eq('httpd')
    end
  end
end