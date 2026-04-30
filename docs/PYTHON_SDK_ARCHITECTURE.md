# Python SDK Architecture Design

## Executive Summary

This document defines the architecture for the **allama Python SDK**, a Python library for interacting with allama model registry and inference server. The SDK provides a Pythonic interface for model management, inference, and integration with popular ML frameworks.

**Language**: Python 3.8+
**Package Name**: `allama`
**License**: MIT

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

The Python SDK enables developers to:

- Manage models through the allama registry
- Run inference with allama models
- Integrate with LangChain, LlamaIndex, and other frameworks
- Build custom applications on top of allama

### Key Features

- **Model Management**: Pull, list, show, delete, copy models
- **Inference**: Generate text, embeddings, and chat completions
- **Streaming**: Support for streaming responses
- **Async**: Async/await support for concurrent operations
- **Type Hints**: Full type annotations for better IDE support
- **Error Handling**: Comprehensive error handling and retry logic
- **Logging**: Structured logging integration

---

## Design Principles

### 1. Pythonic API

The SDK follows Python best practices and idioms:
- Context managers for resource management
- Type hints for IDE support
- Docstrings following PEP 257
- Consistent naming conventions (PEP 8)

### 2. Minimal Dependencies

The SDK has minimal dependencies:
- `httpx` for HTTP requests
- `pydantic` for data validation
- `typing-extensions` for type hints
- Optional: `numpy` for embeddings

### 3. Extensibility

The SDK is designed to be extensible:
- Abstract base classes for custom implementations
- Plugin system for custom integrations
- Callback hooks for lifecycle events

### 4. Performance

The SDK is optimized for performance:
- Connection pooling
- Async I/O for concurrent operations
- Efficient serialization/deserialization

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Application                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │LangChain │  │LlamaIndex│  │Custom App│  │Notebook  │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      allama Python SDK                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │Client Module │  │Model Module  │  │Inference Mod │     │
│  │              │  │              │  │              │     │
│  │- Client     │  │- Model       │  │- Chat        │     │
│  │- AsyncClient│  │- ModelInfo   │  │- Completion  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │Registry Mod │  │Embedding Mod │  │Integration   │     │
│  │              │  │              │  │              │     │
│  │- Registry   │  │- Embedding   │  │- LangChain   │     │
│  │- Pull/Push  │  │- Vector     │  │- LlamaIndex  │     │
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

### Module Structure

```
allama/
├── __init__.py
├── client.py              # Main client for inference
├── async_client.py        # Async client
├── registry.py            # Model registry client
├── models.py              # Model classes
├── chat.py                # Chat completion
├── completion.py          # Text completion
├── embedding.py           # Embedding generation
├── utils.py               # Utility functions
├── exceptions.py          # Custom exceptions
├── types.py               # Type definitions
├── integrations/
│   ├── __init__.py
│   ├── langchain.py        # LangChain integration
│   └── llamaindex.py       # LlamaIndex integration
└── cli/
    ├── __init__.py
    └── commands.py         # CLI commands
```

---

## API Reference

### Client Module

#### Initialization

```python
from allama import Client

# Sync client
client = Client(
    base_url="http://localhost:8080",
    api_key="your-api-key",
    timeout=30.0
)

# Async client
from allama import AsyncClient

async_client = AsyncClient(
    base_url="http://localhost:8080",
    api_key="your-api-key",
    timeout=30.0
)
```

#### Chat Completion

```python
from allama import Client

client = Client(base_url="http://localhost:8080")

# Basic chat
response = client.chat(
    model="llama3:latest",
    messages=[
        {"role": "user", "content": "Hello, how are you?"}
    ]
)
print(response.choices[0].message.content)

# Streaming
for chunk in client.chat.stream(
    model="llama3:latest",
    messages=[{"role": "user", "content": "Tell me a story"}]
):
    print(chunk.choices[0].delta.content, end="", flush=True)

# With parameters
response = client.chat(
    model="llama3:latest",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is the capital of France?"}
    ],
    temperature=0.7,
    max_tokens=100,
    top_p=0.9
)
```

#### Text Completion

```python
from allama import Client

client = Client(base_url="http://localhost:8080")

response = client.completion(
    model="llama3:latest",
    prompt="The meaning of life is",
    max_tokens=100,
    temperature=0.7
)
print(response.choices[0].text)
```

#### Embeddings

```python
from allama import Client

client = Client(base_url="http://localhost:8080")

response = client.embeddings(
    model="llama3:latest",
    input="Hello, world!"
)
print(response.data[0].embedding)
```

### Registry Module

#### Model Management

```python
from allama import Registry

registry = Registry(base_url="http://localhost:8080")

# List models
models = registry.list_models()
for model in models:
    print(f"{model.name}:{model.tag} - {model.size} bytes")

# Pull model
registry.pull("llama3:latest")

# Show model details
details = registry.show("llama3:latest")
print(f"Parameters: {details.parameters}")
print(f"Quantization: {details.quantization}")

# Delete model
registry.delete("llama3:latest")

# Copy model
registry.copy("llama3:latest", "llama3:custom")
```

### Integration Modules

#### LangChain Integration

```python
from allama.integrations.langchain import AllamaLLM

llm = AllamaLLM(
    model="llama3:latest",
    base_url="http://localhost:8080",
    temperature=0.7
)

response = llm.invoke("What is the capital of France?")
print(response)
```

#### LlamaIndex Integration

```python
from allama.integrations.llamaindex import AllamaLLM

llm = AllamaLLM(
    model="llama3:latest",
    base_url="http://localhost:8080"
)

response = llm.complete("What is the capital of France?")
print(response.text)
```

---

## Integration Points

### LangChain

The SDK provides a LangChain integration that implements the `BaseLanguageModel` interface:

```python
from langchain.chains import ConversationChain
from allama.integrations.langchain import AllamaLLM

llm = AllamaLLM(model="llama3:latest")
chain = ConversationChain(llm=llm)
response = chain.run("Hello!")
```

### LlamaIndex

The SDK provides a LlamaIndex integration that implements the `LLM` interface:

```python
from llama_index.core import VectorStoreIndex
from allama.integrations.llamaindex import AllamaLLM

llm = AllamaLLM(model="llama3:latest")
index = VectorStoreIndex.from_documents(documents)
query_engine = index.as_query_engine(llm=llm)
response = query_engine.query("What is the capital of France?")
```

---

## Implementation Roadmap

### Phase 6.1: Core SDK (4-6 weeks)

**Objective**: Implement core SDK functionality.

**Tasks**:
1. Set up Python project structure
2. Implement Client class with chat, completion, embeddings
3. Implement AsyncClient class
4. Implement Registry class for model management
5. Implement error handling and retry logic
6. Add type hints and docstrings
7. Write unit tests
8. Write integration tests

**Deliverables**:
- Working Python SDK
- PyPI package
- Documentation
- Test suite

### Phase 6.2: Integrations (4-6 weeks)

**Objective**: Add framework integrations.

**Tasks**:
1. Implement LangChain integration
2. Implement LlamaIndex integration
3. Implement Haystack integration (optional)
4. Write integration tests
5. Add examples and tutorials

**Deliverables**:
- LangChain integration
- LlamaIndex integration
- Integration documentation
- Example notebooks

### Phase 6.3: CLI Tool (2-4 weeks)

**Objective**: Add CLI commands for model management.

**Tasks**:
1. Implement CLI commands using Click
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

- **httpx**: HTTP client (sync and async)
- **pydantic**: Data validation
- **typing-extensions**: Type hints
- **click**: CLI framework

### Optional Dependencies

- **numpy**: For embeddings
- **pandas**: For data processing
- **rich**: For pretty CLI output
- **httpx[http2]**: For HTTP/2 support

### Development Dependencies

- **pytest**: Testing framework
- **pytest-asyncio**: Async testing
- **mypy**: Type checking
- **black**: Code formatting
- **ruff**: Linting
- **sphinx**: Documentation

---

## Security Considerations

### API Key Management

- API keys should be stored in environment variables
- Support for `.env` files via python-dotenv
- Never log API keys

### Input Validation

- All inputs are validated using Pydantic
- SQL injection prevention
- XSS prevention

### Secure Communication

- HTTPS by default
- Certificate validation
- Support for custom CA bundles

---

## Performance Considerations

### Connection Pooling

- HTTP connection pooling via httpx
- Configurable pool size
- Keep-alive connections

### Async I/O

- Full async/await support
- Concurrent requests
- Efficient resource usage

### Caching

- Model metadata caching
- Optional response caching
- Configurable TTL

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

### E2E Tests

- Test complete workflows
- Test with LangChain
- Test with LlamaIndex

---

## Documentation

### User Documentation

- Installation guide
- Quick start guide
- API reference
- Examples
- Tutorials

### Developer Documentation

- Architecture overview
- Contributing guide
- Code style guide
- Testing guide

---

## Version History

- **v1.0.0** (2026-04-30): Initial architecture design
