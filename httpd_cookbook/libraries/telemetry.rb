# frozen_string_literal: true

module Httpd
  module Telemetry
    # Configure Prometheus exporter for Apache HTTP Server
    # @param module_path [String] Path to install the exporter module
    # @param scrape_uri [String] URI to scrape for metrics
    # @param telemetry_path [String] Path where metrics will be exposed
    # @param metrics [Array<String>] Metrics to collect
    # @return [Boolean] True if configured successfully, false otherwise
    def configure_prometheus_exporter(module_path = nil, scrape_uri = '/server-status?auto', telemetry_path = '/metrics', metrics = nil)
      # Default metrics to collect if none specified
      metrics ||= %w(
        connections
        scoreboard 
        cpu
        requests
        throughput
        response_time
        workers
      )
      
      # Check if mod_prometheus_exporter is available
      if apache_has_prometheus_module?
        Chef::Log.info("Apache has built-in Prometheus exporter module")
        return configure_builtin_prometheus_exporter(scrape_uri, telemetry_path, metrics)
      else
        Chef::Log.info("Configuring external Prometheus exporter for Apache")
        return configure_external_prometheus_exporter(module_path, scrape_uri, telemetry_path, metrics)
      end
    end
    
    # Check if Apache has built-in Prometheus exporter module
    # @return [Boolean] True if module is available, false otherwise
    def apache_has_prometheus_module?
      if node['platform_family'] == 'debian'
        ::File.exist?('/usr/lib/apache2/modules/mod_prometheus_exporter.so') || 
        ::File.exist?('/usr/lib/apache2/modules/mod_prometheus.so')
      else
        ::File.exist?('/usr/lib64/httpd/modules/mod_prometheus_exporter.so') ||
        ::File.exist?('/usr/lib64/httpd/modules/mod_prometheus.so')
      end
    rescue StandardError => e
      Chef::Log.warn("Error checking for Prometheus module: #{e.message}")
      false
    end
    
    # Configure built-in Prometheus exporter module
    # @param scrape_uri [String] URI to scrape for metrics
    # @param telemetry_path [String] Path where metrics will be exposed
    # @param metrics [Array<String>] Metrics to collect
    # @return [Boolean] True if configured successfully, false otherwise
    def configure_builtin_prometheus_exporter(scrape_uri, telemetry_path, metrics)
      # Enable the module
      httpd_module 'prometheus_exporter' do
        action :enable
      end rescue nil
      
      # Create configuration
      config_content = %Q(
# Prometheus exporter configuration
<IfModule mod_prometheus_exporter.c>
  PrometheusExporterScrapeURI "#{scrape_uri}"
  PrometheusExporterTelemetryPath "#{telemetry_path}"
  PrometheusExporterMetrics #{metrics.join(' ')}
</IfModule>

<IfModule mod_prometheus.c>
  PrometheusExporterEnable On
  PrometheusExporterScrapeURI "#{scrape_uri}"
  PrometheusExporterTelemetryPath "#{telemetry_path}"
  PrometheusExporterMetrics #{metrics.join(' ')}
</IfModule>
      )
      
      httpd_config 'prometheus-exporter' do
        content config_content
        action :create
      end
      
      # Enable server-status for scraping
      configure_server_status
      
      true
    rescue StandardError => e
      Chef::Log.error("Failed to configure built-in Prometheus exporter: #{e.message}")
      false
    end
    
    # Configure external Prometheus exporter
    # @param module_path [String] Path to install the exporter module
    # @param scrape_uri [String] URI to scrape for metrics
    # @param telemetry_path [String] Path where metrics will be exposed
    # @param metrics [Array<String>] Metrics to collect
    # @return [Boolean] True if configured successfully, false otherwise
    def configure_external_prometheus_exporter(module_path, scrape_uri, telemetry_path, metrics)
      # Install prometheus-apache-exporter package or binary
      package_name = if node['platform_family'] == 'debian'
                        'prometheus-apache-exporter'
                      elsif node['platform_family'] == 'rhel'
                        'prometheus-apache-exporter'
                      else
                        nil
                      end
      
      if package_name
        package package_name do
          action :install
        end
      else
        # Download binary if package not available
        remote_file '/usr/local/bin/apache_exporter' do
          source 'https://github.com/Lusitaniae/apache_exporter/releases/download/v0.8.0/apache_exporter-0.8.0.linux-amd64.tar.gz'
          mode '0755'
          action :create
          notifies :run, 'execute[extract_apache_exporter]', :immediately
        end
        
        execute 'extract_apache_exporter' do
          command 'tar -xzf /usr/local/bin/apache_exporter -C /tmp && mv /tmp/apache_exporter*/apache_exporter /usr/local/bin/ && chmod +x /usr/local/bin/apache_exporter'
          action :nothing
        end
      end
      
      # Create systemd service file
      template '/etc/systemd/system/apache-exporter.service' do
        source 'apache-exporter.service.erb'
        cookbook 'httpd'
        owner 'root'
        group 'root'
        mode '0644'
        variables(
          scrape_uri: scrape_uri,
          telemetry_path: telemetry_path
        )
        action :create
        notifies :run, 'execute[systemctl-daemon-reload]', :immediately
      end
      
      # Reload systemd
      execute 'systemctl-daemon-reload' do
        command 'systemctl daemon-reload'
        action :nothing
      end
      
      # Enable and start service
      service 'apache-exporter' do
        action [:enable, :start]
      end
      
      # Enable server-status for scraping
      configure_server_status
      
      true
    rescue StandardError => e
      Chef::Log.error("Failed to configure external Prometheus exporter: #{e.message}")
      false
    end
    
    # Configure Apache server-status module
    # @param allow_from [Array<String>] IP addresses allowed to access server-status
    # @return [Boolean] True if configured successfully, false otherwise
    def configure_server_status(allow_from = ['127.0.0.1', '::1'])
      # Enable mod_status
      httpd_module 'status' do
        action :enable
      end
      
      # Create configuration
      config_content = %Q(
<IfModule mod_status.c>
  <Location "/server-status">
    SetHandler server-status
    Require local
    #{allow_from.map { |ip| "Require ip #{ip}" }.join("\n    ")}
    ProxyPass !
  </Location>
  
  # Enable ExtendedStatus for detailed metrics
  ExtendedStatus On
</IfModule>
      )
      
      httpd_config 'server-status' do
        content config_content
        action :create
      end
      
      true
    rescue StandardError => e
      Chef::Log.error("Failed to configure server-status: #{e.message}")
      false
    end
    
    # Configure Grafana dashboard for Apache metrics
    # @param grafana_url [String] Grafana base URL
    # @param datasource [String] Prometheus datasource name
    # @param api_key [String] Grafana API key
    # @return [Boolean] True if configured successfully, false otherwise
    def configure_grafana_dashboard(grafana_url, datasource, api_key = nil)
      require 'uri'
      require 'net/http'
      require 'json'
      
      dashboard_json = {
        "dashboard" => {
          "id" => nil,
          "title" => "Apache HTTP Server Metrics",
          "tags" => ["apache", "httpd", "web"],
          "timezone" => "browser",
          "schemaVersion" => 16,
          "version" => 1,
          "refresh" => "30s",
          "panels" => [
            {
              "type" => "graph",
              "title" => "Requests per second",
              "gridPos" => { "x" => 0, "y" => 0, "w" => 12, "h" => 8 },
              "id" => 1,
              "targets" => [
                {
                  "expr" => "rate(apache_requests_total[5m])",
                  "refId" => "A",
                  "legendFormat" => "Requests/s"
                }
              ]
            },
            {
              "type" => "graph",
              "title" => "Apache Workers",
              "gridPos" => { "x" => 12, "y" => 0, "w" => 12, "h" => 8 },
              "id" => 2,
              "targets" => [
                {
                  "expr" => "apache_workers{state=\"busy\"}",
                  "refId" => "A",
                  "legendFormat" => "Busy Workers"
                },
                {
                  "expr" => "apache_workers{state=\"idle\"}",
                  "refId" => "B",
                  "legendFormat" => "Idle Workers"
                }
              ]
            },
            {
              "type" => "graph",
              "title" => "Apache CPU Usage",
              "gridPos" => { "x" => 0, "y" => 8, "w" => 12, "h" => 8 },
              "id" => 3,
              "targets" => [
                {
                  "expr" => "rate(apache_cpu_seconds_total[5m])",
                  "refId" => "A",
                  "legendFormat" => "CPU seconds/s"
                }
              ]
            },
            {
              "type" => "graph",
              "title" => "Apache Scoreboard",
              "gridPos" => { "x" => 12, "y" => 8, "w" => 12, "h" => 8 },
              "id" => 4,
              "targets" => [
                {
                  "expr" => "apache_scoreboard",
                  "refId" => "A",
                  "legendFormat" => "{{state}}"
                }
              ]
            }
          ],
          "templating" => {
            "list" => []
          },
          "time" => {
            "from" => "now-6h",
            "to" => "now"
          },
          "timepicker" => {
            "refresh_intervals" => ["5s", "10s", "30s", "1m", "5m", "15m", "30m", "1h", "2h", "1d"]
          }
        },
        "folderId" => 0,
        "folderUid" => "",
        "message" => "Apache HTTP Server dashboard created by Chef",
        "overwrite" => true
      }
      
      # Save dashboard JSON to file
      dashboard_path = '/etc/httpd/grafana-dashboard.json'
      if node['platform_family'] == 'debian'
        dashboard_path = '/etc/apache2/grafana-dashboard.json'
      end
      
      file dashboard_path do
        content JSON.pretty_generate(dashboard_json)
        owner 'root'
        group 'root'
        mode '0644'
        action :create
      end
      
      # If API key provided, try to upload dashboard to Grafana
      if api_key
        begin
          uri = URI.parse("#{grafana_url}/api/dashboards/db")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          
          request = Net::HTTP::Post.new(uri.request_uri)
          request['Content-Type'] = 'application/json'
          request['Authorization'] = "Bearer #{api_key}"
          request.body = dashboard_json.to_json
          
          response = http.request(request)
          
          if response.code.to_i == 200
            Chef::Log.info("Grafana dashboard created successfully")
            return true
          else
            Chef::Log.error("Failed to create Grafana dashboard: #{response.body}")
            return false
          end
        rescue => e
          Chef::Log.error("Error communicating with Grafana API: #{e.message}")
          return false
        end
      end
      
      # Return true even if API upload was skipped
      true
    rescue StandardError => e
      Chef::Log.error("Failed to configure Grafana dashboard: #{e.message}")
      false
    end
  end
end

Chef::DSL::Recipe.include(Httpd::Telemetry)
Chef::Resource.include(Httpd::Telemetry)