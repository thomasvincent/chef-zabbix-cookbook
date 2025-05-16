# frozen_string_literal: true

module Httpd
  module ResourceHelpers
    # Find a resource in the resource collection by name and type
    # @param resource_type [String] The resource type
    # @param resource_name [String] The resource name
    # @return [Chef::Resource] The resource or nil if not found
    def find_resource(resource_type, resource_name)
      begin
        resources(resource_type => resource_name)
      rescue Chef::Exceptions::ResourceNotFound
        nil
      end
    end

    # Find or create a resource in the resource collection
    # @param resource_type [String] The resource type
    # @param resource_name [String] The resource name
    # @param run_context [Chef::RunContext] The run context (optional)
    # @return [Chef::Resource] The resource
    def find_or_create_resource(resource_type, resource_name, run_context = nil)
      run_context ||= self.run_context
      
      begin
        resources(resource_type => resource_name)
      rescue Chef::Exceptions::ResourceNotFound
        # Use declare_resource to create the resource
        declare_resource(resource_type, resource_name)
      end
    end

    # Execute a block with a modified resource
    # @param resource_type [String] The resource type
    # @param resource_name [String] The resource name
    # @param block [Proc] The block to execute
    # @return [Chef::Resource] The resource
    def with_resource(resource_type, resource_name, &block)
      resource = find_resource(resource_type, resource_name)
      if resource
        # Execute the block with the resource
        block.call(resource) if block_given?
      end
      resource
    end

    # Find or create a template resource
    # @param path [String] The template path
    # @param options [Hash] The template options
    # @return [Chef::Resource] The template resource
    def get_template_resource(path, options = {})
      find_or_create_resource(:template, path).tap do |template|
        template.cookbook options[:cookbook] if options[:cookbook]
        template.source options[:source] if options[:source]
        template.variables options[:variables] if options[:variables]
        template.owner options[:owner] || 'root'
        template.group options[:group] || 'root'
        template.mode options[:mode] || '0644'
        template.notifies(*options[:notifies]) if options[:notifies]
        template.action options[:action] || :create
      end
    end

    # Find or create a directory resource
    # @param path [String] The directory path
    # @param options [Hash] The directory options
    # @return [Chef::Resource] The directory resource
    def get_directory_resource(path, options = {})
      find_or_create_resource(:directory, path).tap do |directory|
        directory.owner options[:owner] || 'root'
        directory.group options[:group] || 'root'
        directory.mode options[:mode] || '0755'
        directory.recursive options[:recursive].nil? ? true : options[:recursive]
        directory.notifies(*options[:notifies]) if options[:notifies]
        directory.action options[:action] || :create
      end
    end

    # Find or create a file resource
    # @param path [String] The file path
    # @param options [Hash] The file options
    # @return [Chef::Resource] The file resource
    def get_file_resource(path, options = {})
      find_or_create_resource(:file, path).tap do |file|
        file.content options[:content] if options[:content]
        file.owner options[:owner] || 'root'
        file.group options[:group] || 'root'
        file.mode options[:mode] || '0644'
        file.sensitive options[:sensitive] unless options[:sensitive].nil?
        file.notifies(*options[:notifies]) if options[:notifies]
        file.action options[:action] || :create
      end
    end

    # Create multiple resources of the same type
    # @param resource_type [Symbol] The resource type
    # @param resources_hash [Hash] The resources to create
    # @param default_options [Hash] Default options for all resources
    # @return [Array<Chef::Resource>] The created resources
    def create_resources(resource_type, resources_hash, default_options = {})
      resources_hash.map do |resource_name, resource_options|
        options = default_options.merge(resource_options)
        find_or_create_resource(resource_type, resource_name).tap do |resource|
          options.each do |property, value|
            # Skip name since it's already set
            next if property.to_sym == :name
            resource.send(property, value) if resource.respond_to?(property)
          end
        end
      end
    end
  end
end

Chef::DSL::Recipe.include(Httpd::ResourceHelpers)
Chef::Resource.include(Httpd::ResourceHelpers)