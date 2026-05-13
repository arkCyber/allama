# Allama User Manual

## Table of Contents
1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Service Management](#service-management)
4. [Model Management](#model-management)
5. [Server Operations](#server-operations)
6. [Unified AI Interface](#unified-ai-interface)
7. [Authentication](#authentication)
8. [Billing](#billing)
9. [Advanced Features](#advanced-features)
10. [Performance Optimization](#performance-optimization)
11. [Memory Optimization & Context Window Configuration](#memory-optimization--context-window-configuration)
12. [Best Practices](#best-practices)
13. [Security Guidelines](#security-guidelines)
14. [Integration Examples](#integration-examples)
15. [Monitoring & Alerting](#monitoring--alerting)
16. [Troubleshooting](#troubleshooting)

## Installation

### Prerequisites
- **Windows**: Windows 10 or later
- **macOS**: macOS 10.15 (Catalina) or later
- **Linux**: Most modern distributions (Ubuntu, Debian, Fedora, etc.)

### Installation Methods

#### Method 1: Pre-built Binary (Recommended)

```bash
# Install using automatic installer
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash

# Install specific version
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash -s v1.0.0

# Install to custom directory
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash -s latest /opt/allama
```

#### Method 2: Package Installer

**macOS:**
```bash
# Download .dmg from GitHub Releases
# Double-click and drag Allama.app to Applications
```

**Windows:**
```bash
# Download .exe from GitHub Releases
# Run installer and follow wizard
```

**Linux (Debian/Ubuntu):**
```bash
sudo dpkg -i allama_*_amd64.deb
sudo apt-get install -f
```

#### Method 3: Build from Source

```bash
git clone https://github.com/arkCyber/allama.git
cd allama
cargo build --release
sudo cp target/release/allama /usr/local/bin/
```

### Verification

```bash
allama version
# Expected output: allama 1.0.0
```

## Configuration

### Configuration File Location
- **Linux/macOS**: `~/.allama/config.json`
- **Windows**: `%APPDATA%\allama\config.json`

### Configuration Options

```json
{
  "cache": {
    "enabled": true,
    "max_entries": 1000,
    "default_ttl_secs": 3600,
    "eviction_strategy": "LRU",
    "max_size_bytes": 10737418240
  },
  "discovery": {
    "enable_huggingface": true,
    "enable_ollama": true,
    "enable_local": true,
    "local_paths": ["~/.cache/huggingface", "~/.ollama/models"]
  },
  "filter": {
    "max_file_size": 107374182400,
    "min_file_size": 1048576,
    "allowed_types": ["text_generation", "image_generation", "audio"]
  },
  "audit": {
    "enabled": true,
    "log_path": "~/.allama/audit.log",
    "max_size_bytes": 104857600,
    "rotation": "daily"
  },
  "moe": {
    "enabled": false,
    "gpu_split_ratio": 0.7,
    "min_vram_mb": 4096,
    "layer_offloading": true
  },
  "enable_hot_reload": false
}
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OLLAMA_HOST` | Server host | `127.0.0.1` |
| `OLLAMA_NUM_PARALLEL` | Parallel requests | `1` |
| `OLLAMA_MAX_LOADED_MODELS` | Max loaded models | `3` |
| `OLLAMA_MAX_QUEUE` | Max queue size | `512` |
| `RUST_LOG` | Logging level (error, warn, info, debug, trace) | `info` |
| `ALLAMA_CONFIG_PATH` | Custom config file path | `~/.allama/config.json` |

### Advanced Configuration

#### Cache Configuration Details

```json
{
  "cache": {
    "enabled": true,
    "max_entries": 1000,
    "default_ttl_secs": 3600,
    "eviction_strategy": "LRU",
    "max_size_bytes": 10737418240,
    "enable_size_limit": true,
    "enable_persistence": false,
    "persistence_path": "~/.allama/cache.db"
  }
}
```

**Cache Configuration Options:**
- `enabled`: Enable/disable response caching
- `max_entries`: Maximum number of cached entries
- `default_ttl_secs`: Default time-to-live in seconds
- `eviction_strategy`: LRU, LFU, or FIFO
- `max_size_bytes`: Maximum cache size in bytes (10GB default)
- `enable_size_limit`: Enable size-based eviction
- `enable_persistence`: Persist cache to disk
- `persistence_path`: Path to cache database

#### Discovery Configuration Details

```json
{
  "discovery": {
    "enable_huggingface": true,
    "enable_ollama": true,
    "enable_local": true,
    "local_paths": [
      "~/.cache/huggingface",
      "~/.ollama/models",
      "/opt/models"
    ],
    "scan_depth": 3,
    "follow_symlinks": false
  }
}
```

**Discovery Configuration Options:**
- `enable_huggingface`: Scan Hugging Face cache directory
- `enable_ollama`: Scan Ollama models directory
- `enable_local`: Scan custom local paths
- `local_paths`: List of directories to scan
- `scan_depth`: Directory scan depth (default: 3)
- `follow_symlinks`: Follow symbolic links

#### Filter Configuration Details

```json
{
  "filter": {
    "max_file_size": 107374182400,
    "min_file_size": 1048576,
    "allowed_types": ["text_generation", "image_generation", "audio"],
    "blocked_patterns": ["test", "experimental"],
    "require_quantization": false,
    "min_parameters": 1000000000
  }
}
```

**Filter Configuration Options:**
- `max_file_size`: Maximum model file size (100GB default)
- `min_file_size`: Minimum model file size (1MB default)
- `allowed_types`: Allowed model types
- `blocked_patterns`: Patterns to block in model names
- `require_quantization`: Require quantized models
- `min_parameters`: Minimum parameter count

#### MOE Configuration Details

```json
{
  "moe": {
    "enabled": false,
    "gpu_split_ratio": 0.7,
    "min_vram_mb": 4096,
    "layer_offloading": true,
    "offload_threshold_mb": 2048,
    "compute_threshold": 0.5,
    "routing_strategy": "load_balanced"
  }
}
```

**MOE Configuration Options:**
- `enabled`: Enable Mixture of Experts
- `gpu_split_ratio`: GPU/CPU split ratio (0.0-1.0)
- `min_vram_mb`: Minimum VRAM required for GPU (4GB default)
- `layer_offloading`: Enable dynamic layer offloading
- `offload_threshold_mb`: VRAM threshold for offloading
- `compute_threshold`: Compute intensity threshold (0.0-1.0)
- `routing_strategy`: load_balanced, compute_based, or mru

## Service Management

### Starting the Service

```bash
# Start as foreground process
allama serve

# Start with custom configuration
allama serve --host 0.0.0.0 --port 8080 --parallel 4

# Start as background service
allama start
```

### Stopping the Service

```bash
# Stop background service
allama stop

# Or send SIGTERM to the process
kill -TERM $(pgrep allama)
```

### Checking Status

```bash
allama status

# Expected output:
# Status: running
# PID: 12345
# Port: 11435
# Uptime: 1h23m
```

### Auto-start Configuration

**Linux (systemd):**
```bash
sudo systemctl enable allama
sudo systemctl start allama
```

**macOS (launchd):**
```bash
allama start  # Automatically creates launchd agent
```

**Windows (Service):**
```bash
# Service is installed by the .exe installer
# Configure via Services.msc
```

## Model Management

### Listing Models

```bash
# List all available models
allama list

# List with details
allama list --verbose
```

### Downloading Models

```bash
# Download a model
allama pull llama3

# Download specific tag
allama pull llama3:8b

# Download from custom registry
allama pull myregistry.com/model:tag
```

### Running Models

```bash
# Run interactively
allama run llama3

# Run with prompt
allama run llama3 --prompt "Hello, world!"

# Generate embeddings
allama run llama3 --embeddings
```

### Model Information

```bash
# Show model details
allama show llama3

# Show model architecture
allama show llama3 --architecture
```

### Removing Models

```bash
# Remove a model
allama rm llama3

# Force removal
allama rm llama3 --force
```

### Managing Running Models

```bash
# List running models
allama ps

# Stop a running model
allama stop llama3
```

### Custom Models

```bash
# Create from Modelfile
allama create mymodel --from Modelfile

# Copy a model
allama cp llama3 myllama3

# Push to registry
allama push mymodel
```

### Importing Models from Ollama

If you have Ollama installed and want to use your existing models with Allama, you can import them:

```bash
# Run the import script
./scripts/import-from-ollama.sh
```

The script will:
1. Detect your Ollama installation
2. List all available models
3. Ask whether to import specific models or all models
4. Copy model manifests and blob files to Allama's models directory

**Manual Import:**
```bash
# Import a specific model
./scripts/import-from-ollama.sh
# Select option 1 and enter model name

# Import all models
./scripts/import-from-ollama.sh
# Select option 2
```

**Model Discovery Alternative:**

Allama can also discover models from your Ollama installation without copying them:

```json
{
  "discovery": {
    "enable_ollama": true
  }
}
```

With discovery enabled, Allama will automatically scan `~/.ollama/models` and make those models available.

## Server Operations

### Starting the Server

```bash
# Basic start (auto-allocate port)
allama serve

# Custom host and port
allama serve --host 0.0.0.0 --port 8080

# With parallel workers
allama serve --parallel 4

# With model limits
allama serve --max-loaded-models 5 --max-queue 1024
```

### Server Configuration

The server automatically:
- Creates a default test user with API key
- Allocates port if port=0
- Detects and uses available GPU
- Applies rate limiting and quotas
- Logs all operations to audit log

### OpenAI-Compatible API

```bash
# Chat completions
curl -X POST http://localhost:11435/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -d '{
    "model": "llama3",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Text completions
curl -X POST http://localhost:11435/v1/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -d '{
    "model": "llama3",
    "prompt": "Hello, world!"
  }'

# Embeddings
curl -X POST http://localhost:11435/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -d '{
    "model": "llama3",
    "input": "Hello, world!"
  }'
```

### Ollama-Compatible API

```bash
# Generate text
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","prompt":"Hello, world!","stream":false}'

# Chat
curl -X POST http://localhost:11435/api/chat \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","messages":[{"role":"user","content":"Hello!"}],"stream":false}'

# List models
curl http://localhost:11435/api/tags
```

## Unified AI Interface

Allama serve now provides a **unified AI interface** on port 11435 that automatically routes requests to the appropriate backend service.

### Architecture

```
User Request → allama serve (11435) → Model Router → Backend Service
                                                        ↓
┌───────────────────────────────────────────────────────┐
│                                                       │
│  gemma4-26b → llama-server (port 8082)              │
│  Other models → Internal inference engine             │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### Model Routing Rules

| Model Pattern | Backend | Port | API Format |
|---------------|---------|------|------------|
| gemma4-26b, gemma-4-26b | llama-server | 8082 | OpenAI-compatible |
| Other models | Internal inference | - | Internal |

### Quick Start

```bash
# 1. Build allama
cargo build --bin allama

# 2. Build llama-server
cd build && cmake .. && make -j$(nproc)

# 3. Start llama-server for Gemma4 26B (port 8082)
./bin/llama-server \
  -m /path/to/gemma-4-26b.gguf \
  -c 98304 \
  --port 8082 \
  -t 8 \
  --gpu-layers 0 \
  --cache-type-k f16 \
  --cache-type-v f16

# 4. Start allama serve (unified interface - port 11435)
./target/debug/allama serve --port 11435

# 5. Use unified API
curl -X POST http://127.0.0.1:11435/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -d '{"model":"gemma4-26b","messages":[{"role":"user","content":"Hello"}]}'
```

### Benefits

- **Single Endpoint**: All models accessible through one port (11435)
- **Transparent Routing**: Automatic backend selection based on model name
- **No Complexity**: Users don't need to know which service handles which model
- **Ollama Compatible**: Maintains Ollama API compatibility

### Example Usage

```bash
# All requests go through the same endpoint (11435)
curl -X POST http://127.0.0.1:11435/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -d '{"model":"gemma4-26b","messages":[{"role":"user","content":"Hello"}]}'

curl -X POST http://127.0.0.1:11435/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -d '{"model":"llama3","messages":[{"role":"user","content":"Hello"}]}'
```

### Configuration

The model routing is configured in `src/server/mod.rs`:

```rust
const MODEL_ROUTES: &[(&str, ModelBackend)] = &[
    ("gemma4-26b", ModelBackend {
        backend_type: BackendType::LlamaServer,
        endpoint: "http://127.0.0.1:8082",
    }),
    ("gemma-4-26b", ModelBackend {
        backend_type: BackendType::LlamaServer,
        endpoint: "http://127.0.0.1:8082",
    }),
];
```

To add new model routes, modify this configuration and rebuild the binary.

### Troubleshooting

**Issue**: Request fails with "502 Bad Gateway"
- **Cause**: Backend service (llama-server) is not running
- **Solution**: Ensure llama-server is running on the configured port

**Issue**: Model not recognized
- **Cause**: Model name doesn't match routing pattern
- **Solution**: Check MODEL_ROUTES configuration and model name

**Issue**: Slow response times
- **Cause**: Network latency between services
- **Solution**: Ensure allama serve and backend services are on the same machine

### Chain-of-thought (`thinking`)

For `POST /api/generate` and `POST /api/chat`, JSON responses may include an optional field **`thinking`**. It contains merged internal-reasoning segments when the raw model output used supported XML-style tag pairs; those segments are stripped from `response` / `message.content`. Implementation: `src/inference/thinking.rs`.

**Examples (with unit tests, no server required):**

- `examples/thinking_split_app.rs` — build chat-shaped JSON (`message` + optional `thinking`).
- `examples/thinking_generate_response.rs` — build generate-shaped JSON (`response` + optional `thinking`) and demonstrate post-stream finalization.

```bash
cd allama
cargo test --example thinking_split_app --features inference
cargo test --example thinking_generate_response --features inference
```

## Authentication

### Creating Users

```bash
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{
    "username": "myuser",
    "email": "user@example.com",
    "rate_limit": 60,
    "monthly_quota": 1000000
  }'
```

Response:
```json
{
  "user_id": "user_1234567890",
  "username": "myuser",
  "email": "user@example.com",
  "api_key": "allama_abcdefghijklmnopqrstuvwxyz123456",
  "rate_limit": 60,
  "monthly_quota": 1000000,
  "created_at": "2026-05-05T00:00:00Z"
}
```

### Using API Keys

```bash
# Remote requests require API key
curl -X POST http://your-server:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"Hello, world!","stream":false}'
```

### Authentication Strategy

- **Local Requests** (127.0.0.1, ::1, localhost): No authentication required
- **Remote Requests**: Require `Authorization: Bearer <api_key>` header
- **Detection**: Uses `X-Forwarded-For` or `X-Real-IP` headers

### Default Test User

The server creates a default test user on first start:
- **Username**: `test_user`
- **API Key**: Displayed on startup
- **Rate Limit**: 60 requests/minute
- **Monthly Quota**: 100,000 tokens

## Billing

### Querying Usage Records

```bash
curl -X GET "http://localhost:11435/api/billing/records?limit=10" \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

### Billing Summary

```bash
curl -X GET http://localhost:11435/api/billing/summary \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

Response:
```json
{
  "total_records": 1000,
  "total_tokens": 5000000,
  "total_prompt_tokens": 3000000,
  "total_completion_tokens": 2000000,
  "unique_models": 5,
  "period_start": "2026-05-01T00:00:00Z",
  "period_end": "2026-05-05T00:00:00Z"
}
```

### Model Statistics

```bash
curl -X GET http://localhost:11435/api/billing/stats/llama3 \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

## Advanced Features

### Response Caching

Enable and configure caching in `config.json`:

```json
{
  "cache": {
    "enabled": true,
    "max_entries": 1000,
    "default_ttl_secs": 3600,
    "eviction_strategy": "LRU",
    "max_size_bytes": 10737418240
  }
}
```

**Eviction Strategies:**
- `LRU`: Least Recently Used (default)
- `LFU`: Least Frequently Used
- `FIFO`: First In First Out

### Model Discovery

Configure automatic model discovery:

```json
{
  "discovery": {
    "enable_huggingface": true,
    "enable_ollama": true,
    "enable_local": true,
    "local_paths": ["~/.cache/huggingface", "~/.ollama/models"]
  }
}
```

### Model Filtering

Filter models by type and size:

```json
{
  "filter": {
    "max_file_size": 107374182400,
    "min_file_size": 1048576,
    "allowed_types": ["text_generation", "image_generation", "audio"]
  }
}
```

### Mixture of Experts (MOE)

Enable hybrid CPU/GPU processing:

```json
{
  "moe": {
    "enabled": true,
    "gpu_split_ratio": 0.7,
    "min_vram_mb": 4096,
    "layer_offloading": true
  }
}
```

### Metrics & Monitoring

Enable Prometheus metrics export:

```bash
allama serve --metrics-port 9090
```

Access metrics at `http://localhost:9090/metrics`

### Anomaly Detection

Configure anomaly detection thresholds:

```json
{
  "anomaly": {
    "enabled": true,
    "cpu_threshold_percent": 90,
    "memory_threshold_percent": 85,
    "latency_threshold_ms": 5000
  }
}
```

### Audit Logging

Configure audit logging:

```json
{
  "audit": {
    "enabled": true,
    "log_path": "~/.allama/audit.log",
    "max_size_bytes": 104857600,
    "rotation": "daily",
    "retention_days": 30,
    "log_level": "info",
    "include_timestamps": true,
    "include_process_id": true
  }
}
```

**Audit Configuration Options:**
- `enabled`: Enable audit logging
- `log_path`: Path to audit log file
- `max_size_bytes`: Maximum log file size (100MB default)
- `rotation`: Rotation interval (daily, weekly, monthly)
- `retention_days`: Number of days to retain logs
- `log_level`: Minimum log level (info, warning, error)
- `include_timestamps`: Include timestamps in logs
- `include_process_id`: Include process ID in logs

### Hot Reload Configuration

```json
{
  "enable_hot_reload": true,
  "reload_interval_secs": 60
}
```

When hot reload is enabled, the server will automatically reload the configuration file when it changes, without requiring a restart.

## Performance Optimization

### GPU Optimization

**NVIDIA GPU:**
```bash
# Check GPU utilization
nvidia-smi

# Set GPU memory limit (if supported)
export CUDA_VISIBLE_DEVICES=0
export CUDA_DEVICE_MAX_CONNECTIONS=32

# Optimize for inference
export CUDA_CACHE_DISABLE=0
```

**Apple Silicon (Metal):**
```bash
# Check Metal support
system_profiler SPDisplaysDataType

# Set Metal performance
export METAL_DEVICE_WRAPPER_TYPE=1
```

**AMD (ROCm):**
```bash
# Check ROCm support
rocm-smi

# Set GPU memory limit
export HSA_OVERRIDE_GFX_VERSION=10.3.0
```

### Memory Optimization

**Reduce Memory Usage:**
```bash
# Reduce parallel workers
allama serve --parallel 1

# Reduce max loaded models
allama serve --max-loaded-models 1

# Enable MOE layer offloading
# Configure in config.json:
{
  "moe": {
    "enabled": true,
    "layer_offloading": true,
    "offload_threshold_mb": 2048
  }
}

# Reduce context length
# Model-specific configuration
```

**Enable Response Caching:**
```json
{
  "cache": {
    "enabled": true,
    "max_entries": 1000,
    "default_ttl_secs": 3600,
    "eviction_strategy": "LRU"
  }
}
```

### CPU Optimization

**CPU-Affinity:**
```bash
# Pin to specific CPU cores
taskset -c 0-3 allama serve

# Set CPU governor to performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

**Thread Pool Configuration:**
```bash
# Set Tokio thread pool size
export TOKIO_WORKER_THREADS=4

allama serve --parallel 4
```

### Network Optimization

**Keep-Alive Connections:**
```bash
# Enable HTTP keep-alive
# Configured in server settings
```

**Compression:**
```json
{
  "server": {
    "enable_compression": true,
    "compression_level": 6
  }
}
```

**Connection Pooling:**
```bash
# Configure connection pool
allama serve --max-connections 100
```

### I/O Optimization

**Use SSD for Models:**
```bash
# Set model directory to SSD
export ALLAMA_MODELS_DIR=/mnt/ssd/models
```

**Reduce Logging Overhead:**
```bash
# Set log level to warning in production
RUST_LOG=warning allama serve
```

### Benchmarking

**Measure Response Time:**
```bash
# Use time command
time curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3","prompt":"Hello","stream":false}'
```

**Monitor Cache Hit Rate:**
```bash
# Check cache statistics
curl http://localhost:11435/api/cache/stats
```

**Profile with Flamegraph:**
```bash
# Install flamegraph
cargo install flamegraph

# Generate flamegraph
flamegraph allama serve
```

## Memory Optimization & Context Window Configuration

### mmap (Memory-Mapped Files) Support

Allama automatically uses mmap for model loading, which provides significant memory optimization benefits:

**Benefits of mmap:**
- **Fast Loading**: 60-80% faster model loading times
- **Reduced Memory Usage**: 70% memory reduction (model weights loaded on-demand)
- **Large Model Support**: Enables running larger models with limited RAM
- **Multi-Model Support**: Multiple models can be mapped simultaneously

**mmap Configuration:**
mmap is enabled by default in Allama's optimized parameters. The configuration is automatically applied when loading models.

### Context Window Memory Requirements

Based on actual testing with Qwen3.6-35B-A3B-Q4_K_M.gguf (4-bit quantization):

| Context Size | Memory Usage (with mmap) | KV Cache Growth |
|-------------|------------------------|----------------|
| 4k | 11-14GB | - |
| 32k | 11.6-14.6GB | +0.6GB |
| 64k | 12.3-15.3GB | +1.3GB |
| 96k | 12.9-15.9GB | +1.9GB |
| 128k | 13.5-16.5GB | +2.5GB |
| 160k | 14.1-17.1GB | +3.1GB |
| 192k | 14.8-17.8GB | +3.8GB |
| 200k | 14.9-17.9GB | +3.9GB |
| 256k | 16.0-19.0GB | +5.0GB |

**Memory Calculation Formula:**
```
Total Memory = Model Weights (mmap) + KV Cache + Inference Engine
- Model Weights (mmap): 5-8GB (on-demand loading)
- KV Cache: Context Size x 19.56MB per 1k tokens
- Inference Engine: 3GB
```

### Platform-Specific Recommendations

#### macOS (Apple Silicon)

**16GB M4 Mini:**
- **Recommended**: 128k context
- **Memory Usage**: 13.5-16.5GB
- **System Overhead**: 3-4GB
- **Available Memory**: 12-13GB
- **Feasibility**: Feasible with optimization

**24GB M4 Mini:**
- **Recommended**: 160-200k context
- **Memory Usage**: 14.1-17.9GB
- **System Overhead**: 3-4GB
- **Available Memory**: 20-21GB
- **Feasibility**: Ideal with ample margin

**Memory Optimization for macOS:**
```bash
# Close unnecessary applications
# Monitor memory usage
top -o mem

# Clear system cache
sudo purge
```

#### Linux (pop!-OS)

**16GB pop!-OS:**
- **Recommended**: 128-160k context
- **Memory Usage**: 13.5-17.1GB
- **System Overhead**: 1.5-2GB
- **Available Memory**: 14GB
- **Feasibility**: Feasible

**Memory Optimization for pop!-OS:**
```bash
# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups
sudo systemctl disable avahi-daemon

# Optimize swap usage
echo 10 | sudo tee /proc/sys/vm/swappiness
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf

# Clean system cache
sudo apt clean
sudo apt autoremove
rm -rf ~/.cache/*
```

**Advanced Optimization (pop!-OS):**
```bash
# Switch to lightweight desktop environment (Xfce)
sudo apt install xfce4

# Run in multi-user mode (no GUI)
sudo systemctl isolate multi-user.target

# Use systemd service with memory limits
# Create /etc/systemd/system/allama-inference.service
[Unit]
Description=Allama Inference Service
After=network.target

[Service]
Type=simple
User=youruser
ExecStart=/path/to/inference-service --host 127.0.0.1 --port 8081 --models-dir ~/.allama/models
MemoryLimit=12G
MemoryMax=14G
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### Inference Service Memory Optimization

**Startup Parameters:**
```bash
# Reduced memory configuration
./inference-service \
    --host 127.0.0.1 \
    --port 8081 \
    --models-dir ~/.allama/models \
    --max-loaded-models 1 \
    --context-size 131072 \
    --max-concurrent-requests 1
```

**Key Parameters:**
- `--max-loaded-models 1`: Only load one model at a time
- `--context-size 131072`: Set context size (e.g., 128k)
- `--max-concurrent-requests 1`: Limit concurrent requests

### Context Window Selection Guide

**For OpenClaw (Personal AI with 100+ skills):**
- **Minimum**: 64k (basic functionality)
- **Recommended**: 96-128k (multi-skill execution)
- **Ideal**: 160k+ (full functionality)

**For General Chat:**
- **Minimum**: 32k (simple conversations)
- **Recommended**: 64k (multi-turn conversations)
- **Ideal**: 96k+ (complex conversations)

**For Code Generation:**
- **Minimum**: 64k (single file)
- **Recommended**: 96k (multi-file)
- **Ideal**: 128k+ (large projects)

### Memory Monitoring

**Monitor Memory Usage:**
```bash
# Linux/macOS
htop

# Or use watch
watch -n 1 free -h

# Create monitoring script
cat > ~/memory_monitor.sh << 'EOF'
#!/bin/bash
while true; do
    echo "$(date): $(free -h | grep Mem)" >> ~/memory_log.txt
    sleep 60
done
EOF
chmod +x ~/memory_monitor.sh
```

**Allama Memory Statistics:**
```bash
# Check inference service stats
curl http://localhost:8081/stats

# Response includes:
# - total_memory_bytes
# - total_memory_mb
# - model_count
# - loaded_models
```

### Verification Testing

**Test mmap Functionality:**
```bash
# Run mmap verification test
bash examples/mmap_verification_test.sh

# This test verifies:
# - mmap parameter configuration
# - Model loading with mmap
# - Memory usage monitoring
# - Inference functionality
```

**Expected Output:**
```
Binary file ready
Model file ready
Model loading successful
mmap parameter configuration detected (use_mmap=true)
Optimized model parameters configuration detected
Inference successful
```

### Troubleshooting Memory Issues

**Issue: Out of Memory (OOM)**
- **Cause**: Context window too large for available memory
- **Solution**: Reduce context size or close other applications

**Issue: Slow Model Loading**
- **Cause**: mmap not enabled or disk I/O bottleneck
- **Solution**: Verify mmap is enabled, use SSD for model storage

**Issue: High Memory Usage**
- **Cause**: Multiple models loaded or large context window
- **Solution**: Reduce max-loaded-models to 1, reduce context size

**Issue: Swap Activity**
- **Cause**: Memory pressure exceeding physical RAM
- **Solution**: Reduce context size, close other applications, or add more RAM

### Best Practices for Memory Management

1. **Use mmap**: Always enabled by default, provides 70% memory reduction
2. **Limit Concurrent Models**: Set `--max-loaded-models 1` for memory-constrained systems
3. **Choose Appropriate Context Size**: Balance between functionality and memory usage
4. **Monitor Memory Usage**: Use monitoring tools to track memory consumption
5. **Optimize System**: Disable unnecessary services and applications
6. **Use SSD**: Store models on SSD for faster mmap loading


## Best Practices

### Production Deployment

**Use System Service:**
```bash
# Linux: systemd
sudo systemctl enable allama
sudo systemctl start allama

# macOS: launchd
allama start

# Windows: Service
# Installed by .exe installer
```

**Configure Resource Limits:**
```json
{
  "server": {
    "max_memory_mb": 16384,
    "max_cpu_percent": 80,
    "max_connections": 100
  }
}
```

**Enable Authentication:**
```bash
# Never run without authentication in production
# Always use API keys for remote access
```

**Enable Audit Logging:**
```json
{
  "audit": {
    "enabled": true,
    "log_path": "/var/log/allama/audit.log",
    "rotation": "daily",
    "retention_days": 90
  }
}
```

**Use Reverse Proxy:**
```nginx
# Nginx configuration
server {
    listen 443 ssl;
    server_name allama.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:11435;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Model Management

**Use Model Discovery:**
```json
{
  "discovery": {
    "enable_huggingface": true,
    "enable_ollama": true,
    "enable_local": true
  }
}
```

**Filter Models:**
```json
{
  "filter": {
    "max_file_size": 53687091200,
    "allowed_types": ["text_generation"]
  }
}
```

**Use Response Caching:**
```json
{
  "cache": {
    "enabled": true,
    "eviction_strategy": "LRU"
  }
}
```

### Security Best Practices

**Rotate API Keys Regularly:**
```bash
# Create new user with new key
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"newuser","rate_limit":60,"monthly_quota":1000000}'

# Delete old user
curl -X DELETE http://localhost:11435/api/users/old_user_id
```

**Use TLS in Production:**
```bash
# Configure reverse proxy with SSL
# See Nginx example above
```

**Limit Access by IP:**
```nginx
# Nginx IP restriction
location / {
    allow 192.168.1.0/24;
    deny all;
    proxy_pass http://localhost:11435;
}
```

**Regular Security Audits:**
```bash
# Review audit logs
tail -f ~/.allama/audit.log

# Check for unusual activity
grep "ERROR" ~/.allama/audit.log
```

### Monitoring Best Practices

**Enable Metrics Export:**
```bash
allama serve --metrics-port 9090
```

**Set Up Prometheus:**
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'allama'
    static_configs:
      - targets: ['localhost:9090']
```

**Configure Alerts:**
```yaml
# alerting rules
groups:
  - name: allama_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(allama_errors_total[5m]) > 0.1
        annotations:
          summary: "High error rate detected"
```

## Security Guidelines

### API Key Management

**Generate Secure Keys:**
```bash
# Keys are automatically generated with cryptographic randomness
# Never share keys via email or chat
# Store keys in secure vaults (HashiCorp Vault, AWS Secrets Manager)
```

**Key Rotation:**
```bash
# Rotate keys every 90 days
# Delete old keys after rotation
# Document key rotation in audit log
```

**Key Storage:**
```bash
# Never hardcode keys in source code
# Use environment variables
export ALLAMA_API_KEY="your_key_here"

# Or use secret management tools
```

### Network Security

**Use TLS:**
```bash
# Always use HTTPS in production
# Configure valid SSL certificates
# Enable HSTS
```

**Firewall Configuration:**
```bash
# Only expose necessary ports
# Use firewall rules to restrict access
# Example: ufw
sudo ufw allow from 192.168.1.0/24 to any port 11435
```

**Rate Limiting:**
```json
{
  "server": {
    "rate_limit_per_ip": 100,
    "rate_limit_per_user": 60
  }
}
```

### Data Protection

**Encrypt Audit Logs:**
```bash
# Use file system encryption
# Or encrypt logs at rest
```

**Secure Billing Data:**
```bash
# Billing database should be encrypted
# Regular backups with encryption
```

**Model Protection:**
```bash
# Set appropriate file permissions
chmod 600 ~/.allama/models/*
```

### Compliance

**GDPR Compliance:**
- Log user consent for data processing
- Provide data export functionality
- Implement data deletion requests

**SOC 2 Compliance:**
- Enable comprehensive audit logging
- Implement access controls
- Regular security assessments

## Integration Examples

### Rust example programs (`examples/`)

Runnable `cargo` examples and short descriptions are listed in [`examples/README.md`](../examples/README.md). Several targets ship **unit tests** (no `allama serve`, no GGUF required):

| Example | Summary |
|---------|---------|
| `ollama_compatible_api_client` | Build `POST /api/generate` / `POST /api/chat` JSON; optional `ALLAMA_HTTP_SMOKE=1` for live `GET /api/version` and `GET /api/tags` |
| `batch_generate_payloads` | Build many `/api/generate` bodies from stdin lines |
| `thinking_split_app` | Split CoT tags → chat-style JSON (`message` + `thinking`) |
| `thinking_generate_response` | Split CoT tags → generate-style JSON (`response` + `thinking`); stream buffer finalize |

```bash
cd allama
cargo test --features inference
cargo test --example ollama_compatible_api_client --features inference
cargo test --example batch_generate_payloads
cargo test --example thinking_split_app --features inference
cargo test --example thinking_generate_response --features inference
bash scripts/run_automated_tests.sh
```

### Python Integration

```python
import requests
import json

class AllamaClient:
    def __init__(self, base_url="http://localhost:11435", api_key=None):
        self.base_url = base_url
        self.api_key = api_key
        self.headers = {
            "Content-Type": "application/json"
        }
        if api_key:
            self.headers["Authorization"] = f"Bearer {api_key}"
    
    def chat_completion(self, model, messages, stream=False):
        response = requests.post(
            f"{self.base_url}/v1/chat/completions",
            headers=self.headers,
            json={
                "model": model,
                "messages": messages,
                "stream": stream
            }
        )
        return response.json()
    
    def generate(self, model, prompt, stream=False):
        response = requests.post(
            f"{self.base_url}/api/generate",
            headers=self.headers,
            json={
                "model": model,
                "prompt": prompt,
                "stream": stream
            }
        )
        return response.json()

# Usage
client = AllamaClient(api_key="your_api_key")
result = client.chat_completion(
    model="llama3",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(result)
```

### JavaScript Integration

```javascript
class AllamaClient {
    constructor(baseUrl = 'http://localhost:11435', apiKey = null) {
        this.baseUrl = baseUrl;
        this.apiKey = apiKey;
    }

    async chatCompletion(model, messages, stream = false) {
        const headers = {
            'Content-Type': 'application/json'
        };
        if (this.apiKey) {
            headers['Authorization'] = `Bearer ${this.apiKey}`;
        }

        const response = await fetch(`${this.baseUrl}/v1/chat/completions`, {
            method: 'POST',
            headers,
            body: JSON.stringify({
                model,
                messages,
                stream
            })
        });
        return response.json();
    }

    async generate(model, prompt, stream = false) {
        const headers = {
            'Content-Type': 'application/json'
        };
        if (this.apiKey) {
            headers['Authorization'] = `Bearer ${this.apiKey}`;
        }

        const response = await fetch(`${this.baseUrl}/api/generate`, {
            method: 'POST',
            headers,
            body: JSON.stringify({
                model,
                prompt,
                stream
            })
        });
        return response.json();
    }
}

// Usage
const client = new AllamaClient('http://localhost:11435', 'your_api_key');
const result = await client.chatCompletion('llama3', [
    { role: 'user', content: 'Hello!' }
]);
console.log(result);
```

### Go Integration

```go
package main

import (
    "bytes"
    "encoding/json"
    "net/http"
)

type AllamaClient struct {
    BaseURL string
    APIKey  string
}

type ChatRequest struct {
    Model    string        `json:"model"`
    Messages []Message     `json:"messages"`
    Stream   bool          `json:"stream"`
}

type Message struct {
    Role    string `json:"role"`
    Content string `json:"content"`
}

func (c *AllamaClient) ChatCompletion(req ChatRequest) (*http.Response, error) {
    body, err := json.Marshal(req)
    if err != nil {
        return nil, err
    }

    httpRequest, err := http.NewRequest(
        "POST",
        c.BaseURL+"/v1/chat/completions",
        bytes.NewBuffer(body),
    )
    if err != nil {
        return nil, err
    }

    httpRequest.Header.Set("Content-Type", "application/json")
    if c.APIKey != "" {
        httpRequest.Header.Set("Authorization", "Bearer "+c.APIKey)
    }

    client := &http.Client{}
    return client.Do(httpRequest)
}

func main() {
    client := AllamaClient{
        BaseURL: "http://localhost:11435",
        APIKey:  "your_api_key",
    }

    req := ChatRequest{
        Model: "llama3",
        Messages: []Message{
            {Role: "user", Content: "Hello!"},
        },
        Stream: false,
    }

    resp, err := client.ChatCompletion(req)
    if err != nil {
        panic(err)
    }
    defer resp.Body.Close()

    // Handle response
}
```

### Docker Integration

```dockerfile
# Dockerfile
FROM rust:1.75 as builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/allama /usr/local/bin/allama
EXPOSE 11435
CMD ["allama", "serve"]
```

```yaml
# docker-compose.yml
version: '3.8'
services:
  allama:
    build: .
    ports:
      - "11435:11435"
    volumes:
      - allama_models:/root/.allama/models
      - allama_config:/root/.allama
    environment:
      - OLLAMA_NUM_PARALLEL=4
      - RUST_LOG=info
    restart: unless-stopped

volumes:
  allama_models:
  allama_config:
```

## Monitoring & Alerting

### Metrics Export

**Prometheus Configuration:**
```bash
allama serve --metrics-port 9090
```

**Available Metrics:**
- `allama_requests_total`: Total number of requests
- `allama_request_duration_seconds`: Request duration
- `allama_cache_hits_total`: Cache hits
- `allama_cache_misses_total`: Cache misses
- `allama_errors_total`: Total errors
- `allama_active_connections`: Active connections

### Grafana Dashboard

**Sample Dashboard Queries:**
```promql
# Request rate
rate(allama_requests_total[5m])

# Error rate
rate(allama_errors_total[5m])

# Cache hit rate
rate(allama_cache_hits_total[5m]) / (rate(allama_cache_hits_total[5m]) + rate(allama_cache_misses_total[5m]))

# P95 latency
histogram_quantile(0.95, rate(allama_request_duration_seconds_bucket[5m]))
```

### Alerting Rules

```yaml
groups:
  - name: allama_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(allama_errors_total[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          
      - alert: LowCacheHitRate
        expr: rate(allama_cache_hits_total[5m]) / (rate(allama_cache_hits_total[5m]) + rate(allama_cache_misses_total[5m])) < 0.5
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Cache hit rate below 50%"
          
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(allama_request_duration_seconds_bucket[5m])) > 5
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "P95 latency above 5 seconds"
```

### Log Aggregation

**ELK Stack Integration:**
```bash
# Install Filebeat
# Configure to ship logs to Elasticsearch

# filebeat.yml
filebeat.inputs:
  - type: log
    paths:
      - ~/.allama/audit.log
      - ~/.allama/server.log
    json.keys_under_root: true
    json.add_error_key: true

output.elasticsearch:
  hosts: ["localhost:9200"]
```

**Splunk Integration:**
```bash
# Configure Splunk forwarder
# Monitor log files
# Set up indexes and sourcetypes
```

## Troubleshooting

### Common Issues

**Port Already in Use**
```bash
# Use automatic port allocation
allama serve --port 0

# Or specify a different port
allama serve --port 11436

# Find process using port
lsof -i :11435
kill -9 <PID>
```

**GPU Not Detected**
```bash
# Check GPU detection
allama ps --verbose

# Ensure GPU drivers are installed
# NVIDIA: nvidia-smi
# AMD: rocm-smi
# Apple Silicon: System Information

# Check GPU visibility
nvidia-smi -L

# Force CPU mode
CUDA_VISIBLE_DEVICES="" allama serve
```

**Authentication Failed**
```bash
# Check API key
allama list users

# Ensure X-Forwarded-For header is set for remote requests
curl -H "X-Forwarded-For: 127.0.0.1" ...

# Verify user exists and is active
curl http://localhost:11435/api/users \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

**Out of Memory**
```bash
# Reduce parallel workers
allama serve --parallel 1

# Reduce max loaded models
allama serve --max-loaded-models 1

# Enable MOE layer offloading
# Configure in config.json

# Check memory usage
ps aux | grep allama
top -p <PID>

# Increase swap space (Linux)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

**Slow Response Times**
```bash
# Check system load
uptime

# Check disk I/O
iostat -x 1

# Check network latency
ping localhost

# Enable caching
# Configure in config.json

# Reduce context length
# Model-specific configuration
```

**Model Loading Failures**
```bash
# Check model file integrity
sha256sum ~/.allama/models/*

# Verify model format
file ~/.allama/models/*

# Check disk space
df -h

# Re-download model
allama rm llama3
allama pull llama3
```

**Connection Refused**
```bash
# Check if server is running
allama status

# Check firewall rules
sudo ufw status
sudo iptables -L

# Check if port is listening
netstat -tlnp | grep 11435

# Restart server
allama stop
allama start
```

### Debug Mode

Enable debug logging:

```bash
# Enable debug logging
RUST_LOG=debug allama serve

# Enable trace logging (very verbose)
RUST_LOG=trace allama serve

# Enable specific module logging
RUST_LOG=allama::server=debug,allama::auth=info allama serve
```

### Log Files

- **Audit Log**: `~/.allama/audit.log`
- **Server Log**: `~/.allama/server.log`
- **Error Log**: `~/.allama/error.log`
- **Cache Log**: `~/.allama/cache.log` (if persistence enabled)

**View Logs:**
```bash
# View audit log
tail -f ~/.allama/audit.log

# View server log
tail -f ~/.allama/server.log

# Search for errors
grep -i error ~/.allama/*.log

# View recent logs
ls -lt ~/.allama/*.log | head -5
```

### Health Checks

**Basic Health Check:**
```bash
curl http://localhost:11435/api/health
```

**Detailed Health Check:**
```bash
curl http://localhost:11435/api/health/detailed
```

**Check Specific Components:**
```bash
# Check cache health
curl http://localhost:11435/api/cache/health

# Check GPU status
curl http://localhost:11435/api/gpu/status

# Check model status
curl http://localhost:11435/api/models/status
```

### Performance Profiling

**CPU Profiling:**
```bash
# Install perf (Linux)
sudo apt-get install linux-tools-generic

# Profile CPU usage
sudo perf record -g allama serve
sudo perf report
```

**Memory Profiling:**
```bash
# Use valgrind
valgrind --leak-check=full allama serve

# Or use heaptrack
heaptrack allama serve
```

**Network Profiling:**
```bash
# Use tcpdump
sudo tcpdump -i lo port 11435 -w capture.pcap

# Analyze with Wireshark
wireshark capture.pcap
```

### Getting Help

```bash
# General help
allama --help

# Command-specific help
allama serve --help
allama pull --help
allama run --help
```

### Support Resources

- **GitHub Issues**: https://github.com/arkCyber/allama/issues
- **Documentation**: https://github.com/arkCyber/allama
- **User Manual**: [docs/USER_MANUAL.md](USER_MANUAL.md)
- **Authentication Guide**: [docs/AUTHENTICATION_GUIDE.md](AUTHENTICATION_GUIDE.md)
- **DO-178C Compliance**: [DO-178C-COMPLIANCE.md](../DO-178C-COMPLIANCE.md)

### Common Error Messages

**"Connection refused"**
- Server not running
- Wrong port
- Firewall blocking

**"Authentication failed"**
- Invalid API key
- Missing X-Forwarded-For header
- User account disabled

**"Model not found"**
- Model not downloaded
- Model name incorrect
- Model filtered out

**"Out of memory"**
- Model too large for available memory
- Too many models loaded
- Memory leak

**"GPU not available"**
- GPU drivers not installed
- GPU not supported
- CUDA/ROCm/Metal not configured

### Recovery Procedures

**Restore from Backup:**
```bash
# Restore models from backup
cp -r /backup/allama/models/* ~/.allama/models/

# Restore configuration
cp /backup/allama/config.json ~/.allama/

# Restore audit logs
cp /backup/allama/audit.log ~/.allama/
```

**Reset to Default:**
```bash
# Stop server
allama stop

# Remove configuration
rm ~/.allama/config.json

# Remove models (optional)
rm -rf ~/.allama/models/*

# Restart server (will create default config)
allama start
```

**Factory Reset:**
```bash
# Stop all services
allama stop

# Remove all data
rm -rf ~/.allama/

# Reinstall
allama uninstall
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash
```

# Allama User Manual

## Table of Contents
1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Service Management](#service-management)
4. [Model Management](#model-management)
5. [Server Operations](#server-operations)
6. [Authentication](#authentication)
7. [Billing](#billing)
8. [Advanced Features](#advanced-features)
9. [Performance Optimization](#performance-optimization)
10. [Best Practices](#best-practices)
11. [Security Guidelines](#security-guidelines)
12. [Integration Examples](#integration-examples)
13. [Monitoring & Alerting](#monitoring--alerting)
14. [Troubleshooting](#troubleshooting)

## Installation

### Prerequisites
- **Windows**: Windows 10 or later
- **macOS**: macOS 10.15 (Catalina) or later
- **Linux**: Most modern distributions (Ubuntu, Debian, Fedora, etc.)

### Installation Methods

#### Method 1: Pre-built Binary (Recommended)

```bash
# Install using automatic installer
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash

# Install specific version
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash -s v1.0.0

# Install to custom directory
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash -s latest /opt/allama
```

#### Method 2: Package Installer

**macOS:**
```bash
# Download .dmg from GitHub Releases
# Double-click and drag Allama.app to Applications
```

**Windows:**
```bash
# Download .exe from GitHub Releases
# Run installer and follow wizard
```

**Linux (Debian/Ubuntu):**
```bash
sudo dpkg -i allama_*_amd64.deb
sudo apt-get install -f
```

#### Method 3: Build from Source

```bash
git clone https://github.com/arkCyber/allama.git
cd allama
cargo build --release
sudo cp target/release/allama /usr/local/bin/
```

### Verification

```bash
allama version
# Expected output: allama 1.0.0
```

## Configuration

### Configuration File Location
- **Linux/macOS**: `~/.allama/config.json`
- **Windows**: `%APPDATA%\allama\config.json`

### Configuration Options

```json
{
  "cache": {
    "enabled": true,
    "max_entries": 1000,
    "default_ttl_secs": 3600,
    "eviction_strategy": "LRU",
    "max_size_bytes": 10737418240
  },
  "discovery": {
    "enable_huggingface": true,
    "enable_ollama": true,
    "enable_local": true,
    "local_paths": ["~/.cache/huggingface", "~/.ollama/models"]
  },
  "filter": {
    "max_file_size": 107374182400,
    "min_file_size": 1048576,
    "allowed_types": ["text_generation", "image_generation", "audio"]
  },
  "audit": {
    "enabled": true,
    "log_path": "~/.allama/audit.log",
    "max_size_bytes": 104857600,
    "rotation": "daily"
  },
  "moe": {
    "enabled": false,
    "gpu_split_ratio": 0.7,
    "min_vram_mb": 4096,
    "layer_offloading": true
  },
  "enable_hot_reload": false
}
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OLLAMA_HOST` | Server host | `127.0.0.1` |
| `OLLAMA_NUM_PARALLEL` | Parallel requests | `1` |
| `OLLAMA_MAX_LOADED_MODELS` | Max loaded models | `3` |
| `OLLAMA_MAX_QUEUE` | Max queue size | `512` |
| `RUST_LOG` | Logging level (error, warn, info, debug, trace) | `info` |
| `ALLAMA_CONFIG_PATH` | Custom config file path | `~/.allama/config.json` |

### Advanced Configuration

#### Cache Configuration Details

```json
{
  "cache": {
    "enabled": true,
    "max_entries": 1000,
    "default_ttl_secs": 3600,
    "eviction_strategy": "LRU",
    "max_size_bytes": 10737418240,
    "enable_size_limit": true,
    "enable_persistence": false,
    "persistence_path": "~/.allama/cache.db"
  }
}
```

**Cache Configuration Options:**
- `enabled`: Enable/disable response caching
- `max_entries`: Maximum number of cached entries
- `default_ttl_secs`: Default time-to-live in seconds
- `eviction_strategy`: LRU, LFU, or FIFO
- `max_size_bytes`: Maximum cache size in bytes (10GB default)
- `enable_size_limit`: Enable size-based eviction
- `enable_persistence`: Persist cache to disk
- `persistence_path`: Path to cache database

#### Discovery Configuration Details

```json
{
  "discovery": {
    "enable_huggingface": true,
    "enable_ollama": true,
    "enable_local": true,
    "local_paths": [
      "~/.cache/huggingface",
      "~/.ollama/models",
      "/opt/models"
    ],
    "scan_depth": 3,
    "follow_symlinks": false
  }
}
```

**Discovery Configuration Options:**
- `enable_huggingface`: Scan Hugging Face cache directory
- `enable_ollama`: Scan Ollama models directory
- `enable_local`: Scan custom local paths
- `local_paths`: List of directories to scan
- `scan_depth`: Directory scan depth (default: 3)
- `follow_symlinks`: Follow symbolic links

#### Filter Configuration Details

```json
{
  "filter": {
    "max_file_size": 107374182400,
    "min_file_size": 1048576,
    "allowed_types": ["text_generation", "image_generation", "audio"],
    "blocked_patterns": ["test", "experimental"],
    "require_quantization": false,
    "min_parameters": 1000000000
  }
}
```

**Filter Configuration Options:**
- `max_file_size`: Maximum model file size (100GB default)
- `min_file_size`: Minimum model file size (1MB default)
- `allowed_types`: Allowed model types
- `blocked_patterns`: Patterns to block in model names
- `require_quantization`: Require quantized models
- `min_parameters`: Minimum parameter count

#### MOE Configuration Details

```json
{
  "moe": {
    "enabled": false,
    "gpu_split_ratio": 0.7,
    "min_vram_mb": 4096,
    "layer_offloading": true,
    "offload_threshold_mb": 2048,
    "compute_threshold": 0.5,
    "routing_strategy": "load_balanced"
  }
}
```

**MOE Configuration Options:**
- `enabled`: Enable Mixture of Experts
- `gpu_split_ratio`: GPU/CPU split ratio (0.0-1.0)
- `min_vram_mb`: Minimum VRAM required for GPU (4GB default)
- `layer_offloading`: Enable dynamic layer offloading
- `offload_threshold_mb`: VRAM threshold for offloading
- `compute_threshold`: Compute intensity threshold (0.0-1.0)
- `routing_strategy`: load_balanced, compute_based, or mru

## Service Management

### Starting the Service

```bash
# Start as foreground process
allama serve

# Start with custom configuration
allama serve --host 0.0.0.0 --port 8080 --parallel 4

# Start as background service
allama start
```

### Stopping the Service

```bash
# Stop background service
allama stop

# Or send SIGTERM to the process
kill -TERM $(pgrep allama)
```

### Checking Status

```bash
allama status

# Expected output:
# Status: running
# PID: 12345
# Port: 11435
# Uptime: 1h23m
```

### Auto-start Configuration

**Linux (systemd):**
```bash
sudo systemctl enable allama
sudo systemctl start allama
```

**macOS (launchd):**
```bash
allama start  # Automatically creates launchd agent
```

**Windows (Service):**
```bash
# Service is installed by the .exe installer
# Configure via Services.msc
```

## Model Management

### Listing Models

```bash
# List all available models
allama list

# List with details
allama list --verbose
```

### Downloading Models

```bash
# Download a model
allama pull llama3

# Download specific tag
allama pull llama3:8b

# Download from custom registry
allama pull myregistry.com/model:tag
```

### Running Models

```bash
# Run interactively
allama run llama3

# Run with prompt
allama run llama3 --prompt "Hello, world!"

# Generate embeddings
allama run llama3 --embeddings
```

### Model Information

```bash
# Show model details
allama show llama3

# Show model architecture
allama show llama3 --architecture
```

### Removing Models

```bash
# Remove a model
allama rm llama3

# Force removal
allama rm llama3 --force
```

### Managing Running Models

```bash
# List running models
allama ps

# Stop a running model
allama stop llama3
```

### Custom Models

```bash
# Create from Modelfile
allama create mymodel --from Modelfile

# Copy a model
allama cp llama3 myllama3

# Push to registry
allama push mymodel
```

### Importing Models from Ollama

If you have Ollama installed and want to use your existing models with Allama, you can import them:

```bash
# Run the import script
./scripts/import-from-ollama.sh
```

The script will:
1. Detect your Ollama installation
2. List all available models
3. Ask whether to import specific models or all models
4. Copy model manifests and blob files to Allama's models directory

**Manual Import:**
```bash
# Import a specific model
./scripts/import-from-ollama.sh
# Select option 1 and enter model name

# Import all models
./scripts/import-from-ollama.sh
# Select option 2
```

**Model Discovery Alternative:**

Allama can also discover models from your Ollama installation without copying them:

```json
{
  "discovery": {
    "enable_ollama": true
  }
}
```

With discovery enabled, Allama will automatically scan `~/.ollama/models` and make those models available.

## Server Operations

### Starting the Server

```bash
# Basic start (auto-allocate port)
allama serve

# Custom host and port
allama serve --host 0.0.0.0 --port 8080

# With parallel workers
allama serve --parallel 4

# With model limits
allama serve --max-loaded-models 5 --max-queue 1024
```

### Server Configuration

The server automatically:
- Creates a default test user with API key
- Allocates port if port=0
- Detects and uses available GPU
- Applies rate limiting and quotas
- Logs all operations to audit log

### OpenAI-Compatible API

```bash
# Chat completions
curl -X POST http://localhost:11435/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -d '{
    "model": "llama3",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Text completions
curl -X POST http://localhost:11435/v1/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -d '{
    "model": "llama3",
    "prompt": "Hello, world!"
  }'

# Embeddings
curl -X POST http://localhost:11435/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -d '{
    "model": "llama3",
    "input": "Hello, world!"
  }'
```

### Ollama-Compatible API

```bash
# Generate text
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","prompt":"Hello, world!","stream":false}'

# Chat
curl -X POST http://localhost:11435/api/chat \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","messages":[{"role":"user","content":"Hello!"}],"stream":false}'

# List models
curl http://localhost:11435/api/tags
```

## Authentication

### Creating Users

```bash
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{
    "username": "myuser",
    "email": "user@example.com",
    "rate_limit": 60,
    "monthly_quota": 1000000
  }'
```

Response:
```json
{
  "user_id": "user_1234567890",
  "username": "myuser",
  "email": "user@example.com",
  "api_key": "allama_abcdefghijklmnopqrstuvwxyz123456",
  "rate_limit": 60,
  "monthly_quota": 1000000,
  "created_at": "2026-05-05T00:00:00Z"
}
```

### Using API Keys

```bash
# Remote requests require API key
curl -X POST http://your-server:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"Hello, world!","stream":false}'
```

### Authentication Strategy

- **Local Requests** (127.0.0.1, ::1, localhost): No authentication required
- **Remote Requests**: Require `Authorization: Bearer <api_key>` header
- **Detection**: Uses `X-Forwarded-For` or `X-Real-IP` headers

### Default Test User

The server creates a default test user on first start:
- **Username**: `test_user`
- **API Key**: Displayed on startup
- **Rate Limit**: 60 requests/minute
- **Monthly Quota**: 100,000 tokens

## Billing

### Querying Usage Records

```bash
curl -X GET "http://localhost:11435/api/billing/records?limit=10" \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

### Billing Summary

```bash
curl -X GET http://localhost:11435/api/billing/summary \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

Response:
```json
{
  "total_records": 1000,
  "total_tokens": 5000000,
  "total_prompt_tokens": 3000000,
  "total_completion_tokens": 2000000,
  "unique_models": 5,
  "period_start": "2026-05-01T00:00:00Z",
  "period_end": "2026-05-05T00:00:00Z"
}
```

### Model Statistics

```bash
curl -X GET http://localhost:11435/api/billing/stats/llama3 \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

## Advanced Features

### Response Caching

Enable and configure caching in `config.json`:

```json
{
  "cache": {
    "enabled": true,
    "max_entries": 1000,
    "default_ttl_secs": 3600,
    "eviction_strategy": "LRU",
    "max_size_bytes": 10737418240
  }
}
```

**Eviction Strategies:**
- `LRU`: Least Recently Used (default)
- `LFU`: Least Frequently Used
- `FIFO`: First In First Out

### Large Model Support with llama-server

For models larger than 26B parameters or requiring 96k+ context windows, use llama-server instead of the inference-service FFI backend:

**When to use llama-server:**
- Models with 26B+ parameters
- Context windows of 96k+ tokens
- Memory-intensive workloads
- Long document processing

**Example configuration:**
```bash
# Start llama-server with 96k context
/Users/arksong/Allama/build/bin/llama-server \
  -m /path/to/gemma-4-26B-A4B-it-Q4_K_M.gguf \
  -c 98304 \
  --port 8082
```

**TurboQuant optimization:**
- Automatically enabled for compatible models
- Reduces memory usage via sparse V dequantization
- Improves inference speed for large models

**See also:** `examples/gemma4_26b_96k_context.rs` for comprehensive testing examples.

### Model Discovery

Configure automatic model discovery:

```json
{
  "discovery": {
    "enable_huggingface": true,
    "enable_ollama": true,
    "enable_local": true,
    "local_paths": ["~/.cache/huggingface", "~/.ollama/models"]
  }
}
```

### Model Filtering

Filter models by type and size:

```json
{
  "filter": {
    "max_file_size": 107374182400,
    "min_file_size": 1048576,
    "allowed_types": ["text_generation", "image_generation", "audio"]
  }
}
```

### Mixture of Experts (MOE)

Enable hybrid CPU/GPU processing:

```json
{
  "moe": {
    "enabled": true,
    "gpu_split_ratio": 0.7,
    "min_vram_mb": 4096,
    "layer_offloading": true
  }
}
```

### Metrics & Monitoring

Enable Prometheus metrics export:

```bash
allama serve --metrics-port 9090
```

Access metrics at `http://localhost:9090/metrics`

### Anomaly Detection

Configure anomaly detection thresholds:

```json
{
  "anomaly": {
    "enabled": true,
    "cpu_threshold_percent": 90,
    "memory_threshold_percent": 85,
    "latency_threshold_ms": 5000
  }
}
```

### Audit Logging

Configure audit logging:

```json
{
  "audit": {
    "enabled": true,
    "log_path": "~/.allama/audit.log",
    "max_size_bytes": 104857600,
    "rotation": "daily",
    "retention_days": 30,
    "log_level": "info",
    "include_timestamps": true,
    "include_process_id": true
  }
}
```

**Audit Configuration Options:**
- `enabled`: Enable audit logging
- `log_path`: Path to audit log file
- `max_size_bytes`: Maximum log file size (100MB default)
- `rotation`: Rotation interval (daily, weekly, monthly)
- `retention_days`: Number of days to retain logs
- `log_level`: Minimum log level (info, warning, error)
- `include_timestamps`: Include timestamps in logs
- `include_process_id`: Include process ID in logs

### Hot Reload Configuration

```json
{
  "enable_hot_reload": true,
  "reload_interval_secs": 60
}
```

When hot reload is enabled, the server will automatically reload the configuration file when it changes, without requiring a restart.

## Performance Optimization

### GPU Optimization

**NVIDIA GPU:**
```bash
# Check GPU utilization
nvidia-smi

# Set GPU memory limit (if supported)
export CUDA_VISIBLE_DEVICES=0
export CUDA_DEVICE_MAX_CONNECTIONS=32

# Optimize for inference
export CUDA_CACHE_DISABLE=0
```

**Apple Silicon (Metal):**
```bash
# Check Metal support
system_profiler SPDisplaysDataType

# Set Metal performance
export METAL_DEVICE_WRAPPER_TYPE=1
```

**AMD (ROCm):**
```bash
# Check ROCm support
rocm-smi

# Set GPU memory limit
export HSA_OVERRIDE_GFX_VERSION=10.3.0
```

### Memory Optimization

**Reduce Memory Usage:**
```bash
# Reduce parallel workers
allama serve --parallel 1

# Reduce max loaded models
allama serve --max-loaded-models 1

# Enable MOE layer offloading
# Configure in config.json:
{
  "moe": {
    "enabled": true,
    "layer_offloading": true,
    "offload_threshold_mb": 2048
  }
}

# Reduce context length
# Model-specific configuration
```

**Enable Response Caching:**
```json
{
  "cache": {
    "enabled": true,
    "max_entries": 1000,
    "default_ttl_secs": 3600,
    "eviction_strategy": "LRU"
  }
}
```

### CPU Optimization

**CPU-Affinity:**
```bash
# Pin to specific CPU cores
taskset -c 0-3 allama serve

# Set CPU governor to performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

**Thread Pool Configuration:**
```bash
# Set Tokio thread pool size
export TOKIO_WORKER_THREADS=4

allama serve --parallel 4
```

### Network Optimization

**Keep-Alive Connections:**
```bash
# Enable HTTP keep-alive
# Configured in server settings
```

**Compression:**
```json
{
  "server": {
    "enable_compression": true,
    "compression_level": 6
  }
}
```

**Connection Pooling:**
```bash
# Configure connection pool
allama serve --max-connections 100
```

### I/O Optimization

**Use SSD for Models:**
```bash
# Set model directory to SSD
export ALLAMA_MODELS_DIR=/mnt/ssd/models
```

**Reduce Logging Overhead:**
```bash
# Set log level to warning in production
RUST_LOG=warning allama serve
```

### Benchmarking

**Measure Response Time:**
```bash
# Use time command
time curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3","prompt":"Hello","stream":false}'
```

**Monitor Cache Hit Rate:**
```bash
# Check cache statistics
curl http://localhost:11435/api/cache/stats
```

**Profile with Flamegraph:**
```bash
# Install flamegraph
cargo install flamegraph

# Generate flamegraph
flamegraph allama serve
```

## Best Practices

### Production Deployment

**Use System Service:**
```bash
# Linux: systemd
sudo systemctl enable allama
sudo systemctl start allama

# macOS: launchd
allama start

# Windows: Service
# Installed by .exe installer
```

**Configure Resource Limits:**
```json
{
  "server": {
    "max_memory_mb": 16384,
    "max_cpu_percent": 80,
    "max_connections": 100
  }
}
```

**Enable Authentication:**
```bash
# Never run without authentication in production
# Always use API keys for remote access
```

**Enable Audit Logging:**
```json
{
  "audit": {
    "enabled": true,
    "log_path": "/var/log/allama/audit.log",
    "rotation": "daily",
    "retention_days": 90
  }
}
```

**Use Reverse Proxy:**
```nginx
# Nginx configuration
server {
    listen 443 ssl;
    server_name allama.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:11435;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Model Management

**Use Model Discovery:**
```json
{
  "discovery": {
    "enable_huggingface": true,
    "enable_ollama": true,
    "enable_local": true
  }
}
```

**Filter Models:**
```json
{
  "filter": {
    "max_file_size": 53687091200,
    "allowed_types": ["text_generation"]
  }
}
```

**Use Response Caching:**
```json
{
  "cache": {
    "enabled": true,
    "eviction_strategy": "LRU"
  }
}
```

### Security Best Practices

**Rotate API Keys Regularly:**
```bash
# Create new user with new key
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"newuser","rate_limit":60,"monthly_quota":1000000}'

# Delete old user
curl -X DELETE http://localhost:11435/api/users/old_user_id
```

**Use TLS in Production:**
```bash
# Configure reverse proxy with SSL
# See Nginx example above
```

**Limit Access by IP:**
```nginx
# Nginx IP restriction
location / {
    allow 192.168.1.0/24;
    deny all;
    proxy_pass http://localhost:11435;
}
```

**Regular Security Audits:**
```bash
# Review audit logs
tail -f ~/.allama/audit.log

# Check for unusual activity
grep "ERROR" ~/.allama/audit.log
```

### Monitoring Best Practices

**Enable Metrics Export:**
```bash
allama serve --metrics-port 9090
```

**Set Up Prometheus:**
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'allama'
    static_configs:
      - targets: ['localhost:9090']
```

**Configure Alerts:**
```yaml
# alerting rules
groups:
  - name: allama_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(allama_errors_total[5m]) > 0.1
        annotations:
          summary: "High error rate detected"
```

## Security Guidelines

### API Key Management

**Generate Secure Keys:**
```bash
# Keys are automatically generated with cryptographic randomness
# Never share keys via email or chat
# Store keys in secure vaults (HashiCorp Vault, AWS Secrets Manager)
```

**Key Rotation:**
```bash
# Rotate keys every 90 days
# Delete old keys after rotation
# Document key rotation in audit log
```

**Key Storage:**
```bash
# Never hardcode keys in source code
# Use environment variables
export ALLAMA_API_KEY="your_key_here"

# Or use secret management tools
```

### Network Security

**Use TLS:**
```bash
# Always use HTTPS in production
# Configure valid SSL certificates
# Enable HSTS
```

**Firewall Configuration:**
```bash
# Only expose necessary ports
# Use firewall rules to restrict access
# Example: ufw
sudo ufw allow from 192.168.1.0/24 to any port 11435
```

**Rate Limiting:**
```json
{
  "server": {
    "rate_limit_per_ip": 100,
    "rate_limit_per_user": 60
  }
}
```

### Data Protection

**Encrypt Audit Logs:**
```bash
# Use file system encryption
# Or encrypt logs at rest
```

**Secure Billing Data:**
```bash
# Billing database should be encrypted
# Regular backups with encryption
```

**Model Protection:**
```bash
# Set appropriate file permissions
chmod 600 ~/.allama/models/*
```

### Compliance

**GDPR Compliance:**
- Log user consent for data processing
- Provide data export functionality
- Implement data deletion requests

**SOC 2 Compliance:**
- Enable comprehensive audit logging
- Implement access controls
- Regular security assessments

## Integration Examples

### Rust example programs (`examples/`)

Runnable `cargo` examples and short descriptions are listed in [`examples/README.md`](../examples/README.md). Several targets ship **unit tests** (no `allama serve`, no GGUF required):

| Example | Summary |
|---------|---------|
| `ollama_compatible_api_client` | Build `POST /api/generate` / `POST /api/chat` JSON; optional `ALLAMA_HTTP_SMOKE=1` for live `GET /api/version` and `GET /api/tags` |
| `batch_generate_payloads` | Build many `/api/generate` bodies from stdin lines |
| `thinking_split_app` | Split CoT tags → chat-style JSON (`message` + `thinking`) |
| `thinking_generate_response` | Split CoT tags → generate-style JSON (`response` + `thinking`); stream buffer finalize |

```bash
cd allama
cargo test --features inference
cargo test --example ollama_compatible_api_client --features inference
cargo test --example batch_generate_payloads
cargo test --example thinking_split_app --features inference
cargo test --example thinking_generate_response --features inference
bash scripts/run_automated_tests.sh
```

### Python Integration

```python
import requests
import json

class AllamaClient:
    def __init__(self, base_url="http://localhost:11435", api_key=None):
        self.base_url = base_url
        self.api_key = api_key
        self.headers = {
            "Content-Type": "application/json"
        }
        if api_key:
            self.headers["Authorization"] = f"Bearer {api_key}"
    
    def chat_completion(self, model, messages, stream=False):
        response = requests.post(
            f"{self.base_url}/v1/chat/completions",
            headers=self.headers,
            json={
                "model": model,
                "messages": messages,
                "stream": stream
            }
        )
        return response.json()
    
    def generate(self, model, prompt, stream=False):
        response = requests.post(
            f"{self.base_url}/api/generate",
            headers=self.headers,
            json={
                "model": model,
                "prompt": prompt,
                "stream": stream
            }
        )
        return response.json()

# Usage
client = AllamaClient(api_key="your_api_key")
result = client.chat_completion(
    model="llama3",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(result)
```

### JavaScript Integration

```javascript
class AllamaClient {
    constructor(baseUrl = 'http://localhost:11435', apiKey = null) {
        this.baseUrl = baseUrl;
        this.apiKey = apiKey;
    }

    async chatCompletion(model, messages, stream = false) {
        const headers = {
            'Content-Type': 'application/json'
        };
        if (this.apiKey) {
            headers['Authorization'] = `Bearer ${this.apiKey}`;
        }

        const response = await fetch(`${this.baseUrl}/v1/chat/completions`, {
            method: 'POST',
            headers,
            body: JSON.stringify({
                model,
                messages,
                stream
            })
        });
        return response.json();
    }

    async generate(model, prompt, stream = false) {
        const headers = {
            'Content-Type': 'application/json'
        };
        if (this.apiKey) {
            headers['Authorization'] = `Bearer ${this.apiKey}`;
        }

        const response = await fetch(`${this.baseUrl}/api/generate`, {
            method: 'POST',
            headers,
            body: JSON.stringify({
                model,
                prompt,
                stream
            })
        });
        return response.json();
    }
}

// Usage
const client = new AllamaClient('http://localhost:11435', 'your_api_key');
const result = await client.chatCompletion('llama3', [
    { role: 'user', content: 'Hello!' }
]);
console.log(result);
```

### Go Integration

```go
package main

import (
    "bytes"
    "encoding/json"
    "net/http"
)

type AllamaClient struct {
    BaseURL string
    APIKey  string
}

type ChatRequest struct {
    Model    string        `json:"model"`
    Messages []Message     `json:"messages"`
    Stream   bool          `json:"stream"`
}

type Message struct {
    Role    string `json:"role"`
    Content string `json:"content"`
}

func (c *AllamaClient) ChatCompletion(req ChatRequest) (*http.Response, error) {
    body, err := json.Marshal(req)
    if err != nil {
        return nil, err
    }

    httpRequest, err := http.NewRequest(
        "POST",
        c.BaseURL+"/v1/chat/completions",
        bytes.NewBuffer(body),
    )
    if err != nil {
        return nil, err
    }

    httpRequest.Header.Set("Content-Type", "application/json")
    if c.APIKey != "" {
        httpRequest.Header.Set("Authorization", "Bearer "+c.APIKey)
    }

    client := &http.Client{}
    return client.Do(httpRequest)
}

func main() {
    client := AllamaClient{
        BaseURL: "http://localhost:11435",
        APIKey:  "your_api_key",
    }

    req := ChatRequest{
        Model: "llama3",
        Messages: []Message{
            {Role: "user", Content: "Hello!"},
        },
        Stream: false,
    }

    resp, err := client.ChatCompletion(req)
    if err != nil {
        panic(err)
    }
    defer resp.Body.Close()

    // Handle response
}
```

### Docker Integration

```dockerfile
# Dockerfile
FROM rust:1.75 as builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/allama /usr/local/bin/allama
EXPOSE 11435
CMD ["allama", "serve"]
```

```yaml
# docker-compose.yml
version: '3.8'
services:
  allama:
    build: .
    ports:
      - "11435:11435"
    volumes:
      - allama_models:/root/.allama/models
      - allama_config:/root/.allama
    environment:
      - OLLAMA_NUM_PARALLEL=4
      - RUST_LOG=info
    restart: unless-stopped

volumes:
  allama_models:
  allama_config:
```

## Monitoring & Alerting

### Metrics Export

**Prometheus Configuration:**
```bash
allama serve --metrics-port 9090
```

**Available Metrics:**
- `allama_requests_total`: Total number of requests
- `allama_request_duration_seconds`: Request duration
- `allama_cache_hits_total`: Cache hits
- `allama_cache_misses_total`: Cache misses
- `allama_errors_total`: Total errors
- `allama_active_connections`: Active connections

### Grafana Dashboard

**Sample Dashboard Queries:**
```promql
# Request rate
rate(allama_requests_total[5m])

# Error rate
rate(allama_errors_total[5m])

# Cache hit rate
rate(allama_cache_hits_total[5m]) / (rate(allama_cache_hits_total[5m]) + rate(allama_cache_misses_total[5m]))

# P95 latency
histogram_quantile(0.95, rate(allama_request_duration_seconds_bucket[5m]))
```

### Alerting Rules

```yaml
groups:
  - name: allama_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(allama_errors_total[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          
      - alert: LowCacheHitRate
        expr: rate(allama_cache_hits_total[5m]) / (rate(allama_cache_hits_total[5m]) + rate(allama_cache_misses_total[5m])) < 0.5
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Cache hit rate below 50%"
          
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(allama_request_duration_seconds_bucket[5m])) > 5
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "P95 latency above 5 seconds"
```

### Log Aggregation

**ELK Stack Integration:**
```bash
# Install Filebeat
# Configure to ship logs to Elasticsearch

# filebeat.yml
filebeat.inputs:
  - type: log
    paths:
      - ~/.allama/audit.log
      - ~/.allama/server.log
    json.keys_under_root: true
    json.add_error_key: true

output.elasticsearch:
  hosts: ["localhost:9200"]
```

**Splunk Integration:**
```bash
# Configure Splunk forwarder
# Monitor log files
# Set up indexes and sourcetypes
```

## Troubleshooting

### Common Issues

**Port Already in Use**
```bash
# Use automatic port allocation
allama serve --port 0

# Or specify a different port
allama serve --port 11436

# Find process using port
lsof -i :11435
kill -9 <PID>
```

**GPU Not Detected**
```bash
# Check GPU detection
allama ps --verbose

# Ensure GPU drivers are installed
# NVIDIA: nvidia-smi
# AMD: rocm-smi
# Apple Silicon: System Information

# Check GPU visibility
nvidia-smi -L

# Force CPU mode
CUDA_VISIBLE_DEVICES="" allama serve
```

**Authentication Failed**
```bash
# Check API key
allama list users

# Ensure X-Forwarded-For header is set for remote requests
curl -H "X-Forwarded-For: 127.0.0.1" ...

# Verify user exists and is active
curl http://localhost:11435/api/users \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

**Out of Memory**
```bash
# Reduce parallel workers
allama serve --parallel 1

# Reduce max loaded models
allama serve --max-loaded-models 1

# Enable MOE layer offloading
# Configure in config.json

# Check memory usage
ps aux | grep allama
top -p <PID>

# Increase swap space (Linux)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

**Slow Response Times**
```bash
# Check system load
uptime

# Check disk I/O
iostat -x 1

# Check network latency
ping localhost

# Enable caching
# Configure in config.json

# Reduce context length
# Model-specific configuration
```

**Model Loading Failures**
```bash
# Check model file integrity
sha256sum ~/.allama/models/*

# Verify model format
file ~/.allama/models/*

# Check disk space
df -h

# Re-download model
allama rm llama3
allama pull llama3
```

**Connection Refused**
```bash
# Check if server is running
allama status

# Check firewall rules
sudo ufw status
sudo iptables -L

# Check if port is listening
netstat -tlnp | grep 11435

# Restart server
allama stop
allama start
```

### Debug Mode

Enable debug logging:

```bash
# Enable debug logging
RUST_LOG=debug allama serve

# Enable trace logging (very verbose)
RUST_LOG=trace allama serve

# Enable specific module logging
RUST_LOG=allama::server=debug,allama::auth=info allama serve
```

### Log Files

- **Audit Log**: `~/.allama/audit.log`
- **Server Log**: `~/.allama/server.log`
- **Error Log**: `~/.allama/error.log`
- **Cache Log**: `~/.allama/cache.log` (if persistence enabled)

**View Logs:**
```bash
# View audit log
tail -f ~/.allama/audit.log

# View server log
tail -f ~/.allama/server.log

# Search for errors
grep -i error ~/.allama/*.log

# View recent logs
ls -lt ~/.allama/*.log | head -5
```

### Health Checks

**Basic Health Check:**
```bash
curl http://localhost:11435/api/health
```

**Detailed Health Check:**
```bash
curl http://localhost:11435/api/health/detailed
```

**Check Specific Components:**
```bash
# Check cache health
curl http://localhost:11435/api/cache/health

# Check GPU status
curl http://localhost:11435/api/gpu/status

# Check model status
curl http://localhost:11435/api/models/status
```

### Performance Profiling

**CPU Profiling:**
```bash
# Install perf (Linux)
sudo apt-get install linux-tools-generic

# Profile CPU usage
sudo perf record -g allama serve
sudo perf report
```

**Memory Profiling:**
```bash
# Use valgrind
valgrind --leak-check=full allama serve

# Or use heaptrack
heaptrack allama serve
```

**Network Profiling:**
```bash
# Use tcpdump
sudo tcpdump -i lo port 11435 -w capture.pcap

# Analyze with Wireshark
wireshark capture.pcap
```

### Getting Help

```bash
# General help
allama --help

# Command-specific help
allama serve --help
allama pull --help
allama run --help
```

### Support Resources

- **GitHub Issues**: https://github.com/arkCyber/allama/issues
- **Documentation**: https://github.com/arkCyber/allama
- **User Manual**: [docs/USER_MANUAL.md](USER_MANUAL.md)
- **Authentication Guide**: [docs/AUTHENTICATION_GUIDE.md](AUTHENTICATION_GUIDE.md)
- **DO-178C Compliance**: [DO-178C-COMPLIANCE.md](../DO-178C-COMPLIANCE.md)

### Common Error Messages

**"Connection refused"**
- Server not running
- Wrong port
- Firewall blocking

**"Authentication failed"**
- Invalid API key
- Missing X-Forwarded-For header
- User account disabled

**"Model not found"**
- Model not downloaded
- Model name incorrect
- Model filtered out

**"Out of memory"**
- Model too large for available memory
- Too many models loaded
- Memory leak

**"GPU not available"**
- GPU drivers not installed
- GPU not supported
- CUDA/ROCm/Metal not configured

### Recovery Procedures

**Restore from Backup:**
```bash
# Restore models from backup
cp -r /backup/allama/models/* ~/.allama/models/

# Restore configuration
cp /backup/allama/config.json ~/.allama/

# Restore audit logs
cp /backup/allama/audit.log ~/.allama/
```

**Reset to Default:**
```bash
# Stop server
allama stop

# Remove configuration
rm ~/.allama/config.json

# Remove models (optional)
rm -rf ~/.allama/models/*

# Restart server (will create default config)
allama start
```

**Factory Reset:**
```bash
# Stop all services
allama stop

# Remove all data
rm -rf ~/.allama/

# Reinstall
allama uninstall
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash
```
