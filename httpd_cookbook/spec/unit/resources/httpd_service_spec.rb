require 'spec_helper'

describe 'test::httpd_service' do
  platforms = {
    'ubuntu' => {
      'versions' => ['20.04', '22.04'],
      'service_name' => 'apache2',
      'conf_dir' => '/etc/apache2'
    },
    'centos' => {
      'versions' => ['8', '9'],
      'service_name' => 'httpd',
      'conf_dir' => '/etc/httpd/conf'
    }
  }

  platforms.each do |platform, platform_info|
    platform_info['versions'].each do |version|
      context "on #{platform} #{version}" do
        let(:chef_run) do
          runner = ChefSpec::SoloRunner.new(
            step_into: ['httpd_service'],
            platform: platform,
            version: version
          )

          # Set node attributes for the platform
          runner.node.default['httpd']['service_name'] = platform_info['service_name']
          runner.node.default['httpd']['conf_dir'] = platform_info['conf_dir']
          runner.node.default['httpd']['error_log'] = "/var/log/#{platform_info['service_name']}/error_log"
          runner.node.default['httpd']['access_log'] = "/var/log/#{platform_info['service_name']}/access_log"

          if platform == 'centos'
            runner.node.default['httpd']['root_dir'] = '/etc/httpd'
            runner.node.default['httpd']['conf_enabled_dir'] = '/etc/httpd/conf.d'
            runner.node.default['httpd']['mod_dir'] = '/etc/httpd/conf.modules.d'
          elsif platform == 'ubuntu'
            runner.node.default['httpd']['root_dir'] = '/etc/apache2'
            runner.node.default['httpd']['conf_enabled_dir'] = '/etc/apache2/conf-enabled'
            runner.node.default['httpd']['mod_dir'] = '/etc/apache2/mods-enabled'
          end

          runner.converge('test::httpd_service')
        end

        context 'when creating a service' do
          it 'creates the main Apache configuration' do
            expect(chef_run).to create_template("#{platform_info['conf_dir']}/httpd.conf").with(
              source: 'httpd.conf.erb',
              cookbook: 'httpd',
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          end

          it 'creates security configuration' do
            expect(chef_run).to create_httpd_config('security')
          end

          it 'creates a systemd override directory' do
            service_path = platform == 'centos' ? 
              '/etc/systemd/system/httpd.service.d' :
              '/etc/systemd/system/apache2.service.d'
              
            expect(chef_run).to create_directory(service_path).with(
              owner: 'root',
              group: 'root',
              mode: '0755',
              recursive: true
            )
          end

          it 'creates a systemd override file' do
            service_path = platform == 'centos' ? 
              '/etc/systemd/system/httpd.service.d/override.conf' :
              '/etc/systemd/system/apache2.service.d/override.conf'
              
            expect(chef_run).to create_template(service_path).with(
              source: 'systemd-override.conf.erb',
              cookbook: 'httpd',
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          end

          it 'triggers systemd daemon-reload' do
            service_path = platform == 'centos' ? 
              '/etc/systemd/system/httpd.service.d/override.conf' :
              '/etc/systemd/system/apache2.service.d/override.conf'
              
            template = chef_run.template(service_path)
            expect(template).to notify('execute[systemctl-daemon-reload]').immediately
          end
        end

        context 'when starting and enabling the service' do
          it 'starts the service' do
            expect(chef_run).to start_service(platform_info['service_name'])
          end

          it 'enables the service' do
            expect(chef_run).to enable_service(platform_info['service_name'])
          end
        end

        context 'when restarting the service' do
          let(:chef_run) do
            runner = ChefSpec::SoloRunner.new(
              step_into: ['httpd_service'],
              platform: platform,
              version: version
            )
            runner.node.default['httpd']['service_name'] = platform_info['service_name']
            runner.converge('test::httpd_service_restart')
          end

          it 'restarts the service' do
            expect(chef_run).to restart_service(platform_info['service_name'])
          end
        end

        context 'when reloading the service' do
          let(:chef_run) do
            runner = ChefSpec::SoloRunner.new(
              step_into: ['httpd_service'],
              platform: platform,
              version: version
            )
            runner.node.default['httpd']['service_name'] = platform_info['service_name']
            runner.converge('test::httpd_service_reload')
          end

          it 'reloads the service' do
            expect(chef_run).to reload_service(platform_info['service_name'])
          end
        end
      end
    end
  end
end

# Create test cookbook for our custom resource tests
file_cache_path = Chef::Config[:file_cache_path]

cookbook_name = 'test'
cookbook_path = "#{file_cache_path}/cookbooks/#{cookbook_name}"

directory "#{cookbook_path}/recipes" do
  recursive true
end

cookbook_file "#{cookbook_path}/metadata.rb" do
  content "name '#{cookbook_name}'\nversion '0.1.0'"
end

cookbook_file "#{cookbook_path}/recipes/httpd_service.rb" do
  content <<-EOH
    httpd_service 'httpd' do
      action :create
    end

    httpd_service 'httpd' do
      action [:enable, :start]
    end
  EOH
end

cookbook_file "#{cookbook_path}/recipes/httpd_service_restart.rb" do
  content <<-EOH
    httpd_service 'httpd' do
      action :restart
    end
  EOH
end

cookbook_file "#{cookbook_path}/recipes/httpd_service_reload.rb" do
  content <<-EOH
    httpd_service 'httpd' do
      action :reload
    end
  EOH
end