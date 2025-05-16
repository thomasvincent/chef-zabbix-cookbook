require 'spec_helper'

describe 'httpd::configure' do
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

        it 'creates main configuration' do
          expect(chef_run).to create_httpd_config('main')
        end

        it 'creates MPM configuration' do
          expect(chef_run).to create_httpd_config('mpm')
        end

        it 'creates security configuration' do
          expect(chef_run).to create_httpd_config('security')
        end

        it 'creates logging configuration' do
          expect(chef_run).to create_httpd_config('logging')
        end

        it 'creates directory configuration' do
          expect(chef_run).to create_httpd_config('directories')
        end

        it 'creates MIME types configuration' do
          expect(chef_run).to create_httpd_config('mime')
        end
      end

      context 'with health check enabled' do
        let(:chef_run) do
          runner = ChefSpec::SoloRunner.new(platform: platform, version: version)
          runner.node.override['httpd']['health_check']['enabled'] = true
          runner.converge(described_recipe)
        end

        it 'creates health check configuration' do
          expect(chef_run).to create_httpd_config('health-check')
        end
      end

      context 'with monitoring enabled' do
        let(:chef_run) do
          runner = ChefSpec::SoloRunner.new(platform: platform, version: version)
          runner.node.override['httpd']['monitoring']['enabled'] = true
          runner.converge(described_recipe)
        end

        it 'creates monitoring configuration' do
          expect(chef_run).to create_httpd_config('monitoring')
        end
      end

      context 'with SSL enabled' do
        let(:chef_run) do
          runner = ChefSpec::SoloRunner.new(platform: platform, version: version)
          runner.node.override['httpd']['ssl']['enabled'] = true
          runner.converge(described_recipe)
        end

        it 'creates SSL configuration' do
          expect(chef_run).to create_httpd_config('ssl')
        end
      end
    end
  end
end