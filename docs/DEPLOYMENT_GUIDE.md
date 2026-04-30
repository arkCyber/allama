# allama Deployment Guide

## Overview

This guide provides instructions for deploying the allama project to a test environment with aerospace-level security features enabled.

## Prerequisites

### System Requirements

- **OS**: macOS, Linux (Ubuntu 20.04+), or Windows (with WSL2)
- **CPU**: ARM64 or x86_64 architecture
- **RAM**: Minimum 8GB, recommended 16GB+
- **Storage**: Minimum 10GB free space
- **GPU**: Optional (Metal on macOS, CUDA on Linux/Windows)

### Software Dependencies

- **CMake**: 3.20 or higher
- **C Compiler**: GCC 9+ or Clang 10+
- **C++ Compiler**: GCC 9+ or Clang 10+
- **OpenSSL**: 3.0 or higher
- **Python**: 3.8 or higher (optional, for some tests)
- **Git**: For version control

### Optional Dependencies

- **ccache**: For faster builds
- **NVIDIA CUDA Toolkit**: For GPU acceleration (Linux/Windows)
- **Metal Framework**: For GPU acceleration (macOS - included with Xcode)

## Build Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/llama-cpp-turboquant.git
cd llama-cpp-turboquant
```

### 2. Create Build Directory

```bash
mkdir build
cd build
```

### 3. Configure with CMake

#### Release Build (Production)

```bash
cmake .. -DCMAKE_BUILD_TYPE=Release
```

#### Debug Build (Development)

```bash
cmake .. -DCMAKE_BUILD_TYPE=Debug
```

#### With Sanitizers (Testing)

```bash
cmake .. -DCMAKE_BUILD_TYPE=Debug -DLLAMA_SANITIZE_ADDRESS=ON -DLLAMA_SANITIZE_UNDEFINED=ON
```

### 4. Build

```bash
make -j$(nproc)  # Linux
make -j$(sysctl -n hw.ncpu)  # macOS
```

## Deployment to Test Environment

### Option 1: Local Deployment

#### 1. Initialize Security Systems

The security systems are initialized automatically when the application starts. However, you can configure them via environment variables or configuration files.

#### 2. Configure Audit Logging

```bash
export ALLAMA_AUDIT_LOG_FILE="/var/log/allama/audit.log"
export ALLAMA_AUDIT_LOG_ROTATION=true
export ALLAMA_AUDIT_LOG_MAX_SIZE=1048576  # 1MB
```

#### 3. Configure Authentication

```bash
export ALLAMA_AUTH_ENABLED=true
export ALLAMA_AUTH_MAX_SESSIONS=1000
export ALLAMA_AUTH_SESSION_TIMEOUT=3600
```

#### 4. Configure Network Isolation

```bash
export ALLAMA_NETWORK_ISOLATION_MODE=local
export ALLAMA_NETWORK_BIND_ADDRESS="127.0.0.1"
export ALLAMA_NETWORK_BIND_PORT=8080
```

### Option 2: Docker Deployment

#### 1. Build Docker Image

```bash
docker build -t allama:latest .
```

#### 2. Run Container

```bash
docker run -d \
  --name allama-server \
  -p 8080:8080 \
  -v /var/log/allama:/var/log/allama \
  -v /data/models:/data/models \
  -e ALLAMA_AUTH_ENABLED=true \
  -e ALLAMA_NETWORK_ISOLATION_MODE=local \
  allama:latest
```

#### 3. Verify Deployment

```bash
docker logs allama-server
curl http://localhost:8080/health
```

### Option 3: Systemd Service (Linux)

#### 1. Create Service File

```bash
sudo nano /etc/systemd/system/allama.service
```

#### 2. Service Configuration

```ini
[Unit]
Description=allama Server with Aerospace Security
After=network.target

[Service]
Type=simple
User=allama
WorkingDirectory=/opt/allama
ExecStart=/opt/allama/build/bin/llama-server \
  --model /data/models/model.gguf \
  --port 8080 \
  --host 0.0.0.0
Restart=always
RestartSec=10

Environment="ALLAMA_AUTH_ENABLED=true"
Environment="ALLAMA_NETWORK_ISOLATION_MODE=local"
Environment="ALLAMA_AUDIT_LOG_FILE=/var/log/allama/audit.log"

[Install]
WantedBy=multi-user.target
```

#### 3. Enable and Start Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable allama
sudo systemctl start allama
sudo systemctl status allama
```

## Security Configuration

### Audit Logging

The audit logging system records all security-relevant events:

```c
// Initialize audit logging
audit_log_init("/var/log/allama/audit.log", true, 1048576);

// Log events
audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_API_REQUEST, 
               "API", "Request received", NULL, user_id, ip_address);
```

### Authentication

Configure API key authentication:

```c
auth_config_t config;
config.enabled = true;
config.default_method = AUTH_METHOD_API_KEY;
config.max_sessions = 1000;
config.session_timeout = 3600;
auth_init(&config);
```

### Network Isolation

Configure network isolation modes:

```c
network_isolation_config_t config;
config.mode = NETWORK_ISOLATION_LOCAL;
config.bind_address = "127.0.0.1";
config.bind_port = 8080;
network_isolation_init(&config);
```

### Resource Monitoring

Monitor system resources:

```c
monitor_config_t config;
config.update_interval_ms = 1000;
config.enable_alerts = true;
resource_monitor_init(&config);
```

## Integration Testing

### 1. Run Security Module Tests

```bash
cd build
./bin/test-security-modules
```

Expected output:
```
========================================
Allama Security Module Tests
Aerospace-Level Security Testing
========================================
Tests Passed: 52
Tests Failed: 0
Total Tests: 52
Success Rate: 100.0%
========================================
```

### 2. Run Security Audit Tests

```bash
./bin/test-security-audit
```

Expected output:
```
=== allama Security Audit Tests ===
Test 1: Buffer Overflow Prevention  PASS
Test 2: Memory Safety               PASS
Test 3: Input Validation            PASS
Test 4: Thread Safety Basic         PASS
Test 5: Error Handling              PASS
Test 6: Safe String Operations      PASS
Test 7: Resource Management         PASS
Test 8: Type Safety                 PASS
=== All Security Tests Passed ===
```

### 3. Run Full Test Suite

```bash
ctest -j$(nproc)
```

### 4. API Integration Test

```bash
# Start the server
./bin/llama-server --model /path/to/model.gguf --port 8080

# Test health endpoint
curl http://localhost:8080/health

# Test with authentication
curl -H "Authorization: Bearer allama_1234567890123456789012345678" \
     http://localhost:8080/v1/chat/completions
```

## Monitoring and Logging

### Audit Log Location

- Default: `/var/log/allama/audit.log`
- Format: JSON
- Rotation: Enabled by default

### Log Levels

- DEBUG: Detailed diagnostic information
- INFO: General informational messages
- WARNING: Warning messages
- ERROR: Error messages
- CRITICAL: Critical security events

### Monitoring Commands

```bash
# View audit logs in real-time
tail -f /var/log/allama/audit.log

# Search for security events
grep "AUDIT_EVENT_SECURITY_VIOLATION" /var/log/allama/audit.log

# Count events by type
grep "AUDIT_EVENT" /var/log/allama/audit.log | sort | uniq -c
```

## Troubleshooting

### Build Failures

**Issue**: Missing OpenSSL
```bash
# Ubuntu/Debian
sudo apt-get install libssl-dev

# macOS
brew install openssl
```

**Issue**: Missing Python
```bash
# Ubuntu/Debian
sudo apt-get install python3 python3-pip

# macOS
brew install python3
```

### Runtime Issues

**Issue**: Permission denied for audit log
```bash
sudo mkdir -p /var/log/allama
sudo chown $USER /var/log/allama
```

**Issue**: Port already in use
```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>
```

### Security Issues

**Issue**: Authentication failing
- Verify API key format (minimum 32 characters, starts with "allama_")
- Check audit logs for authentication events
- Ensure authentication system is initialized

**Issue**: Network isolation blocking connections
- Verify network isolation mode
- Check IP whitelist/blacklist configuration
- Review audit logs for connection attempts

## Performance Tuning

### Memory Optimization

```bash
# Reduce memory usage
export ALLAMA_SECURE_MEMORY_LOCKING=false
export ALLAMA_SECURE_MEMORY_ENCRYPTION=false
```

### CPU Optimization

```bash
# Use more threads
export OMP_NUM_THREADS=8
export LLAMA_NUM_THREADS=8
```

### GPU Optimization

```bash
# Enable GPU acceleration
export LLAMA_GPU_LAYERS=35
export LLAMA_CUDA_GRAPHS=1
```

## Security Best Practices

1. **Always use Release builds in production**
2. **Enable audit logging and monitor regularly**
3. **Use strong API keys (minimum 32 characters)**
4. **Configure network isolation for production**
5. **Regularly rotate API keys**
6. **Monitor resource usage and set alerts**
7. **Keep dependencies updated**
8. **Run security scans regularly**
9. **Enable rate limiting**
10. **Use TLS/SSL for all network communications**

## Compliance Checklist

### DO-178C (DAL D)

- [ ] Requirements traced to tests
- [ ] Code review completed
- [ ] Static analysis performed
- [ ] Unit testing completed
- [ ] Integration testing completed
- [ ] Safety requirements verified

### ISO 26262 (ASIL A)

- [ ] Hazard analysis completed
- [ ] Safety goals defined
- [ ] Safety requirements specified
- [ ] Safety architecture defined
- [ ] Safety implementation verified
- [ ] Functional safety assessment

### MISRA C

- [ ] Code follows MISRA C guidelines
- [ ] Static analysis configured
- [ ] Deviations documented
- [ ] Review process established

## Support

For issues or questions:
- GitHub Issues: https://github.com/your-org/llama-cpp-turboquant/issues
- Documentation: https://github.com/your-org/llama-cpp-turboquant/docs
- Security: security@your-org.com

## Appendix

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| ALLAMA_AUTH_ENABLED | Enable authentication | true |
| ALLAMA_AUTH_MAX_SESSIONS | Maximum sessions | 1000 |
| ALLAMA_AUTH_SESSION_TIMEOUT | Session timeout (seconds) | 3600 |
| ALLAMA_NETWORK_ISOLATION_MODE | Network mode | local |
| ALLAMA_NETWORK_BIND_ADDRESS | Bind address | 0.0.0.0 |
| ALLAMA_NETWORK_BIND_PORT | Bind port | 8080 |
| ALLAMA_AUDIT_LOG_FILE | Audit log path | /var/log/allama/audit.log |
| ALLAMA_AUDIT_LOG_ROTATION | Enable log rotation | true |
| ALLAMA_AUDIT_LOG_MAX_SIZE | Max log size (bytes) | 1048576 |

### Configuration Files

- `/etc/allama/config.yaml` - Main configuration
- `/etc/allama/auth.yaml` - Authentication configuration
- `/etc/allama/network.yaml` - Network configuration
- `/etc/allama/audit.yaml` - Audit logging configuration

### Ports

- 8080: Main API server
- 8081: Metrics/monitoring endpoint
- 8082: Health check endpoint

## Version History

- v1.0.0: Initial release with aerospace-level security
- v1.1.0: Added anomaly detection and backup systems
- v1.2.0: Enhanced network isolation and formal verification support
