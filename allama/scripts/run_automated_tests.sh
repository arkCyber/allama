#!/usr/bin/env bash
# Allama automated test driver — run from repo root or allama/ directory.
# Usage: ./scripts/run_automated_tests.sh   OR   bash allama/scripts/run_automated_tests.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Allama automated tests (cargo test)"
cargo test --no-fail-fast

echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Example ollama_compatible_api_client (unit tests, no server)"
cargo test --example ollama_compatible_api_client --features inference --no-fail-fast

echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Example batch_generate_payloads (unit tests)"
cargo test --example batch_generate_payloads --no-fail-fast

echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Example thinking_split_app (thinking / CoT, unit tests)"
cargo test --example thinking_split_app --features inference --no-fail-fast

echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Example thinking_generate_response (generate + stream finalize)"
cargo test --example thinking_generate_response --features inference --no-fail-fast

echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Examples compile check (selected)"
cargo check --example web_search_direct --example web_search_http_client --example ollama_compatible_api_client --example batch_generate_payloads --example thinking_split_app --example thinking_generate_response --features inference

echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Done."
