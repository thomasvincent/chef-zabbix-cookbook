require 'spec_helper'
require_relative '../../../libraries/ops_actions'

describe Httpd::OpsActions do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '20.04') do |node|
      node.automatic['hostname'] = 'testhost'
      node.automatic['platform'] = 'ubuntu'
      node.automatic['platform_version'] = '20.04'
      node.automatic['platform_family'] = 'debian'
    end
  end
  
  let(:subject) { Object.new.extend(Httpd::OpsActions) }
  
  before do
    allow(subject).to receive(:node).and_return(chef_run.node)
    allow(subject).to receive(:shell_out).and_return(double('shellout', exitstatus: 0, stdout: 'Apache version: Apache/2.4.41', stderr: ''))
    allow(subject).to receive(:httpd_service_name).and_return('apache2')
    allow(subject).to receive(:platform_family?).and_return(false)
    allow(subject).to receive(:platform_family?).with('debian').and_return(chef_run.node['platform_family'] == 'debian')
    allow(subject).to receive(:file).and_return(nil)
    allow(subject).to receive(:service).and_return(nil)
    
    # Stub FileUtils methods
    allow(FileUtils).to receive(:mkdir_p).and_return(nil)
    allow(FileUtils).to receive(:cp_r).and_return(nil)
    allow(FileUtils).to receive(:chmod_R).and_return(nil)
    allow(FileUtils).to receive(:rm_rf).and_return(nil)
    allow(FileUtils).to receive(:mv).and_return(nil)
    allow(FileUtils).to receive(:ln_s).and_return(nil)
    allow(FileUtils).to receive(:rm).and_return(nil)
    allow(FileUtils).to receive(:remove_entry).and_return(nil)
    
    # Stub Dir methods
    allow(Dir).to receive(:exist?).and_return(true)
    allow(Dir).to receive(:mktmpdir).and_return('/tmp/apache-restore')
    allow(Dir).to receive(:[]).and_return(['/etc/apache2/apache2.conf'])
    
    # Stub File methods
    allow(::File).to receive(:exist?).and_return(true)
    allow(::File).to receive(:directory?).and_return(true)
    allow(::File).to receive(:symlink?).and_return(false)
    allow(::File).to receive(:readlink).and_return('/etc/apache2-blue')
    allow(::File).to receive(:dirname).and_return('/var/backups/httpd')
    allow(::File).to receive(:basename).and_return('apache2')
    allow(::File).to receive(:read).and_return('{"platform":"ubuntu","platform_version":"20.04"}')
    
    # Stub JSON methods
    allow(JSON).to receive(:parse).and_return({'platform' => 'ubuntu', 'platform_version' => '20.04'})
    allow(JSON).to receive(:pretty_generate).and_return('{}')
    
    # Stub Time methods
    allow(Time).to receive(:now).and_return(Time.new(2025, 5, 16, 12, 0, 0))
  end
  
  describe '#backup_config' do
    it 'creates a backup directory if it does not exist' do
      expect(FileUtils).to receive(:mkdir_p).with('/var/backups/httpd')
      
      subject.backup_config
    end
    
    it 'creates a tar.gz archive of the configuration directory' do
      expect(subject).to receive(:shell_out).with("tar -czf /var/backups/httpd/apache-config-20250516-120000.tar.gz -C /etc /apache2").and_return(double('shellout', exitstatus: 0, stderr: ''))
      
      subject.backup_config
    end
    
    it 'returns the path to the backup file on success' do
      result = subject.backup_config
      
      expect(result).to eq('/var/backups/httpd/apache-config-20250516-120000.tar.gz')
    end
    
    it 'adds a label to the backup filename if provided' do
      expect(subject).to receive(:shell_out).with("tar -czf /var/backups/httpd/apache-config-20250516-120000-mylabel.tar.gz -C /etc /apache2").and_return(double('shellout', exitstatus: 0, stderr: ''))
      
      result = subject.backup_config('/var/backups/httpd', 'mylabel')
      
      expect(result).to eq('/var/backups/httpd/apache-config-20250516-120000-mylabel.tar.gz')
    end
    
    it 'returns nil if creating the archive fails' do
      allow(subject).to receive(:shell_out).and_return(double('shellout', exitstatus: 1, stderr: 'Failed to create archive'))
      expect(Chef::Log).to receive(:error).with(/Failed to create backup archive/)
      
      result = subject.backup_config
      
      expect(result).to be_nil
    end
    
    it 'creates a metadata file with backup information' do
      expect(subject).to receive(:file).with('/var/backups/httpd/apache-config-20250516-120000.json')
      
      subject.backup_config
    end
  end
  
  describe '#restore_config' do
    it 'returns false if backup file does not exist' do
      allow(::File).to receive(:exist?).with('/var/backups/httpd/backup.tar.gz').and_return(false)
      expect(Chef::Log).to receive(:error).with(/Backup file not found/)
      
      result = subject.restore_config('/var/backups/httpd/backup.tar.gz')
      
      expect(result).to be false
    end
    
    it 'extracts the backup archive to a temporary directory' do
      expect(subject).to receive(:shell_out).with("tar -xzf /var/backups/httpd/backup.tar.gz -C /tmp/apache-restore").and_return(double('shellout', exitstatus: 0, stderr: ''))
      
      subject.restore_config('/var/backups/httpd/backup.tar.gz')
    end
    
    it 'verifies platform compatibility using metadata' do
      allow(::File).to receive(:exist?).with('/var/backups/httpd/backup.json').and_return(true)
      allow(JSON).to receive(:parse).and_return({'platform' => 'ubuntu', 'platform_version' => '20.04'})
      
      result = subject.restore_config('/var/backups/httpd/backup.tar.gz')
      
      expect(result).to be true
    end
    
    it 'returns false if platform is incompatible and force is false' do
      allow(::File).to receive(:exist?).with('/var/backups/httpd/backup.json').and_return(true)
      allow(JSON).to receive(:parse).and_return({'platform' => 'centos', 'platform_version' => '8'})
      expect(Chef::Log).to receive(:warn).with(/Platform mismatch/)
      
      result = subject.restore_config('/var/backups/httpd/backup.tar.gz', false)
      
      expect(result).to be false
    end
    
    it 'continues if platform is incompatible but force is true' do
      allow(::File).to receive(:exist?).with('/var/backups/httpd/backup.json').and_return(true)
      allow(JSON).to receive(:parse).and_return({'platform' => 'centos', 'platform_version' => '8'})
      expect(subject).to receive(:service).at_least(:once)
      
      result = subject.restore_config('/var/backups/httpd/backup.tar.gz', true)
      
      expect(result).to be true
    end
    
    it 'stops the Apache service before restoring' do
      expect(subject).to receive(:service).with('apache2').at_least(:once)
      
      subject.restore_config('/var/backups/httpd/backup.tar.gz')
    end
    
    it 'creates a backup of the current configuration before restoring' do
      expect(subject).to receive(:backup_config).and_return('/var/backups/httpd/pre-restore-backup.tar.gz')
      
      subject.restore_config('/var/backups/httpd/backup.tar.gz')
    end
    
    it 'validates the restored configuration' do
      expect(subject).to receive(:shell_out).with('apache2ctl -t').and_return(double('shellout', exitstatus: 0, stderr: ''))
      
      subject.restore_config('/var/backups/httpd/backup.tar.gz')
    end
    
    it 'rolls back to previous configuration if validation fails' do
      allow(subject).to receive(:shell_out).with('apache2ctl -t').and_return(double('shellout', exitstatus: 1, stderr: 'Syntax error'))
      expect(Chef::Log).to receive(:error).with(/syntax errors/)
      expect(subject).to receive(:restore_config).with('/var/backups/httpd/pre-restore-backup.tar.gz', true)
      
      result = subject.restore_config('/var/backups/httpd/backup.tar.gz')
      
      expect(result).to be false
    end
    
    it 'starts the Apache service after successful restore' do
      expect(subject).to receive(:service).with('apache2').at_least(:once)
      
      subject.restore_config('/var/backups/httpd/backup.tar.gz')
    end
  end
  
  describe '#blue_green_deployment' do
    it 'determines which environment is active when config_dir is a symlink' do
      allow(::File).to receive(:symlink?).with('/etc/apache2').and_return(true)
      allow(::File).to receive(:readlink).with('/etc/apache2').and_return('/etc/apache2-blue')
      
      result = subject.blue_green_deployment
      
      expect(result).to eq(:green)
    end
    
    it 'initializes blue environment if config_dir is a regular directory' do
      allow(::File).to receive(:symlink?).with('/etc/apache2').and_return(false)
      allow(::File).to receive(:directory?).with('/etc/apache2-blue').and_return(false)
      expect(FileUtils).to receive(:mkdir_p).with('/etc/apache2-blue')
      expect(FileUtils).to receive(:cp_r)
      
      result = subject.blue_green_deployment
      
      expect(result).to eq(:green)
    end
    
    it 'executes the provided block to prepare inactive environment' do
      block_executed = false
      inactive_env = nil
      inactive_dir = nil
      
      allow(::File).to receive(:symlink?).with('/etc/apache2').and_return(true)
      allow(::File).to receive(:readlink).with('/etc/apache2').and_return('/etc/apache2-blue')
      
      result = subject.blue_green_deployment do |env, dir|
        block_executed = true
        inactive_env = env
        inactive_dir = dir
      end
      
      expect(block_executed).to be true
      expect(inactive_env).to eq(:green)
      expect(inactive_dir).to eq('/etc/apache2-green')
      expect(result).to eq(:green)
    end
    
    it 'validates the inactive environment configuration' do
      allow(::File).to receive(:symlink?).with('/etc/apache2').and_return(true)
      allow(::File).to receive(:readlink).with('/etc/apache2').and_return('/etc/apache2-blue')
      expect(subject).to receive(:shell_out).with('APACHE_CONFDIR=/etc/apache2-green apache2ctl -t').and_return(double('shellout', exitstatus: 0, stderr: ''))
      
      subject.blue_green_deployment
    end
    
    it 'returns active environment if validation fails' do
      allow(::File).to receive(:symlink?).with('/etc/apache2').and_return(true)
      allow(::File).to receive(:readlink).with('/etc/apache2').and_return('/etc/apache2-blue')
      allow(subject).to receive(:shell_out).with('APACHE_CONFDIR=/etc/apache2-green apache2ctl -t').and_return(double('shellout', exitstatus: 1, stderr: 'Syntax error'))
      expect(Chef::Log).to receive(:error).with(/syntax errors/)
      
      result = subject.blue_green_deployment
      
      expect(result).to eq(:blue) # Returns current active env
    end
    
    it 'stops Apache service before switching environments' do
      allow(::File).to receive(:symlink?).with('/etc/apache2').and_return(true)
      allow(::File).to receive(:readlink).with('/etc/apache2').and_return('/etc/apache2-blue')
      expect(subject).to receive(:service).with('apache2').at_least(:once)
      
      subject.blue_green_deployment
    end
    
    it 'switches the symlink to the inactive environment' do
      allow(::File).to receive(:symlink?).with('/etc/apache2').and_return(true)
      allow(::File).to receive(:readlink).with('/etc/apache2').and_return('/etc/apache2-blue')
      expect(FileUtils).to receive(:rm).with('/etc/apache2')
      expect(FileUtils).to receive(:ln_s).with('/etc/apache2-green', '/etc/apache2')
      
      subject.blue_green_deployment
    end
    
    it 'starts Apache service after switching environments' do
      allow(::File).to receive(:symlink?).with('/etc/apache2').and_return(true)
      allow(::File).to receive(:readlink).with('/etc/apache2').and_return('/etc/apache2-blue')
      expect(subject).to receive(:service).with('apache2').at_least(:once)
      
      subject.blue_green_deployment
    end
    
    it 'verifies Apache started successfully' do
      allow(::File).to receive(:symlink?).with('/etc/apache2').and_return(true)
      allow(::File).to receive(:readlink).with('/etc/apache2').and_return('/etc/apache2-blue')
      expect(subject).to receive(:shell_out).with('systemctl is-active apache2 || service apache2 status').and_return(double('shellout', exitstatus: 0))
      allow(subject).to receive(:sleep)
      
      subject.blue_green_deployment
    end
    
    it 'rolls back if Apache fails to start with new configuration' do
      allow(::File).to receive(:symlink?).with('/etc/apache2').and_return(true)
      allow(::File).to receive(:readlink).with('/etc/apache2').and_return('/etc/apache2-blue')
      allow(subject).to receive(:shell_out).with('systemctl is-active apache2 || service apache2 status').and_return(double('shellout', exitstatus: 1))
      allow(subject).to receive(:sleep)
      expect(Chef::Log).to receive(:error).with(/Failed to start Apache/)
      expect(FileUtils).to receive(:rm).with('/etc/apache2').twice
      expect(FileUtils).to receive(:ln_s).with('/etc/apache2-blue', '/etc/apache2')
      
      result = subject.blue_green_deployment
      
      expect(result).to eq(:blue) # Returns original active env
    end
  end
  
  describe '#apache_version' do
    it 'parses Apache version from command output' do
      allow(subject).to receive(:shell_out).with('apache2 -v').and_return(double('shellout', exitstatus: 0, stdout: 'Server version: Apache/2.4.41 (Ubuntu)'))
      
      result = subject.apache_version
      
      expect(result).to eq('2.4.41')
    end
    
    it 'returns unknown if command fails' do
      allow(subject).to receive(:shell_out).with('apache2 -v').and_return(double('shellout', exitstatus: 1, stdout: ''))
      
      result = subject.apache_version
      
      expect(result).to eq('unknown')
    end
    
    it 'returns unknown if version cannot be parsed' do
      allow(subject).to receive(:shell_out).with('apache2 -v').and_return(double('shellout', exitstatus: 0, stdout: 'Invalid output'))
      
      result = subject.apache_version
      
      expect(result).to eq('unknown')
    end
  end
end