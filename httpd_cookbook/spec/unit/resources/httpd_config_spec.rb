require 'spec_helper'

describe 'test::httpd_config' do
  platforms = {
    'ubuntu' => {
      'versions' => ['20.04', '22.04'],
      'conf_available_dir' => '/etc/apache2/conf-available',
      'conf_enabled_dir' => '/etc/apache2/conf-enabled'
    },
    'centos' => {
      'versions' => ['8', '9'],
      'conf_available_dir' => '/etc/httpd/conf.available',
      'conf_enabled_dir' => '/etc/httpd/conf.d'
    }
  }

  platforms.each do |platform, platform_info|
    platform_info['versions'].each do |version|
      context "on #{platform} #{version}" do
        let(:chef_run) do
          runner = ChefSpec::SoloRunner.new(
            step_into: ['httpd_config'],
            platform: platform,
            version: version
          )

          # Set node attributes for the platform
          if platform == 'centos'
            runner.node.default['httpd']['conf_available_dir'] = platform_info['conf_available_dir']
            runner.node.default['httpd']['conf_enabled_dir'] = platform_info['conf_enabled_dir']
          elsif platform == 'ubuntu'
            runner.node.default['httpd']['conf_available_dir'] = platform_info['conf_available_dir']
            runner.node.default['httpd']['conf_enabled_dir'] = platform_info['conf_enabled_dir']
          end

          runner.converge('test::httpd_config')
        end

        # Basic content-based config
        context 'with content property' do
          it 'creates the config file with specified content' do
            config_path = platform == 'centos' ? 
              "#{platform_info['conf_enabled_dir']}/test-config.conf" :
              "#{platform_info['conf_available_dir']}/test-config.conf"
              
            expect(chef_run).to create_file(config_path).with(
              content: "# Test config\nServerName localhost\n",
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          end
        end

        # Template-based config
        context 'with source property' do
          it 'creates the config file from template' do
            config_path = platform == 'centos' ? 
              "#{platform_info['conf_enabled_dir']}/template-config.conf" :
              "#{platform_info['conf_available_dir']}/template-config.conf"
              
            expect(chef_run).to create_template(config_path).with(
              source: 'test-template.erb',
              cookbook: 'httpd',
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          end
        end

        # Symlink tests for Debian platforms
        if platform == 'ubuntu'
          context 'with enabled config' do
            it 'creates a symlink in the conf-enabled directory' do
              expect(chef_run).to create_link("#{platform_info['conf_enabled_dir']}/test-config.conf").with(
                to: "#{platform_info['conf_available_dir']}/test-config.conf"
              )
              
              expect(chef_run).to create_link("#{platform_info['conf_enabled_dir']}/template-config.conf").with(
                to: "#{platform_info['conf_available_dir']}/template-config.conf"
              )
            end
          end
          
          context 'when disabling a config' do
            it 'removes the symlink in the conf-enabled directory' do
              expect(chef_run).to delete_link("#{platform_info['conf_enabled_dir']}/disabled-config.conf")
            end
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

cookbook_file "#{cookbook_path}/recipes/httpd_config.rb" do
  content <<-EOH
    httpd_config 'test-config' do
      content "# Test config\\nServerName localhost\\n"
      action :create
    end

    httpd_config 'template-config' do
      source 'test-template.erb'
      action :create
    end

    httpd_config 'disabled-config' do
      content "# Disabled config"
      enable false
      action :create
    end
  EOH
end