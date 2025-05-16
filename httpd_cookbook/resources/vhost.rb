# frozen_string_literal: true

unified_mode true

resource_name :httpd_vhost
provides :httpd_vhost

description 'Use the httpd_vhost resource to configure Apache virtual hosts'

property :domain, String,
         name_property: true,
         description: 'Domain name for the virtual host'

property :aliases, [Array, String],
         default: [],
         coerce: proc { |v| v.is_a?(String) ? [v] : v },
         description: 'ServerAlias entries'

property :port, [Integer, String],
         default: 80,
         coerce: proc { |p| p.to_i },
         description: 'Port to listen on'

property :ip_address, String,
         default: '*',
         description: 'IP address to listen on'

property :server_admin, String,
         default: 'webmaster@localhost',
         description: 'Server admin email'

property :document_root, String,
         required: true,
         description: 'Document root directory'

property :directory_options, String,
         default: 'FollowSymLinks',
         description: 'Options for the <Directory> directive'

property :allow_override, String,
         default: 'None',
         description: 'AllowOverride directive value'

property :directory_index, String,
         default: 'index.html',
         description: 'DirectoryIndex directive value'

property :error_log, String,
         default: lazy {
           case node['platform_family']
           when 'rhel', 'fedora', 'amazon'
             "logs/#{domain}-error_log"
           when 'debian'
             "#{node['httpd']['error_log'].sub('.log', '')}_#{domain}.log"
           end
         },
         description: 'ErrorLog directive value'

property :access_log, String,
         default: lazy {
           case node['platform_family']
           when 'rhel', 'fedora', 'amazon'
             "logs/#{domain}-access_log"
           when 'debian'
             "#{node['httpd']['access_log'].sub('.log', '')}_#{domain}.log"
           end
         },
         description: 'AccessLog directive value'

property :custom_log, String,
         default: lazy {
           case node['platform_family']
           when 'rhel', 'fedora', 'amazon'
             "logs/#{domain}-access_log combined"
           when 'debian'
             "#{node['httpd']['access_log'].sub('.log', '')}_#{domain}.log combined"
           end
         },
         description: 'CustomLog directive value'

property :log_format, String,
         default: 'combined',
         description: 'LogFormat to use for the vhost'

property :ssl_enabled, [true, false],
         default: false,
         description: 'Whether to enable SSL'

property :ssl_cert, String,
         description: 'SSL certificate path'

property :ssl_key, String,
         description: 'SSL key path'

property :ssl_chain, String,
         description: 'SSL chain path'

property :ssl_cipher_suite, String,
         default: lazy { node['httpd']['ssl']['cipher_suite'] },
         description: 'SSL cipher suite'

property :ssl_protocol, [String, Array],
         default: lazy { node['httpd']['ssl']['protocol'] },
         description: 'SSL protocol versions'

property :ssl_honor_cipher_order, String,
         default: lazy { node['httpd']['ssl']['honor_cipher_order'] },
         description: 'SSL honor cipher order'

property :ssl_session_tickets, String,
         default: lazy { node['httpd']['ssl']['session_tickets'] },
         description: 'SSL session tickets'

property :ssl_session_timeout, String,
         default: lazy { node['httpd']['ssl']['session_timeout'] },
         description: 'SSL session timeout'

property :ssl_session_cache, String,
         default: lazy { node['httpd']['ssl']['session_cache'] },
         description: 'SSL session cache'

property :hsts_enabled, [true, false],
         default: lazy { node['httpd']['ssl']['hsts'] },
         description: 'Whether to enable HSTS'

property :hsts_max_age, Integer,
         default: lazy { node['httpd']['ssl']['hsts_max_age'] },
         description: 'HSTS max age in seconds'

property :hsts_include_subdomains, [true, false],
         default: lazy { node['httpd']['ssl']['hsts_include_subdomains'] },
         description: 'Whether to include subdomains in HSTS'

property :hsts_preload, [true, false],
         default: lazy { node['httpd']['ssl']['hsts_preload'] },
         description: 'Whether to preload HSTS'

property :redirect_http_to_https, [true, false],
         default: lazy { node['httpd']['ssl']['auto_redirect_http'] },
         description: 'Whether to redirect HTTP to HTTPS'

property :headers, Hash,
         default: {},
         description: 'Custom headers to add'

property :custom_directives, [Array, String],
         default: [],
         coerce: proc { |v| v.is_a?(String) ? [v] : v },
         description: 'Custom Apache directives to include'

property :enabled, [true, false],
         default: true,
         description: 'Whether the vhost is enabled'

property :cookbook, String,
         default: 'httpd',
         description: 'Cookbook to find template'

property :template, String,
         default: 'vhost.conf.erb',
         description: 'Template to use for vhost configuration'

property :priority, [Integer, String],
         default: 10,
         description: 'Priority for the vhost (lower is higher priority)'

property :enable_cgi, [true, false],
         default: false,
         description: 'Whether to enable CGI'

property :enable_php, [true, false],
         default: false,
         description: 'Whether to enable PHP'

property :enable_perl, [true, false],
         default: false,
         description: 'Whether to enable Perl'

property :enable_python, [true, false],
         default: false,
         description: 'Whether to enable Python'

property :directory_configs, Array,
         default: [],
         description: 'Additional <Directory> configurations'

property :location_configs, Array,
         default: [],
         description: 'Additional <Location> configurations'

property :files_match_configs, Array,
         default: [],
         description: 'Additional <FilesMatch> configurations'

property :proxy_configs, Array,
         default: [],
         description: 'Proxy configurations'

action_class do
  def conf_available_path
    case node['platform_family']
    when 'rhel', 'fedora', 'amazon'
      "#{node['httpd']['conf_available_dir']}/#{new_resource.priority}-#{new_resource.domain}.conf"
    when 'debian'
      "#{node['httpd']['conf_available_dir']}/#{new_resource.priority}-#{new_resource.domain}.conf"
    end
  end

  def conf_enabled_path
    case node['platform_family']
    when 'rhel', 'fedora', 'amazon'
      "#{node['httpd']['conf_enabled_dir']}/#{new_resource.priority}-#{new_resource.domain}.conf"
    when 'debian'
      "#{node['httpd']['conf_enabled_dir']}/#{new_resource.priority}-#{new_resource.domain}.conf"
    end
  end

  def create_vhost_config
    # Ensure the document root exists
    directory new_resource.document_root do
      owner node['httpd']['user']
      group node['httpd']['group']
      mode '0755'
      recursive true
      action :create
    end

    # Create the virtual host configuration file
    template conf_available_path do
      source new_resource.template
      cookbook new_resource.cookbook
      owner 'root'
      group 'root'
      mode '0644'
      variables(
        domain: new_resource.domain,
        aliases: new_resource.aliases,
        port: new_resource.port,
        ip_address: new_resource.ip_address,
        server_admin: new_resource.server_admin,
        document_root: new_resource.document_root,
        directory_options: new_resource.directory_options,
        allow_override: new_resource.allow_override,
        directory_index: new_resource.directory_index,
        error_log: new_resource.error_log,
        access_log: new_resource.access_log,
        custom_log: new_resource.custom_log,
        log_format: new_resource.log_format,
        ssl_enabled: new_resource.ssl_enabled,
        ssl_cert: new_resource.ssl_cert,
        ssl_key: new_resource.ssl_key,
        ssl_chain: new_resource.ssl_chain,
        ssl_cipher_suite: new_resource.ssl_cipher_suite,
        ssl_protocol: new_resource.ssl_protocol,
        ssl_honor_cipher_order: new_resource.ssl_honor_cipher_order,
        ssl_session_tickets: new_resource.ssl_session_tickets,
        ssl_session_timeout: new_resource.ssl_session_timeout,
        ssl_session_cache: new_resource.ssl_session_cache,
        hsts_enabled: new_resource.hsts_enabled,
        hsts_max_age: new_resource.hsts_max_age,
        hsts_include_subdomains: new_resource.hsts_include_subdomains,
        hsts_preload: new_resource.hsts_preload,
        redirect_http_to_https: new_resource.redirect_http_to_https,
        headers: new_resource.headers,
        custom_directives: new_resource.custom_directives,
        enable_cgi: new_resource.enable_cgi,
        enable_php: new_resource.enable_php,
        enable_perl: new_resource.enable_perl,
        enable_python: new_resource.enable_python,
        directory_configs: new_resource.directory_configs,
        location_configs: new_resource.location_configs,
        files_match_configs: new_resource.files_match_configs,
        proxy_configs: new_resource.proxy_configs
      )
      action :create
      notifies :restart, "service[#{node['httpd']['service_name']}]", :delayed
    end
  end

  def enable_vhost
    if node['platform_family'] == 'debian'
      execute "a2ensite #{new_resource.priority}-#{new_resource.domain}.conf" do
        command "a2ensite #{new_resource.priority}-#{new_resource.domain}.conf"
        not_if { ::File.exist?(conf_enabled_path) }
        action :run
        notifies :restart, 'service[apache2]', :delayed
      end
    else
      link conf_enabled_path do
        to conf_available_path
        action :create
        notifies :restart, "service[#{node['httpd']['service_name']}]", :delayed
      end
    end
  end

  def disable_vhost
    if node['platform_family'] == 'debian'
      execute "a2dissite #{new_resource.priority}-#{new_resource.domain}.conf" do
        command "a2dissite #{new_resource.priority}-#{new_resource.domain}.conf"
        only_if { ::File.exist?(conf_enabled_path) }
        action :run
        notifies :restart, 'service[apache2]', :delayed
      end
    else
      link conf_enabled_path do
        action :delete
        only_if { ::File.exist?(conf_enabled_path) }
        notifies :restart, "service[#{node['httpd']['service_name']}]", :delayed
      end
    end
  end

  def setup_ssl_dependencies
    # If SSL is enabled, ensure the SSL module is enabled
    if new_resource.ssl_enabled
      httpd_module 'ssl' do
        action :enable
      end

      # Ensure SSL directories exist
      if new_resource.ssl_cert && new_resource.ssl_key
        directory ::File.dirname(new_resource.ssl_cert) do
          recursive true
          action :create
        end

        directory ::File.dirname(new_resource.ssl_key) do
          recursive true
          action :create
        end
      end
    end
  end
end

action :create do
  # Set up SSL dependencies if needed
  setup_ssl_dependencies if new_resource.ssl_enabled

  # Create vhost configuration
  create_vhost_config

  # Enable the vhost if enabled is true
  if new_resource.enabled
    enable_vhost
  else
    disable_vhost
  end
end

action :delete do
  # Delete the vhost configuration file
  file conf_available_path do
    action :delete
  end

  # Disable the vhost
  disable_vhost

  # Restart the service
  service node['httpd']['service_name'] do
    action :nothing
  end
end

action :enable do
  # Enable the vhost
  enable_vhost
end

action :disable do
  # Disable the vhost
  disable_vhost
end