# frozen_string_literal: true

module Httpd
  module VaultHelpers
    # Chef 18+ style vault integration - uses native Chef methods rather than 
    # requiring the chef-vault gem to be loaded

    # Get a value from Chef Vault with proper error handling
    # @param bag [String] The name of the vault bag
    # @param item [String] The name of the vault item
    # @param key [String] The key to retrieve from the vault
    # @param default_value [Object] The default value to return if the key is not found
    # @return [Object] The value from the vault or the default value
    def get_vault_data(bag, item, key = nil, default_value = nil)
      require 'chef/encrypted_data_bag_item'
      
      begin
        # Use Chef::EncryptedDataBagItem which is built-in to Chef
        vault_item = Chef::EncryptedDataBagItem.load(bag, item)
        return key ? vault_item[key] || default_value : vault_item
      rescue => e
        Chef::Log.warn("Failed to load vault data for #{bag}/#{item}: #{e.message}")
        key ? default_value : {}
      end
    end

    # Check if Chef Vault is available
    # @return [Boolean] True if Chef Vault is available
    def vault_available?
      begin
        require 'chef/encrypted_data_bag_item'
        true
      rescue LoadError
        false
      end
    end

    # Get SSL certificate data from vault
    # @param name [String] The name of the certificate
    # @return [Hash] A hash containing certificate, key, and chain information
    def ssl_data_from_vault(name)
      return nil unless vault_available?
      
      ssl_item = get_vault_data('ssl_certificates', name)
      return nil if ssl_item.empty?
      
      {
        'certificate' => ssl_item['cert'],
        'key' => ssl_item['key'],
        'chain' => ssl_item['chain']
      }
    end

    # Write SSL certificate files from vault data
    # @param name [String] The name of the certificate
    # @param cert_path [String] The path to write the certificate
    # @param key_path [String] The path to write the key
    # @param chain_path [String] The path to write the chain
    # @return [Boolean] True if successful, false otherwise
    def write_ssl_files_from_vault(name, cert_path, key_path, chain_path = nil)
      ssl_data = ssl_data_from_vault(name)
      return false unless ssl_data
      
      # Write certificate file
      file cert_path do
        content ssl_data['certificate']
        owner 'root'
        group 'root'
        mode '0644'
        sensitive true
        action :create
      end
      
      # Write key file
      file key_path do
        content ssl_data['key']
        owner 'root'
        group node['httpd']['config']['group'] # Allow Apache to read it
        mode '0640'
        sensitive true
        action :create
      end
      
      # Write chain file if provided
      if chain_path && ssl_data['chain']
        file chain_path do
          content ssl_data['chain']
          owner 'root'
          group 'root'
          mode '0644'
          sensitive true
          action :create
        end
      end
      
      true
    end
  end
end

Chef::DSL::Recipe.include(Httpd::VaultHelpers)
Chef::Resource.include(Httpd::VaultHelpers)