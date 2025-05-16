require 'spec_helper'
require_relative '../../../libraries/yaml_processor'

describe Httpd::YAMLProcessor do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '20.04')
  end
  
  let(:subject) { Object.new.extend(Httpd::YAMLProcessor) }
  
  before do
    allow(subject).to receive(:node).and_return(chef_run.node)
  end
  
  describe '#yaml_to_apache_config' do
    it 'converts server configuration correctly' do
      yaml_config = {
        'server' => {
          'root' => '/etc/httpd',
          'name' => 'example.com',
          'admin' => 'webmaster@example.com',
          'timeout' => 300,
          'keep_alive' => 'On',
          'keep_alive_timeout' => 5,
          'keep_alive_requests' => 100,
          'user' => 'apache',
          'group' => 'apache'
        }
      }
      
      result = subject.yaml_to_apache_config(yaml_config)
      
      expect(result).to include('ServerRoot "/etc/httpd"')
      expect(result).to include('ServerName example.com')
      expect(result).to include('ServerAdmin webmaster@example.com')
      expect(result).to include('Timeout 300')
      expect(result).to include('KeepAlive On')
      expect(result).to include('KeepAliveTimeout 5')
      expect(result).to include('MaxKeepAliveRequests 100')
      expect(result).to include('User apache')
      expect(result).to include('Group apache')
    end
    
    it 'converts listen directives correctly' do
      yaml_config = {
        'listen' => [
          '*:80',
          '*:443'
        ]
      }
      
      result = subject.yaml_to_apache_config(yaml_config)
      
      expect(result).to include('Listen *:80')
      expect(result).to include('Listen *:443')
    end
    
    it 'converts module configuration correctly' do
      yaml_config = {
        'modules' => [
          'ssl',
          'rewrite',
          'proxy'
        ]
      }
      
      result = subject.yaml_to_apache_config(yaml_config)
      
      expect(result).to include('LoadModule ssl_module /usr/lib/apache2/modules/mod_ssl.so')
      expect(result).to include('LoadModule rewrite_module /usr/lib/apache2/modules/mod_rewrite.so')
      expect(result).to include('LoadModule proxy_module /usr/lib/apache2/modules/mod_proxy.so')
    end
    
    it 'converts MPM configuration correctly' do
      yaml_config = {
        'mpm' => {
          'type' => 'event',
          'server_limit' => 16,
          'max_request_workers' => 400,
          'threads_per_child' => 25,
          'max_connections_per_child' => 0
        }
      }
      
      result = subject.yaml_to_apache_config(yaml_config)
      
      expect(result).to include('<IfModule event_module>')
      expect(result).to include('  ServerLimit 16')
      expect(result).to include('  MaxRequestWorkers 400')
      expect(result).to include('  ThreadsPerChild 25')
      expect(result).to include('  MaxConnectionsPerChild 0')
      expect(result).to include('</IfModule>')
    end
    
    it 'converts logging configuration correctly' do
      yaml_config = {
        'logs' => {
          'level' => 'warn',
          'error_log' => '/var/log/httpd/error_log',
          'access_log' => '/var/log/httpd/access_log',
          'formats' => {
            'combined' => '%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"',
            'common' => '%h %l %u %t \"%r\" %>s %b'
          }
        }
      }
      
      result = subject.yaml_to_apache_config(yaml_config)
      
      expect(result).to include('LogLevel warn')
      expect(result).to include('ErrorLog "/var/log/httpd/error_log"')
      expect(result).to include('LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined')
      expect(result).to include('LogFormat "%h %l %u %t \"%r\" %>s %b" common')
      expect(result).to include('CustomLog "/var/log/httpd/access_log" combined')
    end
    
    it 'converts directory configuration correctly' do
      yaml_config = {
        'directories' => [
          {
            'path' => '/var/www/html',
            'options' => 'FollowSymLinks',
            'allow_override' => 'None',
            'require' => 'all granted'
          },
          {
            'path' => '/var/www/restricted',
            'options' => 'None',
            'allow_override' => 'None',
            'require' => 'all denied'
          }
        ]
      }
      
      result = subject.yaml_to_apache_config(yaml_config)
      
      expect(result).to include('<Directory "/var/www/html">')
      expect(result).to include('  Options FollowSymLinks')
      expect(result).to include('  AllowOverride None')
      expect(result).to include('  Require all granted')
      expect(result).to include('</Directory>')
      
      expect(result).to include('<Directory "/var/www/restricted">')
      expect(result).to include('  Options None')
      expect(result).to include('  AllowOverride None')
      expect(result).to include('  Require all denied')
      expect(result).to include('</Directory>')
    end
    
    it 'converts security configuration correctly' do
      yaml_config = {
        'security' => {
          'server_tokens' => 'Prod',
          'server_signature' => 'Off',
          'trace_enable' => 'Off'
        }
      }
      
      result = subject.yaml_to_apache_config(yaml_config)
      
      expect(result).to include('ServerTokens Prod')
      expect(result).to include('ServerSignature Off')
      expect(result).to include('TraceEnable Off')
    end
    
    it 'converts HTTP/2 configuration correctly' do
      yaml_config = {
        'http2' => {
          'enabled' => true
        }
      }
      
      result = subject.yaml_to_apache_config(yaml_config)
      
      expect(result).to include('Protocols h2 http/1.1')
    end
    
    it 'converts SSL configuration correctly' do
      yaml_config = {
        'ssl' => {
          'enabled' => true,
          'port' => 443,
          'protocol' => 'all -SSLv3 -TLSv1 -TLSv1.1',
          'cipher_suite' => 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384',
          'honor_cipher_order' => 'on',
          'certificate' => '/etc/pki/tls/certs/localhost.crt',
          'certificate_key' => '/etc/pki/tls/private/localhost.key',
          'certificate_chain' => '/etc/pki/tls/certs/chain.crt',
          'hsts' => {
            'enabled' => true,
            'max_age' => 31536000,
            'include_subdomains' => true,
            'preload' => true
          }
        }
      }
      
      result = subject.yaml_to_apache_config(yaml_config)
      
      expect(result).to include('<VirtualHost *:443>')
      expect(result).to include('  SSLEngine on')
      expect(result).to include('  SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1')
      expect(result).to include('  SSLCipherSuite ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384')
      expect(result).to include('  SSLHonorCipherOrder on')
      expect(result).to include('  SSLCertificateFile /etc/pki/tls/certs/localhost.crt')
      expect(result).to include('  SSLCertificateKeyFile /etc/pki/tls/private/localhost.key')
      expect(result).to include('  SSLCertificateChainFile /etc/pki/tls/certs/chain.crt')
      expect(result).to include('  Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"')
      expect(result).to include('</VirtualHost>')
    end
    
    it 'converts additional configuration correctly' do
      yaml_config = {
        'additional_config' => {
          'MaxClients' => 150,
          '<Location "/server-status">' => {
            'SetHandler' => 'server-status',
            'Require' => 'local'
          }
        }
      }
      
      result = subject.yaml_to_apache_config(yaml_config)
      
      expect(result).to include('MaxClients 150')
      expect(result).to include('<Location "/server-status">')
      expect(result).to include('  SetHandler server-status')
      expect(result).to include('  Require local')
      expect(result).to include('</Location>')
    end
  end
end