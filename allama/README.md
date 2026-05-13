# Allama

Aerospace-Level Security Enhanced LLM Inference Server

Allama is a Rust-based, aerospace-grade LLM inference server that provides enterprise-grade authentication, billing, and monitoring capabilities. It aligns with Ollama's API methodology while adding advanced security features, user management, and token-based billing.

## Key Features

### Authentication & User Management
- **API Key Authentication**: Secure Bearer token authentication for remote requests
- **User Management**: Create, list, and manage user accounts
- **Default Test User**: Automatic creation of a default test account for quick testing
- **Rate Limiting**: Configurable per-user rate limits (requests per minute)
- **Monthly Quotas**: Token-based monthly quotas for billing control
- **Local Request Bypass**: Local requests (127.0.0.1) bypass authentication for development

### Billing & Usage Tracking
- **Token Counting**: Accurate token counting for prompt and completion
- **Usage Records**: Detailed billing records with timestamps, user info, and endpoints
- **Billing API**: RESTful API for querying usage records and statistics
- **User Attribution**: All requests are attributed to specific users for billing

### OpenAI API Compatibility
- **Chat Completions**: `/v1/chat/completions` endpoint
- **Completions**: `/v1/completions` endpoint
- **Embeddings**: `/v1/embeddings` endpoint
- **Drop-in Replacement**: Compatible with OpenAI SDKs

### Aerospace-Level Security
- **Code Signing & Verification**: HMAC-SHA256 based binary signing
- **Audit Logging**: Tamper-evident logging for all operations
- **Integrity Hashing**: Cryptographic integrity verification
- **Secure Random Generation**: Cryptographically secure key generation
- **Binary Integrity**: Runtime verification of executable integrity

### Fault Tolerance
- **Timeout Protection**: Configurable timeouts for all operations
- **Retry Mechanisms**: Exponential backoff for transient failures
- **Graceful Degradation**: System continues with reduced functionality on failures
- **Signal Handling**: Clean shutdown on SIGTERM/SIGINT
- **Watchdog Timers**: Prevent infinite loops and deadlocks

### Hardware Acceleration
- **Automatic GPU Detection**: NVIDIA (CUDA), Apple Silicon (Metal), AMD (ROCm)
- **Dynamic VRAM Allocation**: Automatic context length configuration
- **CPU Fallback**: Automatic CPU inference when GPU unavailable
- **Resource Monitoring**: Real-time CPU, memory, disk I/O, and network I/O monitoring

### Response Caching
- **Intelligent Caching**: LRU/LFU/FIFO eviction strategies
- **Configurable TTL**: Time-to-live for cached responses
- **Cache Statistics**: Hit rate, miss rate, and eviction tracking
- **Size Limits**: Configurable maximum cache size and entry count

### Model Management
- **Model Discovery**: Automatic discovery from Hugging Face cache, Ollama, and local directories
- **Model Filtering**: Filter models by type (text, image, audio) and size
- **Custom Models**: Create and manage custom model configurations
- **Model Persistence**: Save and load model configurations
- **Large Model Support**: Support for 26B+ models with 96k+ context windows via llama-server integration

### Mixture of Experts (MOE)
- **Hybrid Processing**: CPU/GPU hybrid processing for large models
- **Layer Allocation**: Intelligent layer allocation based on compute intensity
- **Expert Routing**: Load-balanced and compute-based routing strategies
- **Memory Optimization**: Dynamic layer offloading to manage VRAM constraints

### Large Model Support
- **26B Model Support**: Gemma4 26B with 96k context window via llama-server
- **TurboQuant**: Automatic sparse V dequantization for memory optimization
- **Context Management**: Efficient KV cache allocation for long contexts
- **GPU Offloading**: Full layer and KV cache offloading to GPU

### Memory Optimization
- **mmap Support**: Memory-mapped file loading for fast model loading and reduced memory usage
- **Smart Backend Selection**: Automatic CPU/GPU backend selection based on model size
- **Optimized Parameters**: Aerospace-level optimized model and context parameters
- **Memory Monitoring**: Real-time memory usage tracking and optimization
- **Context Window Scaling**: Support for up to 256k context windows with proper memory management

### Metrics & Monitoring
- **Performance Metrics**: Request duration, throughput, error rates
- **Resource Metrics**: CPU, memory, disk, and network usage
- **Custom Metrics**: Counters, gauges, and histograms
- **Prometheus Export**: Export metrics in Prometheus format

### Anomaly Detection
- **Resource Anomalies**: Detect unusual resource usage patterns
- **Performance Anomalies**: Identify performance degradation
- **Threshold Alerts**: Configurable thresholds for anomaly detection
- **Automatic Monitoring**: Continuous monitoring of system health

### Service Management
- **Background Service**: Run as a system service (Windows Service, systemd, launchd)
- **Auto-start**: Configure automatic startup on boot
- **Service Status**: Check service status and health
- **Service Control**: Start, stop, and restart services

### Update Management
- **Automatic Updates**: Check for and install updates automatically
- **Version Checking**: Compare installed version with latest release
- **Rollback Support**: Rollback to previous versions if needed
- **Update Notifications**: Notify users of available updates

## Pre-built Binaries

Allama provides pre-built binaries for multiple platforms, enabling you to download and use it without compilation.

### Supported Platforms

- **Linux**: x86_64 (amd64), ARM64 (aarch64)
- **macOS**: x86_64 (Intel), ARM64 (Apple Silicon), Universal Binary
- **Windows**: x86_64

### Features Included

Pre-built binaries include:
- All GPU backends (CUDA, Metal, ROCm)
- Automatic hardware detection
- Complete feature set (authentication, billing, monitoring)
- Static linking (no external dependencies required)
- Optimized for performance (LTO, strip symbols)

### Download Options

#### Automatic Installation Script

```bash
# Install latest version
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash

# Install specific version
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash -s v1.0.0

# Install to custom directory
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash -s latest /opt/allama
```

#### Manual Download

Visit [GitHub Releases](https://github.com/arkCyber/allama/releases) to download:

**Binaries:**
- `allama-linux-amd64.tar.gz` - Linux x86_64
- `allama-linux-arm64.tar.gz` - Linux ARM64
- `allama-macos-amd64.tar.gz` - macOS Intel
- `allama-macos-arm64.tar.gz` - macOS Apple Silicon
- `allama-macos-universal.tar.gz` - macOS Universal Binary
- `allama-windows-amd64.zip` - Windows x86_64

**Installers:**
- `allama-*-macos.dmg` - macOS DMG Installer (drag-and-drop installation)
- `allama-*-windows-setup.exe` - Windows Installer (NSIS-based)
- `allama_*_amd64.deb` - Linux Debian/Ubuntu Package

Each release includes:
- The binary executable
- SHA256 checksum file
- Release notes

#### Verification

After downloading, verify the integrity:

```bash
# Download the checksum file
wget https://github.com/arkCyber/allama/releases/download/v1.0.0/SHA256SUMS.txt

# Verify
sha256sum -c SHA256SUMS.txt
```

### Installation from Binary

#### Option A: Using Installer (Recommended)

**macOS:**
```bash
# Download and open the .dmg file
# Double-click the DMG to mount it
# Drag Allama.app to Applications folder

# Or install from command line
hdiutil attach allama-*-macos.dmg
cp -R /Volumes/Allama/Allama.app /Applications/
hdiutil detach /Volumes/Allama

# Run from Applications
/Applications/Allama.app/Contents/MacOS/allama --help
```

**Windows:**
```bash
# Double-click the .exe installer
# Follow the installation wizard
# The installer will:
#   - Copy allama.exe to Program Files
#   - Add to system PATH
#   - Create Start Menu shortcuts
#   - Register uninstaller
```

**Linux (Debian/Ubuntu):**
```bash
# Install the .deb package
sudo dpkg -i allama_*_amd64.deb
sudo apt-get install -f  # Handle dependencies

# The package will:
#   - Install to /usr/bin/allama
#   - Create allama user
#   - Set up data directory at /var/lib/allama
#   - Install man page
```

#### Option B: Manual Binary Installation

```bash
# Extract
tar -xzf allama-linux-amd64.tar.gz

# Make executable
chmod +x allama-linux-amd64

# Move to PATH
sudo mv allama-linux-amd64 /usr/local/bin/allama

# Or use in current directory
./allama-linux-amd64 --help
```

### Building Release Binaries

If you want to build release binaries yourself:

```bash
# Install cross-compilation tools (Linux)
sudo apt-get install gcc-aarch64-linux-gnu gcc-x86-64-linux-gnu

# Or use cross-rs for Windows builds
cargo install cross

# Build all platforms
chmod +x scripts/build-release.sh
./scripts/build-release.sh

# Build specific version
./scripts/build-release.sh v1.0.0
```

This will create static binaries with:
- Maximum optimization (-O3)
- Link-time optimization (LTO)
- Stripped symbols
- Static linking where possible

### Building Installers

To build platform-specific installers:

**macOS DMG:**
```bash
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh v1.0.0
```

**Windows EXE (requires NSIS):**
```bash
# Install NSIS from https://nsis.sourceforge.io/
chmod +x scripts/build-installer.sh
./scripts/build-installer.sh v1.0.0
```

**Linux DEB:**
```bash
chmod +x scripts/build-deb.sh
./scripts/build-deb.sh v1.0.0
```

## CLI Commands

Allama provides a comprehensive CLI aligned with Ollama's methodology:

### Installation Commands
```bash
allama install [--dir <path>]    # Install allama
allama uninstall                 # Uninstall allama
allama update                    # Update to latest version
allama version                   # Show version information
```

### Service Management
```bash
allama start                     # Start allama service
allama stop                      # Stop allama service
allama status                    # Check service status
```

### Model Management
```bash
allama list                      # List available models (alias: ls)
allama pull <model>              # Download a model
allama run <model>               # Run a model interactively
allama show <model>              # Show model details
allama rm <model>                # Remove a model
allama ps                        # List running models
allama stop <model>              # Stop a running model
```

### Model Operations
```bash
allama create <model> [--from <file>]  # Create a custom model
allama cp <source> <dest>              # Copy a model
allama push <model> [--insecure]       # Push a model to registry
```

### Importing from Ollama

```bash
# Import models from Ollama installation
./scripts/import-from-ollama.sh
```

This script copies models from your Ollama installation to Allama, or you can enable model discovery to use Ollama models directly without copying.

### Server & Integration
```bash
allama serve [--host <host>] [--port <port>] [--parallel <n>]  # Start server
allama launch [integration] [model] [config]                  # Launch integrations
```

### Cloud Integration
```bash
allama signin                     # Sign in to Ollama Cloud
allama signout                    # Sign out of Ollama Cloud
```

### Model Control
```bash
allama stop-model <model>         # Stop a running model
```

### Environment Variables
- `OLLAMA_HOST`: Default host for server (default: 127.0.0.1)
- `OLLAMA_NUM_PARALLEL`: Number of parallel requests (default: 1)
- `OLLAMA_MAX_LOADED_MODELS`: Maximum loaded models (default: 3)
- `OLLAMA_MAX_QUEUE`: Maximum queue size (default: 512)

## Quick Start

### Installation

#### Option 1: Pre-built Binary (Recommended)

Download and install the pre-built binary for your platform:

```bash
# Linux x86_64
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash

# macOS (Apple Silicon)
curl -fsSL https://raw.githubusercontent.com/arkCyber/allama/main/scripts/install.sh | bash

# Or manually download from GitHub Releases
# Visit: https://github.com/arkCyber/allama/releases
```

The installer will:
- Detect your platform automatically
- Download the appropriate binary
- Verify the checksum
- Install to `~/.allama/` by default
- Add to PATH in your shell configuration

#### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/arkCyber/allama.git
cd allama

# Build in release mode
cargo build --release

# The binary will be at target/release/allama
```

#### Option 3: Build Release Binaries

To build release binaries for all platforms:

```bash
# Make the build script executable
chmod +x scripts/build-release.sh

# Build for all platforms
./scripts/build-release.sh

# Binaries will be in dist/release-<version>/
```

### Starting the Server

```bash
# Start the server (default port 11435)
./allama serve

# Start with custom port
./allama serve --port 8080

# Start with custom host
./allama serve --host 0.0.0.0 --port 8080

# Start with parallel workers
./allama serve --parallel 4
```

When the server starts, it will automatically create a default test user and display the API key:

```
==========================================
Default Test User Created
==========================================
Username: test_user
API Key: allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm
Rate Limit: 60 requests/minute
Monthly Quota: 100000 tokens
==========================================
```

### Making API Requests

#### Local Requests (No Authentication Required)

```bash
# Generate text
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","prompt":"Hello, world!","stream":false}'

# Chat completion
curl -X POST http://localhost:11435/api/chat \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","messages":[{"role":"user","content":"Hello!"}],"stream":false}'
```

#### Optional `thinking` (chain-of-thought)

If the model wraps internal reasoning in supported XML-style tag pairs (see `src/inference/thinking.rs` in this crate), Allama strips those regions from the visible completion and may return them in the JSON field `thinking` on **`/api/generate`** and **`/api/chat`**. See `examples/thinking_split_app.rs`, `examples/thinking_generate_response.rs`, and [docs/USER_MANUAL.md](docs/USER_MANUAL.md#chain-of-thought-thinking).

#### Remote Requests (Authentication Required)

```bash
# Using the default test user API key
curl -X POST http://your-server:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"Hello, world!","stream":false}'
```

## Authentication

### Creating a New User

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
  "created_at": "2026-05-03T08:00:00Z"
}
```

### Listing All Users

```bash
curl -X GET http://localhost:11435/api/users \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

### Default Test User

The server automatically creates a default test user with:
- **Username**: `test_user`
- **Rate Limit**: 60 requests/minute
- **Monthly Quota**: 100,000 tokens
- **API Key**: Displayed on server startup

This account is intended for development and testing only. For production, create dedicated user accounts.

For detailed authentication documentation, see [docs/AUTHENTICATION_GUIDE.md](docs/AUTHENTICATION_GUIDE.md).

## API Endpoints

### Ollama-Compatible Endpoints

| Endpoint | Method | Auth Required | Description |
|----------|--------|--------------|-------------|
| `/api/tags` | GET | No | List available models |
| `/api/tags/:model` | GET | No | Get model information |
| `/api/generate` | POST | Remote only | Generate text (optional `thinking` when model emits tagged CoT) |
| `/api/chat` | POST | Remote only | Chat completion (optional `thinking`; `message.content` is stripped text) |
| `/api/embed` | POST | Remote only | Generate embeddings |
| `/api/ps` | GET | No | List running models |
| `/api/show` | POST | Yes | Show model details |
| `/api/delete` | DELETE | Yes | Delete a model |
| `/api/pull` | POST | Yes | Pull a model |
| `/api/push` | POST | Yes | Push a model |
| `/api/create` | POST | Yes | Create a model |
| `/api/copy` | POST | Yes | Copy a model |
| `/api/stop` | POST | Yes | Stop a model |
| `/api/version` | GET | No | Get version information |
| `/api/users` | POST | No | Create user |
| `/api/users` | GET | Yes | List users |

### OpenAI-Compatible Endpoints

| Endpoint | Method | Auth Required | Description |
|----------|--------|--------------|-------------|
| `/v1/chat/completions` | POST | Remote only | Chat completions (OpenAI-compatible) |
| `/v1/completions` | POST | Remote only | Text completions (OpenAI-compatible) |
| `/v1/embeddings` | POST | Remote only | Embeddings (OpenAI-compatible) |

### Billing Endpoints

| Endpoint | Method | Auth Required | Description |
|----------|--------|--------------|-------------|
| `/api/billing/records` | GET | Yes | Get billing records |
| `/api/billing/summary` | GET | Yes | Get billing summary |
| `/api/billing/stats/:model` | GET | Yes | Get model statistics |

### Authentication Strategy

- **Local Requests**: Requests from `127.0.0.1`, `::1`, or `localhost` bypass authentication
- **Remote Requests**: All other requests require a valid API key via `Authorization: Bearer <key>` header
- **Detection**: Uses `X-Forwarded-For` or `X-Real-IP` headers to determine client IP

## Billing

### Querying Usage Records

```bash
curl -X GET "http://localhost:11435/api/billing/records?limit=10" \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

### Getting Billing Summary

```bash
curl -X GET http://localhost:11435/api/billing/summary \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

### Model Statistics

```bash
curl -X GET http://localhost:11435/api/billing/stats/llama3 \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

## OpenAI SDK Compatibility

### Python Example

```python
import requests

# Use the default test user API key
api_key = "allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm"
base_url = "http://localhost:11435"

response = requests.post(
    f"{base_url}/v1/chat/completions",
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    },
    json={
        "model": "llama3",
        "messages": [
            {"role": "user", "content": "Hello!"}
        ]
    }
)
print(response.json())
```

### JavaScript/Node.js Example

```javascript
const axios = require('axios');

const apiKey = "allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm";
const baseUrl = "http://localhost:11435";

async function chat() {
  const response = await axios.post(
    `${baseUrl}/v1/chat/completions`,
    {
      model: 'llama3',
      messages: [
        {role: 'user', content: 'Hello!'}
      ]
    },
    {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      }
    }
  );
  console.log(response.data);
}

chat();
```

## Installation

### Prerequisites
- **Windows**: Windows 10 or later
- **macOS**: macOS 10.15 (Catalina) or later
- **Linux**: Most modern distributions (Ubuntu, Debian, Fedora, etc.)
- **Rust**: 1.70 or later (for building from source)

### Building from Source

```bash
# Clone the repository
git clone https://github.com/arkCyber/allama.git
cd allama

# Build for current platform
cargo build --release

# The binary will be at target/release/allama
```

### Cross-Platform Building

```bash
# Build for Windows (from Linux/macOS)
./build-windows.sh

# Build for macOS
./build-macos.sh

# Build for Linux
./build-linux.sh
```

## Architecture

### Project Structure

```
allama/
├── src/
│   ├── main.rs              # CLI entry point
│   ├── server/              # HTTP server and API endpoints
│   ├── auth/                # Authentication and user management
│   ├── billing/             # Billing and usage tracking
│   ├── model/               # Model management
│   │   ├── model_filter.rs  # Model filtering
│   │   ├── model_discovery.rs # Model discovery
│   │   └── response_cache.rs # Response caching
│   ├── moe/                 # Mixture of Experts
│   ├── audit/               # Audit logging
│   ├── fault/               # Fault tolerance
│   ├── security/            # Security features
│   ├── metrics/             # Metrics collection
│   ├── anomaly/             # Anomaly detection
│   ├── gpu/                 # GPU detection
│   ├── network/             # Network utilities
│   ├── service/             # Service management
│   ├── update/              # Update management
│   ├── config/              # Configuration
│   ├── installer/           # Installation
│   ├── platform/             # Platform-specific code
│   └── logging/             # Logging
├── docs/
│   ├── USER_MANUAL.md       # User manual
│   ├── AUTHENTICATION_GUIDE.md  # Authentication documentation
│   └── ...
├── tests/
│   └── integration/         # Integration tests
├── scripts/
│   ├── build-release.sh      # Release build script
│   ├── build-dmg.sh         # macOS DMG builder
│   ├── build-installer.sh   # Windows installer builder
│   ├── build-deb.sh         # Linux DEB builder
│   └── install.sh           # Installation script
├── examples/                # Example scripts
├── Cargo.toml               # Dependencies
└── README.md                # This file
```

### Key Components

#### Authentication Module (`src/auth/`)
- User management with API key generation
- Secure API key storage with SHA-256 hashing
- Rate limiting and quota enforcement
- Default test user creation

#### Billing Module (`src/billing/`)
- Token counting for all requests
- Usage record storage with user attribution
- Billing statistics and summaries
- Time-based querying

#### Model Management (`src/model/`)
- **Model Filter** (`model_filter.rs`): Filter models by type and size
- **Model Discovery** (`model_discovery.rs`): Discover models from multiple sources
- **Response Cache** (`response_cache.rs`): Intelligent caching with LRU/LFU/FIFO

#### Server Module (`src/server/`)
- HTTP API server with Axum
- Ollama-compatible endpoints
- OpenAI-compatible endpoints
- Authentication middleware
- Rate limiting and graceful degradation

#### MOE Module (`src/moe/`)
- Mixture of Experts implementation
- Hybrid CPU/GPU processing
- Layer allocation and offloading
- Expert routing strategies

#### Metrics Module (`src/metrics/`)
- Performance metrics collection
- Resource monitoring
- Prometheus export
- Custom counters, gauges, histograms

#### Anomaly Detection (`src/anomaly/`)
- Resource anomaly detection
- Performance anomaly detection
- Threshold-based alerting
- Continuous health monitoring

#### Service Management (`src/service/`)
- Background service management
- System service integration (systemd, launchd, Windows Service)
- Auto-start configuration
- Service status monitoring

## Examples

### Large Model Testing

Allama includes comprehensive examples for testing large models with long context windows:

```bash
# Test Gemma4 26B with 96k context (requires llama-server)
cargo run --example gemma4_26b_96k_context --features inference

# Test simple model inference
cargo run --example gemma4_simple_test --features inference

# Test long context scenarios
cargo run --example gemma4_long_context --features inference
```

**Note**: The 26B model example requires llama-server (not inference-service FFI backend) due to memory management requirements for large models with 96k context windows. See `examples/README.md` for details.

### Ollama-style HTTP, batch payloads, and thinking (testable without a model)

Rust examples under `examples/` include unit tests for JSON builders and chain-of-thought splitting:

```bash
cd allama

# Library + integration tests (default features include `inference`)
cargo test --features inference

# Selected example unit tests (no running server)
cargo test --example ollama_compatible_api_client --features inference
cargo test --example batch_generate_payloads
cargo test --example thinking_split_app --features inference
cargo test --example thinking_generate_response --features inference

# Optional: live HTTP smoke against `allama serve` (version + tags)
ALLAMA_HTTP_SMOKE=1 cargo run --example ollama_compatible_api_client
```

Full automated script (tests + example checks): `bash scripts/run_automated_tests.sh`.

### Memory Optimization Testing

Allama includes mmap verification and memory optimization testing:

```bash
# Verify mmap functionality
bash examples/mmap_verification_test.sh

# Test memory usage with different context sizes
cargo run --example memory_stress_test --features inference
```

See [ALLAMA_MMAP_AUDIT_AND_TEST_REPORT.md](ALLAMA_MMAP_AUDIT_AND_TEST_REPORT.md) for detailed mmap testing results.

## Development

### Running Tests

```bash
cd allama

# Full crate tests (recommended: enable inference)
cargo test --features inference

# Same as CI helper: library tests + selected `cargo test --example …` + `cargo check` on examples
bash scripts/run_automated_tests.sh

# Legacy integration shell scripts (optional)
bash tests/integration/run_all_tests.sh

# Run specific remote auth script
bash tests/integration/remote_auth_test.sh
```

### Publishing changes to GitHub

From the repository root (or `allama/` for the Rust crate only):

```bash
git status
git add README.md allama/README.md allama/docs/USER_MANUAL.md allama/examples/README.md
git commit -m "docs: update README, user manual, and examples index"
git push origin <your-branch>
```

Then open a **Pull Request** on GitHub against the default branch. For upstream **llama.cpp**–related policies, see `AGENTS.md` / `CONTRIBUTING.md` if you contribute to those projects.

### Adding New Features

1. Implement feature in appropriate module
2. Add authentication if needed for API endpoints
3. Add billing records for token-based operations
4. Add audit logging for security-relevant operations
5. Add integration tests
6. Update documentation

### Security Guidelines

- All API endpoints must have appropriate authentication
- Local requests (127.0.0.1) should bypass authentication for development
- Remote requests must require valid API keys
- Never log or expose API keys in plain text
- Use SHA-256 for API key hashing

## Documentation

- **User Manual**: [docs/USER_MANUAL.md](docs/USER_MANUAL.md) - Comprehensive user guide (includes `thinking` / examples table under *Integration Examples*)
- **Authentication Guide**: [docs/AUTHENTICATION_GUIDE.md](docs/AUTHENTICATION_GUIDE.md)
- **Examples index**: [examples/README.md](examples/README.md) - Application demos and shell tests
- **API Endpoints**: See API Endpoints section above
- **Automated test driver**: `bash scripts/run_automated_tests.sh` from the `allama/` directory

## Alignment with Ollama

Allama aligns with Ollama's API methodology while adding enterprise features:

| Feature | Ollama | Allama |
|---------|--------|--------|
| One-click installation | ✅ | ✅ |
| Background service | ✅ | ✅ |
| GPU detection | ✅ | ✅ |
| OpenAI-compatible API | ✅ | ✅ |
| Authentication | ❌ | ✅ API Key-based |
| User Management | ❌ | ✅ |
| Billing/Usage Tracking | ❌ | ✅ |
| Rate Limiting | ❌ | ✅ |
| Audit Logging | ❌ | ✅ Aerospace-level |
| Fault Tolerance | ❌ | ✅ Aerospace-level |

## DO-178C Compliance

This project is designed with aerospace certification requirements in mind:

### Safety Critical Features
- Deterministic behavior in critical paths
- Fail-safe operation modes
- Comprehensive error handling
- Audit trail for all operations

### Security Requirements
- API key authentication for remote access
- Integrity verification at runtime
- Tamper-evident logging
- Secure cryptographic operations

### Fault Tolerance
- Timeout protection prevents hangs
- Retry mechanisms handle transient failures
- Graceful degradation ensures continued operation
- Watchdog timers prevent infinite loops

## License

MIT License - Same as llama.cpp

## Acknowledgments

Based on [Ollama](https://github.com/ollama/ollama) API methodology.
Built with [Rust](https://www.rust-lang.org/) for reliability and performance.
Aerospace-level security features inspired by DO-178C certification requirements.

## Contributing

This project follows the [llama.cpp contributing guidelines](../../CONTRIBUTING.md) with additional requirements:
- All changes must be tested on all target platforms
- Security features must maintain aerospace-level standards
- Code must be thoroughly documented
- Audit logging must be added for all new operations
- Fault tolerance mechanisms must be applied to all new features
- Authentication must be added to all public API endpoints
- Billing records must be added to token-based operations

**Important:** This project does not accept fully AI-generated pull requests. AI tools may be used only in an assistive capacity. See [CONTRIBUTING.md](../../CONTRIBUTING.md) for details.

## Support

For issues and questions:
- GitHub Issues: https://github.com/arkCyber/allama/issues
- Documentation: https://github.com/arkCyber/allama
- User Manual: [docs/USER_MANUAL.md](docs/USER_MANUAL.md)
- Authentication Guide: [docs/AUTHENTICATION_GUIDE.md](docs/AUTHENTICATION_GUIDE.md)
