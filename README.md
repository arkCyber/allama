<div align="center">

# allama

[Language: English](#english) | [中文](#chinese) | [Deutsch](#deutsch)

---

<a name="english"></a>
# allama

![Security](https://img.shields.io/badge/security-aerospace--level-red)
![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Build Status](https://img.shields.io/badge/build-passing-green)

**Aerospace-Level Security Enhanced LLM Inference Engine**

This is a security-hardened, aerospace-grade version of [llama.cpp](https://github.com/ggml-org/llama.cpp) with comprehensive security, fault tolerance, and enterprise-grade features for mission-critical deployments.

## 🚀 Key Features

### Aerospace-Level Security
- **Comprehensive Authentication** (API keys, JWT, Basic auth)
- **Code Signing & Verification** (HMAC-SHA256 based)
- **Audit Logging** (all operations logged with tamper-evidence)
- **Rate Limiting** (configurable per-user limits)
- **Resource Monitoring** (CPU, GPU, memory tracking)
- **File Sandbox** (restricted file system access)
- **Secure Memory** (encrypted memory regions)
- **GPU Isolation** (dedicated GPU resource management)
- **Anomaly Detection** (real-time threat detection)
- **Network Isolation** (firewall and network segmentation)
- **Backup System** (automatic state backup and recovery)

### Fault Tolerance
- **Timeout Protection** (all operations have configurable timeouts)
- **Watchdog Timers** (prevent infinite loops and deadlocks)
- **Retry Mechanisms** (exponential backoff for transient failures)
- **Graceful Degradation** (system continues with reduced functionality on failures)
- **Signal Handling** (clean shutdown on SIGTERM/SIGINT)

### Model Management
- **Local Model Registry** (SQLite-based metadata storage)
- **Allama CLI** (model management commands: pull, list, show, rm, cp, add, create, search, stats, validate)
- **Modelfile Support** (model definition DSL for custom configurations)
- **REST API** (Ollama-compatible endpoints: /api/tags, /api/show, /api/delete, /api/copy, /api/ps, /api/pull, /api/version)

### Performance
- All llama.cpp performance optimizations preserved
- Metal (Apple Silicon), CUDA (NVIDIA), HIP (AMD), Vulkan support
- 1.5-bit to 8-bit quantization
- CPU+GPU hybrid inference
- Speculative decoding

## 📋 Quick Start

### Building from Source

```bash
# Clone the repository
git clone https://github.com/arkCyber/allama.git
cd allama

# Create build directory
mkdir build && cd build

# Configure and build
cmake ..
make -j$(nproc)

# Install (optional)
sudo make install
```

### Using Allama CLI

```bash
# Initialize model registry
./bin/allama stats

# Add a local model
./bin/allama add my-model /path/to/model.gguf

# List all models
./bin/allama list

# Show model details
./bin/allama show my-model

# Validate model integrity
./bin/allama validate my-model

# Search models
./bin/allama search "llama"

# Start server with model registry
./bin/allama serve
```

### Using the Enhanced Server

```bash
# Start server with security features enabled
./bin/llama-server \
  --model-registry-path ~/.allama/registry.db \
  --models-path ~/.allama/models \
  --port 8080 \
  --auth-api-key your-secret-key \
  --enable-audit-log

# Use API with authentication
curl -H "Authorization: Bearer your-secret-key" \
  http://localhost:8080/v1/chat/completions
```

## 🔒 Security Architecture

### Authentication

The authentication system supports multiple methods:

```c
// API Key authentication
auth_config_t config = {
    .require_auth = true,
    .api_keys = {"secret-key-1", "secret-key-2"},
    .api_key_count = 2
};
auth_init(&config);

// JWT authentication
auth_validate_jwt(token, &user_id);

// Basic authentication
auth_validate_basic(username, password, &user_id);
```

### Code Signing

Sign and verify model files for integrity:

```bash
# Sign a model file
./bin/allama sign-model /path/to/model.gguf

# Verify a model file
./bin/allama verify-model /path/to/model.gguf.sig

# Sign a binary
./bin/allama sign-binary /path/to/binary

# Verify a binary
./bin/allama verify-binary /path/to/binary.sig
```

### Audit Logging

All security-relevant operations are logged:

```
[INFO] [2024-01-01 12:00:00] AUTH: User authenticated via API key
[INFO] [2024-01-01 12:00:05] CODE_SIGN: Model signature verified
[WARNING] [2024-01-01 12:00:10] RATE_LIMIT: User exceeded rate limit
[ERROR] [2024-01-01 12:00:15] SECURITY_VIOLATION: Invalid signature detected
```

## 🛡️ Fault Tolerance

### Timeout Protection

All operations have configurable timeouts:

```c
// Short timeout (5 seconds) for quick operations
ft_timeout_t timeout;
ft_timeout_init(&timeout, SHORT_TIMEOUT);

// Loop with timeout protection
while (condition && !ft_timeout_check(&timeout)) {
    // Do work
}

ft_timeout_cleanup(&timeout);
```

### Watchdog Timer

System-level watchdog prevents hangs:

```c
// Initialize global fault tolerance
ft_global_init();

// Check for shutdown request
if (ft_is_shutdown_requested()) {
    // Clean shutdown
    ft_global_cleanup();
}
```

## 📊 REST API Endpoints

### Ollama-Compatible Endpoints

- `GET /api/tags` - List all models
- `GET /api/show?name=<model>` - Show model details
- `POST /api/delete` - Delete a model
- `POST /api/copy` - Copy a model
- `GET /api/ps` - System info and running models
- `POST /api/pull` - Pull a model (placeholder for remote registry)
- `GET /api/version` - Version information

### OpenAI-Compatible Endpoints

- `POST /v1/chat/completions` - Chat completions
- `POST /v1/completions` - Text completions
- `POST /v1/embeddings` - Generate embeddings

## 🏗️ Architecture

### Core Components

```
common/
├── auth.c/h                    # Authentication system
├── code-sign.c/h               # Code signing and verification
├── audit-log.c/h               # Audit logging
├── model-registry.c/h           # Model registry
├── modelfile.c/h               # Modelfile parser
├── resource-monitor.c/h         # Resource monitoring
├── file-sandbox.c/h             # File sandbox
├── rate-limit.c/h               # Rate limiting
├── secure-memory.c/h            # Secure memory
├── gpu-isolation.c/h            # GPU isolation
├── anomaly-detection.c/h        # Anomaly detection
├── backup-system.c/h            # Backup system
├── network-isolation.c/h        # Network isolation
└── fault-tolerance.c/h          # Fault tolerance framework

tools/
├── allama/                      # Allama CLI tool
└── server/                      # Enhanced llama-server
```

## 🧪 Testing

### Run Security Module Tests

```bash
cd build
./bin/test-security-modules
```

### Run CLI Tests

```bash
./bin/test-allama-cli
```

### Run Model Registry Tests

```bash
./bin/test-model-registry
```

## 📖 Documentation

- [DO-178C Requirements](docs/DO178C_REQUIREMENTS.md) - Aerospace certification requirements
- [Ollama Alignment Analysis](docs/OLLAMA_ALIGNMENT_GAP_ANALYSIS.md) - Feature comparison with Ollama
- [Build Guide](docs/build.md) - Build instructions
- [Server Documentation](tools/server/README.md) - Server configuration

## 🤝 Contributing

This project follows the [llama.cpp contributing guidelines](CONTRIBUTING.md) with additional requirements for security features:

1. All security changes must include comprehensive tests
2. Code signing must be maintained for all security-critical binaries
3. Audit logging must be added for all new security-relevant operations
4. Fault tolerance mechanisms must be applied to all new features

**Important:** This project does not accept fully AI-generated pull requests. AI tools may be used only in an assistive capacity. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## 📄 License

MIT License - Same as [llama.cpp](https://github.com/ggml-org/llama.cpp)

## 🙏 Acknowledgments

Based on [llama.cpp](https://github.com/ggml-org/llama.cpp) by Georgi Gerganov and contributors.

Security enhancements inspired by aerospace industry standards and DO-178C certification requirements.

## 🔗 Links

- [llama.cpp](https://github.com/ggml-org/llama.cpp) - Original project
- [ggml](https://github.com/ggml-org/ggml) - Tensor library
- [Ollama](https://github.com/ollama/ollama) - Model management reference

---

<a name="chinese"></a>
# allama (中文)

![Security](https://img.shields.io/badge/security-aerospace--level-red)
![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Build Status](https://img.shields.io/badge/build-passing-green)

**航空航天级安全增强型 LLM 推理引擎**

这是 [llama.cpp](https://github.com/ggml-org/llama.cpp) 的安全加固、航空航天级版本，具有全面的安全、容错和企业级功能，专为关键任务部署而设计。

## 🚀 主要特性

### 航空航天级安全
- **全面认证**（API 密钥、JWT、Basic 认证）
- **代码签名与验证**（基于 HMAC-SHA256）
- **审计日志**（所有操作均记录，具有防篡改证据）
- **速率限制**（可配置的每用户限制）
- **资源监控**（CPU、GPU、内存跟踪）
- **文件沙箱**（受限的文件系统访问）
- **安全内存**（加密内存区域）
- **GPU 隔离**（专用 GPU 资源管理）
- **异常检测**（实时威胁检测）
- **网络隔离**（防火墙和网络分段）
- **备份系统**（自动状态备份和恢复）

### 容错能力
- **超时保护**（所有操作都有可配置的超时）
- **看门狗定时器**（防止无限循环和死锁）
- **重试机制**（指数退避处理瞬态故障）
- **优雅降级**（系统在故障时以降低功能继续运行）
- **信号处理**（SIGTERM/SIGINT 上的干净关闭）

### 模型管理
- **本地模型注册表**（基于 SQLite 的元数据存储）
- **Allama CLI**（模型管理命令：pull、list、show、rm、cp、add、create、search、stats、validate）
- **Modelfile 支持**（自定义配置的模型定义 DSL）
- **REST API**（Ollama 兼容端点：/api/tags、/api/show、/api/delete、/api/copy、/api/ps、/api/pull、/api/version）

### 性能
- 保留所有 llama.cpp 性能优化
- Metal（Apple Silicon）、CUDA（NVIDIA）、HIP（AMD）、Vulkan 支持
- 1.5 位到 8 位量化
- CPU+GPU 混合推理
- 推测性解码

## 📋 快速开始

### 从源代码构建

```bash
# 克隆仓库
git clone https://github.com/arkCyber/allama.git
cd allama

# 创建构建目录
mkdir build && cd build

# 配置和构建
cmake ..
make -j$(nproc)

# 安装（可选）
sudo make install
```

### 使用 Allama CLI

```bash
# 初始化模型注册表
./bin/allama stats

# 添加本地模型
./bin/allama add my-model /path/to/model.gguf

# 列出所有模型
./bin/allama list

# 显示模型详细信息
./bin/allama show my-model

# 验证模型完整性
./bin/allama validate my-model

# 搜索模型
./bin/allama search "llama"

# 启动带有模型注册表的服务器
./bin/allama serve
```

### 使用增强版服务器

```bash
# 启用安全功能启动服务器
./bin/llama-server \
  --model-registry-path ~/.allama/registry.db \
  --models-path ~/.allama/models \
  --port 8080 \
  --auth-api-key your-secret-key \
  --enable-audit-log

# 使用带认证的 API
curl -H "Authorization: Bearer your-secret-key" \
  http://localhost:8080/v1/chat/completions
```

## 🔒 安全架构

### 认证

认证系统支持多种方法：

```c
// API 密钥认证
auth_config_t config = {
    .require_auth = true,
    .api_keys = {"secret-key-1", "secret-key-2"},
    .api_key_count = 2
};
auth_init(&config);

// JWT 认证
auth_validate_jwt(token, &user_id);

// Basic 认证
auth_validate_basic(username, password, &user_id);
```

### 代码签名

对模型文件进行签名和验证以确保完整性：

```bash
# 对模型文件签名
./bin/allama sign-model /path/to/model.gguf

# 验证模型文件
./bin/allama verify-model /path/to/model.gguf.sig

# 对二进制文件签名
./bin/allama sign-binary /path/to/binary

# 验证二进制文件
./bin/allama verify-binary /path/to/binary.sig
```

### 审计日志

所有安全相关操作都会被记录：

```
[INFO] [2024-01-01 12:00:00] AUTH: User authenticated via API key
[INFO] [2024-01-01 12:00:05] CODE_SIGN: Model signature verified
[WARNING] [2024-01-01 12:00:10] RATE_LIMIT: User exceeded rate limit
[ERROR] [2024-01-01 12:00:15] SECURITY_VIOLATION: Invalid signature detected
```

## 🛡️ 容错能力

### 超时保护

所有操作都有可配置的超时：

```c
// 短超时（5 秒）用于快速操作
ft_timeout_t timeout;
ft_timeout_init(&timeout, SHORT_TIMEOUT);

// 带超时保护的循环
while (condition && !ft_timeout_check(&timeout)) {
    // 执行工作
}

ft_timeout_cleanup(&timeout);
```

### 看门狗定时器

系统级看门狗防止挂起：

```c
// 初始化全局容错
ft_global_init();

// 检查关机请求
if (ft_is_shutdown_requested()) {
    // 干净关闭
    ft_global_cleanup();
}
```

## 📊 REST API 端点

### Ollama 兼容端点

- `GET /api/tags` - 列出所有模型
- `GET /api/show?name=<model>` - 显示模型详细信息
- `POST /api/delete` - 删除模型
- `POST /api/copy` - 复制模型
- `GET /api/ps` - 系统信息和运行中的模型
- `POST /api/pull` - 拉取模型（远程注册表的占位符）
- `GET /api/version` - 版本信息

### OpenAI 兼容端点

- `POST /v1/chat/completions` - 聊天完成
- `POST /v1/completions` - 文本完成
- `POST /v1/embeddings` - 生成嵌入

## 🏗️ 架构

### 核心组件

```
common/
├── auth.c/h                    # 认证系统
├── code-sign.c/h               # 代码签名和验证
├── audit-log.c/h               # 审计日志
├── model-registry.c/h           # 模型注册表
├── modelfile.c/h               # Modelfile 解析器
├── resource-monitor.c/h         # 资源监控
├── file-sandbox.c/h             # 文件沙箱
├── rate-limit.c/h               # 速率限制
├── secure-memory.c/h            # 安全内存
├── gpu-isolation.c/h            # GPU 隔离
├── anomaly-detection.c/h        # 异常检测
├── backup-system.c/h            # 备份系统
├── network-isolation.c/h        # 网络隔离
└── fault-tolerance.c/h          # 容错框架

tools/
├── allama/                      # Allama CLI 工具
└── server/                      # 增强版 llama-server
```

## 🧪 测试

### 运行安全模块测试

```bash
cd build
./bin/test-security-modules
```

### 运行 CLI 测试

```bash
./bin/test-allama-cli
```

### 运行模型注册表测试

```bash
./bin/test-model-registry
```

## 📖 文档

- [DO-178C 要求](docs/DO178C_REQUIREMENTS.md) - 航空航天认证要求
- [Ollama 对齐分析](docs/OLLAMA_ALIGNMENT_GAP_ANALYSIS.md) - 与 Ollama 的功能比较
- [构建指南](docs/build.md) - 构建说明
- [服务器文档](tools/server/README.md) - 服务器配置

## 🤝 贡献

本项目遵循 [llama.cpp 贡献指南](CONTRIBUTING.md)，并对安全功能有额外要求：

1. 所有安全更改必须包含全面的测试
2. 必须为所有安全关键二进制文件维护代码签名
3. 必须为所有新的安全相关操作添加审计日志
4. 必须将容错机制应用于所有新功能

**重要：** 本项目不接受完全 AI 生成的拉取请求。AI 工具只能以辅助方式使用。详情请参阅 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 📄 许可证

MIT 许可证 - 与 [llama.cpp](https://github.com/ggml-org/llama.cpp) 相同

## 🙏 致谢

基于 [llama.cpp](https://github.com/ggml-org/llama.cpp)，作者为 Georgi Gerganov 和贡献者。

安全增强功能受航空航天行业标准 和 DO-178C 认证要求启发。

## 🔗 链接

- [llama.cpp](https://github.com/ggml-org/llama.cpp) - 原始项目
- [ggml](https://github.com/ggml-org/ggml) - 张量库
- [Ollama](https://github.com/ollama/ollama) - 模型管理参考

---

<a name="deutsch"></a>
# allama (Deutsch)

![Security](https://img.shields.io/badge/security-aerospace--level-red)
![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Build Status](https://img.shields.io/badge/build-passing-green)

**Aerospace-Level Security Enhanced LLM Inference Engine**

Dies ist eine sicherheitshärtete, aerospace-grade Version von [llama.cpp](https://github.com/ggml-org/llama.cpp) mit umfassenden Sicherheits-, Fehlertoleranz- und Enterprise-Features für mission-critical Deployments.

## 🚀 Hauptfunktionen

### Aerospace-Level Sicherheit
- **Umfassende Authentifizierung** (API-Schlüssel, JWT, Basic-Auth)
- **Code-Signing & Verifizierung** (HMAC-SHA256-basiert)
- **Audit-Logging** (alle Operationen werden mit Beweis gegen Manipulation protokolliert)
- **Rate-Limiting** (konfigurierbare pro-Benutzer-Limits)
- **Ressourcen-Monitoring** (CPU-, GPU-, Speicher-Tracking)
- **File-Sandbox** (eingeschränkter Dateisystem-Zugriff)
- **Secure Memory** (verschlüsselte Speicherbereiche)
- **GPU-Isolation** (dedizierte GPU-Ressourcenverwaltung)
- **Anomalie-Erkennung** (Echtzeit-Bedrohungserkennung)
- **Netzwerk-Isolation** (Firewall und Netzwerk-Segmentierung)
- **Backup-System** (automatische Zustandssicherung und -wiederherstellung)

### Fehlertoleranz
- **Timeout-Schutz** (alle Operationen haben konfigurierbare Timeouts)
- **Watchdog-Timer** (verhindern Endlosschleifen und Deadlocks)
- **Retry-Mechanismen** (exponentielles Backoff für transiente Fehler)
- **Graceful Degradation** (System läuft bei Fehlern mit reduzierter Funktionalität weiter)
- **Signal-Handling** (sauberes Herunterfahren bei SIGTERM/SIGINT)

### Modell-Management
- **Lokales Modell-Register** (SQLite-basierte Metadatenspeicherung)
- **Allama CLI** (Modell-Management-Befehle: pull, list, show, rm, cp, add, create, search, stats, validate)
- **Modelfile-Support** (Modell-Definition-DSL für benutzerdefinierte Konfigurationen)
- **REST API** (Ollama-kompatible Endpunkte: /api/tags, /api/show, /api/delete, /api/copy, /api/ps, /api/pull, /api/version)

### Leistung
- Alle llama.cpp-Performance-Optimierungen beibehalten
- Metal (Apple Silicon), CUDA (NVIDIA), HIP (AMD), Vulkan-Support
- 1.5-Bit bis 8-Bit-Quantisierung
- CPU+GPU-Hybrid-Inferenz
- Spekulatives Decoding

## 📋 Schnellstart

### Aus dem Quellcode bauen

```bash
# Repository klonen
git clone https://github.com/arkCyber/allama.git
cd allama

# Build-Verzeichnis erstellen
mkdir build && cd build

# Konfigurieren und bauen
cmake ..
make -j$(nproc)

# Installieren (optional)
sudo make install
```

### Allama CLI verwenden

```bash
# Modell-Register initialisieren
./bin/allama stats

# Lokales Modell hinzufügen
./bin/allama add my-model /path/to/model.gguf

# Alle Modelle auflisten
./bin/allama list

# Modell-Details anzeigen
./bin/allama show my-model

# Modell-Integrität validieren
./bin/allama validate my-model

# Modelle suchen
./bin/allama search "llama"

# Server mit Modell-Register starten
./bin/allama serve
```

### Erweiterten Server verwenden

```bash
# Server mit Sicherheitsfunktionen starten
./bin/llama-server \
  --model-registry-path ~/.allama/registry.db \
  --models-path ~/.allama/models \
  --port 8080 \
  --auth-api-key your-secret-key \
  --enable-audit-log

# API mit Authentifizierung verwenden
curl -H "Authorization: Bearer your-secret-key" \
  http://localhost:8080/v1/chat/completions
```

## 🔒 Sicherheitsarchitektur

### Authentifizierung

Das Authentifizierungssystem unterstützt mehrere Methoden:

```c
// API-Schlüssel-Authentifizierung
auth_config_t config = {
    .require_auth = true,
    .api_keys = {"secret-key-1", "secret-key-2"},
    .api_key_count = 2
};
auth_init(&config);

// JWT-Authentifizierung
auth_validate_jwt(token, &user_id);

// Basic-Authentifizierung
auth_validate_basic(username, password, &user_id);
```

### Code-Signing

Modell-Dateien signieren und verifizieren für Integrität:

```bash
# Modell-Datei signieren
./bin/allama sign-model /path/to/model.gguf

# Modell-Datei verifizieren
./bin/allama verify-model /path/to/model.gguf.sig

# Binary signieren
./bin/allama sign-binary /path/to/binary

# Binary verifizieren
./bin/allama verify-binary /path/to/binary.sig
```

### Audit-Logging

Alle sicherheitsrelevanten Operationen werden protokolliert:

```
[INFO] [2024-01-01 12:00:00] AUTH: User authenticated via API key
[INFO] [2024-01-01 12:00:05] CODE_SIGN: Model signature verified
[WARNING] [2024-01-01 12:00:10] RATE_LIMIT: User exceeded rate limit
[ERROR] [2024-01-01 12:00:15] SECURITY_VIOLATION: Invalid signature detected
```

## 🛡️ Fehlertoleranz

### Timeout-Schutz

Alle Operationen haben konfigurierbare Timeouts:

```c
// Kurzes Timeout (5 Sekunden) für schnelle Operationen
ft_timeout_t timeout;
ft_timeout_init(&timeout, SHORT_TIMEOUT);

// Schleife mit Timeout-Schutz
while (condition && !ft_timeout_check(&timeout)) {
    // Arbeit ausführen
}

ft_timeout_cleanup(&timeout);
```

### Watchdog-Timer

Systemweiter Watchdog verhindert Hängen:

```c
// Globale Fehlertoleranz initialisieren
ft_global_init();

// Auf Shutdown-Anfrage prüfen
if (ft_is_shutdown_requested()) {
    // Sauberes Herunterfahren
    ft_global_cleanup();
}
```

## 📊 REST API Endpunkte

### Ollama-kompatible Endpunkte

- `GET /api/tags` - Alle Modelle auflisten
- `GET /api/show?name=<model>` - Modell-Details anzeigen
- `POST /api/delete` - Modell löschen
- `POST /api/copy` - Modell kopieren
- `GET /api/ps` - System-Info und laufende Modelle
- `POST /api/pull` - Modell pullen (Platzhalter für Remote-Register)
- `GET /api/version` - Versionsinformationen

### OpenAI-kompatible Endpunkte

- `POST /v1/chat/completions` - Chat-Completions
- `POST /v1/completions` - Text-Completions
- `POST /v1/embeddings` - Embeddings generieren

## 🏗️ Architektur

### Kernkomponenten

```
common/
├── auth.c/h                    # Authentifizierungssystem
├── code-sign.c/h               # Code-Signing und -Verifizierung
├── audit-log.c/h               # Audit-Logging
├── model-registry.c/h           # Modell-Register
├── modelfile.c/h               # Modelfile-Parser
├── resource-monitor.c/h         # Ressourcen-Monitoring
├── file-sandbox.c/h             # File-Sandbox
├── rate-limit.c/h               # Rate-Limiting
├── secure-memory.c/h            # Secure Memory
├── gpu-isolation.c/h            # GPU-Isolation
├── anomaly-detection.c/h        # Anomalie-Erkennung
├── backup-system.c/h            # Backup-System
├── network-isolation.c/h        # Netzwerk-Isolation
└── fault-tolerance.c/h          # Fehlertoleranz-Framework

tools/
├── allama/                      # Allama CLI Tool
└── server/                      # Erweitertes llama-server
```

## 🧪 Tests

### Sicherheitsmodul-Tests ausführen

```bash
cd build
./bin/test-security-modules
```

### CLI-Tests ausführen

```bash
./bin/test-allama-cli
```

### Modell-Register-Tests ausführen

```bash
./bin/test-model-registry
```

## 📖 Dokumentation

- [DO-178C Anforderungen](docs/DO178C_REQUIREMENTS.md) - Aerospace-Zertifizierungsanforderungen
- [Ollama-Alignment-Analyse](docs/OLLAMA_ALIGNMENT_GAP_ANALYSIS.md) - Funktionsvergleich mit Ollama
- [Build-Leitfaden](docs/build.md) - Build-Anweisungen
- [Server-Dokumentation](tools/server/README.md) - Server-Konfiguration

## 🤝 Mitwirken

Dieses Projekt folgt den [llama.cpp Contributing-Richtlinien](CONTRIBUTING.md) mit zusätzlichen Anforderungen für Sicherheitsfunktionen:

1. Alle Sicherheitsänderungen müssen umfassende Tests enthalten
2. Code-Signing muss für alle sicherheitskritischen Binaries gepflegt werden
3. Audit-Logging muss für alle neuen sicherheitsrelevanten Operationen hinzugefügt werden
4. Fehlertoleranz-Mechanismen müssen auf alle neuen Funktionen angewendet werden

**Wichtig:** Dieses Projekt akzeptiert keine vollständig KI-generierten Pull Requests. KI-Tools dürfen nur in unterstützender Funktion verwendet werden. Details siehe [CONTRIBUTING.md](CONTRIBUTING.md).

## 📄 Lizenz

MIT-Lizenz - Gleich wie [llama.cpp](https://github.com/ggml-org/llama.cpp)

## 🙏 Danksagungen

Basierend auf [llama.cpp](https://github.com/ggml-org/llama.cpp) von Georgi Gerganov und Mitwirkenden.

Sicherheitsverbesserungen inspiriert von Aerospace-Industriestandards und DO-178C-Zertifizierungsanforderungen.

## 🔗 Links

- [llama.cpp](https://github.com/ggml-org/llama.cpp) - Originalprojekt
- [ggml](https://github.com/ggml-org/ggml) - Tensor-Bibliothek
- [Ollama](https://github.com/ollama/ollama) - Modell-Management-Referenz

---

[↑ Back to top](#allama)

</div>
