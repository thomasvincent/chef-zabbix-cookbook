require 'spec_helper'

describe 'httpd::service' do
  platforms = {
    'ubuntu' => {
      'versions' => ['20.04', '22.04'],
      'package_name' => 'apache2',
      'service_name' => 'apache2'
    },
    'centos' => {
      'versions' => ['8', '9'],
      'package_name' => 'httpd',
      'service_name' => 'httpd'
    }
  }

  platforms.each do |platform, platform_info|
    platform_info['versions'].each do |version|
      context "On #{platform} #{version}" do
        let(:chef_run) do
          runner = ChefSpec::SoloRunner.new(platform: platform, version: version)
          runner.converge(described_recipe)
        end

        it 'converges successfully' do
          expect { chef_run }.to_not raise_error
        end

        it 'creates httpd service resource' do
          service_name = platform_info['service_name']
          expect(chef_run).to create_httpd_service(service_name)
        end

        it 'creates systemd service override directory' do
          service_name = platform_info['service_name']
          expect(chef_run).to create_directory("/etc/systemd/system/#{service_name}.service.d").with(
            recursive: true
          )
        end

        it 'creates systemd override configuration' do
          service_name = platform_info['service_name']
          expect(chef_run).to create_template("/etc/systemd/system/#{service_name}.service.d/override.conf")
        end

        it 'notifies systemctl to daemon-reload on template change' do
          service_name = platform_info['service_name']
          template = chef_run.template("/etc/systemd/system/#{service_name}.service.d/override.conf")
          expect(template).to notify('execute[systemctl-daemon-reload]').immediately
        end

        it 'starts and enables the Apache service' do
          service_name = platform_info['service_name']
          expect(chef_run).to start_service(service_name)
          expect(chef_run).to enable_service(service_name)
        end
      end

      context "On #{platform} #{version} with logrotate enabled" do
        let(:chef_run) do
          runner = ChefSpec::SoloRunner.new(platform: platform, version: version)
          runner.node.override['httpd']['logrotate']['enabled'] = true
          runner.converge(described_recipe)
        end

        it 'creates logrotate configuration' do
          service_name = platform_info['service_name']
          expect(chef_run).to create_template("/etc/logrotate.d/#{service_name}")
        end
      end
    end
  end
end