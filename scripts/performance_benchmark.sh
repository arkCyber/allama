#!/bin/bash
# Performance benchmarking script for allama
# Aerospace-level performance monitoring

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
BENCHMARK_DIR="${PROJECT_ROOT}/benchmark_results"

echo "=== allama Performance Benchmarking ==="
echo "Project root: $PROJECT_ROOT"
echo "Build directory: $BUILD_DIR"
echo "Benchmark directory: $BENCHMARK_DIR"

# Create benchmark directory
mkdir -p "$BENCHMARK_DIR"

# Check if llama-bench is built
if [ ! -f "$BUILD_DIR/bin/llama-bench" ]; then
    echo "llama-bench not found. Building..."
    cd "$BUILD_DIR"
    cmake .. -DCMAKE_BUILD_TYPE=Release
    make llama-bench -j$(sysctl -n hw.ncpu)
fi

# Run benchmarks with different models
echo "Running performance benchmarks..."

# Benchmark 1: Tiny model
echo "Benchmark 1: Tiny model (15M)"
"$BUILD_DIR/bin/llama-bench" \
    -m tinyllamas/stories15M-q4_0.gguf \
    -ngl 99 \
    -n 512 \
    -p 128 \
    -t $(sysctl -n hw.ncpu) \
    > "$BENCHMARK_DIR/benchmark_tiny.txt" 2>&1

# Benchmark 2: Medium model (if available)
if [ -f "gemma-3-1b-it-Q4_K_M.gguf" ]; then
    echo "Benchmark 2: Medium model (1B)"
    "$BUILD_DIR/bin/llama-bench" \
        -m gemma-3-1b-it-Q4_K_M.gguf \
        -ngl 99 \
        -n 512 \
        -p 128 \
        -t $(sysctl -n hw.ncpu) \
        > "$BENCHMARK_DIR/benchmark_medium.txt" 2>&1
fi

# Benchmark 3: TurboQuant performance
echo "Benchmark 3: TurboQuant performance"
"$BUILD_DIR/bin/llama-bench" \
    -m tinyllamas/stories15M-q4_0.gguf \
    -ngl 99 \
    -n 512 \
    -p 128 \
    -t $(sysctl -n hw.ncpu) \
    --cache-type-k turbo3 \
    --cache-type-v turbo3 \
    > "$BENCHMARK_DIR/benchmark_turboquant.txt" 2>&1

# Generate performance report
echo "Generating performance report..."
cat > "$BENCHMARK_DIR/performance_report.md" << EOF
# allama Performance Benchmark Report

## System Information
- Date: $(date)
- CPU: $(sysctl -n machdep.cpu.brand_string)
- CPU Cores: $(sysctl -n hw.ncpu)
- Memory: $(sysctl -n hw.memsize) bytes

## Benchmark Results

### Tiny Model (15M)
EOF

if [ -f "$BENCHMARK_DIR/benchmark_tiny.txt" ]; then
    echo '```' >> "$BENCHMARK_DIR/performance_report.md"
    cat "$BENCHMARK_DIR/benchmark_tiny.txt" >> "$BENCHMARK_DIR/performance_report.md"
    echo '```' >> "$BENCHMARK_DIR/performance_report.md"
fi

if [ -f "$BENCHMARK_DIR/benchmark_turboquant.txt" ]; then
    echo -e "\n### TurboQuant Performance\n" >> "$BENCHMARK_DIR/performance_report.md"
    echo '```' >> "$BENCHMARK_DIR/performance_report.md"
    cat "$BENCHMARK_DIR/benchmark_turboquant.txt" >> "$BENCHMARK_DIR/performance_report.md"
    echo '```' >> "$BENCHMARK_DIR/performance_report.md"
fi

echo "Performance benchmarking completed"
echo "Report saved to: $BENCHMARK_DIR/performance_report.md"
