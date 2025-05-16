require 'spec_helper'
require_relative '../../../libraries/yaml_config'

describe Httpd::YAMLConfig do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '20.04')
  end
  
  let(:subject) { Object.new.extend(Httpd::YAMLConfig) }
  
  before do
    allow(subject).to receive(:file) do |path, &block|
      # Mock file resource
      resource = Chef::Resource::File.new(path, chef_run.run_context)
      block.call(resource) if block
      resource
    end
  end
  
  describe '#create_yaml_config' do
    it 'creates a file with YAML content' do
      resource = subject.create_yaml_config('/etc/httpd/conf.d/config.yaml', { key: 'value' })
      
      expect(resource).to be_a(Chef::Resource::File)
      expect(resource.path).to eq('/etc/httpd/conf.d/config.yaml')
      expect(resource.content).to eq("---\nkey: value\n")
      expect(resource.owner).to eq('root')
      expect(resource.group).to eq('root')
      expect(resource.mode).to eq('0644')
      expect(resource.action).to eq([:create])
    end
    
    it 'respects custom owner, group, and mode' do
      resource = subject.create_yaml_config('/etc/httpd/conf.d/config.yaml', 
                                           { key: 'value' },
                                           owner: 'apache',
                                           group: 'apache',
                                           mode: '0640')
      
      expect(resource.owner).to eq('apache')
      expect(resource.group).to eq('apache')
      expect(resource.mode).to eq('0640')
    end
  end
  
  describe '#read_yaml_config' do
    it 'reads and parses an existing YAML file' do
      yaml_content = "---\nkey: value\n"
      
      allow(::File).to receive(:exist?).with('/etc/httpd/conf.d/config.yaml').and_return(true)
      allow(YAML).to receive(:load_file).with('/etc/httpd/conf.d/config.yaml').and_return({ 'key' => 'value' })
      
      result = subject.read_yaml_config('/etc/httpd/conf.d/config.yaml')
      
      expect(result).to eq({ 'key' => 'value' })
    end
    
    it 'returns an empty hash when file does not exist' do
      allow(::File).to receive(:exist?).with('/etc/httpd/conf.d/missing.yaml').and_return(false)
      
      result = subject.read_yaml_config('/etc/httpd/conf.d/missing.yaml')
      
      expect(result).to eq({})
    end
    
    it 'returns an empty hash on parsing error' do
      allow(::File).to receive(:exist?).with('/etc/httpd/conf.d/invalid.yaml').and_return(true)
      allow(YAML).to receive(:load_file).with('/etc/httpd/conf.d/invalid.yaml').and_raise(Psych::SyntaxError.new('file', 1, 1, 0, 'error', 'problem'))
      
      result = subject.read_yaml_config('/etc/httpd/conf.d/invalid.yaml')
      
      expect(result).to eq({})
    end
  end
  
  describe '#merge_yaml_config' do
    it 'merges new configuration with existing configuration' do
      allow(subject).to receive(:read_yaml_config).with('/etc/httpd/conf.d/config.yaml').and_return({ 'existing' => 'value', 'nested' => { 'key' => 'value' } })
      
      resource = subject.merge_yaml_config('/etc/httpd/conf.d/config.yaml', { 'new' => 'value', 'nested' => { 'new_key' => 'new_value' } })
      
      expect(resource).to be_a(Chef::Resource::File)
      expect(resource.content).to include('existing: value')
      expect(resource.content).to include('new: value')
      expect(resource.content).to include('key: value')
      expect(resource.content).to include('new_key: new_value')
    end
  end
  
  describe '#hash_to_yaml' do
    it 'converts a hash to YAML string' do
      result = subject.hash_to_yaml({ 'key' => 'value', 'nested' => { 'key' => 'value' } })
      
      expect(result).to include('key: value')
      expect(result).to include('nested:')
      expect(result).to include('  key: value')
    end
    
    it 'handles errors gracefully' do
      # Create a hash that can't be serialized to YAML
      problematic_hash = {}
      problematic_hash['circular'] = problematic_hash
      
      result = subject.hash_to_yaml(problematic_hash)
      
      expect(result).to eq("{}\n")
    end
  end
  
  describe '#yaml_to_hash' do
    it 'parses a YAML string to a hash' do
      yaml_string = "---\nkey: value\nnested:\n  key: value\n"
      
      result = subject.yaml_to_hash(yaml_string)
      
      expect(result).to eq({ 'key' => 'value', 'nested' => { 'key' => 'value' } })
    end
    
    it 'handles parsing errors gracefully' do
      invalid_yaml = "key: value\n  indentation error"
      
      result = subject.yaml_to_hash(invalid_yaml)
      
      expect(result).to eq({})
    end
  end
end