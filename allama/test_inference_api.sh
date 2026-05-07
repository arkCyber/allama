#!/bin/bash

# Allama Gemma4 Inference API Test Script
# Aerospace-level testing protocol

set -e

echo "════════════════════════════════════════════════════════════════"
echo "🚀 Allama Gemma4 Inference API Test Suite"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Configuration
SERVER_URL="http://127.0.0.1:11435"
API_KEY="test-api-key-12345"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "────────────────────────────────────────────────────────────────"
    echo "📋 Test: $test_name"
    echo "────────────────────────────────────────────────────────────────"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASSED${NC}: $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAILED${NC}: $test_name"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Test 1: Server Health Check
test_health() {
    echo "Checking server health..."
    curl -s -f "$SERVER_URL/metrics" > /dev/null
}

# Test 2: API Tags Endpoint
test_tags() {
    echo "Testing /api/tags endpoint..."
    response=$(curl -s -X GET "$SERVER_URL/api/tags" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json")
    echo "Response: $response"
    echo "$response" | grep -q "models"
}

# Test 3: Generate API - Simple Prompt
test_generate_simple() {
    echo "Testing /api/generate with simple prompt..."
    response=$(curl -s -X POST "$SERVER_URL/api/generate" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gemma-2-2b-it",
            "prompt": "Hello, how are you?",
            "stream": false
        }')
    echo "Response: $response"
    echo "$response" | grep -q "response"
}

# Test 4: Generate API - Math Problem
test_generate_math() {
    echo "Testing /api/generate with math problem..."
    response=$(curl -s -X POST "$SERVER_URL/api/generate" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gemma-2-2b-it",
            "prompt": "What is 15 + 27?",
            "stream": false
        }')
    echo "Response: $response"
    echo "$response" | grep -q "response"
}

# Test 5: Generate API - Code Generation
test_generate_code() {
    echo "Testing /api/generate with code generation..."
    response=$(curl -s -X POST "$SERVER_URL/api/generate" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gemma-2-2b-it",
            "prompt": "Write a Python function to calculate fibonacci numbers",
            "stream": false
        }')
    echo "Response: $response"
    echo "$response" | grep -q "response"
}

# Test 6: Generate API - Empty Model Name (Should Fail)
test_generate_empty_model() {
    echo "Testing /api/generate with empty model name (should fail)..."
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$SERVER_URL/api/generate" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "",
            "prompt": "Test",
            "stream": false
        }')
    echo "HTTP Code: $http_code"
    [ "$http_code" = "400" ]
}

# Test 7: Generate API - Long Prompt (Should Fail)
test_generate_long_prompt() {
    echo "Testing /api/generate with very long prompt (should fail)..."
    long_prompt=$(python3 -c "print('A' * 100001)")
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$SERVER_URL/api/generate" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"gemma-2-2b-it\",
            \"prompt\": \"$long_prompt\",
            \"stream\": false
        }")
    echo "HTTP Code: $http_code"
    [ "$http_code" = "400" ]
}

# Run all tests
echo "Starting test suite..."
echo ""

run_test "Server Health Check" "test_health"
run_test "API Tags Endpoint" "test_tags"
run_test "Generate API - Simple Prompt" "test_generate_simple"
run_test "Generate API - Math Problem" "test_generate_math"
run_test "Generate API - Code Generation" "test_generate_code"
run_test "Generate API - Empty Model (Validation)" "test_generate_empty_model"
run_test "Generate API - Long Prompt (Validation)" "test_generate_long_prompt"

# Summary
echo "════════════════════════════════════════════════════════════════"
echo "📊 Test Summary"
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ Passed: $TESTS_PASSED${NC}"
echo -e "${RED}❌ Failed: $TESTS_FAILED${NC}"
echo "Total: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some tests failed${NC}"
    exit 1
fi
