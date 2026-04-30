# Modelfile DSL Specification

## Aerospace-Level Security Implementation

This document defines the Modelfile DSL (Domain-Specific Language) for allama, designed to be compatible with ollama's Modelfile format while adding aerospace-level security features, formal verification support, and enhanced functionality.

---

## Table of Contents

1. [Overview](#overview)
2. [Design Principles](#design-principments)
3. [Syntax Reference](#syntax-reference)
4. [Security Features](#security-features)
5. [Formal Verification](#formal-verification)
6. [Examples](#examples)
7. [Comparison with Ollama](#comparison-with-ollama)
8. [Implementation Notes](#implementation-notes)

---

## Overview

The Modelfile DSL provides a declarative way to define LLM models, their parameters, quantization settings, and runtime behavior. It enables:

- Custom model creation from base models
- Quantization configuration
- Adapter (LoRA) integration
- Template customization
- Security policy definition
- Resource constraints
- Audit logging configuration

### Goals

1. **Ollama Compatibility**: Maintain compatibility with ollama's Modelfile format
2. **Security-First**: Add aerospace-level security features
3. **Formal Verification**: Support ACSL annotations for formal verification
4. **Extensibility**: Allow for future enhancements
5. **Simplicity**: Keep the syntax simple and readable

---

## Design Principles

### 1. Declarative Syntax

The Modelfile uses a declarative syntax that describes what the model should be, not how to create it.

### 2. Security by Default

All security features are enabled by default and must be explicitly disabled.

### 3. Validation at Parse Time

All Modelfiles are validated during parsing, with comprehensive error reporting.

### 4. Backward Compatibility

All ollama Modelfiles are valid allama Modelfiles.

### 5. Forward Compatibility

New directives are ignored by older parsers (with warnings).

---

## Syntax Reference

### File Structure

A Modelfile consists of directives, each on its own line or spanning multiple lines with line continuation (`\`).

```
DIRECTIVE VALUE
DIRECTIVE "VALUE WITH SPACES"
DIRECTIVE VALUE \
    CONTINUED_VALUE
```

### Comments

Comments start with `#` and extend to the end of the line.

```
# This is a comment
PARAMETER value  # inline comment
```

### Directives

#### FROM

Specifies the base model to use. Required.

```
FROM llama3:latest
FROM /path/to/model.gguf
FROM https://huggingface.co/model.gguf
```

**Security Considerations**:
- Remote URLs are validated against a whitelist
- SHA256 digests are required for remote models
- File paths are validated for directory traversal attacks

#### PARAMETER

Sets model parameters.

```
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER num_ctx 4096
PARAMETER repeat_penalty 1.1
```

**Supported Parameters**:
- `temperature` (float): Sampling temperature (0.0 - 2.0)
- `top_p` (float): Nucleus sampling threshold (0.0 - 1.0)
- `top_k` (int): Top-k sampling (1 - 100)
- `num_ctx` (int): Context window size (1 - 32768)
- `num_predict` (int): Maximum tokens to predict
- `repeat_penalty` (float): Repetition penalty (0.0 - 2.0)
- `num_gpu` (int): Number of GPU layers (0 - all)
- `seed` (int): Random seed
- `num_thread` (int): Number of threads
- `stop` (string): Stop sequence (can be specified multiple times)

#### LICENSE

Specifies the model license.

```
LICENSE MIT
LICENSE Apache-2.0
LICENSE GPL-3.0
```

#### TEMPLATE

Defines the chat template.

```
TEMPLATE """
{{- if .System }}
<|start_header_id|>system<|end_header_id|>

{{ .System }}<|eot_id|>{{ end }}
{{- range .Messages }}
<|start_header_id|>{{ .Role }}<|end_header_id|>

{{ .Content }}<|eot_id|>{{ end }}
<|start_header_id|>assistant<|end_header_id|>

"""
```

Template variables:
- `{{ .System }}`: System prompt
- `{{ .Messages }}`: Message array
- `{{ .Role }}`: Message role (user/assistant/system)
- `{{ .Content }}`: Message content

#### ADAPTER

Adds LoRA adapters.

```
ADAPTER /path/to/adapter.gguf
ADAPTER https://huggingface.co/adapter.gguf
```

**Security Considerations**:
- Adapters are validated against the base model
- SHA256 digests are required for remote adapters
- Adapter size limits are enforced

#### QUANTIZE

Specifies quantization settings.

```
QUANTIZE Q4_K_M
QUANTIZE Q8_0
QUANTIZE F16
```

**Supported Quantization**:
- `F16`: 16-bit float (no quantization)
- `Q8_0`: 8-bit quantization
- `Q5_K_M`: 5-bit quantization (medium)
- `Q5_K_S`: 5-bit quantization (small)
- `Q4_K_M`: 4-bit quantization (medium)
- `Q4_K_S`: 4-bit quantization (small)
- `Q3_K_M`: 3-bit quantization (medium)
- `Q3_K_S`: 3-bit quantization (small)
- `Q2_K`: 2-bit quantization

#### SECURITY

Defines security policies (allama-specific).

```
SECURITY audit_enabled true
SECURITY rate_limit_enabled true
SECURITY rate_limit_requests_per_minute 60
SECURITY rate_limit_tokens_per_minute 10000
SECURITY network_isolation_enabled true
SECURITY allowed_hosts localhost,127.0.0.1
SECURITY file_sandbox_enabled true
SECURITY allowed_directories ~/.allama/models
SECURITY max_file_size 10GB
SECURITY gpu_isolation_enabled true
SECURITY max_gpu_memory 8GB
SECURITY anomaly_detection_enabled true
SECURITY audit_log_path /var/log/allama/audit.log
```

**Security Directives**:
- `audit_enabled`: Enable audit logging (default: true)
- `rate_limit_enabled`: Enable rate limiting (default: true)
- `rate_limit_requests_per_minute`: Request rate limit
- `rate_limit_tokens_per_minute`: Token rate limit
- `network_isolation_enabled`: Enable network isolation (default: true)
- `allowed_hosts`: Comma-separated list of allowed hosts
- `file_sandbox_enabled`: Enable file sandbox (default: true)
- `allowed_directories`: Comma-separated list of allowed directories
- `max_file_size`: Maximum file size for model files
- `gpu_isolation_enabled`: Enable GPU isolation (default: true)
- `max_gpu_memory`: Maximum GPU memory per tenant
- `anomaly_detection_enabled`: Enable anomaly detection (default: true)
- `audit_log_path`: Path to audit log file

#### RESOURCE

Defines resource constraints (allama-specific).

```
RESOURCE max_memory 16GB
RESOURCE max_cpu_cores 8
RESOURCE max_gpu_memory 8GB
RESOURCE max_disk_space 100GB
RESOURCE max_concurrent_requests 4
```

#### METADATA

Adds custom metadata.

```
METADATA author "Your Name"
METADATA description "Model description"
METADATA version "1.0.0"
METADATA tags "chat,code,assistant"
```

#### MESSAGE

Adds example messages for few-shot learning.

```
MESSAGE user Hello
MESSAGE assistant Hi there! How can I help you?
MESSAGE user What is 2+2?
MESSAGE assistant 2+2 equals 4.
```

#### SYSTEM

Sets the system prompt.

```
SYSTEM You are a helpful assistant.
```

---

## Security Features

### 1. Input Validation

All Modelfile directives are validated for:
- Type correctness
- Range validation
- Format validation
- Security constraints

### 2. Path Traversal Prevention

File paths are validated to prevent directory traversal attacks:
- `../` sequences are rejected
- Absolute paths are restricted to allowed directories
- Symbolic links are resolved and validated

### 3. Resource Limits

Resource limits are enforced:
- Maximum file size
- Maximum memory usage
- Maximum GPU memory
- Maximum concurrent requests

### 4. Audit Logging

All Modelfile operations are logged:
- Modelfile creation
- Model building
- Model deployment
- Security violations

### 5. Rate Limiting

Rate limits are enforced:
- Requests per minute
- Tokens per minute
- Concurrent requests

### 6. Network Isolation

Network access is restricted:
- Allowed hosts whitelist
- Blocked hosts blacklist
- Firewall rules

### 7. File Sandbox

File access is restricted:
- Allowed directories
- File size limits
- File type validation

### 8. GPU Isolation

GPU resources are isolated:
- Per-tenant memory limits
- Per-tenant compute limits
- GPU usage monitoring

### 9. Anomaly Detection

Anomalous behavior is detected:
- Statistical analysis
- Rule-based detection
- Alert generation

---

## Formal Verification

### ACSL Annotations

The Modelfile parser includes ACSL annotations for formal verification:

```c
/*@ 
  predicate valid_modelfile(struct modelfile *mf) = 
    \valid_read(mf) &&
    \valid_read(mf->directives) &&
    mf->directive_count > 0 &&
    \forall integer i; 0 <= i < mf->directive_count ==>
      \valid_read(&mf->directives[i]) &&
      \valid_read(mf->directives[i].name) &&
      \valid_read(mf->directives[i].value);
@*/
```

### Verification Goals

1. **Memory Safety**: No buffer overflows, no null pointer dereferences
2. **Type Safety**: All type conversions are safe
3. **Resource Safety**: No resource leaks
4. **Concurrency Safety**: No race conditions
5. **Security**: No security vulnerabilities

---

## Examples

### Basic Modelfile

```
FROM llama3:latest
PARAMETER temperature 0.7
PARAMETER top_p 0.9
SYSTEM You are a helpful assistant.
```

### Custom Model with Quantization

```
FROM /path/to/base-model.gguf
QUANTIZE Q4_K_M
PARAMETER num_ctx 4096
PARAMETER temperature 0.8
LICENSE MIT
```

### Model with LoRA Adapter

```
FROM llama3:latest
ADAPTER /path/to/adapter.gguf
PARAMETER temperature 0.7
SYSTEM You are a code assistant.
```

### Model with Security Policies

```
FROM llama3:latest
PARAMETER temperature 0.7
SECURITY audit_enabled true
SECURITY rate_limit_enabled true
SECURITY rate_limit_requests_per_minute 60
SECURITY network_isolation_enabled true
SECURITY allowed_hosts localhost,127.0.0.1
SECURITY file_sandbox_enabled true
SECURITY allowed_directories ~/.allama/models
RESOURCE max_memory 16GB
RESOURCE max_gpu_memory 8GB
```

### Model with Custom Template

```
FROM llama3:latest
TEMPLATE """
<|im_start|>system
{{ .System }}<|im_end|>
{{- range .Messages }}
<|im_start|>{{ .Role }}
{{ .Content }}<|im_end|>
{{- end }}
<|im_start|>assistant
"""
PARAMETER temperature 0.7
SYSTEM You are a helpful assistant.
```

### Model with Few-Shot Examples

```
FROM llama3:latest
MESSAGE user What is the capital of France?
MESSAGE assistant The capital of France is Paris.
MESSAGE user What is the capital of Germany?
MESSAGE assistant The capital of Germany is Berlin.
PARAMETER temperature 0.1
```

---

## Comparison with Ollama

### Compatible Directives

All ollama Modelfile directives are supported:
- ✅ FROM
- ✅ PARAMETER
- ✅ LICENSE
- ✅ TEMPLATE
- ✅ ADAPTER
- ✅ MESSAGE
- ✅ SYSTEM

### Allama-Specific Directives

Additional directives for aerospace-level security:
- 🔒 SECURITY
- 🔒 RESOURCE
- 🔒 METADATA (extended)

### Enhanced Features

1. **Security**: SECURITY and RESOURCE directives
2. **Validation**: Stricter input validation
3. **Audit Logging**: Comprehensive audit trail
4. **Resource Limits**: Enforced resource constraints
5. **Network Isolation**: Whitelist/blacklist support

### Differences

| Feature | Ollama | Allama |
|---------|--------|--------|
| Security Policies | ❌ | ✅ |
| Resource Limits | ❌ | ✅ |
| Audit Logging | ❌ | ✅ |
| Network Isolation | ❌ | ✅ |
| File Sandbox | ❌ | ✅ |
| GPU Isolation | ❌ | ✅ |
| Anomaly Detection | ❌ | ✅ |
| Formal Verification | ❌ | ✅ |

---

## Implementation Notes

### Parser Architecture

The Modelfile parser is implemented as a recursive descent parser with:

1. **Lexical Analysis**: Tokenization of input
2. **Syntax Analysis**: Parse tree construction
3. **Semantic Analysis**: Validation and type checking
4. **Security Analysis**: Security policy validation
5. **Code Generation**: Internal representation generation

### Error Handling

Errors are reported with:
- Line number
- Column number
- Error type
- Error message
- Suggested fix

Example:
```
Error at line 10, column 15: Invalid parameter value
  PARAMETER temperature 5.0
                ^
  Temperature must be between 0.0 and 2.0
  Suggested: PARAMETER temperature 1.0
```

### Security Validation

Security validation is performed in multiple stages:

1. **Parse-Time Validation**: Immediate validation of directives
2. **Load-Time Validation**: Validation when loading the model
3. **Runtime Validation**: Continuous validation during operation

### Performance Considerations

The parser is optimized for:
- Fast parsing (O(n) complexity)
- Low memory footprint
- Minimal allocations
- Cache-friendly data structures

---

## Future Extensions

### Planned Features

1. **Conditional Directives**: Support for conditional compilation
2. **Include Directives**: Support for including other Modelfiles
3. **Macro Support**: Support for macros and variables
4. **Plugin System**: Support for custom directives via plugins
5. **Versioning**: Support for Modelfile versioning
6. **Schema Validation**: JSON schema for validation

### Experimental Features

1. **Type System**: Strong typing for directives
2. **Imports**: Import from other Modelfiles
3. **Inheritance**: Inherit from base Modelfiles
4. **Composition**: Compose multiple Modelfiles

---

## Compliance

### Aerospace Standards

The Modelfile DSL is designed to comply with:

- **DO-178C**: Software considerations in airborne systems
- **ISO 26262**: Functional safety for road vehicles
- **IEC 61508**: Functional safety of electrical/electronic systems
- **NIST SP 800-53**: Security and privacy controls

### Certification Readiness

The implementation includes:

- ACSL annotations for formal verification
- Comprehensive test coverage
- Audit logging for all operations
- Security validation at all stages
- Documentation for certification

---

## References

1. [Ollama Modelfile Documentation](https://github.com/ollama/ollama/blob/main/docs/modelfile.md)
2. [DO-178C Guidelines](https://www.rtca.org/)
3. [ISO 26262 Standard](https://www.iso.org/)
4. [IEC 61508 Standard](https://www.iec.ch/)
5. [NIST SP 800-53](https://csrc.nist.gov/)
6. [ACSL Language Reference](https://frama-c.com/acsl.html)

---

## Version History

- **v1.0.0** (2026-04-30): Initial specification
  - Basic directive support
  - Security features
  - Resource constraints
  - Formal verification annotations

---

## License

This specification is licensed under the MIT License.

---

## Contact

For questions or feedback, please contact the allama development team.
