require 'spec_helper'
require_relative '../../../libraries/resource_helpers'

describe Httpd::ResourceHelpers do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '20.04') do |node|
      node.default['httpd']['config']['group'] = 'www-data'
    end
  end
  
  let(:subject) { Object.new.extend(Httpd::ResourceHelpers) }
  
  before do
    # Create a mock run_context
    allow(subject).to receive(:run_context).and_return(chef_run.run_context)
    
    # Stub resources method
    allow(subject).to receive(:resources) do |arg|
      resource_key = arg.keys.first
      resource_name = arg.values.first
      
      if resource_key == :template && resource_name == '/etc/httpd/conf/httpd.conf'
        # Return a mock template resource
        template = Chef::Resource::Template.new('/etc/httpd/conf/httpd.conf', chef_run.run_context)
        template.source 'httpd.conf.erb'
        template
      else
        raise Chef::Exceptions::ResourceNotFound.new(resource_key, resource_name)
      end
    end
    
    # Stub declare_resource method
    allow(subject).to receive(:declare_resource) do |resource_type, resource_name|
      # Create a new resource of the requested type
      resource_class = Chef::Resource.const_get(resource_type.to_s.split('_').map(&:capitalize).join)
      resource_class.new(resource_name, chef_run.run_context)
    end
  end
  
  describe '#find_resource' do
    it 'returns the resource when it exists' do
      resource = subject.find_resource(:template, '/etc/httpd/conf/httpd.conf')
      expect(resource).to be_a(Chef::Resource::Template)
      expect(resource.source).to eq('httpd.conf.erb')
    end
    
    it 'returns nil when the resource does not exist' do
      resource = subject.find_resource(:file, '/etc/httpd/conf/missing.conf')
      expect(resource).to be_nil
    end
  end
  
  describe '#find_or_create_resource' do
    it 'returns the resource when it exists' do
      resource = subject.find_or_create_resource(:template, '/etc/httpd/conf/httpd.conf')
      expect(resource).to be_a(Chef::Resource::Template)
      expect(resource.source).to eq('httpd.conf.erb')
    end
    
    it 'creates and returns a new resource when it does not exist' do
      resource = subject.find_or_create_resource(:file, '/etc/httpd/conf/new.conf')
      expect(resource).to be_a(Chef::Resource::File)
      expect(resource.path).to eq('/etc/httpd/conf/new.conf')
    end
  end
  
  describe '#with_resource' do
    it 'executes the block with the resource when it exists' do
      executed = false
      subject.with_resource(:template, '/etc/httpd/conf/httpd.conf') do |resource|
        executed = true
        expect(resource).to be_a(Chef::Resource::Template)
      end
      expect(executed).to be true
    end
    
    it 'does not execute the block when the resource does not exist' do
      executed = false
      subject.with_resource(:file, '/etc/httpd/conf/missing.conf') do |resource|
        executed = true
      end
      expect(executed).to be false
    end
  end
  
  describe '#get_template_resource' do
    it 'creates a template resource with the specified options' do
      resource = subject.get_template_resource('/etc/httpd/conf/custom.conf', 
                                             cookbook: 'httpd',
                                             source: 'custom.conf.erb',
                                             variables: { key: 'value' },
                                             owner: 'apache',
                                             group: 'apache',
                                             mode: '0640',
                                             action: :create_if_missing)
      
      expect(resource).to be_a(Chef::Resource::Template)
      expect(resource.cookbook).to eq('httpd')
      expect(resource.source).to eq('custom.conf.erb')
      expect(resource.variables).to eq({ key: 'value' })
      expect(resource.owner).to eq('apache')
      expect(resource.group).to eq('apache')
      expect(resource.mode).to eq('0640')
      expect(resource.action).to eq([:create_if_missing])
    end
  end
  
  describe '#get_directory_resource' do
    it 'creates a directory resource with the specified options' do
      resource = subject.get_directory_resource('/etc/httpd/custom', 
                                              owner: 'apache',
                                              group: 'apache',
                                              mode: '0750',
                                              recursive: false,
                                              action: :create_if_missing)
      
      expect(resource).to be_a(Chef::Resource::Directory)
      expect(resource.owner).to eq('apache')
      expect(resource.group).to eq('apache')
      expect(resource.mode).to eq('0750')
      expect(resource.recursive).to eq(false)
      expect(resource.action).to eq([:create_if_missing])
    end
  end
  
  describe '#get_file_resource' do
    it 'creates a file resource with the specified options' do
      resource = subject.get_file_resource('/etc/httpd/conf/custom.conf',
                                         content: 'Configuration content',
                                         owner: 'apache',
                                         group: 'apache',
                                         mode: '0640',
                                         sensitive: true,
                                         action: :create_if_missing)
      
      expect(resource).to be_a(Chef::Resource::File)
      expect(resource.content).to eq('Configuration content')
      expect(resource.owner).to eq('apache')
      expect(resource.group).to eq('apache')
      expect(resource.mode).to eq('0640')
      expect(resource.sensitive).to eq(true)
      expect(resource.action).to eq([:create_if_missing])
    end
  end
  
  describe '#create_resources' do
    it 'creates multiple resources of the same type with specified options' do
      resources_hash = {
        '/etc/httpd/conf/site1.conf' => {
          content: 'Site 1 configuration',
          owner: 'apache'
        },
        '/etc/httpd/conf/site2.conf' => {
          content: 'Site 2 configuration',
          owner: 'www-data'
        }
      }
      
      default_options = {
        group: 'apache',
        mode: '0640',
        action: :create
      }
      
      resources = subject.create_resources(:file, resources_hash, default_options)
      
      expect(resources.length).to eq(2)
      expect(resources[0]).to be_a(Chef::Resource::File)
      expect(resources[0].path).to eq('/etc/httpd/conf/site1.conf')
      expect(resources[0].content).to eq('Site 1 configuration')
      expect(resources[0].owner).to eq('apache')
      expect(resources[0].group).to eq('apache')
      expect(resources[0].mode).to eq('0640')
      
      expect(resources[1]).to be_a(Chef::Resource::File)
      expect(resources[1].path).to eq('/etc/httpd/conf/site2.conf')
      expect(resources[1].content).to eq('Site 2 configuration')
      expect(resources[1].owner).to eq('www-data')
      expect(resources[1].group).to eq('apache')
      expect(resources[1].mode).to eq('0640')
    end
  end
end