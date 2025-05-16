require 'chefspec'
require 'chefspec/berkshelf'
require 'simplecov'

# Start SimpleCov
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  add_group 'Libraries', 'libraries'
  add_group 'Resources', 'resources'
  add_group 'Recipes', 'recipes'
end

RSpec.configure do |config|
  # Specify the Chef log_level (default: :warn)
  config.log_level = :error

  # Specify the operating platform to mock Ohai data from (default: nil)
  config.platform = 'ubuntu'

  # Specify the operating version to mock Ohai data from (default: nil)
  config.version = '20.04'
  
  # Use color in STDOUT
  config.color = true

  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :json, :junit, :progress, :documentation

  # Run all examples within a transaction
  config.around(:each) do |example|
    # Only use a transaction if we have a database
    Chefspec::SoloRunner.cleanup_after_run!
    example.run
  end
end

# Mock the Chef::Platform method default_provider to use httpd_service, httpd_config, httpd_module, etc.
# This is needed for proper resource collection testing with ChefSpec
include ChefSpec::API

def stub_resources
  allow_any_instance_of(Chef::ResourceCollection).to receive(:find).and_call_original
  allow_any_instance_of(Chef::ResourceCollection).to receive(:find).with('template[/etc/httpd/conf/httpd.conf]').and_return(
    Chef::Resource::Template.new('/etc/httpd/conf/httpd.conf', run_context).tap do |r|
      r.source 'httpd.conf.erb'
      r.cookbook 'httpd'
    end
  )
end