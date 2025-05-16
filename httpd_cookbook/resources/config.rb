# frozen_string_literal: true

unified_mode true

resource_name :httpd_config
provides :httpd_config

description 'Use the httpd_config resource to create configuration snippets'

property :config_name, String,
         name_property: true,
         description: 'The name of the configuration file'

property :source, String,
         description: 'Template source file'

property :cookbook, String,
         default: 'httpd',
         description: 'Cookbook containing the template'

property :variables, Hash,
         default: {},
         description: 'Variables to pass to the template'

property :content, String,
         description: 'Configuration content'

property :enable, [true, false],
         default: true,
         description: 'Whether to enable the configuration'

property :priority, [Integer, String],
         description: 'Priority for the configuration (lower is higher priority)'

property :create_symlink, [true, false],
         default: false,
         description: 'Whether to create a symlink from available to enabled'

action_class do
  def config_file_path
    case node['platform_family']
    when 'rhel', 'fedora', 'amazon'
      if new_resource.create_symlink
        "#{node['httpd']['conf_available_dir']}/#{filename}"
      else
        "#{node['httpd']['conf_enabled_dir']}/#{filename}"
      end
    when 'debian'
      "#{node['httpd']['conf_available_dir']}/#{filename}"
    end
  end

  def filename
    if new_resource.priority
      "#{new_resource.priority}-#{new_resource.config_name}.conf"
    else
      "#{new_resource.config_name}.conf"
    end
  end

  def symlink_path
    case node['platform_family']
    when 'rhel', 'fedora', 'amazon'
      if new_resource.priority
        "#{node['httpd']['conf_enabled_dir']}/#{new_resource.priority}-#{new_resource.config_name}.conf"
      else
        "#{node['httpd']['conf_enabled_dir']}/#{new_resource.config_name}.conf"
      end
    when 'debian'
      "#{node['httpd']['conf_enabled_dir']}/#{filename}"
    end
  end

  def create_custom_config
    if new_resource.content
      file config_file_path do
        content new_resource.content
        owner 'root'
        group 'root'
        mode '0644'
        action :create
      end
    elsif new_resource.source
      template config_file_path do
        source new_resource.source
        cookbook new_resource.cookbook
        owner 'root'
        group 'root'
        mode '0644'
        variables new_resource.variables
        action :create
      end
    else
      Chef::Log.error("The httpd_config resource #{new_resource.config_name} requires either content or source property")
    end
  end

  def create_symlink_to_enabled
    # Only create symlink for Debian-based platforms or if create_symlink is true
    if node['platform_family'] == 'debian' || new_resource.create_symlink
      link symlink_path do
        to config_file_path
        action :create
      end
    end
  end

  def delete_symlink
    if node['platform_family'] == 'debian' || new_resource.create_symlink
      link symlink_path do
        action :delete
        only_if { ::File.exist?(symlink_path) }
      end
    end
  end
end

action :create do
  # Create configuration file
  create_custom_config

  # Create symlink to enabled configuration if enabled
  if new_resource.enable
    create_symlink_to_enabled
  else
    delete_symlink
  end
end

action :delete do
  # Delete configuration file
  file config_file_path do
    action :delete
  end

  # Delete symlink
  delete_symlink
end

action :enable do
  # Create symlink to enabled configuration
  create_symlink_to_enabled
end

action :disable do
  # Delete symlink
  delete_symlink
end