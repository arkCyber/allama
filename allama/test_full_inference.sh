#!/bin/bash

# Full inference test - generate multiple tokens

set -e

echo "=========================================="
echo "Full Gemma Inference Test"
echo "=========================================="

./target/release/inference-service \
    --host 127.0.0.1 \
    --port 8083 \
    --models-dir "$HOME/.allama/models" \
    --max-loaded-models 1 \
    --context-size 4096 &

SERVICE_PID=$!
echo "Service PID: $SERVICE_PID"

cleanup() {
    echo ""
    echo "Stopping service..."
    kill $SERVICE_PID 2>/dev/null || true
}
trap cleanup EXIT

sleep 5

# Load model
echo "Loading Gemma 4B model..."
curl -s -X POST "http://127.0.0.1:8083/load-model" \
    -H "Content-Type: application/json" \
    -d '{"model": "gemma-4-4b.gguf"}'
echo ""

sleep 5

# Test 1: Short generation
echo "=========================================="
echo "Test 1: Short Generation (10 tokens)"
echo "=========================================="
curl -X POST "http://127.0.0.1:8083/inference" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "gemma-4-4b.gguf",
        "prompt": "The capital of France is",
        "max_tokens": 10,
        "temperature": 0.7
    }' 2>&1 | python3 -m json.tool || echo "Request failed"

echo ""
sleep 2

# Test 2: Medium generation
echo "=========================================="
echo "Test 2: Medium Generation (20 tokens)"
echo "=========================================="
curl -X POST "http://127.0.0.1:8083/inference" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "gemma-4-4b.gguf",
        "prompt": "Explain quantum computing:",
        "max_tokens": 20,
        "temperature": 0.8
    }' 2>&1 | python3 -m json.tool || echo "Request failed"

echo ""
sleep 2

# Test 3: Greedy sampling
echo "=========================================="
echo "Test 3: Greedy Sampling (15 tokens)"
echo "=========================================="
curl -X POST "http://127.0.0.1:8083/inference" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "gemma-4-4b.gguf",
        "prompt": "Hello, how are you?",
        "max_tokens": 15,
        "temperature": 0.1
    }' 2>&1 | python3 -m json.tool || echo "Request failed"

echo ""
echo "=========================================="
echo "All tests completed!"
echo "=========================================="

sleep 5
