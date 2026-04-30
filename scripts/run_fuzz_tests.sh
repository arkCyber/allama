#!/bin/bash
# Fuzz testing script for allama
# Aerospace-level security testing using AFL/libFuzzer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
FUZZ_DIR="${PROJECT_ROOT}/fuzz_corpus"

echo "=== allama Fuzz Testing ==="
echo "Project root: $PROJECT_ROOT"
echo "Build directory: $BUILD_DIR"
echo "Fuzz corpus directory: $FUZZ_DIR"

# Create fuzz corpus directory
mkdir -p "$FUZZ_DIR"

# Check if fuzzer is built
if [ ! -f "$BUILD_DIR/bin/fuzz-test-gguf-parser" ]; then
    echo "Fuzzer not found. Building with sanitizers..."
    cd "$BUILD_DIR"
    cmake .. -DCMAKE_BUILD_TYPE=Debug -DLLAMA_SANITIZE_ADDRESS=ON -DLLAMA_BUILD_TESTS=ON
    make fuzz-test-gguf-parser
fi

# Run libFuzzer (if available)
if command -v "$BUILD_DIR/bin/fuzz-test-gguf-parser" &> /dev/null; then
    echo "Running libFuzzer..."
    timeout 300 "$BUILD_DIR/bin/fuzz-test-gguf-parser" \
        "$FUZZ_DIR" \
        -max_total_time=300 \
        -max_len=4096 \
        -print_final_stats=1 || true
fi

# Run AFL (if available)
if command -v afl-fuzz &> /dev/null; then
    echo "Running AFL..."
    afl-fuzz -i "$FUZZ_DIR" -o "$BUILD_DIR/afl_output" \
        -t 1000 \
        -m 512 \
        -- \
        "$BUILD_DIR/bin/fuzz-test-gguf-parser" @@ || true
fi

echo "Fuzz testing completed"
