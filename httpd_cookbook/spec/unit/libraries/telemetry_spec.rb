# frozen_string_literal: true

require 'spec_helper'

describe 'Httpd::Telemetry' do
  let(:dummy_class) { Class.new { include Httpd::Telemetry } }
  let(:telemetry) { dummy_class.new }
  let(:node) { Chef::Node.new }
  let(:run_context) { Chef::RunContext.new(node, {}, nil) }

  before do
    allow(telemetry).to receive(:node).and_return(node)
    allow(Chef::Resource).to receive(:new).and_return(double('resource').as_null_object)
    allow(Chef::Log).to receive(:info)
    allow(Chef::Log).to receive(:warn)
    allow(Chef::Log).to receive(:error)
  end

  describe '#configure_prometheus_exporter' do
    context 'when built-in module is available' do
      before do
        allow(telemetry).to receive(:apache_has_prometheus_module?).and_return(true)
        allow(telemetry).to receive(:configure_builtin_prometheus_exporter).and_return(true)
      end

      it 'uses the built-in exporter' do
        expect(telemetry).to receive(:configure_builtin_prometheus_exporter)
        expect(telemetry).not_to receive(:configure_external_prometheus_exporter)
        
        result = telemetry.configure_prometheus_exporter
        expect(result).to be true
      end
    end

    context 'when built-in module is not available' do
      before do
        allow(telemetry).to receive(:apache_has_prometheus_module?).and_return(false)
        allow(telemetry).to receive(:configure_external_prometheus_exporter).and_return(true)
      end

      it 'uses the external exporter' do
        expect(telemetry).not_to receive(:configure_builtin_prometheus_exporter)
        expect(telemetry).to receive(:configure_external_prometheus_exporter)
        
        result = telemetry.configure_prometheus_exporter
        expect(result).to be true
      end
    end

    it 'passes correct default metrics' do
      allow(telemetry).to receive(:apache_has_prometheus_module?).and_return(true)
      
      expected_metrics = %w(
        connections
        scoreboard 
        cpu
        requests
        throughput
        response_time
        workers
      )
      
      expect(telemetry).to receive(:configure_builtin_prometheus_exporter).with(
        '/server-status?auto', 
        '/metrics', 
        expected_metrics
      ).and_return(true)
      
      telemetry.configure_prometheus_exporter
    end
  end

  describe '#apache_has_prometheus_module?' do
    context 'on Debian systems' do
      before do
        allow(node).to receive(:[]).with('platform_family').and_return('debian')
      end

      it 'checks the correct file paths' do
        expect(::File).to receive(:exist?).with('/usr/lib/apache2/modules/mod_prometheus_exporter.so').and_return(false)
        expect(::File).to receive(:exist?).with('/usr/lib/apache2/modules/mod_prometheus.so').and_return(true)
        
        result = telemetry.apache_has_prometheus_module?
        expect(result).to be true
      end
      
      it 'returns false if no module files are found' do
        expect(::File).to receive(:exist?).with('/usr/lib/apache2/modules/mod_prometheus_exporter.so').and_return(false)
        expect(::File).to receive(:exist?).with('/usr/lib/apache2/modules/mod_prometheus.so').and_return(false)
        
        result = telemetry.apache_has_prometheus_module?
        expect(result).to be false
      end
      
      it 'handles errors gracefully' do
        expect(::File).to receive(:exist?).with('/usr/lib/apache2/modules/mod_prometheus_exporter.so').and_raise(StandardError, 'Test error')
        
        result = telemetry.apache_has_prometheus_module?
        expect(result).to be false
      end
    end
    
    context 'on RHEL systems' do
      before do
        allow(node).to receive(:[]).with('platform_family').and_return('rhel')
      end

      it 'checks the correct file paths' do
        expect(::File).to receive(:exist?).with('/usr/lib64/httpd/modules/mod_prometheus_exporter.so').and_return(true)
        
        result = telemetry.apache_has_prometheus_module?
        expect(result).to be true
      end
    end
  end

  describe '#configure_builtin_prometheus_exporter' do
    let(:httpd_module) { double('httpd_module') }
    let(:httpd_config) { double('httpd_config') }
    
    before do
      allow(telemetry).to receive(:httpd_module).and_return(httpd_module)
      allow(telemetry).to receive(:httpd_config).and_return(httpd_config)
      allow(telemetry).to receive(:configure_server_status).and_return(true)
      allow(httpd_module).to receive(:action)
      allow(httpd_config).to receive(:content)
      allow(httpd_config).to receive(:action)
    end
    
    it 'enables the prometheus_exporter module' do
      expect(telemetry).to receive(:httpd_module).with('prometheus_exporter')
      expect(httpd_module).to receive(:action).with(:enable)
      
      telemetry.configure_builtin_prometheus_exporter('/server-status?auto', '/metrics', ['connections'])
    end
    
    it 'creates the necessary configuration' do
      expect(telemetry).to receive(:httpd_config).with('prometheus-exporter')
      expect(httpd_config).to receive(:content).with(kind_of(String))
      expect(httpd_config).to receive(:action).with(:create)
      
      telemetry.configure_builtin_prometheus_exporter('/server-status?auto', '/metrics', ['connections'])
    end
    
    it 'configures server-status module' do
      expect(telemetry).to receive(:configure_server_status)
      
      telemetry.configure_builtin_prometheus_exporter('/server-status?auto', '/metrics', ['connections'])
    end
    
    it 'returns true on success' do
      result = telemetry.configure_builtin_prometheus_exporter('/server-status?auto', '/metrics', ['connections'])
      expect(result).to be true
    end
    
    it 'handles errors gracefully' do
      allow(telemetry).to receive(:httpd_module).and_raise(StandardError, 'Test error')
      
      result = telemetry.configure_builtin_prometheus_exporter('/server-status?auto', '/metrics', ['connections'])
      expect(result).to be false
    end
  end

  describe '#configure_external_prometheus_exporter' do
    context 'with package installation' do
      let(:package) { double('package') }
      let(:template) { double('template') }
      let(:service) { double('service') }
      let(:execute) { double('execute') }
      
      before do
        allow(node).to receive(:[]).with('platform_family').and_return('debian')
        allow(telemetry).to receive(:package).and_return(package)
        allow(telemetry).to receive(:template).and_return(template)
        allow(telemetry).to receive(:execute).and_return(execute)
        allow(telemetry).to receive(:service).and_return(service)
        allow(telemetry).to receive(:configure_server_status).and_return(true)
        allow(package).to receive(:action)
        allow(template).to receive(:source)
        allow(template).to receive(:cookbook)
        allow(template).to receive(:owner)
        allow(template).to receive(:group)
        allow(template).to receive(:mode)
        allow(template).to receive(:variables)
        allow(template).to receive(:action)
        allow(template).to receive(:notifies)
        allow(execute).to receive(:command)
        allow(execute).to receive(:action)
        allow(service).to receive(:action)
      end
      
      it 'installs the appropriate package' do
        expect(telemetry).to receive(:package).with('prometheus-apache-exporter')
        expect(package).to receive(:action).with(:install)
        
        telemetry.configure_external_prometheus_exporter(nil, '/server-status?auto', '/metrics', nil)
      end
      
      it 'creates the systemd service file' do
        expect(telemetry).to receive(:template).with('/etc/systemd/system/apache-exporter.service')
        expect(template).to receive(:source).with('apache-exporter.service.erb')
        expect(template).to receive(:cookbook).with('httpd')
        expect(template).to receive(:owner).with('root')
        expect(template).to receive(:group).with('root')
        expect(template).to receive(:mode).with('0644')
        expect(template).to receive(:variables).with(
          scrape_uri: '/server-status?auto',
          telemetry_path: '/metrics'
        )
        expect(template).to receive(:action).with(:create)
        expect(template).to receive(:notifies).with(:run, 'execute[systemctl-daemon-reload]', :immediately)
        
        telemetry.configure_external_prometheus_exporter(nil, '/server-status?auto', '/metrics', nil)
      end
      
      it 'enables and starts the service' do
        expect(telemetry).to receive(:service).with('apache-exporter')
        expect(service).to receive(:action).with([:enable, :start])
        
        telemetry.configure_external_prometheus_exporter(nil, '/server-status?auto', '/metrics', nil)
      end
      
      it 'configures server-status module' do
        expect(telemetry).to receive(:configure_server_status)
        
        telemetry.configure_external_prometheus_exporter(nil, '/server-status?auto', '/metrics', nil)
      end
      
      it 'returns true on success' do
        result = telemetry.configure_external_prometheus_exporter(nil, '/server-status?auto', '/metrics', nil)
        expect(result).to be true
      end
      
      it 'handles errors gracefully' do
        allow(telemetry).to receive(:package).and_raise(StandardError, 'Test error')
        
        result = telemetry.configure_external_prometheus_exporter(nil, '/server-status?auto', '/metrics', nil)
        expect(result).to be false
      end
    end
    
    context 'with binary installation' do
      let(:remote_file) { double('remote_file') }
      
      before do
        allow(node).to receive(:[]).with('platform_family').and_return('suse')
        allow(telemetry).to receive(:remote_file).and_return(remote_file)
        allow(telemetry).to receive(:template).and_return(double('template').as_null_object)
        allow(telemetry).to receive(:execute).and_return(double('execute').as_null_object)
        allow(telemetry).to receive(:service).and_return(double('service').as_null_object)
        allow(telemetry).to receive(:configure_server_status).and_return(true)
        allow(remote_file).to receive(:source)
        allow(remote_file).to receive(:mode)
        allow(remote_file).to receive(:action)
        allow(remote_file).to receive(:notifies)
      end
      
      it 'downloads the binary' do
        expect(telemetry).to receive(:remote_file).with('/usr/local/bin/apache_exporter')
        expect(remote_file).to receive(:source).with('https://github.com/Lusitaniae/apache_exporter/releases/download/v0.8.0/apache_exporter-0.8.0.linux-amd64.tar.gz')
        expect(remote_file).to receive(:mode).with('0755')
        expect(remote_file).to receive(:action).with(:create)
        expect(remote_file).to receive(:notifies).with(:run, 'execute[extract_apache_exporter]', :immediately)
        
        telemetry.configure_external_prometheus_exporter(nil, '/server-status?auto', '/metrics', nil)
      end
    end
  end

  describe '#configure_server_status' do
    let(:httpd_module) { double('httpd_module') }
    let(:httpd_config) { double('httpd_config') }
    
    before do
      allow(telemetry).to receive(:httpd_module).and_return(httpd_module)
      allow(telemetry).to receive(:httpd_config).and_return(httpd_config)
      allow(httpd_module).to receive(:action)
      allow(httpd_config).to receive(:content)
      allow(httpd_config).to receive(:action)
    end
    
    it 'enables the status module' do
      expect(telemetry).to receive(:httpd_module).with('status')
      expect(httpd_module).to receive(:action).with(:enable)
      
      telemetry.configure_server_status
    end
    
    it 'creates the necessary configuration with default IPs' do
      expect(telemetry).to receive(:httpd_config).with('server-status')
      expect(httpd_config).to receive(:content) do |content|
        expect(content).to include('Require ip 127.0.0.1')
        expect(content).to include('Require ip ::1')
      end
      expect(httpd_config).to receive(:action).with(:create)
      
      telemetry.configure_server_status
    end
    
    it 'uses custom IPs if provided' do
      expect(httpd_config).to receive(:content) do |content|
        expect(content).to include('Require ip 10.0.0.1')
        expect(content).to include('Require ip 10.0.0.2')
      end
      
      telemetry.configure_server_status(['10.0.0.1', '10.0.0.2'])
    end
    
    it 'returns true on success' do
      result = telemetry.configure_server_status
      expect(result).to be true
    end
    
    it 'handles errors gracefully' do
      allow(telemetry).to receive(:httpd_module).and_raise(StandardError, 'Test error')
      
      result = telemetry.configure_server_status
      expect(result).to be false
    end
  end

  describe '#configure_grafana_dashboard' do
    let(:file) { double('file') }
    
    before do
      allow(node).to receive(:[]).with('platform_family').and_return('rhel')
      allow(telemetry).to receive(:file).and_return(file)
      allow(file).to receive(:content)
      allow(file).to receive(:owner)
      allow(file).to receive(:group)
      allow(file).to receive(:mode)
      allow(file).to receive(:action)
      # For JSON.pretty_generate
      allow(JSON).to receive(:pretty_generate).and_return('{}')
    end
    
    it 'creates a dashboard JSON file' do
      expect(telemetry).to receive(:file).with('/etc/httpd/grafana-dashboard.json')
      expect(file).to receive(:content).with('{}')
      expect(file).to receive(:owner).with('root')
      expect(file).to receive(:group).with('root')
      expect(file).to receive(:mode).with('0644')
      expect(file).to receive(:action).with(:create)
      
      telemetry.configure_grafana_dashboard('http://grafana:3000', 'prometheus')
    end
    
    it 'uses the correct path based on platform' do
      allow(node).to receive(:[]).with('platform_family').and_return('debian')
      
      expect(telemetry).to receive(:file).with('/etc/apache2/grafana-dashboard.json')
      
      telemetry.configure_grafana_dashboard('http://grafana:3000', 'prometheus')
    end
    
    context 'with API key provided' do
      let(:http) { double('http') }
      let(:response) { double('response') }
      
      before do
        allow(URI).to receive(:parse).and_return(double('uri', host: 'grafana', port: 3000, scheme: 'http', request_uri: '/api/dashboards/db'))
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(Net::HTTP::Post).to receive(:new).and_return(double('request', :[]= => nil, :body= => nil))
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:request).and_return(response)
      end
      
      it 'attempts to upload dashboard via API' do
        allow(response).to receive(:code).and_return('200')
        
        result = telemetry.configure_grafana_dashboard('http://grafana:3000', 'prometheus', 'api-key')
        expect(result).to be true
      end
      
      it 'handles API errors gracefully' do
        allow(response).to receive(:code).and_return('400')
        allow(response).to receive(:body).and_return('Error message')
        
        result = telemetry.configure_grafana_dashboard('http://grafana:3000', 'prometheus', 'api-key')
        expect(result).to be false
      end
      
      it 'handles HTTP errors gracefully' do
        allow(http).to receive(:request).and_raise(StandardError, 'Connection error')
        
        result = telemetry.configure_grafana_dashboard('http://grafana:3000', 'prometheus', 'api-key')
        expect(result).to be false
      end
    end
    
    it 'returns true when API key is not provided' do
      result = telemetry.configure_grafana_dashboard('http://grafana:3000', 'prometheus')
      expect(result).to be true
    end
    
    it 'handles errors gracefully' do
      allow(JSON).to receive(:pretty_generate).and_raise(StandardError, 'Test error')
      
      result = telemetry.configure_grafana_dashboard('http://grafana:3000', 'prometheus')
      expect(result).to be false
    end
  end
end