# frozen_string_literal: true

require 'spec_helper'

describe 'httpd::telemetry' do
  platform 'ubuntu'
  
  context 'when telemetry is disabled' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        node.normal['httpd']['telemetry']['enabled'] = false
      end.converge(described_recipe)
    end

    it 'does not configure prometheus exporter' do
      expect(chef_run).not_to run_ruby_block('configure_prometheus_exporter')
    end
    
    it 'does not configure grafana dashboard' do
      expect(chef_run).not_to run_ruby_block('configure_grafana_dashboard')
    end
  end
  
  context 'when telemetry is enabled with prometheus' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        node.normal['httpd']['telemetry']['enabled'] = true
        node.normal['httpd']['telemetry']['prometheus']['enabled'] = true
        node.normal['httpd']['telemetry']['grafana']['enabled'] = false
      end.converge(described_recipe)
    end

    before do
      allow_any_instance_of(Chef::Recipe).to receive(:configure_prometheus_exporter).and_return(true)
    end

    it 'enables server-status' do
      expect(chef_run.node['httpd']['security']['disable_server_status']).to eq(false)
    end
    
    it 'restricts server-status access' do
      expect(chef_run.node['httpd']['monitoring']['restricted_access']).to eq(true)
    end
    
    it 'configures prometheus exporter' do
      expect_any_instance_of(Chef::Recipe).to receive(:configure_prometheus_exporter)
      chef_run
    end
    
    it 'does not configure grafana dashboard' do
      expect_any_instance_of(Chef::Recipe).not_to receive(:configure_grafana_dashboard)
      chef_run
    end
  end
  
  context 'when telemetry is enabled with prometheus and grafana' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        node.normal['httpd']['telemetry']['enabled'] = true
        node.normal['httpd']['telemetry']['prometheus']['enabled'] = true
        node.normal['httpd']['telemetry']['grafana']['enabled'] = true
        node.normal['httpd']['telemetry']['grafana']['url'] = 'http://grafana:3000'
        node.normal['httpd']['telemetry']['grafana']['datasource'] = 'Prometheus'
      end.converge(described_recipe)
    end

    before do
      allow_any_instance_of(Chef::Recipe).to receive(:configure_prometheus_exporter).and_return(true)
      allow_any_instance_of(Chef::Recipe).to receive(:configure_grafana_dashboard).and_return(true)
    end

    it 'configures prometheus exporter' do
      expect_any_instance_of(Chef::Recipe).to receive(:configure_prometheus_exporter)
      chef_run
    end
    
    it 'configures grafana dashboard' do
      expect_any_instance_of(Chef::Recipe).to receive(:configure_grafana_dashboard)
        .with('http://grafana:3000', 'Prometheus', nil)
      chef_run
    end
  end
  
  context 'with Grafana API key' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        node.normal['httpd']['telemetry']['enabled'] = true
        node.normal['httpd']['telemetry']['prometheus']['enabled'] = true
        node.normal['httpd']['telemetry']['grafana']['enabled'] = true
        node.normal['httpd']['telemetry']['grafana']['url'] = 'http://grafana:3000'
        node.normal['httpd']['telemetry']['grafana']['datasource'] = 'Prometheus'
        node.normal['httpd']['telemetry']['grafana']['api_key'] = 'secret-key'
      end.converge(described_recipe)
    end

    before do
      allow_any_instance_of(Chef::Recipe).to receive(:configure_prometheus_exporter).and_return(true)
      allow_any_instance_of(Chef::Recipe).to receive(:configure_grafana_dashboard).and_return(true)
    end

    it 'passes API key to grafana dashboard configuration' do
      expect_any_instance_of(Chef::Recipe).to receive(:configure_grafana_dashboard)
        .with('http://grafana:3000', 'Prometheus', 'secret-key')
      chef_run
    end
  end
end