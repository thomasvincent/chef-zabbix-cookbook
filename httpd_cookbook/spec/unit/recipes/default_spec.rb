require 'spec_helper'

describe 'httpd::default' do
  context 'When all attributes are default, on Ubuntu 20.04' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['memory']['total'] = '2048000kB'
        node.automatic['cpu']['total'] = 4
      end.converge(described_recipe)
    end

    it 'converges successfully' do
      expect { chef_run }.to_not raise_error
    end

    it 'includes the install recipe' do
      expect(chef_run).to include_recipe('httpd::install')
    end

    it 'includes the configure recipe' do
      expect(chef_run).to include_recipe('httpd::configure')
    end

    it 'includes the vhosts recipe' do
      expect(chef_run).to include_recipe('httpd::vhosts')
    end

    it 'includes the service recipe' do
      expect(chef_run).to include_recipe('httpd::service')
    end
  end

  context 'When all attributes are default, on CentOS 8' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'centos', version: '8') do |node|
        node.automatic['memory']['total'] = '2048000kB'
        node.automatic['cpu']['total'] = 4
      end.converge(described_recipe)
    end

    it 'converges successfully' do
      expect { chef_run }.to_not raise_error
    end
  end
end