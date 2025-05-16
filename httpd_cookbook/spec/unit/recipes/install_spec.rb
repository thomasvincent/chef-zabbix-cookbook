require 'spec_helper'

describe 'httpd::install' do
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

        context 'when installing from package' do
          it 'installs the correct package' do
            expect(chef_run).to install_package(platform_info['package_name'])
          end

          it 'creates configuration directories' do
            expect(chef_run).to create_directory('/etc/httpd/conf.d').with(
              recursive: true
            ) if platform == 'centos'

            expect(chef_run).to create_directory('/etc/apache2/conf-available').with(
              recursive: true
            ) if platform == 'ubuntu'
          end

          it 'creates MPM configuration' do
            expect(chef_run).to create_template('/etc/httpd/mpm.conf') if platform == 'centos'
            expect(chef_run).to create_template('/etc/apache2/mods-available/mpm_event.conf') if platform == 'ubuntu'
          end
        end

        context 'when installing from source' do
          let(:chef_run) do
            runner = ChefSpec::SoloRunner.new(platform: platform, version: version)
            runner.node.override['httpd']['install_method'] = 'source'
            runner.node.override['httpd']['version'] = '2.4.57'
            runner.converge(described_recipe)
          end

          it 'installs required dependencies' do
            expect(chef_run).to install_package('httpd-deps')
          end

          it 'downloads the source tarball' do
            expect(chef_run).to create_remote_file("#{Chef::Config[:file_cache_path]}/httpd/httpd-2.4.57.tar.gz")
          end

          it 'extracts and compiles Apache' do
            expect(chef_run).to run_bash('compile-httpd')
          end
        end

        context 'when configuring SELinux on RHEL family' do
          let(:chef_run) do
            runner = ChefSpec::SoloRunner.new(platform: 'centos', version: '8')
            runner.node.override['httpd']['selinux']['enabled'] = true
            runner.converge(described_recipe)
          end

          it 'installs SELinux policy packages' do
            expect(chef_run).to install_package('policycoreutils-python')
          end
        end
      end
    end
  end
end