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

## Quick Start

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
| `/api/generate` | POST | Remote only | Generate text |
| `/api/chat` | POST | Remote only | Chat completion |
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
│   ├── audit/               # Audit logging
│   ├── fault/               # Fault tolerance
│   └── security/            # Security features
├── docs/
│   ├── AUTHENTICATION_GUIDE.md  # Authentication documentation
│   └── ...
├── tests/
│   └── integration/         # Integration tests
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

#### Server Module (`src/server/`)
- HTTP API server with Axum
- Ollama-compatible endpoints
- OpenAI-compatible endpoints
- Authentication middleware

## Development

### Running Tests

```bash
# Run all tests
cargo test

# Run integration tests
bash tests/integration/run_all_tests.sh

# Run specific test
bash tests/integration/remote_auth_test.sh
```

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

- **Authentication Guide**: [docs/AUTHENTICATION_GUIDE.md](docs/AUTHENTICATION_GUIDE.md)
- **API Endpoints**: See API Endpoints section above
- **Examples**: See `examples/` directory

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
- Authentication Guide: [docs/AUTHENTICATION_GUIDE.md](docs/AUTHENTICATION_GUIDE.md)
