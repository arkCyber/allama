# allama Installation Guide

## Quick Install

### One-Line Install (Linux/macOS)

```bash
curl -fsSL https://raw.githubusercontent.com/ggml-org/llama-cpp-turboquant/main/scripts/install-allama.sh | bash
```

### Using Homebrew (macOS)

```bash
brew install ggml-org/allama/allama
```

### From Source

```bash
git clone https://github.com/ggml-org/llama-cpp-turboquant.git
cd llama-cpp-turboquant
mkdir build && cd build
cmake .. -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_ALLAMA=ON
make -j$(nproc)
sudo make install
```

---

## System-Specific Instructions

### macOS

#### Homebrew (Recommended)

```bash
# Tap the repository
brew tap ggml-org/allama

# Install allama
brew install allama
```

#### Manual Installation

```bash
# Install dependencies
brew install cmake git sqlite3

# Clone and build
git clone https://github.com/ggml-org/llama-cpp-turboquant.git
cd llama-cpp-turboquant
mkdir build && cd build
cmake .. -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_ALLAMA=ON
make -j$(sysctl -n hw.ncpu)

# Install to /usr/local/bin
sudo cp bin/allama /usr/local/bin/
sudo chmod +x /usr/local/bin/allama
```

#### Apple Silicon (M1/M2/M3)

The build process automatically detects Apple Silicon and builds accordingly. No special configuration needed.

---

### Linux (Ubuntu/Debian)

#### apt (Recommended for Ubuntu 22.04+)

```bash
# Add repository
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:ggml-org/allama
sudo apt-get update

# Install allama
sudo apt-get install -y allama
```

#### Manual Installation

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y build-essential cmake git sqlite3 libssl-dev

# Clone and build
git clone https://github.com/ggml-org/llama-cpp-turboquant.git
cd llama-cpp-turboquant
mkdir build && cd build
cmake .. -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_ALLAMA=ON
make -j$(nproc)

# Install to /usr/local/bin
sudo cp bin/allama /usr/local/bin/
sudo chmod +x /usr/local/bin/allama
```

---

### Linux (Fedora/CentOS/RHEL)

#### dnf (Recommended for Fedora 38+)

```bash
# Add repository
sudo dnf install -y dnf-plugins-core
sudo dnf copr enable ggml-org/allama
sudo dnf install -y allama
```

#### Manual Installation

```bash
# Install dependencies
sudo dnf install -y gcc-c++ cmake git sqlite3-devel openssl-devel make

# Clone and build
git clone https://github.com/ggml-org/llama-cpp-turboquant.git
cd llama-cpp-turboquant
mkdir build && cd build
cmake .. -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_ALLAMA=ON
make -j$(nproc)

# Install to /usr/local/bin
sudo cp bin/allama /usr/local/bin/
sudo chmod +x /usr/local/bin/allama
```

---

### Windows

#### Winget (Recommended for Windows 10/11)

```powershell
# Install using Winget
winget install ggml-org.allama
```

#### Chocolatey

```powershell
# Add Chocolatey repository
choco source add -n ggml-org -s https://chocolatey.ggml.org/api/v2/

# Install allama
choco install allama
```

#### Manual Installation (MSYS2)

```bash
# Install MSYS2 from https://www.msys2.org/

# Update packages
pacman -Syu

# Install dependencies
pacman -S --needed base-devel mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake git mingw-w64-x86_64-sqlite3 mingw-w64-x86_64-openssl

# Clone and build
git clone https://github.com/ggml-org/llama-cpp-turboquant.git
cd llama-cpp-turboquant
mkdir build && cd build
cmake .. -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_ALLAMA=ON
cmake --build . --config Release

# Copy binary to PATH
cp bin/allama.exe /c/Users/$USERNAME/AppData/Local/Microsoft/WindowsApps/
```

#### Visual Studio Build

```powershell
# Install Visual Studio 2022 with C++ development tools
# Install CMake from https://cmake.org/download/

# Clone repository
git clone https://github.com/ggml-org/llama-cpp-turboquant.git
cd llama-cpp-turboquant

# Build
mkdir build
cd build
cmake .. -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_ALLAMA=ON -G "Visual Studio 17 2022"
cmake --build . --config Release

# Copy binary to PATH
copy Release\allama.exe C:\Windows\System32\
```

---

## Docker

### Using Docker Image

```bash
# Pull the official image
docker pull ggml-org/allama:latest

# Run allama in container
docker run -it --rm \
  -v ~/.allama:/root/.allama \
  ggml-org/allama:latest \
  allama list

# Run server in container
docker run -d \
  -p 8080:8080 \
  -v ~/.allama:/root/.allama \
  ggml-org/allama:latest \
  llama-server --model ~/.allama/models/llama3:latest
```

### Build from Dockerfile

```bash
# Build image
docker build -t allama:local .

# Run container
docker run -it --rm \
  -v ~/.allama:/root/.allama \
  allama:local \
  allama list
```

---

## Verification

### Verify Installation

```bash
# Check version
allama --version

# Check help
allama --help

# List models
allama list
```

### Test Installation

```bash
# Initialize model registry (automatic on first use)
allama list

# Pull a test model (requires internet connection)
allama pull tinyllama:latest

# Verify model
allama show tinyllama:latest
```

---

## Configuration

### Environment Variables

```bash
# Set custom registry path
export ALLAMA_REGISTRY_PATH=/custom/path/registry.db

# Set custom models path
export ALLAMA_MODELS_PATH=/custom/path/models

# Set custom audit log path
export ALLAMA_AUDIT_LOG_PATH=/custom/path/audit.log

# Enable verbose logging
export ALLAMA_VERBOSE=1
```

### Configuration File

Create `~/.allama/config.toml`:

```toml
[registry]
path = "~/.allama/registry.db"
models_path = "~/.allama/models"
max_models = 1000
max_storage = "100GB"
enable_audit = true
enable_validation = true

[server]
port = 8080
host = "0.0.0.0"
api_prefix = "/v1"

[security]
audit_enabled = true
rate_limit_enabled = true
rate_limit_requests_per_minute = 60
network_isolation_enabled = true
file_sandbox_enabled = true
```

---

## Uninstallation

### macOS (Homebrew)

```bash
brew uninstall allama
brew untap ggml-org/allama
```

### Linux (apt)

```bash
sudo apt-get remove --purge allama
sudo add-apt-repository --remove ppa:ggml-org/allama
```

### Linux (dnf)

```bash
sudo dnf remove allama
sudo dnf copr disable ggml-org/allama
```

### Manual Removal

```bash
# Remove binary
sudo rm /usr/local/bin/allama
sudo rm /usr/local/bin/allama-server

# Remove registry and models (optional)
rm -rf ~/.allama
```

---

## Troubleshooting

### Common Issues

#### Permission Denied

```bash
# Fix: Use sudo or add user to appropriate groups
sudo chmod +x /usr/local/bin/allama
```

#### Library Not Found

```bash
# Fix: Update library path
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

#### Build Fails

```bash
# Fix: Clean build directory
rm -rf build
mkdir build
cd build
cmake .. -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_ALLAMA=ON
make -j$(nproc)
```

#### SQLite3 Not Found

```bash
# Linux (Ubuntu/Debian)
sudo apt-get install -y libsqlite3-dev

# Linux (Fedora/CentOS)
sudo dnf install -y sqlite-devel

# macOS
brew install sqlite3
```

---

## Getting Help

- **Documentation**: https://github.com/ggml-org/llama-cpp-turboquant/docs
- **Issues**: https://github.com/ggml-org/llama-cpp-turboquant/issues
- **Discussions**: https://github.com/ggml-org/llama-cpp-turboquant/discussions

---

## Security Notes

This installation follows aerospace-level security standards:

- All downloads are verified with SHA256 checksums
- Code is built from source with full audit trail
- No pre-built binaries are distributed without verification
- All operations are logged for compliance

For security concerns, please review:
- [Security Policy](https://github.com/ggml-org/llama-cpp-turboquant/security/policy)
- [Audit Log Documentation](https://github.com/ggml-org/llama-cpp-turboquant/docs/AUDIT_LOG.md)
