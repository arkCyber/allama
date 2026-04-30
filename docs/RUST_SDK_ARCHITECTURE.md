# Rust SDK Architecture Design

## Executive Summary

This document defines the architecture for the **allama Rust SDK**, a Rust library for interacting with allama model registry and inference server. The SDK provides a Rust-native interface for model management, inference, and integration with popular Rust ML frameworks.

**Language**: Rust 1.70+
**Package Name**: `allama`
**License**: MIT
**Repository**: https://github.com/ggml-org/allama-rs

---

## Table of Contents

1. [Overview](#overview)
2. [Design Principles](#design-principles)
3. [Architecture](#architecture)
4. [API Reference](#api-reference)
5. [Integration Points](#integration-points)
6. [Implementation Roadmap](#implementation-roadmap)

---

## Overview

### Purpose

The Rust SDK enables developers to:

- Manage models through the allama registry
- Run inference with allama models
- Integrate with Rust ML frameworks (candle, burn, tract)
- Build high-performance applications on top of allama
- Leverage Rust's safety and performance guarantees

### Key Features

- **Model Management**: Pull, list, show, delete, copy models
- **Inference**: Generate text, embeddings, and chat completions
- **Streaming**: Support for streaming responses with async streams
- **Type Safety**: Full type safety with Rust's type system
- **Error Handling**: Comprehensive error handling with Result types
- **Async Support**: Full async/await support with tokio
- **Performance**: Zero-cost abstractions, minimal allocations

---

## Design Principles

### 1. Idiomatic Rust

The SDK follows Rust best practices:
- Builder pattern for configuration
- Result types for error handling
- Iterator traits for streaming
- Derive macros for common traits
- Consistent naming conventions

### 2. Minimal Dependencies

The SDK has minimal dependencies:
- `reqwest` for HTTP requests
- `serde` for serialization/deserialization
- `tokio` for async runtime
- `tracing` for logging

### 3. Type Safety

The SDK leverages Rust's type system:
- Strong typing for all data structures
- Enum-based error handling
- Compile-time guarantees
- No runtime type errors

### 4. Performance

The SDK is optimized for performance:
- Zero-copy deserialization where possible
- Connection pooling
- Efficient async I/O
- Minimal allocations

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Application                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │Candle    │  │Burn      │  │Tract     │  │Custom App│  │
│  │ML        │  │ML        │  │ML        │  │          │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      allama Rust SDK                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │Client Module │  │Model Module  │  │Inference Mod │     │
│  │              │  │              │  │              │     │
│  │- Client     │  │- Model       │  │- Chat        │     │
│  │- AsyncClient│  │- ModelInfo   │  │- Completion  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │Registry Mod │  │Embedding Mod │  │Streaming     │     │
│  │              │  │              │  │              │     │
│  │- Registry   │  │- Embedding   │  │- Stream      │     │
│  │- Pull/Push  │  │- Vector     │  │- AsyncStream │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    allama Server / CLI                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │llama-server  │  │allama CLI   │  │Model Registry│     │
│  │              │  │              │  │              │     │
│  │- HTTP API    │  │- pull/list  │  │- SQLite DB   │     │
│  │- OpenAI API  │  │- show/rm    │  │- Model Files │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### Crate Structure

```
allama/
├── Cargo.toml
├── src/
│   ├── lib.rs              # Library entry point
│   ├── client.rs           # Main client for inference
│   ├── async_client.rs     # Async client
│   ├── registry.rs         # Model registry client
│   ├── models.rs           # Model types and structs
│   ├── chat.rs             # Chat completion
│   ├── completion.rs       # Text completion
│   ├── embedding.rs        # Embedding generation
│   ├── streaming.rs        # Streaming utilities
│   ├── error.rs            # Error types
│   ├── types.rs            # Common types
│   └── integrations/
│       ├── mod.rs
│       ├── candle.rs       # Candle ML framework integration
│       └── burn.rs         # Burn ML framework integration
├── examples/
│   ├── chat.rs
│   ├── completion.rs
│   ├── embeddings.rs
│   └── streaming.rs
└── tests/
    ├── integration.rs
    └── models.rs
```

---

## API Reference

### Client Module

#### Initialization

```rust
use allama::Client;

// Sync client
let client = Client::builder()
    .base_url("http://localhost:8080")
    .api_key("your-api-key")
    .timeout(Duration::from_secs(30))
    .build()?;

// Async client
use allama::AsyncClient;

let client = AsyncClient::builder()
    .base_url("http://localhost:8080")
    .api_key("your-api-key")
    .timeout(Duration::from_secs(30))
    .build()?;
```

#### Chat Completion

```rust
use allama::Client;

let client = Client::builder()
    .base_url("http://localhost:8080")
    .build()?;

// Basic chat
let response = client.chat()
    .model("llama3:latest")
    .message("user", "Hello, how are you?")
    .send()?;

println!("{}", response.choices[0].message.content);

// Streaming
let mut stream = client.chat()
    .model("llama3:latest")
    .message("user", "Tell me a story")
    .stream()?;

while let Some(chunk) = stream.next().await {
    print!("{}", chunk.choices[0].delta.content);
}

// With parameters
let response = client.chat()
    .model("llama3:latest")
    .system_message("You are a helpful assistant.")
    .message("user", "What is the capital of France?")
    .temperature(0.7)
    .max_tokens(100)
    .top_p(0.9)
    .send()?;
```

#### Text Completion

```rust
use allama::Client;

let client = Client::builder()
    .base_url("http://localhost:8080")
    .build()?;

let response = client.completion()
    .model("llama3:latest")
    .prompt("The meaning of life is")
    .max_tokens(100)
    .temperature(0.7)
    .send()?;

println!("{}", response.choices[0].text);
```

#### Embeddings

```rust
use allama::Client;

let client = Client::builder()
    .base_url("http://localhost:8080")
    .build()?;

let response = client.embeddings()
    .model("llama3:latest")
    .input("Hello, world!")
    .send()?;

println!("{:?}", response.data[0].embedding);
```

### Registry Module

#### Model Management

```rust
use allama::Registry;

let registry = Registry::builder()
    .base_url("http://localhost:8080")
    .build()?;

// List models
let models = registry.list_models().await?;
for model in models {
    println!("{}:{} - {} bytes", model.name, model.tag, model.size);
}

// Pull model
registry.pull("llama3:latest").await?;

// Show model details
let details = registry.show("llama3:latest").await?;
println!("Parameters: {}", details.parameters);
println!("Quantization: {}", details.quantization);

// Delete model
registry.delete("llama3:latest").await?;

// Copy model
registry.copy("llama3:latest", "llama3:custom").await?;
```

### Integration Modules

#### Candle Integration

```rust
use allama::integrations::candle::AllamaLLM;

let llm = AllamaLLM::builder()
    .model("llama3:latest")
    .base_url("http://localhost:8080")
    .temperature(0.7)
    .build()?;

let response = llm.generate("What is the capital of France?")?;
println!("{}", response);
```

#### Burn Integration

```rust
use allama::integrations::burn::AllamaLLM;

let llm = AllamaLLM::builder()
    .model("llama3:latest")
    .base_url("http://localhost:8080")
    .build()?;

let response = llm.generate("What is the capital of France?")?;
println!("{}", response);
```

---

## Integration Points

### Candle ML Framework

The SDK provides a Candle integration that implements the `LLM` interface:

```rust
use candle_core::Tensor;
use allama::integrations::candle::AllamaLLM;

let llm = AllamaLLM::builder()
    .model("llama3:latest")
    .base_url("http://localhost:8080")
    .build()?;

let input = Tensor::new(vec![1i32, 2, 3], &[1, 2, 3])?;
let output = llm.forward(&input)?;
```

### Burn ML Framework

The SDK provides a Burn integration that implements the `LLM` interface:

```rust
use burn::tensor::Tensor;
use allama::integrations::burn::AllamaLLM;

let llm = AllamaLLM::builder()
    .model("llama3:latest")
    .base_url("http://localhost:8080")
    .build()?;

let input = Tensor::from_floats([1.0, 2.0, 3.0]);
let output = llm.generate(&input)?;
```

---

## Implementation Roadmap

### Phase 6.1: Core SDK (4-6 weeks)

**Objective**: Implement core SDK functionality.

**Tasks**:
1. Set up Rust project structure
2. Implement Client struct with chat, completion, embeddings
3. Implement AsyncClient struct with async methods
4. Implement Registry struct for model management
5. Implement error handling with Result types
6. Add builder patterns for configuration
7. Write unit tests
8. Write integration tests
9. Add documentation

**Deliverables**:
- Working Rust SDK
- crates.io package
- Documentation
- Test suite

### Phase 6.2: Streaming Support (2-4 weeks)

**Objective**: Add streaming support for responses.

**Tasks**:
1. Implement streaming utilities
2. Add async stream support
3. Implement SSE (Server-Sent Events) parsing
4. Add stream buffering
5. Write streaming tests

**Deliverables**:
- Streaming support
- Streaming examples
- Streaming tests

### Phase 6.3: Framework Integrations (4-6 weeks)

**Objective**: Add framework integrations.

**Tasks**:
1. Implement Candle integration
2. Implement Burn integration
3. Implement Tract integration (optional)
4. Write integration tests
5. Add examples

**Deliverables**:
- Candle integration
- Burn integration
- Integration documentation
- Example projects

### Phase 6.4: CLI Tool (2-4 weeks)

**Objective**: Add CLI commands for model management.

**Tasks**:
1. Implement CLI using clap
2. Add model pull/list/show/delete commands
3. Add inference commands
4. Add configuration management
5. Write CLI tests

**Deliverables**:
- CLI tool
- CLI documentation
- CLI tests

---

## Technology Stack

### Core Dependencies

- **reqwest**: HTTP client (sync and async)
- **serde**: Serialization/deserialization
- **serde_json**: JSON support
- **tokio**: Async runtime
- **tracing**: Structured logging
- **thiserror**: Error handling

### Optional Dependencies

- **candle**: Candle ML framework integration
- **burn**: Burn ML framework integration
- **tract**: Tract ML framework integration
- **ndarray**: For embeddings (optional)

### Development Dependencies

- **tokio-test**: Async testing
- **mockito**: Mocking for tests
- **criterion**: Benchmarking
- **clap**: CLI framework (for CLI tool)
- **cargo-doc**: Documentation generation

---

## Security Considerations

### API Key Management

- API keys should be stored in environment variables
- Support for `.env` files via dotenv
- Never log API keys

### Input Validation

- All inputs are validated with Rust's type system
- SQL injection prevention (not applicable for HTTP client)
- XSS prevention (not applicable for HTTP client)

### Secure Communication

- HTTPS by default
- Certificate validation
- Support for custom CA bundles via reqwest

### Memory Safety

- Rust's ownership system prevents memory leaks
- No unsafe code unless absolutely necessary
- All unsafe code is audited and documented

---

## Performance Considerations

### Connection Pooling

- HTTP connection pooling via reqwest
- Configurable pool size
- Keep-alive connections

### Async I/O

- Full async/await support with tokio
- Concurrent requests
- Efficient resource usage

### Zero-Copy

- Zero-copy deserialization where possible
- Efficient serialization
- Minimal allocations

---

## Testing Strategy

### Unit Tests

- Test all public API methods
- Mock HTTP responses
- Test error handling
- Test type validation

### Integration Tests

- Test against real allama server
- Test model operations
- Test inference operations
- Test streaming

### Benchmarks

- Benchmark API calls
- Benchmark serialization
- Benchmark streaming

---

## Documentation

### User Documentation

- Installation guide
- Quick start guide
- API reference (rustdoc)
- Examples
- Tutorials

### Developer Documentation

- Architecture overview
- Contributing guide
- Code style guide
- Testing guide

---

## Error Handling

### Error Types

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AllamaError {
    #[error("HTTP request failed: {0}")]
    RequestError(#[from] reqwest::Error),
    
    #[error("Serialization error: {0}")]
    SerializationError(#[from] serde_json::Error),
    
    #[error("API error: {0}")]
    ApiError(String),
    
    #[error("Model not found: {0}")]
    ModelNotFound(String),
    
    #[error("Invalid parameter: {0}")]
    InvalidParameter(String),
}
```

### Result Types

All functions return `Result<T, AllamaError>` for explicit error handling.

---

## Configuration

### Client Configuration

```rust
use allama::Client;

let client = Client::builder()
    .base_url("http://localhost:8080")
    .api_key("your-api-key")
    .timeout(Duration::from_secs(30))
    .max_retries(3)
    .user_agent("allama-rs/1.0.0")
    .build()?;
```

### Environment Variables

- `ALLAMA_BASE_URL`: Default base URL
- `ALLAMA_API_KEY`: Default API key
- `ALLAMA_TIMEOUT`: Default timeout in seconds
- `ALLAMA_MAX_RETRIES`: Default max retries

---

## Version History

- **v1.0.0** (2026-04-30): Initial architecture design
