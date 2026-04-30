#!/bin/bash
# Coverage generation script for allama
# Aerospace-level code coverage analysis

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
COVERAGE_DIR="${PROJECT_ROOT}/coverage"

echo "=== allama Coverage Generation ==="
echo "Project root: $PROJECT_ROOT"
echo "Build directory: $BUILD_DIR"
echo "Coverage directory: $COVERAGE_DIR"

# Clean previous coverage data
echo "Cleaning previous coverage data..."
rm -rf "$COVERAGE_DIR"
mkdir -p "$COVERAGE_DIR"

# Configure with coverage enabled
echo "Configuring with coverage enabled..."
cd "$BUILD_DIR"
cmake .. -DCMAKE_BUILD_TYPE=Debug -DLLAMA_COVERAGE=ON

# Build with coverage
echo "Building with coverage..."
make -j$(sysctl -n hw.ncpu)

# Run tests
echo "Running tests..."
ctest --output-on-failure

# Generate coverage data
echo "Generating coverage data..."
lcov --capture --directory "$BUILD_DIR" --output-file "$COVERAGE_DIR/coverage.info"

# Filter out system headers and test files
echo "Filtering coverage data..."
lcov --remove "$COVERAGE_DIR/coverage.info" \
    '/usr/include/*' \
    '/Applications/*' \
    '*/tests/*' \
    '*/examples/*' \
    '*/pocs/*' \
    '*/vendor/*' \
    --output-file "$COVERAGE_DIR/coverage_filtered.info"

# Generate HTML report
echo "Generating HTML report..."
genhtml "$COVERAGE_DIR/coverage_filtered.info" \
    --output-directory "$COVERAGE_DIR/html" \
    --title "allama Coverage Report" \
    --legend \
    --show-details

# Generate summary
echo "Generating coverage summary..."
lcov --summary "$COVERAGE_DIR/coverage_filtered.info"

# Check coverage threshold (aerospace-level requirement: >90%)
echo "Checking coverage threshold..."
LINES_COVERED=$(lcov --summary "$COVERAGE_DIR/coverage_filtered.info" 2>&1 | grep "lines" | awk '{print $2}' | tr -d '%')
echo "Lines covered: ${LINES_COVERED}%"

if (( $(echo "$LINES_COVERED < 90" | bc -l) )); then
    echo "WARNING: Coverage (${LINES_COVERED}%) is below aerospace-level threshold (90%)"
    exit 1
else
    echo "SUCCESS: Coverage (${LINES_COVERED}%) meets aerospace-level threshold (90%)"
fi

echo "Coverage report generated at: $COVERAGE_DIR/html/index.html"
