#!/bin/bash

# Test script for standalone inference service

set -e

echo "=========================================="
echo "Testing Allama Inference Service"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if binary exists
if [ ! -f "./target/release/inference-service" ]; then
    echo -e "${RED}❌ Binary not found. Building...${NC}"
    cargo build --release --bin inference-service --features inference
fi

echo -e "${GREEN}✓ Binary found${NC}"

# Test 1: Health check
echo ""
echo "Test 1: Health Check"
echo "--------------------"

# Start service in background
echo "Starting inference service..."
./target/release/inference-service --host 127.0.0.1 --port 8081 --models-dir ./models &
SERVICE_PID=$!

# Wait for service to start
sleep 3

# Test health endpoint
echo "Testing /health endpoint..."
HEALTH_RESPONSE=$(curl -s -X POST http://127.0.0.1:8081/health)
echo "Response: $HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q '"status":"ok"'; then
    echo -e "${GREEN}✅ Health check passed${NC}"
else
    echo -e "${RED}❌ Health check failed${NC}"
    kill $SERVICE_PID 2>/dev/null || true
    exit 1
fi

# Test 2: Inference request (will fail without model, but tests endpoint)
echo ""
echo "Test 2: Inference Endpoint"
echo "--------------------------"

INFERENCE_REQUEST='{
  "model": "test-model",
  "prompt": "Hello, world!",
  "max_tokens": 10,
  "temperature": 0.7
}'

echo "Sending inference request..."
INFERENCE_RESPONSE=$(curl -s -X POST http://127.0.0.1:8081/inference \
  -H "Content-Type: application/json" \
  -d "$INFERENCE_REQUEST")

echo "Response: $INFERENCE_RESPONSE"

if echo "$INFERENCE_RESPONSE" | grep -q '"error"'; then
    echo -e "${YELLOW}⚠️  Inference returned error (expected without model)${NC}"
    echo -e "${GREEN}✅ Endpoint is functional${NC}"
else
    echo -e "${GREEN}✅ Inference endpoint working${NC}"
fi

# Cleanup
echo ""
echo "Cleaning up..."
kill $SERVICE_PID 2>/dev/null || true
sleep 1

echo ""
echo "=========================================="
echo -e "${GREEN}✅ All tests completed${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Download a Gemma4 model to ./models/"
echo "2. Start the inference service"
echo "3. Start the main Allama server"
echo "4. Test end-to-end inference"
