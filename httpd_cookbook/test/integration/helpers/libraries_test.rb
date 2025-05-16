# InSpec test for httpd cookbook libraries

# These tests validate the functionality of the helper methods in the libraries

title 'Apache configuration values match system'

# Get system memory in MB for comparison
total_memory_kb = inspec.file('/proc/meminfo').content.match(/MemTotal:\s+(\d+)/)[1].to_i
total_memory_mb = total_memory_kb / 1024
cpu_count = command('nproc').stdout.strip.to_i

# Check the MaxRequestWorkers value is sensible for the system memory
control 'apache-max-request-workers' do
  impact 1.0
  title 'Apache MaxRequestWorkers is optimized for system memory'
  desc 'The MaxRequestWorkers setting should be optimized for system memory to prevent swapping'
  
  # A very basic check to ensure MaxRequestWorkers is proportional to system memory
  # Based on the algorithm in calculate_max_request_workers helper
  optimal_value = if total_memory_mb < 1024
                   [15, (total_memory_mb / 10).to_i].max
                 elsif total_memory_mb < 4096
                   [40, (total_memory_mb / 15).to_i].max
                 elsif total_memory_mb < 16384
                   [100, (total_memory_mb / 20).to_i].max
                 else
                   [250, (total_memory_mb / 40).to_i].max
                 end
  
  # Check MaxRequestWorkers in MPM config file
  if os.redhat?
    describe file('/etc/httpd/mpm.conf') do
      its('content') { should match /MaxRequestWorkers\s+\d+/ }
    end
    
    apache_config = command('grep MaxRequestWorkers /etc/httpd/mpm.conf').stdout
    max_workers = apache_config.match(/MaxRequestWorkers\s+(\d+)/)[1].to_i
  elsif os.debian?
    describe file('/etc/apache2/mods-enabled/mpm_event.conf') do
      its('content') { should match /MaxRequestWorkers\s+\d+/ }
    end
    
    apache_config = command('grep MaxRequestWorkers /etc/apache2/mods-enabled/mpm_event.conf').stdout
    max_workers = apache_config.match(/MaxRequestWorkers\s+(\d+)/)[1].to_i
  end
  
  # The configured value should be within 30% of our calculated optimal value
  # This allows for the fact that the tests are run in a constrained Docker environment
  describe max_workers do
    it { should be_within(optimal_value * 0.3).of(optimal_value) }
  end
  
  # Check memory usage per worker process
  apache_procs = command('ps aux | grep -v grep | grep -E "httpd|apache2" | wc -l').stdout.to_i
  
  # Ensure we have a reasonable number of worker processes based on system resources
  describe apache_procs do
    it { should be > 0 }
    it { should be <= (total_memory_mb / 50 + 5) } # Allow for a reasonable maximum
  end
end

# Check ThreadsPerChild is optimized for CPU count
control 'apache-threads-per-child' do
  impact 1.0
  title 'Apache ThreadsPerChild is optimized for CPU count'
  desc 'The ThreadsPerChild setting should be optimized for the number of CPU cores'
  
  # Calculate optimal ThreadsPerChild based on CPU count
  optimal_value = if cpu_count <= 2
                    [8, cpu_count * 4].min
                  elsif cpu_count <= 4
                    [16, cpu_count * 4].min
                  elsif cpu_count <= 8
                    25
                  else
                    [50, cpu_count * 6].min
                  end
  
  # Check ThreadsPerChild in MPM config file
  if os.redhat?
    describe file('/etc/httpd/mpm.conf') do
      its('content') { should match /ThreadsPerChild\s+\d+/ }
    end
    
    apache_config = command('grep ThreadsPerChild /etc/httpd/mpm.conf').stdout
    threads_per_child = apache_config.match(/ThreadsPerChild\s+(\d+)/)[1].to_i
  elsif os.debian?
    describe file('/etc/apache2/mods-enabled/mpm_event.conf') do
      its('content') { should match /ThreadsPerChild\s+\d+/ }
    end
    
    apache_config = command('grep ThreadsPerChild /etc/apache2/mods-enabled/mpm_event.conf').stdout
    threads_per_child = apache_config.match(/ThreadsPerChild\s+(\d+)/)[1].to_i
  end
  
  # The configured value should be within 30% of our calculated optimal value
  describe threads_per_child do
    it { should be_within(optimal_value * 0.3).of(optimal_value) }
  end
end

# Check ServerLimit calculation based on max_request_workers and threads_per_child
control 'apache-server-limit' do
  impact 1.0
  title 'Apache ServerLimit is correctly calculated'
  desc 'The ServerLimit setting should be correctly calculated based on MaxRequestWorkers and ThreadsPerChild'
  
  # Get MaxRequestWorkers and ThreadsPerChild
  if os.redhat?
    apache_config = command('grep -E "MaxRequestWorkers|ThreadsPerChild|ServerLimit" /etc/httpd/mpm.conf').stdout
    max_workers = apache_config.match(/MaxRequestWorkers\s+(\d+)/)[1].to_i
    threads_per_child = apache_config.match(/ThreadsPerChild\s+(\d+)/)[1].to_i
    server_limit = apache_config.match(/ServerLimit\s+(\d+)/)[1].to_i
  elsif os.debian?
    apache_config = command('grep -E "MaxRequestWorkers|ThreadsPerChild|ServerLimit" /etc/apache2/mods-enabled/mpm_event.conf').stdout
    max_workers = apache_config.match(/MaxRequestWorkers\s+(\d+)/)[1].to_i
    threads_per_child = apache_config.match(/ThreadsPerChild\s+(\d+)/)[1].to_i
    server_limit = apache_config.match(/ServerLimit\s+(\d+)/)[1].to_i
  end
  
  # Calculate optimal ServerLimit
  optimal_value = ((max_workers / threads_per_child.to_f) * 1.1).ceil
  
  # The configured value should match our calculation
  describe server_limit do
    it { should be_within(1).of(optimal_value) }
  end
end