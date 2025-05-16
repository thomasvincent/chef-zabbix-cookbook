name 'httpd'
maintainer 'Thomas Vincent'
maintainer_email 'thomasvincent@example.com'
license 'Apache-2.0'
description 'Installs and configures Apache HTTP Server with advanced features'
version '1.0.0'
chef_version '>= 18.0'
source_url 'https://github.com/thomasvincent/httpd-cookbook'
issues_url 'https://github.com/thomasvincent/httpd-cookbook/issues'

supports 'ubuntu', '>= 20.04'
supports 'debian', '>= 11.0'
supports 'centos', '>= 8.0'
supports 'redhat', '>= 8.0'
supports 'amazon', '>= 2.0'
supports 'rocky', '>= 8.0'
supports 'alma', '>= 8.0'
supports 'fedora', '>= 35'
supports 'opensuse', '>= 15.0'
supports 'arch', '>= 1.0'

# We can handle our own firewall and logging
depends 'selinux', '~> 4.0' # Only required dependency for SELinux management
depends 'zypper', '~> 0.4', platform_family: 'suse' # Only for SUSE systems

# Suggesting (but not requiring) useful related cookbooks
suggests 'firewall', '~> 2.7'
suggests 'logrotate', '~> 3.0'
suggests 'chef-vault', '~> 4.1' # Modern secrets management
suggests 'audit', '~> 11.0' # For compliance phase integration