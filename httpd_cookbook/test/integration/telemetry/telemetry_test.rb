# InSpec test for the telemetry functionality in the httpd cookbook

title 'Apache HTTP Server Telemetry Tests'

# Common variables
apache_service_name = os.debian? ? 'apache2' : 'httpd'
apache_config_dir = os.debian? ? '/etc/apache2' : '/etc/httpd'
apache_user = os.debian? ? 'www-data' : 'apache'
apache_modules_dir = os.debian? ? '/usr/lib/apache2/modules' : '/usr/lib64/httpd/modules'

control 'httpd-telemetry-1' do
  impact 1.0
  title 'Ensure Apache server-status is properly configured'
  desc 'Verify that Apache server-status is enabled and properly secured'

  describe file("#{apache_config_dir}/conf.d/server-status.conf") do
    it { should exist }
    its('content') { should match %r{<Location "/server-status">} }
    its('content') { should match /ExtendedStatus On/ }
    its('content') { should match /Require local/ }
    its('content') { should match /Require ip 127\.0\.0\.1/ }
    its('mode') { should cmp '0644' }
    its('owner') { should eq 'root' }
  end

  describe apache_conf("#{apache_config_dir}/conf.d/server-status.conf") do
    its('LocationMatch "/server-status"') { should_not be_nil }
  end if os.debian? # apache_conf resource is available in some InSpec versions

  describe command("#{os.debian? ? 'a2query' : 'httpd'} -M") do
    its('stdout') { should match /status_module/ }
  end
end

control 'httpd-telemetry-2' do
  impact 1.0
  title 'Ensure Prometheus exporter is properly configured'
  desc 'Verify that the Prometheus exporter configuration is correct'

  # Check for either the built-in module or external exporter configuration
  describe file("#{apache_config_dir}/conf.d/prometheus-exporter.conf"), :if => file("#{apache_modules_dir}/mod_prometheus_exporter.so").exist? do
    it { should exist }
    its('content') { should match /PrometheusExporterScrapeURI/ }
    its('content') { should match /PrometheusExporterTelemetryPath/ }
    its('content') { should match /PrometheusExporterMetrics/ }
  end

  describe file('/etc/systemd/system/apache-exporter.service'), :if => !file("#{apache_modules_dir}/mod_prometheus_exporter.so").exist? do
    it { should exist }
    its('content') { should match /Description=Prometheus Apache Exporter/ }
    its('content') { should match /ExecStart=\/usr\/local\/bin\/apache_exporter/ }
    its('content') { should match /--telemetry.path/ }
    its('content') { should match /--scrape_uri/ }
    # Security enhancements
    its('content') { should match /NoNewPrivileges=true/ }
    its('content') { should match /ProtectSystem=full/ }
    its('mode') { should cmp '0644' }
    its('owner') { should eq 'root' }
  end

  # Check if either the built-in module is loaded or the external service is running
  describe command("#{os.debian? ? 'a2query' : 'httpd'} -M"), :if => file("#{apache_modules_dir}/mod_prometheus_exporter.so").exist? do
    its('stdout') { should match /prometheus_exporter_module/ }
  end

  describe service('apache-exporter'), :if => !file("#{apache_modules_dir}/mod_prometheus_exporter.so").exist? do
    it { should be_enabled }
    it { should be_running }
  end

  # Check for the exporter binary if using external exporter
  describe file('/usr/local/bin/apache_exporter'), :if => !file("#{apache_modules_dir}/mod_prometheus_exporter.so").exist? do
    it { should exist }
    it { should be_executable }
  end
end

control 'httpd-telemetry-3' do
  impact 1.0
  title 'Ensure Grafana dashboard configuration exists'
  desc 'Verify that the Grafana dashboard configuration file is present'

  dashboard_path = os.debian? ? '/etc/apache2/grafana-dashboard.json' : '/etc/httpd/grafana-dashboard.json'
  
  describe file(dashboard_path) do
    it { should exist }
    its('content') { should match /"title": "Apache HTTP Server Metrics"/ }
    its('content') { should match /"tags": \["apache", "httpd", "web"\]/ }
    its('content') { should match /"expr": "rate\(apache_requests_total\[5m\]\)"/ }
    its('content') { should match /"expr": "apache_workers{state=\\"busy\\"}"/ }
    its('mode') { should cmp '0644' }
    its('owner') { should eq 'root' }
  end
end

control 'httpd-telemetry-4' do
  impact 1.0
  title 'Verify telemetry endpoints are accessible'
  desc 'Ensure telemetry endpoints are properly secured and responding'

  # Test server-status accessibility (should only be accessible locally)
  describe command('curl -s -o /dev/null -w "%{http_code}" http://localhost/server-status') do
    its('stdout') { should match /(200|403)/ } # Either accessible or properly secured
  end

  # External IPs should be denied
  describe command('curl -s -o /dev/null -w "%{http_code}" --resolve "external.example.com:80:127.0.0.1" http://external.example.com/server-status') do
    its('stdout') { should match /403/ } # Should be denied
  end

  # Test metrics endpoint if using external exporter
  describe command('curl -s -o /dev/null -w "%{http_code}" http://localhost:9117/metrics'), :if => !file("#{apache_modules_dir}/mod_prometheus_exporter.so").exist? do
    its('stdout') { should match /200/ }
  end

  # Test metrics endpoint if using built-in module
  describe command('curl -s -o /dev/null -w "%{http_code}" http://localhost/metrics'), :if => file("#{apache_modules_dir}/mod_prometheus_exporter.so").exist? do
    its('stdout') { should match /(200|403)/ } # Either accessible or properly secured
  end
end