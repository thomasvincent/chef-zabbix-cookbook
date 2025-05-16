require 'spec_helper'
require_relative '../../../libraries/zero_downtime'

describe Httpd::ZeroDowntime do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '20.04')
  end
  
  let(:subject) { Object.new.extend(Httpd::ZeroDowntime) }
  
  before do
    allow(subject).to receive(:platform_family?).and_return(false)
    allow(subject).to receive(:platform_family?).with('debian').and_return(chef_run.node['platform_family'] == 'debian')
    allow(subject).to receive(:systemd?).and_return(true)
    allow(subject).to receive(:httpd_service_name).and_return('apache2')
    allow(subject).to receive(:shell_out).and_return(double('shellout', exitstatus: 0, stdout: "123\n456\n789\n", stderr: ''))
  end
  
  describe '#graceful_reload' do
    it 'returns true when reload succeeds' do
      allow(subject).to receive(:httpd_worker_pids).and_return([123, 456, 789], [123, 456, 790])
      allow(subject).to receive(:sleep).and_return(nil)
      
      result = subject.graceful_reload
      
      expect(result).to be true
    end
    
    it 'runs pre-check if provided' do
      pre_check_executed = false
      pre_check = -> { pre_check_executed = true; true }
      
      allow(subject).to receive(:httpd_worker_pids).and_return([123, 456, 789], [123, 456, 790])
      allow(subject).to receive(:sleep).and_return(nil)
      
      subject.graceful_reload(pre_check: pre_check)
      
      expect(pre_check_executed).to be true
    end
    
    it 'returns false if pre-check fails' do
      pre_check = -> { false }
      
      result = subject.graceful_reload(pre_check: pre_check)
      
      expect(result).to be false
    end
    
    it 'runs post-check if provided' do
      post_check_executed = false
      post_check = -> { post_check_executed = true; true }
      
      allow(subject).to receive(:httpd_worker_pids).and_return([123, 456, 789], [123, 456, 790])
      allow(subject).to receive(:sleep).and_return(nil)
      
      subject.graceful_reload(post_check: post_check)
      
      expect(post_check_executed).to be true
    end
    
    it 'returns false if post-check fails' do
      post_check = -> { false }
      
      allow(subject).to receive(:httpd_worker_pids).and_return([123, 456, 789], [123, 456, 790])
      allow(subject).to receive(:sleep).and_return(nil)
      
      result = subject.graceful_reload(post_check: post_check)
      
      expect(result).to be false
    end
    
    it 'retries reload when it fails' do
      fail_count = 0
      
      allow(subject).to receive(:shell_out) do
        fail_count += 1
        double('shellout', exitstatus: fail_count > 2 ? 0 : 1, stdout: '', stderr: '')
      end
      
      allow(subject).to receive(:httpd_worker_pids).and_return([123, 456, 789], [123, 456, 790])
      allow(subject).to receive(:sleep).and_return(nil)
      
      result = subject.graceful_reload(max_attempts: 3)
      
      expect(result).to be true
      expect(fail_count).to eq(3)
    end
    
    it 'warns if no worker processes were replaced' do
      allow(subject).to receive(:httpd_worker_pids).and_return([123, 456, 789], [123, 456, 789])
      allow(subject).to receive(:sleep).and_return(nil)
      expect(Chef::Log).to receive(:warn).with(/No worker processes were replaced/)
      
      subject.graceful_reload
    end
  end
  
  describe '#httpd_worker_pids' do
    it 'returns array of PIDs when command succeeds' do
      allow(subject).to receive(:shell_out).and_return(double('shellout', exitstatus: 0, stdout: "123\n456\n789\n"))
      
      result = subject.httpd_worker_pids
      
      expect(result).to eq([123, 456, 789])
    end
    
    it 'returns empty array when command fails' do
      allow(subject).to receive(:shell_out).and_return(double('shellout', exitstatus: 1, stdout: ''))
      
      result = subject.httpd_worker_pids
      
      expect(result).to eq([])
    end
  end
  
  describe '#apache_health_check' do
    let(:socket_double) { double('socket') }
    
    before do
      allow(TCPSocket).to receive(:new).and_return(socket_double)
      allow(socket_double).to receive(:print)
      allow(socket_double).to receive(:close)
    end
    
    it 'returns true when HTTP response is 200' do
      allow(socket_double).to receive(:read).and_return("HTTP/1.1 200 OK\r\n")
      
      result = subject.apache_health_check
      
      expect(result).to be true
    end
    
    it 'returns true when HTTP response is a redirect' do
      allow(socket_double).to receive(:read).and_return("HTTP/1.1 302 Found\r\n")
      
      result = subject.apache_health_check
      
      expect(result).to be true
    end
    
    it 'returns false when HTTP response is an error' do
      allow(socket_double).to receive(:read).and_return("HTTP/1.1 500 Internal Server Error\r\n")
      
      result = subject.apache_health_check
      
      expect(result).to be false
    end
    
    it 'returns false when connection fails' do
      allow(TCPSocket).to receive(:new).and_raise(Errno::ECONNREFUSED)
      expect(Chef::Log).to receive(:warn).with(/Health check failed/)
      
      result = subject.apache_health_check
      
      expect(result).to be false
    end
  end
  
  describe '#staged_rollout' do
    let(:file_double) { double('file') }
    let(:execute_double) { double('execute') }
    let(:block_executed) { false }
    
    before do
      allow(subject).to receive(:directory).and_return(nil)
      allow(subject).to receive(:execute).and_return(execute_double)
      allow(subject).to receive(:apache_health_check).and_return(true)
      allow(subject).to receive(:graceful_reload).and_return(true)
      allow(::File).to receive(:exist?).and_return(true)
      allow(::File).to receive(:dirname).and_return('/etc/apache2/backup')
    end
    
    it 'executes the provided block' do
      block_executed = false
      
      subject.staged_rollout do
        block_executed = true
      end
      
      expect(block_executed).to be true
    end
    
    it 'backs up the configuration file if paths are provided' do
      expect(subject).to receive(:execute).with("Backing up /etc/apache2/apache2.conf")
      
      subject.staged_rollout(config_path: '/etc/apache2/apache2.conf', backup_path: '/etc/apache2/backup/apache2.conf.bak') do
        # Configuration change
      end
    end
    
    it 'validates the configuration syntax' do
      expect(subject).to receive(:shell_out).with('apache2ctl -t').and_return(double('shellout', exitstatus: 0, stderr: ''))
      
      subject.staged_rollout
    end
    
    it 'returns false and rolls back if configuration validation fails' do
      allow(subject).to receive(:shell_out).with('apache2ctl -t').and_return(double('shellout', exitstatus: 1, stderr: 'Syntax error'))
      expect(Chef::Log).to receive(:error).with(/Configuration validation failed/)
      expect(subject).to receive(:execute).with("Restoring /etc/apache2/apache2.conf")
      
      result = subject.staged_rollout(config_path: '/etc/apache2/apache2.conf', backup_path: '/etc/apache2/backup/apache2.conf.bak')
      
      expect(result).to be false
    end
    
    it 'performs graceful reload with health checks' do
      expect(subject).to receive(:graceful_reload).and_return(true)
      
      result = subject.staged_rollout
      
      expect(result).to be true
    end
    
    it 'rolls back if reload fails and rollback is enabled' do
      allow(subject).to receive(:graceful_reload).and_return(false)
      expect(Chef::Log).to receive(:warn).with(/Reload failed, rolling back/)
      expect(subject).to receive(:execute).with("Restoring /etc/apache2/apache2.conf")
      expect(subject).to receive(:graceful_reload).twice # Once for initial attempt, once after rollback
      
      result = subject.staged_rollout(config_path: '/etc/apache2/apache2.conf', backup_path: '/etc/apache2/backup/apache2.conf.bak')
      
      expect(result).to be false
    end
  end
end