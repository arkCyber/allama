#!/bin/bash

# Simple inference test - just start service and check logs

set -e

echo "Starting inference service..."

./target/release/inference-service \
    --host 127.0.0.1 \
    --port 8081 \
    --models-dir "$HOME/.allama/models" \
    --max-loaded-models 3 \
    --context-size 4096 &

SERVICE_PID=$!
echo "Service PID: $SERVICE_PID"

# Cleanup on exit
cleanup() {
    echo "Stopping service..."
    kill $SERVICE_PID 2>/dev/null || true
}
trap cleanup EXIT

# Wait for service to start
sleep 5

# Health check
echo "Testing health endpoint..."
curl -s -X POST "http://127.0.0.1:8081/health"
echo ""

# Load model
echo "Loading model..."
curl -s -X POST "http://127.0.0.1:8081/load-model" \
    -H "Content-Type: application/json" \
    -d '{"model": "gemma-4-4b.gguf"}'
echo ""

sleep 5

# Simple inference
echo "Running inference..."
curl -v -X POST "http://127.0.0.1:8081/inference" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "gemma-4-4b.gguf",
        "prompt": "Hello",
        "max_tokens": 10,
        "temperature": 0.7
    }'
echo ""

# Wait to see logs
echo "Waiting for completion..."
sleep 30

echo "Done!"
