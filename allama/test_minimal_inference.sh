#!/bin/bash

# Minimal inference test - just generate 1 token

set -e

echo "Starting minimal inference test..."

./target/release/inference-service \
    --host 127.0.0.1 \
    --port 8082 \
    --models-dir "$HOME/.allama/models" \
    --max-loaded-models 1 \
    --context-size 2048 &

SERVICE_PID=$!
echo "Service PID: $SERVICE_PID"

cleanup() {
    echo "Stopping service..."
    kill $SERVICE_PID 2>/dev/null || true
}
trap cleanup EXIT

sleep 5

# Load model
echo "Loading model..."
curl -s -X POST "http://127.0.0.1:8082/load-model" \
    -H "Content-Type: application/json" \
    -d '{"model": "gemma-4-4b.gguf"}'
echo ""

sleep 5

# Minimal inference - just 1 token
echo "Running minimal inference (1 token)..."
curl -X POST "http://127.0.0.1:8082/inference" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "gemma-4-4b.gguf",
        "prompt": "Hi",
        "max_tokens": 1,
        "temperature": 0.7
    }' 2>&1 | python3 -m json.tool || echo "Request failed"

echo ""
echo "Waiting for logs..."
sleep 5

echo "Done!"
