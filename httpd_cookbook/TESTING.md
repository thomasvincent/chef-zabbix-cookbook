# Testing the httpd Cookbook

This cookbook includes a comprehensive test suite using ChefSpec for unit testing and Test Kitchen with Dokken (Docker) for integration testing.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Chef Workstation](https://downloads.chef.io/tools/workstation) (latest version recommended)
- [Docker](https://docs.docker.com/get-docker/) (required for Test Kitchen with kitchen-dokken)
- Ruby 3.1+

## Docker Setup

This cookbook uses Docker exclusively for testing via kitchen-dokken. Ensure Docker is properly installed and configured:

```bash
# Verify Docker installation
docker --version

# Ensure Docker daemon is running
docker info

# Give your user permissions (if needed)
sudo usermod -aG docker $USER
```

## Setting Up Your Test Environment

1. Clone the repository:
   ```
   git clone [repository_url]
   cd httpd_cookbook
   ```

2. Install dependencies:
   ```
   bundle install
   ```

3. Install required gems for Test Kitchen Docker support:
   ```
   chef gem install kitchen-dokken
   ```

## Running Unit Tests (ChefSpec)

ChefSpec tests verify the cookbook's functionality without requiring Docker containers:

```
chef exec rspec
```

### Running Specific Tests

To run specific tests:

```
chef exec rspec spec/unit/recipes/default_spec.rb
```

## Running Integration Tests (Test Kitchen with Docker)

Integration tests use Test Kitchen with Docker (via kitchen-dokken) to validate the cookbook functionality in containerized environments:

### List Available Test Suites

```
kitchen list
```

Output will show combinations of test suites and platforms:
```
Instance                      Driver   Provisioner  Verifier  Transport  Last Action    Last Error
default-ubuntu-2004           Dokken   Dokken       Inspec    Dokken     <Not Created>  <None>
default-ubuntu-2204           Dokken   Dokken       Inspec    Dokken     <Not Created>  <None>
default-debian-11             Dokken   Dokken       Inspec    Dokken     <Not Created>  <None>
default-centos-stream-8       Dokken   Dokken       Inspec    Dokken     <Not Created>  <None>
...
```

### Run All Tests (Not Recommended - Very Resource Intensive)

```
kitchen test
```

### Test a Specific Suite and Platform

```
kitchen test default-ubuntu-2004
```

### Recommended Testing Workflow (Step by Step)

Docker-based testing is fast and lightweight. Use this workflow for efficient testing:

```bash
# Create Docker container for a specific suite
kitchen create default-ubuntu-2004

# Converge (run Chef) on the container 
kitchen converge default-ubuntu-2004

# Run tests
kitchen verify default-ubuntu-2004

# Remove container when done
kitchen destroy default-ubuntu-2004
```

Or to do everything in one command:

```bash
kitchen test default-ubuntu-2004
```

## Docker Optimization

When using Docker for testing, keep these tips in mind:

1. **Caching**: Docker will cache layers, making subsequent test runs faster
2. **Parallel Testing**: You can run multiple instances in parallel with:
   ```
   kitchen test default-ubuntu-2004 & kitchen test default-centos-stream-8
   ```
3. **Resource Limits**: If Docker consumes too many resources:
   ```
   # Create a .kitchen.local.yml file:
   driver:
     name: dokken
     memory: 1024  # Limit to 1GB RAM per container
     cpus: 2       # Limit to 2 CPUs per container
   ```

## Test Suites

The cookbook includes comprehensive test coverage through the following test suites, all running in Docker containers:

1. **default**: Tests basic functionality with a default virtual host
2. **ssl**: Tests SSL/TLS configurations
3. **source**: Tests Apache installation from source
4. **prefork-mpm**: Tests using the prefork MPM instead of event
5. **multi-vhost**: Tests multiple virtual host configurations
6. **modules**: Tests module management functionality
7. **performance-tuning**: Tests performance tuning configurations

## CI Pipeline

This cookbook uses GitHub Actions for continuous integration testing with Docker containers. The workflow is defined in `.github/workflows/ci.yml` and includes:

1. Linting with Cookstyle
2. Unit testing with ChefSpec
3. Integration testing with Test Kitchen and Docker (via kitchen-dokken)

## Docker Troubleshooting

### Common Docker Issues

1. **Permission denied**:
   ```
   ERROR: Got permission denied while trying to connect to the Docker daemon socket
   ```
   Solution:
   ```
   sudo usermod -aG docker $USER
   ```
   Then log out and back in.

2. **Insufficient memory**:
   ```
   ERROR: failed to start containers: OCI runtime create failed: container_linux.go:345
   ```
   Solution: Increase Docker memory limit in Docker Desktop settings.

3. **Sync issues with systemd containers**:
   If tests fail due to systemd issues in containers, try:
   ```
   kitchen destroy
   docker system prune -a
   ```
   Then run tests again.

## Debugging Tests

For more detailed output during Docker test runs:

```
KITCHEN_LOG=debug kitchen verify
```

To inspect a running Docker container:

```
# Get container ID
docker ps

# Open a shell in the container
docker exec -it CONTAINER_ID /bin/bash
```