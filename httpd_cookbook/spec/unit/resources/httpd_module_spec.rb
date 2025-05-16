require 'spec_helper'

describe 'test::httpd_module' do
  platforms = {
    'ubuntu' => {
      'versions' => ['20.04', '22.04'],
      'mod_dir' => '/etc/apache2/mods-available',
      'mod_enabled_dir' => '/etc/apache2/mods-enabled',
      'a2enmod_cmd' => '/usr/sbin/a2enmod',
      'a2dismod_cmd' => '/usr/sbin/a2dismod'
    },
    'centos' => {
      'versions' => ['8', '9'],
      'mod_dir' => '/etc/httpd/conf.modules.d',
      'libexec_dir' => '/usr/lib64/httpd/modules'
    }
  }

  platforms.each do |platform, platform_info|
    platform_info['versions'].each do |version|
      context "on #{platform} #{version}" do
        let(:chef_run) do
          runner = ChefSpec::SoloRunner.new(
            step_into: ['httpd_module'],
            platform: platform,
            version: version
          )

          # Set node attributes for the platform
          if platform == 'centos'
            runner.node.default['httpd']['mod_dir'] = platform_info['mod_dir']
            runner.node.default['httpd']['libexec_dir'] = platform_info['libexec_dir']
          elsif platform == 'ubuntu'
            runner.node.default['httpd']['mod_dir'] = platform_info['mod_dir']
            runner.node.default['httpd']['mod_enabled_dir'] = platform_info['mod_enabled_dir']
          end

          # Stub the file exists checks
          allow(::File).to receive(:exist?).and_call_original
          if platform == 'centos'
            allow(::File).to receive(:exist?).with("#{platform_info['mod_dir']}/ssl.load").and_return(false)
            allow(::File).to receive(:exist?).with("#{platform_info['mod_dir']}/rewrite.load").and_return(true)
            allow(::File).to receive(:exist?).with("#{platform_info['libexec_dir']}/mod_ssl.so").and_return(true)
          elsif platform == 'ubuntu'
            allow(::File).to receive(:exist?).with("#{platform_info['mod_enabled_dir']}/ssl.load").and_return(false)
            allow(::File).to receive(:exist?).with("#{platform_info['mod_enabled_dir']}/rewrite.load").and_return(true)
          end

          runner.converge('test::httpd_module')
        end

        # Stubbing a2enmod/a2dismod for Ubuntu
        before do
          if platform == 'ubuntu'
            stub_command("#{platform_info['a2enmod_cmd']} ssl").and_return(true)
            stub_command("#{platform_info['a2dismod_cmd']} rewrite").and_return(true)
          end
        end

        context 'when enabling a module' do
          if platform == 'centos'
            it 'creates module load file' do
              expect(chef_run).to create_file("#{platform_info['mod_dir']}/ssl.load").with(
                content: "LoadModule ssl_module #{platform_info['libexec_dir']}/mod_ssl.so\n",
                owner: 'root',
                group: 'root',
                mode: '0644'
              )
            end
          elsif platform == 'ubuntu'
            it 'runs a2enmod command' do
              expect(chef_run).to run_execute('a2enmod ssl')
            end
          end
        end

        context 'when disabling a module' do
          if platform == 'centos'
            it 'deletes module load file' do
              expect(chef_run).to delete_file("#{platform_info['mod_dir']}/rewrite.load")
            end
          elsif platform == 'ubuntu'
            it 'runs a2dismod command' do
              expect(chef_run).to run_execute('a2dismod rewrite')
            end
          end
        end

        context 'with module configuration' do
          it 'creates a configuration file for the module' do
            if platform == 'centos'
              expect(chef_run).to create_file("#{platform_info['mod_dir']}/status.conf").with(
                content: "<Location \"/server-status\">\n  SetHandler server-status\n  Require local\n</Location>\n",
                owner: 'root',
                group: 'root',
                mode: '0644'
              )
            elsif platform == 'ubuntu'
              expect(chef_run).to create_file("#{platform_info['mod_dir']}/conf-available/status.conf").with(
                content: "<Location \"/server-status\">\n  SetHandler server-status\n  Require local\n</Location>\n",
                owner: 'root',
                group: 'root',
                mode: '0644'
              )
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

cookbook_file "#{cookbook_path}/recipes/httpd_module.rb" do
  content <<-EOH
    httpd_module 'ssl' do
      action :enable
    end

    httpd_module 'rewrite' do
      action :disable
    end

    httpd_module 'status' do
      configuration <<-EOC
<Location "/server-status">
  SetHandler server-status
  Require local
</Location>
      EOC
      action :enable
    end
  EOH
end