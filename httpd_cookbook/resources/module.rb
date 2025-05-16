# frozen_string_literal: true

unified_mode true

resource_name :httpd_module
provides :httpd_module

description 'Use the httpd_module resource to enable or disable Apache modules'

property :module_name, String,
         name_property: true,
         description: 'The name of the module to enable or disable'

property :configuration, [String, NilClass],
         default: nil,
         description: 'Optional configuration for the module'

property :install_package, [true, false],
         default: true,
         description: 'Whether to install the module package'

property :package_name, [String, Array, NilClass],
         default: nil,
         coerce: proc { |p| p.is_a?(String) ? [p] : p },
         description: 'Package name(s) for the module'

property :module_path, String,
         default: lazy {
           case node['platform_family']
           when 'rhel', 'fedora', 'amazon'
             "#{node['httpd']['libexec_dir']}/mod_#{module_name}.so"
           when 'debian'
             "/usr/lib/apache2/modules/mod_#{module_name}.so"
           end
         },
         description: 'Path to the module file'

property :identifier, String,
         default: lazy { module_name },
         description: 'Module identifier used in LoadModule directive'

property :conf_name, String,
         default: lazy { "#{module_name}.conf" },
         description: 'Configuration file name'

action_class do
  def compute_package_name
    # Return the user-provided package name if specified
    return new_resource.package_name if new_resource.package_name

    # Otherwise, compute a default package name based on platform
    case node['platform_family']
    when 'rhel', 'fedora', 'amazon'
      ["mod_#{new_resource.module_name}", "httpd-mod-#{new_resource.module_name}"]
    when 'debian'
      "libapache2-mod-#{new_resource.module_name}"
    end
  end

  def module_path_exists?
    ::File.exist?(new_resource.module_path)
  end

  def installation_attempted?
    @installation_attempted
  end

  def module_available?
    case node['platform_family']
    when 'rhel', 'fedora', 'amazon'
      ::File.exist?("#{node['httpd']['mod_dir']}/#{new_resource.module_name}.load") ||
        ::File.exist?("#{node['httpd']['mod_dir']}/#{new_resource.conf_name}")
    when 'debian'
      ::File.exist?("#{node['httpd']['mod_dir']}/#{new_resource.module_name}.load")
    end
  end

  def module_enabled?
    case node['platform_family']
    when 'rhel', 'fedora', 'amazon'
      ::File.exist?("#{node['httpd']['mod_dir']}/#{new_resource.module_name}.load") ||
        ::File.exist?("#{node['httpd']['mod_dir']}/#{new_resource.conf_name}")
    when 'debian'
      ::File.exist?("#{node['httpd']['mod_enabled_dir']}/#{new_resource.module_name}.load")
    end
  end

  def create_module_config
    if new_resource.configuration
      case node['platform_family']
      when 'rhel', 'fedora', 'amazon'
        file "#{node['httpd']['mod_dir']}/#{new_resource.conf_name}" do
          content new_resource.configuration
          owner 'root'
          group 'root'
          mode '0644'
          action :create
          notifies :restart, 'service[httpd]', :delayed
        end
      when 'debian'
        file "#{node['httpd']['mod_dir']}/conf-available/#{new_resource.conf_name}" do
          content new_resource.configuration
          owner 'root'
          group 'root'
          mode '0644'
          action :create
          notifies :restart, 'service[apache2]', :delayed
        end

        link "#{node['httpd']['mod_dir']}/conf-enabled/#{new_resource.conf_name}" do
          to "#{node['httpd']['mod_dir']}/conf-available/#{new_resource.conf_name}"
          action :create
          notifies :restart, 'service[apache2]', :delayed
        end
      end
    end
  end

  def a2enmod
    execute "a2enmod #{new_resource.module_name}" do
      command "/usr/sbin/a2enmod #{new_resource.module_name}"
      not_if { module_enabled? }
      action :run
      notifies :restart, 'service[apache2]', :delayed
    end

    # If there's an associated conf file, enable it
    execute "a2enconf #{new_resource.module_name}" do
      command "/usr/sbin/a2enconf #{new_resource.module_name}"
      only_if { new_resource.configuration && ::File.exist?("#{node['httpd']['mod_dir']}/conf-available/#{new_resource.conf_name}") }
      not_if { ::File.exist?("#{node['httpd']['mod_dir']}/conf-enabled/#{new_resource.conf_name}") }
      action :run
      notifies :restart, 'service[apache2]', :delayed
    end
  end

  def a2dismod
    execute "a2dismod #{new_resource.module_name}" do
      command "/usr/sbin/a2dismod #{new_resource.module_name}"
      only_if { module_enabled? }
      action :run
      notifies :restart, 'service[apache2]', :delayed
    end

    # If there's an associated conf file, disable it
    execute "a2disconf #{new_resource.module_name}" do
      command "/usr/sbin/a2disconf #{new_resource.module_name}"
      only_if { ::File.exist?("#{node['httpd']['mod_dir']}/conf-enabled/#{new_resource.conf_name}") }
      action :run
      notifies :restart, 'service[apache2]', :delayed
    end
  end

  def rhel_enable_module
    # Ensure the modules load directory exists
    directory node['httpd']['mod_dir'] do
      owner 'root'
      group 'root'
      mode '0755'
      recursive true
      action :create
    end

    # Create the .load file
    file "#{node['httpd']['mod_dir']}/#{new_resource.module_name}.load" do
      content "LoadModule #{new_resource.identifier}_module #{new_resource.module_path}\n"
      owner 'root'
      group 'root'
      mode '0644'
      action :create
      not_if { ::File.exist?("#{node['httpd']['mod_dir']}/#{new_resource.module_name}.load") }
      notifies :restart, 'service[httpd]', :delayed
    end
  end

  def rhel_disable_module
    file "#{node['httpd']['mod_dir']}/#{new_resource.module_name}.load" do
      action :delete
      only_if { ::File.exist?("#{node['httpd']['mod_dir']}/#{new_resource.module_name}.load") }
      notifies :restart, 'service[httpd]', :delayed
    end

    file "#{node['httpd']['mod_dir']}/#{new_resource.conf_name}" do
      action :delete
      only_if { ::File.exist?("#{node['httpd']['mod_dir']}/#{new_resource.conf_name}") }
      notifies :restart, 'service[httpd]', :delayed
    end
  end
end

action :enable do
  # Install package if needed
  if new_resource.install_package
    package_names = compute_package_name
    @installation_attempted = true

    if package_names
      package package_names do
        action :install
        not_if { module_path_exists? }
      end
    end
  end

  # Create module config if provided
  create_module_config if new_resource.configuration

  # Enable the module based on platform
  case node['platform_family']
  when 'rhel', 'fedora', 'amazon'
    rhel_enable_module
  when 'debian'
    a2enmod
  end
end

action :disable do
  # Disable the module based on platform
  case node['platform_family']
  when 'rhel', 'fedora', 'amazon'
    rhel_disable_module
  when 'debian'
    a2dismod
  end
end