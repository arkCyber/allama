#!/bin/bash

# allama One-Line Install Script
# Aerospace-Level Security Implementation
# This script installs allama and its dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ALLAMA_VERSION="1.0.0"
INSTALL_DIR="${ALLAMA_INSTALL_DIR:-/usr/local/bin}"
REPO_URL="https://github.com/ggml-org/llama-cpp-turboquant"
BINARY_NAME="allama"

# Functions
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "[INFO] $1"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS=Linux;;
        Darwin*)    OS=Mac;;
        CYGWIN*)    OS=Cygwin;;
        MINGW*)     OS=MinGW;;
        *)          OS="UNKNOWN:${uname -s}"
    esac
}

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64)     ARCH=amd64;;
        aarch64)    ARCH=arm64;;
        arm64)      ARCH=arm64;;
        *)          ARCH="UNKNOWN:${uname -m}"
    esac
}

# Check dependencies
check_dependencies() {
    print_info "Checking dependencies..."

    # Check for curl or wget
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        print_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    # Check for cmake
    if ! command -v cmake &> /dev/null; then
        print_warning "CMake not found. Installing CMake..."
        install_cmake
    fi

    # Check for git
    if ! command -v git &> /dev/null; then
        print_warning "Git not found. Installing Git..."
        install_git
    fi

    # Check for make
    if ! command -v make &> /dev/null; then
        print_warning "Make not found. Installing Make..."
        install_make
    fi

    print_success "All dependencies checked"
}

# Install CMake
install_cmake() {
    if [ "$OS" = "Mac" ]; then
        if command -v brew &> /dev/null; then
            brew install cmake
        else
            print_error "Homebrew not found. Please install Homebrew first."
            exit 1
        fi
    elif [ "$OS" = "Linux" ]; then
        if [ -f /etc/debian_version ]; then
            sudo apt-get update && sudo apt-get install -y cmake
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y cmake
        else
            print_error "Unsupported Linux distribution for automatic CMake installation."
            exit 1
        fi
    fi
}

# Install Git
install_git() {
    if [ "$OS" = "Mac" ]; then
        if command -v brew &> /dev/null; then
            brew install git
        else
            print_error "Homebrew not found. Please install Homebrew first."
            exit 1
        fi
    elif [ "$OS" = "Linux" ]; then
        if [ -f /etc/debian_version ]; then
            sudo apt-get update && sudo apt-get install -y git
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y git
        else
            print_error "Unsupported Linux distribution for automatic Git installation."
            exit 1
        fi
    fi
}

# Install Make
install_make() {
    if [ "$OS" = "Mac" ]; then
        if command -v brew &> /dev/null; then
            brew install make
        else
            print_error "Homebrew not found. Please install Homebrew first."
            exit 1
        fi
    elif [ "$OS" = "Linux" ]; then
        if [ -f /etc/debian_version ]; then
            sudo apt-get update && sudo apt-get install -y build-essential
        elif [ -f /etc/redhat-release ]; then
            sudo yum groupinstall -y "Development Tools"
        else
            print_error "Unsupported Linux distribution for automatic Make installation."
            exit 1
        fi
    fi
}

# Clone repository
clone_repo() {
    print_info "Cloning allama repository..."

    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    if command -v git &> /dev/null; then
        git clone --depth 1 "$REPO_URL" .
    else
        print_error "Git not available. Cannot clone repository."
        exit 1
    fi

    print_success "Repository cloned to $TEMP_DIR"
}

# Build allama
build_allama() {
    print_info "Building allama..."

    cd "$TEMP_DIR"
    mkdir -p build
    cd build

    cmake .. -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_ALLAMA=ON
    make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

    print_success "allama built successfully"
}

# Install allama
install_allama() {
    print_info "Installing allama to $INSTALL_DIR..."

    # Check if INSTALL_DIR exists and is writable
    if [ ! -d "$INSTALL_DIR" ]; then
        sudo mkdir -p "$INSTALL_DIR"
    fi

    # Copy binary
    if [ -w "$INSTALL_DIR" ]; then
        cp "$TEMP_DIR/build/bin/allama" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/allama"
    else
        sudo cp "$TEMP_DIR/build/bin/allama" "$INSTALL_DIR/"
        sudo chmod +x "$INSTALL_DIR/allama"
    fi

    # Create symbolic link for allama-server if it exists
    if [ -f "$TEMP_DIR/build/bin/llama-server" ]; then
        if [ -w "$INSTALL_DIR" ]; then
            cp "$TEMP_DIR/build/bin/llama-server" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/llama-server"
        else
            sudo cp "$TEMP_DIR/build/bin/llama-server" "$INSTALL_DIR/"
            sudo chmod +x "$INSTALL_DIR/llama-server"
        fi
    fi

    print_success "allama installed to $INSTALL_DIR/allama"
}

# Cleanup
cleanup() {
    print_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    print_success "Cleanup complete"
}

# Verify installation
verify_installation() {
    print_info "Verifying installation..."

    if command -v allama &> /dev/null; then
        ALLAMA_VERSION_OUTPUT=$(allama --version 2>/dev/null || echo "unknown")
        print_success "allama installed successfully (version: $ALLAMA_VERSION_OUTPUT)"
    else
        print_error "allama not found in PATH. Please add $INSTALL_DIR to your PATH."
        exit 1
    fi
}

# Print usage
print_usage() {
    cat << EOF
allama Installation Complete!

To get started:

1. Verify installation:
   allama --version

2. List available models:
   allama list

3. Pull a model:
   allama pull llama3:latest

4. Run the server:
   llama-server --model ~/.allama/models/llama3:latest

For more information:
   allama --help
   https://github.com/ggml-org/llama-cpp-turboquant

Model Registry:
   Default registry path: ~/.allama/registry.db
   Default models path: ~/.allama/models/

To customize paths:
   export ALLAMA_REGISTRY_PATH=/custom/path/registry.db
   export ALLAMA_MODELS_PATH=/custom/path/models
EOF
}

# Main installation flow
main() {
    echo "========================================"
    echo "allama One-Line Install Script"
    echo "Version: $ALLAMA_VERSION"
    echo "========================================"
    echo ""

    detect_os
    detect_arch

    print_info "Detected OS: $OS"
    print_info "Detected Architecture: $ARCH"
    echo ""

    # Check if running as root (not recommended)
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root is not recommended. Please run without sudo."
    fi

    # Check dependencies
    check_dependencies
    echo ""

    # Clone repository
    clone_repo
    echo ""

    # Build allama
    build_allama
    echo ""

    # Install allama
    install_allama
    echo ""

    # Cleanup
    cleanup
    echo ""

    # Verify installation
    verify_installation
    echo ""

    # Print usage
    print_usage
}

# Run main function
main "$@"
