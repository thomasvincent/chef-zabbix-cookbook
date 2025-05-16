# frozen_string_literal: true

module Httpd
  module YAMLProcessor
    # Process a YAML configuration into Apache HTTP Server configuration format
    # This provides a modern way to handle complex configurations in Chef 18+
    
    # Convert YAML configuration to Apache HTTP Server configuration format
    # @param yaml_config [Hash] The YAML configuration hash
    # @return [String] The Apache HTTP Server configuration
    def yaml_to_apache_config(yaml_config)
      result = []
      
      # Process server section
      if yaml_config['server']
        server = yaml_config['server']
        result << "ServerRoot \"#{server['root']}\"" if server['root']
        result << "ServerName #{server['name']}" if server['name']
        result << "ServerAdmin #{server['admin']}" if server['admin']
        result << "HostnameLookups #{server['hostname_lookups']}" if server['hostname_lookups']
        result << "Timeout #{server['timeout']}" if server['timeout']
        result << "KeepAlive #{server['keep_alive']}" if server['keep_alive']
        result << "KeepAliveTimeout #{server['keep_alive_timeout']}" if server['keep_alive_timeout']
        result << "MaxKeepAliveRequests #{server['keep_alive_requests']}" if server['keep_alive_requests']
        result << "User #{server['user']}" if server['user']
        result << "Group #{server['group']}" if server['group']
      end
      
      # Process listen directives
      if yaml_config['listen']
        yaml_config['listen'].each do |listen|
          result << "Listen #{listen}"
        end
      end
      
      # Process module loading
      if yaml_config['modules']
        yaml_config['modules'].each do |mod|
          result << "LoadModule #{mod}_module #{apache_module_path(mod)}"
        end
      end
      
      # Process MPM configuration
      if yaml_config['mpm']
        mpm = yaml_config['mpm']
        result << "<IfModule #{mpm['type']}_module>"
        result << "  ServerLimit #{mpm['server_limit']}" if mpm['server_limit']
        result << "  MaxRequestWorkers #{mpm['max_request_workers']}" if mpm['max_request_workers']
        result << "  ThreadsPerChild #{mpm['threads_per_child']}" if mpm['threads_per_child']
        result << "  MaxConnectionsPerChild #{mpm['max_connections_per_child']}" if mpm['max_connections_per_child']
        result << "</IfModule>"
      end
      
      # Process logging configuration
      if yaml_config['logs']
        logs = yaml_config['logs']
        result << "LogLevel #{logs['level']}" if logs['level']
        result << "ErrorLog \"#{logs['error_log']}\"" if logs['error_log']
        
        if logs['formats']
          logs['formats'].each do |name, format|
            result << "LogFormat \"#{format}\" #{name}"
          end
        end
        
        result << "CustomLog \"#{logs['access_log']}\" combined" if logs['access_log']
      end
      
      # Process directory configurations
      if yaml_config['directories']
        yaml_config['directories'].each do |dir|
          result << "<Directory \"#{dir['path']}\">"
          result << "  Options #{dir['options']}" if dir['options']
          result << "  AllowOverride #{dir['allow_override']}" if dir['allow_override']
          result << "  Require #{dir['require']}" if dir['require']
          result << "</Directory>"
        end
      end
      
      # Process security settings
      if yaml_config['security']
        security = yaml_config['security']
        result << "ServerTokens #{security['server_tokens']}" if security['server_tokens']
        result << "ServerSignature #{security['server_signature']}" if security['server_signature']
        result << "TraceEnable #{security['trace_enable']}" if security['trace_enable']
      end
      
      # Process HTTP/2 settings
      if yaml_config['http2'] && yaml_config['http2']['enabled']
        result << "Protocols h2 http/1.1"
      end
      
      # Process SSL settings
      if yaml_config['ssl'] && yaml_config['ssl']['enabled']
        ssl = yaml_config['ssl']
        result << "<VirtualHost *:#{ssl['port']}>"
        result << "  SSLEngine on"
        result << "  SSLProtocol #{ssl['protocol']}" if ssl['protocol']
        result << "  SSLCipherSuite #{ssl['cipher_suite']}" if ssl['cipher_suite']
        result << "  SSLHonorCipherOrder #{ssl['honor_cipher_order']}" if ssl['honor_cipher_order']
        result << "  SSLCertificateFile #{ssl['certificate']}" if ssl['certificate']
        result << "  SSLCertificateKeyFile #{ssl['certificate_key']}" if ssl['certificate_key']
        result << "  SSLCertificateChainFile #{ssl['certificate_chain']}" if ssl['certificate_chain']
        
        if ssl['hsts'] && ssl['hsts']['enabled']
          header = "Strict-Transport-Security \"max-age=#{ssl['hsts']['max_age']}"
          header += "; includeSubDomains" if ssl['hsts']['include_subdomains']
          header += "; preload" if ssl['hsts']['preload']
          header += "\""
          result << "  Header always set #{header}"
        end
        
        result << "</VirtualHost>"
      end
      
      # Process additional configuration sections
      if yaml_config['additional_config']
        yaml_config['additional_config'].each do |key, value|
          if value.is_a?(Hash)
            process_nested_config(result, key, value)
          else
            result << "#{key} #{value}"
          end
        end
      end
      
      result.join("\n")
    end
    
    private
    
    # Process nested configuration sections
    # @param result [Array] The result array to append to
    # @param section [String] The section name
    # @param config [Hash] The configuration hash
    # @return [void]
    def process_nested_config(result, section, config)
      if section.start_with?('<') && section.end_with?('>')
        # This is a block directive like <Directory>
        result << section
        config.each do |key, value|
          if value.is_a?(Hash)
            process_nested_config(result, "  #{key}", value)
          else
            result << "  #{key} #{value}"
          end
        end
        result << "</#{section[1..-2]}>"
      else
        # This is a simple directive
        config.each do |key, value|
          if value.is_a?(Hash)
            process_nested_config(result, "#{section} #{key}", value)
          else
            result << "#{section} #{key} #{value}"
          end
        end
      end
    end
    
    # Get the module path based on the module name and platform
    # @param module_name [String] The module name
    # @return [String] The module path
    def apache_module_path(module_name)
      case node['platform_family']
      when 'debian'
        "/usr/lib/apache2/modules/mod_#{module_name}.so"
      when 'rhel', 'fedora', 'amazon'
        "/usr/lib64/httpd/modules/mod_#{module_name}.so"
      when 'suse'
        "/usr/lib64/apache2/mod_#{module_name}.so"
      else
        "/usr/lib64/httpd/modules/mod_#{module_name}.so"
      end
    end
  end
end

Chef::DSL::Recipe.include(Httpd::YAMLProcessor)
Chef::Resource.include(Httpd::YAMLProcessor)