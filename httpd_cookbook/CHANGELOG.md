# httpd Cookbook CHANGELOG

This file is used to list changes made in each version of the httpd cookbook.

## 1.1.0 (Unreleased)

### Added
- Zero Downtime Deployment pattern with graceful reloads and health checks
- Ops Actions pattern for backup/restore and blue-green deployments
- Telemetry integration with Prometheus and Grafana
- Apache Prometheus Exporter configuration (both built-in and external)
- Grafana dashboard template for Apache metrics
- Library methods for integrating Apache with monitoring systems
- Comprehensive test coverage for telemetry functions

## 1.0.0 (2025-05-16)

### Added
- Initial release of httpd cookbook
- Complete Apache HTTP Server management with custom resources
- Support for multiple platforms (RHEL/CentOS, Debian/Ubuntu, Amazon Linux)
- Comprehensive configuration options with performance tuning
- SSL/TLS support with modern cipher configurations
- Virtual host management
- Module management
- Advanced security features
- Health check endpoints
- Monitoring configuration
- SELinux and AppArmor support
- Firewall configuration
- Logrotate integration
- Helper library for optimal configuration based on system resources