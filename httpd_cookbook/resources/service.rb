# frozen_string_literal: true

unified_mode true

resource_name :httpd_service
provides :httpd_service

description 'Use the httpd_service resource to manage the Apache HTTP Server service'

property :service_name, String,
         default: lazy { node['httpd']['service_name'] },
         description: 'The service name'

property :restart_command, [String, nil],
         default: nil,
         description: 'Command to restart the service'

property :reload_command, [String, nil],
         default: nil,
         description: 'Command to reload the service'

property :supports, Hash,
         default: { restart: true, reload: true, status: true },
         description: 'Service supports hash'

property :service_config_changes, [true, false],
         default: true,
         description: 'Whether to apply service configuration changes'

property :max_keepalive_requests, Integer,
         default: 100,
         description: 'MaxKeepAliveRequests directive value'

property :keep_alive, [String, TrueClass, FalseClass],
         default: 'On',
         coerce: proc { |v| v == true ? 'On' : (v == false ? 'Off' : v) },
         description: 'KeepAlive directive value'

property :keep_alive_timeout, Integer,
         default: 5,
         description: 'KeepAliveTimeout directive value'

property :log_level, String,
         default: 'warn',
         description: 'LogLevel directive value'

property :listen, [String, Array],
         default: ['*:80'],
         coerce: proc { |v| v.is_a?(String) ? [v] : v },
         description: 'Listen directive value'

property :timeout, Integer,
         default: 300,
         description: 'Timeout directive value'

property :enable_http2, [TrueClass, FalseClass],
         default: true,
         description: 'Whether to enable HTTP/2'

property :server_tokens, String,
         default: 'Prod',
         description: 'ServerTokens directive value'

property :server_signature, String,
         default: 'Off',
         description: 'ServerSignature directive value'

property :trace_enable, String,
         default: 'Off',
         description: 'TraceEnable directive value'

property :mpm_config, [Hash, nil],
         default: nil,
         description: 'MPM configuration override'

property :additional_config, [Hash, nil],
         default: nil,
         description: 'Additional configuration options'

action_class do
  def create_apache_config
    template "#{node['httpd']['conf_dir']}/httpd.conf" do
      source 'httpd.conf.erb'
      cookbook 'httpd'
      owner 'root'
      group 'root'
      mode '0644'
      variables(
        server_root: node['httpd']['root_dir'],
        listen: new_resource.listen,
        server_admin: node['httpd']['config']['server_admin'],
        server_name: node['fqdn'] || node['hostname'] || 'localhost',
        document_root: node['httpd']['default_vhost']['document_root'],
        directory_index: node['httpd']['config']['directory_index'],
        user: node['httpd']['config']['user'],
        group: node['httpd']['config']['group'],
        max_keep_alive_requests: new_resource.max_keepalive_requests,
        keep_alive: new_resource.keep_alive,
        keep_alive_timeout: new_resource.keep_alive_timeout,
        timeout: new_resource.timeout,
        log_level: new_resource.log_level,
        error_log: node['httpd']['error_log'],
        access_log: node['httpd']['access_log'],
        mpm: node['httpd']['mpm'],
        mpm_config: new_resource.mpm_config || node['httpd']['performance'],
        modules_path: node['httpd']['libexec_dir'],
        server_tokens: new_resource.server_tokens,
        server_signature: new_resource.server_signature,
        trace_enable: new_resource.trace_enable,
        enable_http2: new_resource.enable_http2,
        conf_enabled_dir: node['httpd']['conf_enabled_dir'],
        mod_dir: node['httpd']['mod_dir'],
        additional_config: new_resource.additional_config
      )
      notifies :restart, "service[#{new_resource.service_name}]", :delayed
      action :create
      only_if { new_resource.service_config_changes }
    end

    # Create security.conf
    httpd_config 'security' do
      source 'security.conf.erb'
      variables(
        server_tokens: new_resource.server_tokens,
        server_signature: new_resource.server_signature,
        trace_enable: new_resource.trace_enable,
        clickjacking_protection: node['httpd']['security']['clickjacking_protection'],
        xss_protection: node['httpd']['security']['xss_protection'],
        mime_sniffing_protection: node['httpd']['security']['mime_sniffing_protection'],
        content_security_policy: node['httpd']['security']['content_security_policy']
      )
      action :create
      only_if { new_resource.service_config_changes }
    end

    # Create health-check.conf if enabled
    if node['httpd']['health_check']['enabled']
      httpd_config 'health-check' do
        source 'health-check.conf.erb'
        variables(
          health_check_path: node['httpd']['health_check']['path'],
          health_check_content: node['httpd']['health_check']['content']
        )
        action :create
        only_if { new_resource.service_config_changes }
      end
    end

    # Create monitoring.conf if enabled
    if node['httpd']['monitoring']['enabled']
      httpd_config 'monitoring' do
        source 'monitoring.conf.erb'
        variables(
          status_path: node['httpd']['monitoring']['status_path'],
          restricted_access: node['httpd']['monitoring']['restricted_access'],
          allowed_ips: node['httpd']['monitoring']['allowed_ips']
        )
        action :create
        only_if { new_resource.service_config_changes }
      end
    end

    # Create SSL configuration if enabled
    if node['httpd']['ssl']['enabled']
      httpd_config 'ssl' do
        source 'ssl.conf.erb'
        variables(
          ssl_port: node['httpd']['ssl']['port'],
          ssl_protocol: node['httpd']['ssl']['protocol'],
          ssl_cipher_suite: node['httpd']['ssl']['cipher_suite'],
          ssl_honor_cipher_order: node['httpd']['ssl']['honor_cipher_order'],
          ssl_session_tickets: node['httpd']['ssl']['session_tickets'],
          ssl_session_timeout: node['httpd']['ssl']['session_timeout'],
          ssl_session_cache: node['httpd']['ssl']['session_cache'],
          ssl_certificate: node['httpd']['ssl']['certificate'],
          ssl_certificate_key: node['httpd']['ssl']['certificate_key'],
          ssl_certificate_chain: node['httpd']['ssl']['certificate_chain'],
          hsts: node['httpd']['ssl']['hsts'],
          hsts_max_age: node['httpd']['ssl']['hsts_max_age'],
          hsts_include_subdomains: node['httpd']['ssl']['hsts_include_subdomains'],
          hsts_preload: node['httpd']['ssl']['hsts_preload'],
          ocsp_stapling: node['httpd']['ssl']['ocsp_stapling']
        )
        action :create
        only_if { new_resource.service_config_changes }
      end
    end
  end

  def service_path
    case node['platform_family']
    when 'rhel', 'fedora', 'amazon'
      '/usr/lib/systemd/system/httpd.service'
    when 'debian'
      '/lib/systemd/system/apache2.service'
    end
  end

  def systemd_override_path
    case node['platform_family']
    when 'rhel', 'fedora', 'amazon'
      '/etc/systemd/system/httpd.service.d'
    when 'debian'
      '/etc/systemd/system/apache2.service.d'
    end
  end

  def create_systemd_override
    # Only create systemd override if using systemd
    return unless ::File.exist?(service_path)

    directory systemd_override_path do
      owner 'root'
      group 'root'
      mode '0755'
      recursive true
      action :create
    end

    # Create a systemd override file for tuning
    template "#{systemd_override_path}/override.conf" do
      source 'systemd-override.conf.erb'
      cookbook 'httpd'
      owner 'root'
      group 'root'
      mode '0644'
      variables(
        timeout_start_sec: 600,
        timeout_stop_sec: 600,
        restart_sec: 10,
        limit_nofile: 65536,
        memory_limit: nil, # Leave memory management to system defaults
        cpu_quota: nil     # Leave CPU management to system defaults
      )
      notifies :run, 'execute[systemctl-daemon-reload]', :immediately
      action :create
    end

    execute 'systemctl-daemon-reload' do
      command 'systemctl daemon-reload'
      action :nothing
    end
  end
end

action :create do
  # Create main Apache configuration
  create_apache_config

  # Create systemd override files if using systemd
  create_systemd_override

  # Configure the service with the appropriate init system
  service new_resource.service_name do
    supports new_resource.supports
    restart_command new_resource.restart_command if new_resource.restart_command
    reload_command new_resource.reload_command if new_resource.reload_command
    action :nothing
  end
end

action :restart do
  service new_resource.service_name do
    action :restart
  end
end

action :reload do
  service new_resource.service_name do
    action :reload
  end
end

action :start do
  service new_resource.service_name do
    action :start
  end
end

action :stop do
  service new_resource.service_name do
    action :stop
  end
end

action :enable do
  service new_resource.service_name do
    action :enable
  end
end

action :disable do
  service new_resource.service_name do
    action :disable
  end
end

# Convenience method to enable and start the service
action [:enable, :start] do
  action_enable
  action_start
end