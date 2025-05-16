require 'spec_helper'

describe 'httpd::vhosts' do
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
      context "On #{platform} #{version} with default vhost enabled" do
        let(:chef_run) do
          runner = ChefSpec::SoloRunner.new(platform: platform, version: version)
          runner.node.override['httpd']['default_vhost']['enabled'] = true
          runner.converge(described_recipe)
        end

        it 'converges successfully' do
          expect { chef_run }.to_not raise_error
        end

        it 'creates the default virtual host' do
          expect(chef_run).to create_httpd_vhost('default')
        end

        it 'does not create a SSL version of the default vhost when SSL is not enabled' do
          expect(chef_run).not_to create_httpd_vhost('default-ssl')
        end
      end

      context "On #{platform} #{version} with SSL enabled and certificate/key defined" do
        let(:chef_run) do
          runner = ChefSpec::SoloRunner.new(platform: platform, version: version)
          runner.node.override['httpd']['default_vhost']['enabled'] = true
          runner.node.override['httpd']['ssl']['enabled'] = true
          runner.node.override['httpd']['ssl']['certificate'] = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
          runner.node.override['httpd']['ssl']['certificate_key'] = '/etc/ssl/private/ssl-cert-snakeoil.key'
          runner.converge(described_recipe)
        end

        it 'creates an SSL version of the default virtual host' do
          expect(chef_run).to create_httpd_vhost('default-ssl').with(
            ssl_enabled: true
          )
        end
      end

      context "On #{platform} #{version} with custom vhosts" do
        let(:chef_run) do
          runner = ChefSpec::SoloRunner.new(platform: platform, version: version)
          runner.node.override['httpd']['vhosts']['example'] = {
            'domain' => 'example.com',
            'document_root' => '/var/www/example',
            'aliases' => ['www.example.com']
          }
          runner.node.override['httpd']['vhosts']['secure'] = {
            'domain' => 'secure.example.com',
            'document_root' => '/var/www/secure',
            'ssl_enabled' => true,
            'ssl_cert' => '/etc/ssl/certs/ssl-cert-snakeoil.pem',
            'ssl_key' => '/etc/ssl/private/ssl-cert-snakeoil.key'
          }
          runner.converge(described_recipe)
        end

        it 'creates all defined virtual hosts' do
          expect(chef_run).to create_httpd_vhost('example').with(
            domain: 'example.com',
            document_root: '/var/www/example',
            aliases: ['www.example.com']
          )

          expect(chef_run).to create_httpd_vhost('secure').with(
            domain: 'secure.example.com',
            document_root: '/var/www/secure',
            ssl_enabled: true
          )
        end

        it 'creates document root directories for each vhost' do
          expect(chef_run).to create_directory('/var/www/example').with(
            recursive: true
          )
          
          expect(chef_run).to create_directory('/var/www/secure').with(
            recursive: true
          )
        end

        it 'creates default index.html files for each vhost' do
          expect(chef_run).to create_file_if_missing('/var/www/example/index.html')
          expect(chef_run).to create_file_if_missing('/var/www/secure/index.html')
        end
      end
    end
  end
end