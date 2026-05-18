# Allama 用户开发与应用文档手册

## 目录

1. [快速开始](#快速开始)
2. [Web UI 与桌面应用](#web-ui-与桌面应用)
3. [远程免费测试账号使用指南](#远程免费测试账号使用指南)
4. [安装指南](#安装指南)
5. [模型兼容性指南](#模型兼容性指南)
6. [Ollama迁移指南](#ollama迁移指南)
7. [CLI命令参考](#cli命令参考)
8. [认证系统应用案例](#认证系统应用案例)
9. [计费系统应用案例](#计费系统应用案例)
10. [OpenAI兼容API应用案例](#openai兼容api应用案例)
11. [高级功能应用案例](#高级功能应用案例)
12. [故障排除](#故障排除)
13. [常见问题FAQ](#常见问题faq)

---

## 快速开始

### 5分钟快速体验

Allama是一个航空级安全的LLM推理服务器，支持用户认证、计费和OpenAI兼容API。本指南将帮助您在5分钟内快速体验Allama的核心功能，包括服务器启动、API调用、认证测试和使用统计查看。

**与Ollama的兼容性：**

Allama在设计上与Ollama保持完全兼容，这意味着：

- **命令行接口一致**：所有Ollama的命令在Allama中都可以直接使用，无需学习新的命令语法
- **API端点兼容**：Allama提供了与Ollama完全相同的API端点，包括`/api/generate`、`/api/chat`、`/api/embed`等
- **模型格式兼容**：Allama使用与Ollama相同的模型格式，可以直接使用Ollama的模型库
- **配置文件兼容**：Modelfile等配置文件格式完全兼容
- **环境变量兼容**：支持相同的环境变量，如`OLLAMA_HOST`、`OLLAMA_NUM_PARALLEL`等
- **无缝迁移**：如果您已经熟悉Ollama，可以立即开始使用Allama，无需任何学习成本

**Allama相比Ollama的增强功能：**

虽然Allama与Ollama保持兼容，但还增加了企业级功能：

- **用户认证系统**：支持API Key认证，适合多用户环境
- **计费和使用追踪**：精确的token计数和详细的计费记录
- **速率限制和配额管理**：可以为不同用户设置不同的速率限制和月度配额
- **航空级安全**：代码签名验证、审计日志、完整性保护
- **故障容错**：超时保护、重试机制、优雅降级
- **异常检测**：资源监控、阈值检测、统计分析和告警

**前提条件：**
- 已安装Rust 1.70或更高版本
- 至少8GB可用内存
- 网络连接（用于下载模型）
- 终端或命令行访问权限
- 如果您已经熟悉Ollama，可以跳过基础知识，直接使用Allama的增强功能

**步骤1：编译项目**

Allama是用Rust编写的高性能推理服务器，首先需要从源码编译项目。编译过程可能需要几分钟，具体时间取决于您的系统性能。

```bash
# 克隆仓库（如果还没有克隆）
git clone https://github.com/arkCyber/allama.git
cd allama

# 编译项目（使用release模式以获得最佳性能）
cargo build --release
```

编译完成后，可执行文件将位于`target/release/allama`。您可以将其添加到系统PATH中，以便在任何位置使用：

```bash
# 临时添加到PATH（当前会话有效）
export PATH=$PATH:$(pwd)/target/release

# 永久添加到PATH（添加到~/.bashrc或~/.zshrc）
echo 'export PATH=$PATH:$(pwd)/target/release' >> ~/.bashrc
source ~/.bashrc
```

**步骤2：启动服务器**

启动Allama HTTP服务器，提供API服务。服务器启动时会自动初始化认证系统、计费系统，并创建默认测试用户。

```bash
# 启动服务器（使用默认配置）
./target/release/allama serve --port 11435
```

服务器启动后会显示详细的初始化信息，包括：

```
Allama v1.0.0
==========================================
Aerospace-Level Security Enhanced LLM Inference Server
==========================================

Initializing authentication manager...
Initializing billing manager...
Loading models...
Starting HTTP server on 127.0.0.1:11435 with 1 parallel workers
Maximum loaded models: 3
Maximum queue size: 512

==========================================
Default Test User Created
==========================================
Username: test_user
API Key: allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm
Rate Limit: 60 requests/minute
Monthly Quota: 100000 tokens
==========================================

Aerospace-level HTTP server ready
```

**重要提示：**
- 默认测试用户仅用于开发和测试
- API Key会在每次服务器启动时显示，请妥善保存
- 服务器默认监听127.0.0.1（仅本地访问），如需远程访问请使用`--host 0.0.0.0`
- 默认端口为11434，本示例使用11435以避免冲突

**步骤3：本地测试（无需认证）**

Allama为本地请求提供了认证绕过机制，来自127.0.0.1的请求无需API Key即可访问。这大大简化了开发和测试流程。

```bash
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","prompt":"Hello, world!","stream":false}'
```

**响应示例：**
```json
{
  "model": "llama3",
  "response": "Generate response for model 'llama3': Hello, world!",
  "done": true
}
```

**认证绕过机制说明：**
- 本地请求（127.0.0.1, ::1, localhost）自动绕过认证
- 通过`X-Forwarded-For`或`X-Real-IP`头部检测客户端IP
- 适合本地开发、测试和调试
- 生产环境应使用反向代理（如Nginx）并正确配置IP检测

**步骤4：远程测试（使用认证）**

模拟远程请求场景，使用API Key进行认证。这是生产环境中推荐的使用方式。

```bash
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"Hello, world!","stream":false}'
```

**认证机制说明：**
- 远程请求必须提供有效的API Key
- API Key通过`Authorization: Bearer <key>`头部传递
- API Key使用SHA-256哈希存储，确保安全性
- 每个用户有独立的速率限制和月度配额

**步骤5：查看使用统计**

Allama内置了完善的计费系统，可以追踪每次API调用的token使用情况，包括prompt tokens、completion tokens和总token数。

```bash
curl -X GET "http://localhost:11435/api/billing/records?limit=5" \
  -H "Authorization: Bearer allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm" \
  -H "X-Forwarded-For: 127.0.0.1"
```

**响应示例：**
```json
{
  "records": [
    {
      "id": "req_123456",
      "timestamp": "2026-05-03T08:30:00Z",
      "user_id": "user_abc123",
      "username": "test_user",
      "model_name": "llama3",
      "prompt_tokens": 3,
      "completion_tokens": 12,
      "total_tokens": 15,
      "prompt_text": "Hello, world!",
      "completion_text": "Generate response for model 'llama3': Hello, world!",
      "client_ip": "127.0.0.1",
      "endpoint": "/api/generate",
      "duration_ms": 150
    }
  ],
  "total": 1
}
```

**计费系统特点：**
- 精确的token计数，支持多种分词器
- 详细的请求记录，包括时间戳、用户信息、模型信息
- 支持按时间范围查询
- 提供统计汇总功能
- 可用于成本分析和资源规划

**步骤6：尝试对话API**

体验Allama的对话API，支持多轮对话和上下文管理。

```bash
curl -X POST http://localhost:11435/api/chat \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{
    "model": "llama3",
    "messages": [
      {"role": "user", "content": "What is the capital of France?"}
    ],
    "stream": false
  }'
```

**响应示例：**
```json
{
  "model": "llama3",
  "message": {
    "role": "assistant",
    "content": "The capital of France is Paris."
  },
  "done": true
}
```

**下一步：**
- 阅读CLI命令参考章节，了解所有可用命令
- 查看认证系统应用案例，学习如何创建和管理用户
- 探索OpenAI兼容API，了解如何与现有应用集成
- 参考高级功能应用案例，学习批量处理、流式响应等高级用法

---

## Web UI 与桌面应用

Allama 提供了现代化的 Web 界面和跨平台桌面应用程序，为喜欢图形界面的用户提供了比命令行更友好的选择。

### Web UI 功能特性

- **实时聊天**：支持服务器发送事件（SSE）的流式响应
- **模型管理器**：可视化界面下载、删除和管理模型
- **设置管理**：配置模型、参数和偏好设置
- **多语言支持**：英语、中文、日语
- **会话管理**：保存和恢复聊天会话
- **深色/浅色主题**：主题切换
- **键盘快捷键**：提升生产力
- **状态栏**：实时系统状态和连接监控

### 构建 Web UI

```bash
# 导航到 web-ui 目录
cd web-ui

# 安装依赖
npm install

# 开发模式构建
npm run dev

# 生产模式构建
npm run build

# 运行测试
npm test
```

### Tauri 桌面应用程序

Tauri 桌面应用程序将 Web UI 包装在原生桌面窗口中，具有增强的性能和系统集成功能。

**功能特性：**
- 跨平台（Windows、macOS、Linux）
- 原生性能
- 系统托盘集成
- 开机自启动
- 单实例强制
- 原生文件对话框

**构建桌面应用：**

```bash
# 导航到 web-ui 目录
cd web-ui

# 安装依赖
npm install

# 开发模式运行
npm run tauri dev

# 生产模式构建
npm run tauri build

# 输出文件位于 src-tauri/target/release/bundle/ 目录
```

**平台特定构建：**

```bash
# macOS
npm run tauri build -- --target universal-apple-darwin

# Windows
npm run tauri build -- --target x86_64-pc-windows-msvc

# Linux
npm run tauri build -- --target x86_64-unknown-linux-gnu
```

### 使用 Web UI

**启动 Web UI：**

```bash
# 选项 1：使用 Tauri 应用（推荐）
cd web-ui
npm run tauri dev

# 选项 2：使用 Web 服务器
cd web-ui
npm run dev
# 在浏览器中打开 http://localhost:5173
```

**Web UI 配置：**

Web UI 连接到 Allama 服务器。在设置中配置服务器 URL：

```json
{
  "serverUrl": "http://localhost:11435",
  "apiKey": "your-api-key",
  "defaultModel": "llama3"
}
```

### Web UI 测试状态

Web UI 具有全面的测试覆盖：
- **228 个测试通过**（8 个测试文件）
- 组件：ModelManager（25）、Chat（16）、Settings（36）、Sidebar（28）、App（42）
- Hooks：useSettings（23）、useSessions（39）
- API 客户端：（19）

### 推荐使用方式

**优先级顺序：**

1. **Web UI / Tauri 应用** ⭐⭐⭐⭐⭐（最适合日常使用）
   - 100% 稳定，228 个测试通过
   - 功能完整，用户友好界面
   - 跨平台桌面应用
   - 实时聊天与流式响应
   - 可视化模型管理

2. **llama-server** ⭐⭐⭐⭐⭐（最适合大型模型）
   - 100% 稳定，完全避免 FFI 问题
   - 支持 Turbo4（节省 73% 内存）
   - 适用于所有模型大小
   - 简单易部署

3. **API** ⭐⭐⭐⭐（最适合脚本）
   - 可脚本化，可靠
   - OpenAI 兼容端点
   - Ollama 兼容端点

4. **CLI FFI** ⭐⭐（实验性，仅限小型模型）
   - 仅适用于 <4GB 模型
   - 大型模型可能崩溃

---

## 远程免费测试账号使用指南

Allama为远程用户提供了默认的免费测试账号，方便快速体验Allama的功能而无需手动创建用户。这个账号专为远程测试设计，具有适度的配额限制。

### 默认测试账号信息

**账号详情：**
- **用户名**: `test_user`
- **邮箱**: `test@allama.ai`
- **速率限制**: 60 requests/minute（每分钟60次请求）
- **月度配额**: 100,000 tokens（每月10万个token）
- **API Key**: 服务器启动时自动生成并显示

**账号特点：**
- **自动创建**: 每次服务器启动时自动创建或获取
- **免费使用**: 无需任何费用，适合测试和评估
- **适度限制**: 配额限制确保公平使用，避免滥用
- **重置机制**: 每月配额在月初自动重置
- **仅用于测试**: 不适合生产环境使用

### 获取API Key

服务器启动时会自动显示默认测试用户的API Key：

```
==========================================
Default Test User Created
==========================================
Username: test_user
API Key: allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm
Rate Limit: 60 requests/minute
Monthly Quota: 100000 tokens
==========================================
```

**重要提示：**
- API Key在每次服务器启动时可能不同
- 请妥善保存API Key，不要泄露给他人
- 如果忘记API Key，可以重启服务器查看
- 生产环境应创建独立的用户账号

### 远程请求认证

**本地请求 vs 远程请求：**

Allama根据客户端IP地址自动判断请求类型：

- **本地请求**: IP为127.0.0.1、::1或localhost的请求
  - 无需认证，可以直接访问
  - 适合本地开发和测试
  - 通过`X-Forwarded-For: 127.0.0.1`或`X-Real-IP: 127.0.0.1`头部模拟

- **远程请求**: IP非本地的请求
  - 必须提供有效的API Key
  - 通过`Authorization: Bearer <key>`头部认证
  - 适合生产环境和远程访问

**远程请求示例：**

```bash
# 使用默认测试账号的API Key进行远程请求
curl -X POST http://your-server:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"Hello from remote!","stream":false}'
```

**认证头部说明：**
- `Authorization: Bearer <key>`: API Key认证，必需
- `X-Forwarded-For: <ip>`: 客户端真实IP，必需（用于判断是否为远程请求）
- `Content-Type: application/json`: 内容类型，必需

### 配额管理

**速率限制：**
- 默认测试账号的速率限制为60 requests/minute
- 超过限制会返回429状态码
- 速率限制按分钟重置

**月度配额：**
- 默认测试账号的月度配额为100,000 tokens
- 包括prompt tokens和completion tokens
- 配额按月重置（通常在每月1号）
- 超过配额会返回错误提示

**查看配额使用情况：**

```bash
# 查看计费摘要
curl -X GET http://localhost:11435/api/billing/summary \
  -H "Authorization: Bearer allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm" \
  -H "X-Forwarded-For: 127.0.0.1"

# 响应示例
{
  "total_tokens": 15000,
  "total_requests": 500,
  "monthly_quota": 100000,
  "quota_usage": "15%"
}
```

### 适用场景

**适合使用默认测试账号的场景：**
- 快速体验Allama的功能
- 开发和调试应用程序
- 评估Allama是否满足需求
- 学习API的使用方法
- 小规模的个人项目测试

**不适合使用默认测试账号的场景：**
- 生产环境部署
- 大规模应用
- 多用户共享
- 商业用途
- 需要更高配额的场景

### 从测试账号迁移到生产账号

当您准备将应用部署到生产环境时，建议创建独立的用户账号：

```bash
# 创建生产用户账号
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{
    "username": "production_user",
    "email": "prod@company.com",
    "rate_limit": 1000,
    "monthly_quota": 10000000
  }'

# 响应会返回新的API Key
# 将新API Key用于生产环境
```

**迁移步骤：**
1. 创建生产用户账号
2. 获取新的API Key
3. 更新应用程序中的API Key配置
4. 测试新账号是否正常工作
5. 停止使用测试账号（可选）

### 常见问题

**Q: 默认测试账号的API Key会变吗？**
A: 是的，每次服务器启动时可能生成新的API Key。建议保存当前使用的API Key。

**Q: 可以提高默认测试账号的配额吗？**
A: 不可以，默认测试账号的配额是固定的。如需更高配额，请创建独立的用户账号。

**Q: 默认测试账号会过期吗？**
A: 不会过期，但月度配额会每月重置。

**Q: 可以删除默认测试账号吗？**
A: 可以，但不建议。删除后服务器重启时会自动重新创建。

**Q: 如何查看默认测试账号的使用情况？**
A: 使用计费API查询，参考"查看配额使用情况"章节。

---

## 安装指南

### 系统要求

在开始安装Allama之前，请确保您的系统满足以下最低要求。这些要求是为了保证Allama能够正常运行并提供良好的性能。

**操作系统：**
- **Windows**: Windows 10或更高版本（推荐Windows 11）
- **macOS**: macOS 10.15 (Catalina)或更高版本（推荐macOS 12+）
- **Linux**: 主流Linux发行版（Ubuntu 20.04+, Debian 11+, Fedora 35+, CentOS 8+等）

**硬件要求：**
- **CPU**: 支持AVX2指令集的x86_64处理器，或Apple Silicon M1/M2/M3芯片
- **内存**: 至少8GB RAM（推荐16GB或更多，用于运行大型模型）
- **存储**: 至少10GB可用空间（用于存储模型文件，大型模型可能需要更多）
- **GPU**: 可选，支持NVIDIA CUDA（CUDA 11.0+）、Apple Silicon Metal、AMD ROCm

**软件依赖：**
- **Rust**: 1.70或更高版本（仅从源码编译时需要）
- **Git**: 用于克隆源代码仓库
- **curl**: 用于测试API和下载模型
- **编译工具链**: gcc/clang（Linux/macOS），Visual Studio Build Tools（Windows）

**网络要求：**
- 稳定的互联网连接（用于下载模型文件）
- 如果使用GPU加速，需要安装相应的GPU驱动程序

### 从源码编译

从源码编译Allama可以确保您获得最新的功能和性能优化，同时允许您根据需要进行自定义配置。编译过程虽然需要一些时间，但相对简单，且只需要执行一次。

**步骤1：安装Rust工具链**

Allama使用Rust编程语言开发，首先需要安装Rust工具链。Rust官方提供了便捷的安装脚本，可以自动处理大部分配置工作。

```bash
# 使用rustup安装Rust（推荐方式）
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 安装完成后，重新加载环境变量
source $HOME/.cargo/env

# 验证安装
rustc --version
cargo --version
```

**Rust安装说明：**
- 安装过程会自动配置PATH环境变量
- 默认安装stable版本，这是经过测试的最稳定版本
- 如果需要特定版本，可以使用`rustup install <version>`命令
- 安装完成后，可以使用`rustup update`更新到最新版本

**步骤2：克隆源代码仓库**

从GitHub克隆Allama的源代码仓库到本地。这将下载所有必要的源代码文件和配置文件。

```bash
# 克隆仓库
git clone https://github.com/arkCyber/allama.git
cd allama

# 查看仓库信息
git remote -v
git log --oneline -5
```

**仓库说明：**
- 主分支包含最新的稳定代码
- 开发分支可能包含实验性功能
- 建议定期执行`git pull`获取最新更新
- 如果需要特定版本，可以使用`git checkout <tag>`切换到版本标签

**步骤3：编译项目**

使用Cargo（Rust的包管理器和构建工具）编译Allama。编译过程可能需要几分钟到几十分钟，具体时间取决于您的系统性能和网络速度。

```bash
# 使用release模式编译（优化性能，编译时间较长）
cargo build --release

# 如果只想快速测试，可以使用debug模式（编译快但性能较低）
cargo build
```

**编译参数说明：**
- `--release`: 启用所有优化，生成高性能的二进制文件，适合生产环境使用
- 不使用`--release`: 编译速度快，但性能较低，适合开发和调试
- 编译产物位于`target/release/`（release模式）或`target/debug/`（debug模式）

**编译优化建议：**
```bash
# 使用多核编译加速（使用所有CPU核心）
cargo build --release --jobs $(nproc)

# 仅编译allama二进制文件（不运行测试）
cargo build --release --bin allama

# 清理之前的编译产物（释放磁盘空间）
cargo clean
cargo build --release
```

**步骤4：验证编译结果**

编译完成后，验证生成的二进制文件是否正常工作。

```bash
# 检查二进制文件
ls -lh target/release/allama

# 显示版本信息
./target/release/allama --version

# 查看帮助信息
./target/release/allama --help
```

**步骤5：添加到系统PATH（可选但推荐）**

将Allama添加到系统PATH中，这样您就可以在任何位置直接使用allama命令，无需指定完整路径。

```bash
# 临时添加到PATH（当前终端会话有效）
export PATH=$PATH:$(pwd)/target/release

# 永久添加到PATH（添加到shell配置文件）
# 对于bash用户
echo 'export PATH=$PATH:$(pwd)/target/release' >> ~/.bashrc
source ~/.bashrc

# 对于zsh用户（macOS默认）
echo 'export PATH=$PATH:$(pwd)/target/release' >> ~/.zshrc
source ~/.zshrc

# 验证PATH配置
which allama
```

### 验证安装

完成安装后，通过一系列验证步骤确保Allama已正确安装并可以正常工作。

**步骤1：检查版本信息**

```bash
# 显示Allama版本
allama --version

# 或者使用完整路径
./target/release/allama --version
```

**预期输出：**
```
Allama v1.0.0
```

**步骤2：查看帮助信息**

```bash
# 查看所有可用命令
allama --help

# 查看特定命令的帮助
allama serve --help
allama pull --help
```

**步骤3：测试服务器启动**

```bash
# 启动服务器（前台运行，方便查看日志）
allama serve --port 11435

# 在另一个终端测试API
curl http://localhost:11435/api/tags
```

**步骤4：下载测试模型**

```bash
# 下载一个小型模型进行测试
allama pull llama3

# 查看已下载的模型
allama list
```

### 平台特定说明

不同操作系统可能有特定的安装要求和注意事项，请根据您的操作系统参考相应的说明。

#### Windows平台

**安装Rust：**
```powershell
# 使用PowerShell安装Rust
Invoke-WebRequest -Uri https://win.rustup.rs/x86_64 -OutFile rustup-init.exe
.\rustup-init.exe
```

**安装Visual Studio Build Tools：**
- 下载并安装Visual Studio Build Tools
- 确保包含"C++ build tools"组件
- 或者安装完整的Visual Studio Community

**编译注意事项：**
- Windows路径使用反斜杠`\`，但在命令中可以使用正斜杠`/`
- 可能需要管理员权限
- 防火墙可能会阻止网络访问，需要添加例外

#### macOS平台

**安装Xcode Command Line Tools：**
```bash
# 安装Xcode命令行工具
xcode-select --install

# 接受许可协议
sudo xcodebuild -license
```

**Apple Silicon优化：**
- M1/M2/M3芯片可以充分利用Metal加速
- 编译时会自动检测并启用Metal支持
- 建议使用Homebrew安装依赖：`brew install rust`

#### Linux平台

**安装依赖：**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install build-essential curl git pkg-config libssl-dev

# Fedora/CentOS
sudo dnf install gcc-c++ curl git pkg-config openssl-devel

# Arch Linux
sudo pacman -S base-devel curl git pkg-config openssl
```

**NVIDIA GPU支持：**
```bash
# 安装CUDA Toolkit
# 下载地址：https://developer.nvidia.com/cuda-downloads

# 安装cuDNN
# 下载地址：https://developer.nvidia.com/cudnn

# 验证CUDA安装
nvidia-smi
nvcc --version
```

### 常见编译问题

**问题1：编译失败，提示缺少依赖**

**解决方案：**
```bash
# 更新Cargo索引
cargo update

# 清理并重新编译
cargo clean
cargo build --release
```

**问题2：编译时间过长**

**解决方案：**
```bash
# 使用更多CPU核心
cargo build --release --jobs $(nproc)

# 使用ccache加速编译（需要先安装ccache）
export RUSTC_WRAPPER=ccache
cargo build --release
```

**问题3：链接器错误**

**解决方案：**
```bash
# Linux: 安装必要的链接器
sudo apt install binutils-dev

# macOS: 更新Xcode Command Line Tools
sudo xcode-select --install
```

### 卸载Allama

如果需要完全移除Allama，可以按照以下步骤操作。

**步骤1：停止运行的服务**
```bash
# 停止后台服务（如果正在运行）
allama stop

# 或者直接终止进程
pkill allama
```

**步骤2：删除二进制文件**
```bash
# 删除编译的二进制文件
rm -rf target/

# 如果添加到了PATH，需要从配置文件中删除
# 编辑 ~/.bashrc 或 ~/.zshrc，删除对应的export PATH行
```

**步骤3：删除数据文件（可选）**
```bash
# 删除Allama数据目录（包含模型、日志、数据库等）
rm -rf ~/.allama/

# 或者只删除特定目录
rm -rf ~/.allama/models/
rm -rf ~/.allama/data/
```

**步骤4：卸载Rust（可选）**
```bash
# 如果不再需要Rust，可以完全卸载
rustup self uninstall

# 删除Rust配置
rm -rf ~/.cargo/
rm -rf ~/.rustup/
```

**卸载说明：**
- 删除数据文件会丢失所有下载的模型和配置，请谨慎操作
- 建议在卸载前备份重要数据
- 如果计划重新安装，可以保留数据目录

---

## 模型兼容性指南

Allama基于llama.cpp构建，完全兼容llama.cpp的GGUF模型格式。这意味着您可以使用llama.cpp生态系统中的所有模型，无需任何转换或修改。

### 大模型支持（26B+ 模型与长上下文）

Allama支持通过llama-server运行大型模型（如Gemma4 26B）并支持长上下文窗口（96k tokens）。

**支持的大模型：**
- **Gemma4 26B**: 支持96k上下文窗口
- **Mixtral 8x7B**: 47B参数混合专家模型
- **LLaMA 3 70B**: 70B参数高质量模型

**长上下文支持：**
- **96k上下文**: 支持高达98,304 tokens的上下文窗口
- **TurboQuant**: 自动启用稀疏V反量化以优化内存使用
- **KV缓存优化**: 高效的KV缓存分配和管理
- **GPU卸载**: 完整的层和KV缓存GPU卸载

**重要说明：**
- 大模型（26B+）建议使用llama-server而非inference-service FFI后端
- llama-server对大模型有更好的内存管理和优化策略
- 96k上下文需要至少64GB系统内存
- 详见`examples/gemma4_26b_96k_context.rs`示例代码

**运行26B模型示例：**
```bash
# 确保 llama-server 已编译
cd /Users/arksong/Allama/build
make llama-server

# 运行26B模型测试示例
cargo run --example gemma4_26b_96k_context --features inference
```

**测试场景包括：**
- 英文对话
- 中文对话
- 代码生成
- 长文档摘要
- 多轮对话
- 创意写作
- 技术问答
- 数学推理

### GGUF模型格式

**什么是GGUF？**

GGUF（GPT-Generated Unified Format）是llama.cpp团队开发的一种高效的模型文件格式，专为大语言模型推理优化。它具有以下特点：

- **高效存储**: 使用量化技术大幅减少模型大小
- **快速加载**: 优化的文件结构，加载速度快
- **跨平台**: 支持多种硬件架构（x86_64, ARM64, Apple Silicon等）
- **灵活量化**: 支持多种量化级别（Q4_0, Q4_K_M, Q5_K_M, Q8_0, F16等）
- **元数据丰富**: 包含模型架构、参数、词汇表等完整信息

**GGUF vs 其他格式：**

| 格式 | 特点 | 文件大小 | 推理速度 | 兼容性 |
|------|------|---------|---------|--------|
| GGUF | 量化优化，元数据丰富 | 小 | 快 | llama.cpp, Allama |
| GGML | 早期格式，已废弃 | 中 | 中 | llama.cpp（旧版） |
| HF Transformers | Hugging Face格式 | 大 | 慢 | PyTorch, TensorFlow |
| SafeTensors | 安全的HF格式 | 大 | 慢 | PyTorch |

### Allama支持的模型

**支持的模型架构：**

Allama基于llama.cpp，支持llama.cpp支持的所有模型架构：

- **LLaMA系列**: LLaMA, LLaMA 2, LLaMA 3, LLaMA 3.1, LLaMA 3.2
- **Mistral系列**: Mistral 7B, Mixtral 8x7B, Mixtral 8x22B
- **Qwen系列**: Qwen, Qwen 1.5, Qwen 2, Qwen 2.5
- **Gemma系列**: Gemma, Gemma 2
- **Phi系列**: Phi-2, Phi-3
- **Yi系列**: Yi, Yi 1.5
- **DeepSeek系列**: DeepSeek, DeepSeek Coder
- **Falcon系列**: Falcon 7B, Falcon 40B
- **其他**: StarCoder, CodeLlama, Vicuna, Alpaca等

**支持的量化级别：**

| 量化级别 | 说明 | 大小比例 | 精度 | 推荐场景 |
|---------|------|---------|------|---------|
| F32 | 32位浮点 | 100% | 最高 | 精度要求极高的场景 |
| F16 | 16位浮点 | 50% | 高 | 平衡精度和性能 |
| Q8_0 | 8位量化 | 25% | 中高 | 高精度需求 |
| Q6_K | 6位量化 | 20% | 中 | 平衡精度和大小 |
| Q5_K_M | 5位量化 | 17% | 中低 | 推荐的通用量化 |
| Q4_K_M | 4位量化 | 13% | 中低 | 最常用的量化 |
| Q4_0 | 4位量化 | 13% | 低 | 兼容性最好 |
| Q3_K_M | 3位量化 | 10% | 低 | 极限压缩 |
| Q2_K | 2位量化 | 7% | 极低 | 仅用于测试 |

**推荐的量化级别：**
- **最佳平衡**: Q5_K_M 或 Q4_K_M
- **最佳性能**: Q4_K_M
- **最佳精度**: Q8_0 或 F16
- **极限压缩**: Q3_K_M

### 获取GGUF模型

**方法1：使用llama.cpp官方模型库**

llama.cpp官方维护了一个GGUF模型库，包含大量预转换的模型：

```bash
# 从llama.cpp官方模型库下载
# 访问：https://huggingface.co/TheBloke

# 示例：下载LLaMA 3 8B Q4_K_M模型
wget https://huggingface.co/TheBloke/Llama-3-8B-GGUF/resolve/main/llama-3-8b-q4_k_m.gguf

# 将模型放入Allama模型目录
mkdir -p ~/.allama/models/
mv llama-3-8b-q4_k_m.gguf ~/.allama/models/
```

**方法2：从Hugging Face下载**

Hugging Face上有大量GGUF格式的模型：

```bash
# 使用huggingface-cli下载
pip install huggingface-hub

# 下载模型
huggingface-cli download TheBloke/Llama-3-8B-GGUF llama-3-8b-q4_k_m.gguf --local-dir ~/.allama/models/

# 或者使用git-lfs
git lfs install
git clone https://huggingface.co/TheBloke/Llama-3-8B-GGUF ~/.allama/models/llama-3-8b
```

**方法3：手动转换HF模型**

如果您有Hugging Face格式的模型，可以使用llama.cpp提供的转换工具转换为GGUF：

```bash
# 克隆llama.cpp仓库
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# 转换模型
python convert.py /path/to/hf/model \
  --outfile ~/.allama/models/converted-model.gguf \
  --outtype q4_k_m
```

**方法4：使用Allama的pull命令**

Allama支持类似Ollama的模型下载功能（如果配置了模型仓库）：

```bash
# 下载模型
allama pull llama3

# 列出已下载的模型
allama list
```

### 使用GGUF模型

**步骤1：准备模型文件**

将GGUF模型文件放置在Allama的模型目录中：

```bash
# 创建模型目录
mkdir -p ~/.allama/models/

# 复制模型文件
cp /path/to/model.gguf ~/.allama/models/

# 验证模型
file ~/.allama/models/model.gguf
# 输出：model.gguf: GGUF v3 data
```

**步骤2：启动Allama服务器**

```bash
# 启动服务器
allama serve --port 11435
```

**步骤3：使用模型**

```bash
# 通过API使用模型
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{
    "model": "/path/to/model.gguf",
    "prompt": "Hello, world!",
    "stream": false
  }'
```

**步骤4：配置模型别名（可选）**

为了方便使用，可以为模型配置别名：

```bash
# 创建模型配置文件
cat > ~/.allama/models/aliases.json << EOF
{
  "llama3": "~/.allama/models/llama-3-8b-q4_k_m.gguf",
  "mistral": "~/.allama/models/mistral-7b-q4_k_m.gguf",
  "qwen": "~/.allama/models/qwen-7b-q4_k_m.gguf"
}
EOF

# 使用别名调用
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","prompt":"Hello!","stream":false}'
```

### 模型性能优化

**1. 选择合适的量化级别**

根据硬件和需求选择合适的量化级别：

```bash
# 查看不同量化级别的性能对比
# Q4_K_M: 13%大小，95%精度，推荐用于大多数场景
# Q5_K_M: 17%大小，97%精度，推荐用于高精度需求
# Q8_0: 25%大小，99%精度，推荐用于最高精度需求
```

**2. 使用GPU加速**

如果您的系统支持GPU，Allama会自动使用GPU加速：

```bash
# 检查GPU支持
nvidia-smi  # NVIDIA GPU
rocm-smi   # AMD GPU

# Allama会自动检测并使用GPU
# 无需额外配置
```

**3. 调整上下文长度**

根据需求调整模型的上下文长度：

```bash
# 使用较小的上下文长度以提高速度
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3","prompt":"test","stream":false,"options":{"ctx_size":2048}}'

# 使用较大的上下文长度以支持长文本
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3","prompt":"test","stream":false,"options":{"ctx_size":8192}}'
```

**4. 批处理**

对于批量处理，可以增加并行度：

```bash
# 启动服务器时设置更高的并行度
allama serve --parallel 4
```

### 常用模型推荐

**入门级模型（适合测试和学习）：**

| 模型 | 参数 | 量化 | 大小 | VRAM需求 | 用途 |
|------|------|------|------|----------|------|
| LLaMA 3 8B | 8B | Q4_K_M | 4.7GB | 6GB | 通用对话 |
| Mistral 7B | 7B | Q4_K_M | 4.1GB | 5GB | 通用对话 |
| Phi-3 Mini | 3.8B | Q4_K_M | 2.3GB | 3GB | 轻量级任务 |

**中级模型（适合日常使用）：**

| 模型 | 参数 | 量化 | 大小 | VRAM需求 | 用途 |
|------|------|------|------|----------|------|
| LLaMA 3 8B | 8B | Q5_K_M | 5.5GB | 7GB | 高精度对话 |
| Qwen 2 7B | 7B | Q4_K_M | 4.2GB | 5GB | 中文优化 |
| Gemma 2 9B | 9B | Q4_K_M | 5.4GB | 7GB | 多语言 |

**高级模型（适合专业用途）：**

| 模型 | 参数 | 量化 | 大小 | VRAM需求 | 用途 |
|------|------|------|------|----------|------|
| Mixtral 8x7B | 47B | Q4_K_M | 26GB | 30GB | 复杂推理 |
| LLaMA 3 70B | 70B | Q4_K_M | 41GB | 45GB | 高质量生成 |
| DeepSeek Coder | 33B | Q4_K_M | 19GB | 22GB | 代码生成 |

### 模型兼容性验证

**验证模型格式：**

```bash
# 检查模型文件格式
file ~/.allama/models/model.gguf

# 预期输出
# model.gguf: GGUF v3 data
```

**验证模型完整性：**

```bash
# 使用llama.cpp的llama-cli验证
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# 编译
make

# 验证模型
./llama-cli -m ~/.allama/models/model.gguf -p "test" -n 10
```

**测试模型推理：**

```bash
# 使用Allama API测试
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"model.gguf","prompt":"Hello, world!","stream":false}'
```

### 常见问题

**Q: Allama支持哪些模型格式？**
A: Allama主要支持GGUF格式，这是llama.cpp的标准格式。理论上支持llama.cpp支持的所有模型架构。

**Q: 可以使用Hugging Face的原始模型吗？**
A: 不可以直接使用，需要先转换为GGUF格式。可以使用llama.cpp的convert.py工具进行转换。

**Q: 如何选择合适的量化级别？**
A: 推荐使用Q4_K_M作为默认选择，它在大小和精度之间提供了最佳平衡。如果需要更高精度，可以使用Q5_K_M或Q8_0。

**Q: 模型文件太大怎么办？**
A: 可以选择更低级别的量化（如Q3_K_M），或者使用参数更小的模型。

**Q: 可以同时加载多个模型吗？**
A: 可以，但受限于系统内存。可以在启动服务器时设置`--max-loaded-models`参数来控制最大加载模型数。

**Q: Allama与Ollama的模型兼容吗？**
A: 完全兼容。Allama使用与Ollama相同的模型格式和目录结构，可以直接使用Ollama的模型。

**Q: 如何更新模型？**
A: 下载新的GGUF模型文件，替换旧文件即可。建议先备份旧模型。

**Q: 模型推理速度慢怎么办？**
A: 1) 使用更低级别的量化；2) 启用GPU加速；3) 增加并行度；4) 使用更小的模型。

---

## Ollama迁移指南

如果您已经熟悉Ollama或正在使用Ollama，迁移到Allama非常简单。Allama在设计上与Ollama保持完全兼容，这意味着您可以无缝迁移，无需学习新的命令或修改现有代码。

### 为什么选择Allama？

**Ollama的优势：**
- 简单易用，适合个人开发者
- 轻量级，资源占用低
- 社区活跃，模型丰富
- 快速迭代，功能更新快

**Allama的增强：**
- **企业级认证**：支持多用户环境，API Key管理
- **精确计费**：token级别的使用追踪和成本分析
- **配额管理**：灵活的速率限制和月度配额设置
- **航空级安全**：代码签名、审计日志、完整性保护
- **故障容错**：超时保护、重试机制、优雅降级
- **异常检测**：资源监控、阈值检测、自动告警
- **完全兼容**：与Ollama命令、API、模型格式100%兼容

### 迁移场景

**场景1：个人开发者**

如果您是个人开发者，主要在本地使用：

```bash
# Ollama的使用方式
ollama serve
ollama run llama3

# Allama的使用方式（完全相同）
allama serve
allama run llama3
```

**迁移步骤：**
1. 编译安装Allama（参考安装指南）
2. 将`ollama`命令替换为`allama`命令
3. 所有脚本和配置无需修改
4. 可以选择性地启用认证和计费功能

**场景2：团队协作**

如果您需要为团队提供共享的LLM服务：

```bash
# Ollama：无法区分用户，难以管理
ollama serve --host 0.0.0.0

# Allama：可以为每个团队成员创建独立账号
allama serve --host 0.0.0.0
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@team.com","rate_limit":60,"monthly_quota":1000000}'
```

**迁移步骤：**
1. 安装Allama并启动服务器
2. 为团队成员创建用户账号
3. 分配不同的API Key和配额
4. 监控使用情况，优化资源分配

**场景3：生产环境**

如果您需要在生产环境中部署LLM服务：

```bash
# Ollama：缺乏认证和计费，不适合生产
ollama serve --host 0.0.0.0

# Allama：完整的认证、计费、监控
allama serve --host 0.0.0.0 --parallel 4
```

**迁移步骤：**
1. 使用Allama的systemd服务管理
2. 配置反向代理（Nginx）
3. 启用HTTPS加密
4. 创建生产用户账号
5. 设置监控和告警
6. 定期备份认证和计费数据库

### 命令迁移对照表

**基础命令：**

| Ollama命令 | Allama命令 | 差异 | 说明 |
|-----------|-----------|------|------|
| `ollama serve` | `allama serve` | 无 | 完全相同，参数兼容 |
| `ollama list` | `allama list` | 无 | 完全相同 |
| `ollama ls` | `allama ls` | 无 | 完全相同 |
| `ollama pull llama3` | `allama pull llama3` | 无 | 完全相同 |
| `ollama run llama3` | `allama run llama3` | 无 | 完全相同 |
| `ollama show llama3` | `allama show llama3` | 无 | 完全相同 |
| `ollama rm llama3` | `allama rm llama3` | 无 | 完全相同 |
| `ollama ps` | `allama ps` | 无 | 完全相同 |

**高级命令：**

| Ollama命令 | Allama命令 | 差异 | 说明 |
|-----------|-----------|------|------|
| `ollama create my-model` | `allama create my-model` | 无 | 完全相同 |
| `ollama cp llama3 my-llama3` | `allama cp llama3 my-llama3` | 无 | 完全相同 |
| `ollama push my-model` | `allama push my-model` | 无 | 完全相同 |
| `ollama stop llama3` | `allama stop llama3` | 无 | 完全相同 |
| `ollama launch` | `allama launch` | 无 | 完全相同 |
| `ollama signin` | `allama signin` | 无 | 完全相同 |
| `ollama signout` | `allama signout` | 无 | 完全相同 |
| `ollama version` | `allama version` | 无 | 完全相同 |

**Allama特有命令：**

| Allama命令 | 说明 | Ollama对应 |
|-----------|------|-----------|
| `allama install` | 安装系统服务 | 无 |
| `allama uninstall` | 卸载系统服务 | 无 |
| `allama start` | 启动后台服务 | 无 |
| `allama stop` | 停止后台服务 | 无（与ollama stop <model>不同） |
| `allama status` | 检查服务状态 | 无 |
| `allama update` | 更新版本 | 无 |

### API迁移对照表

**Ollama API端点 → Allama API端点：**

| Ollama端点 | Allama端点 | 认证要求 | 差异 |
|-----------|-----------|---------|------|
| `GET /api/tags` | `GET /api/tags` | 本地无需 | 完全相同 |
| `POST /api/generate` | `POST /api/generate` | 远程需要 | 完全相同 |
| `POST /api/chat` | `POST /api/chat` | 远程需要 | 完全相同 |
| `POST /api/embed` | `POST /api/embed` | 远程需要 | 完全相同 |
| `GET /api/ps` | `GET /api/ps` | 本地无需 | 完全相同 |
| `POST /api/show` | `POST /api/show` | 远程需要 | 完全相同 |
| `DELETE /api/delete` | `DELETE /api/delete` | 远程需要 | 完全相同 |
| `POST /api/pull` | `POST /api/pull` | 远程需要 | 完全相同 |
| `POST /api/push` | `POST /api/push` | 远程需要 | 完全相同 |
| `POST /api/create` | `POST /api/create` | 远程需要 | 完全相同 |
| `POST /api/copy` | `POST /api/copy` | 远程需要 | 完全相同 |
| `POST /api/stop` | `POST /api/stop` | 远程需要 | 完全相同 |

**Allama新增API端点：**

| Allama端点 | 说明 | Ollama对应 |
|-----------|------|-----------|
| `POST /api/users` | 创建用户 | 无 |
| `GET /api/users` | 列出用户 | 无 |
| `GET /api/billing/records` | 获取计费记录 | 无 |
| `GET /api/billing/summary` | 获取计费摘要 | 无 |
| `GET /api/billing/stats/:model` | 获取模型统计 | 无 |

### 模型迁移

**模型文件位置：**

- **Ollama**: `~/.ollama/models/`
- **Allama**: `~/.allama/models/`

**迁移方法：**

```bash
# 方法1：直接复制模型文件
cp -r ~/.ollama/models/* ~/.allama/models/

# 方法2：重新下载（推荐，确保兼容性）
allama pull llama3
allama pull mistral
# ... 其他模型

# 验证模型
allama list
```

**模型格式兼容性：**

- Allama使用与Ollama完全相同的模型格式
- GGUF格式模型完全兼容
- 量化参数完全兼容
- Modelfile配置完全兼容

### 配置文件迁移

**Modelfile兼容性：**

Allama完全支持Ollama的Modelfile格式，无需修改：

```dockerfile
# Modelfile示例（Ollama和Allama都支持）
FROM llama3
PARAMETER temperature 0.7
PARAMETER top_p 0.9
SYSTEM You are a helpful assistant.
```

**环境变量迁移：**

| Ollama环境变量 | Allama环境变量 | 兼容性 |
|---------------|---------------|--------|
| `OLLAMA_HOST` | `OLLAMA_HOST` | ✅ 完全兼容 |
| `OLLAMA_NUM_PARALLEL` | `OLLAMA_NUM_PARALLEL` | ✅ 完全兼容 |
| `OLLAMA_MAX_LOADED_MODELS` | `OLLAMA_MAX_LOADED_MODELS` | ✅ 完全兼容 |
| `OLLAMA_MAX_QUEUE` | `OLLAMA_MAX_QUEUE` | ✅ 完全兼容 |
| `ALLAMA_API_KEY` | `ALLAMA_API_KEY` | ❌ Allama特有 |
| `RUST_LOG` | `RUST_LOG` | ❌ Allama特有 |

### 客户端代码迁移

**Python客户端迁移：**

```python
# Ollama客户端
import ollama
response = ollama.generate(model='llama3', prompt='Hello')

# Allama客户端（使用相同的API）
import ollama
# 只需更改base_url
response = ollama.generate(
    model='llama3', 
    prompt='Hello',
    host='http://localhost:11435'  # 如果端口不同
)

# 或者使用Allama的认证功能
import requests
response = requests.post(
    'http://localhost:11435/api/generate',
    headers={
        'Authorization': 'Bearer your_api_key',
        'Content-Type': 'application/json'
    },
    json={'model': 'llama3', 'prompt': 'Hello'}
)
```

**JavaScript客户端迁移：**

```javascript
// Ollama客户端
import ollama from 'ollama';
const response = await ollama.generate({ model: 'llama3', prompt: 'Hello' });

// Allama客户端（使用相同的API）
import ollama from 'ollama';
const response = await ollama.generate({
    model: 'llama3', 
    prompt: 'Hello',
    host: 'http://localhost:11435'  // 如果端口不同
});

// 或者使用Allama的认证功能
const response = await fetch('http://localhost:11435/api/generate', {
    method: 'POST',
    headers: {
        'Authorization': 'Bearer your_api_key',
        'Content-Type': 'application/json'
    },
    body: JSON.stringify({ model: 'llama3', prompt: 'Hello' })
});
```

### 渐进式迁移策略

**阶段1：并行运行（1-2周）**

```bash
# 同时运行Ollama和Allama
ollama serve --port 11434 &
allama serve --port 11435 &

# 测试Allama的兼容性
curl http://localhost:11435/api/tags
curl http://localhost:11434/api/tags

# 对比结果
diff <(curl http://localhost:11435/api/tags) <(curl http://localhost:11434/api/tags)
```

**阶段2：功能验证（1周）**

```bash
# 验证所有常用命令
allama list
allama pull llama3
allama run llama3 --prompt "test"
allama show llama3

# 验证API兼容性
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3","prompt":"test","stream":false}'
```

**阶段3：启用认证（1周）**

```bash
# 创建测试用户
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@example.com","rate_limit":60,"monthly_quota":100000}'

# 测试认证
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test_api_key" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"test","stream":false}'
```

**阶段4：启用计费（1周）**

```bash
# 查看计费记录
curl -X GET "http://localhost:11435/api/billing/records?limit=10" \
  -H "Authorization: Bearer test_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"

# 查看计费摘要
curl -X GET http://localhost:11435/api/billing/summary \
  -H "Authorization: Bearer test_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

**阶段5：完全迁移（1周）**

```bash
# 停止Ollama
pkill ollama

# 切换到Allama
allama serve --port 11434  # 使用Ollama的默认端口

# 更新所有脚本和配置
# 将 ollama 替换为 allama
```

### 迁移检查清单

**迁移前：**
- [ ] 备份Ollama模型文件
- [ ] 备份Ollama配置文件
- [ ] 记录当前Ollama版本和配置
- [ ] 准备Allama安装环境
- [ ] 制定迁移计划和时间表

**迁移中：**
- [ ] 安装Allama
- [ ] 复制或重新下载模型
- [ ] 验证命令兼容性
- [ ] 验证API兼容性
- [ ] 测试常用功能
- [ ] 验证性能表现

**迁移后：**
- [ ] 停止Ollama服务
- [ ] 切换到Allama
- [ ] 更新所有脚本和配置
- [ ] 创建用户账号（如需要）
- [ ] 启用认证（如需要）
- [ ] 启用计费（如需要）
- [ ] 监控系统运行
- [ ] 培训团队成员

### 常见迁移问题

**问题1：模型文件不兼容**

**解决方案：**
```bash
# 重新下载模型
allama pull llama3

# 或者检查模型格式
file ~/.allama/models/llama3/*
```

**问题2：API端点返回401**

**解决方案：**
```bash
# 本地请求添加IP头部
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","prompt":"test","stream":false}'

# 或使用API Key
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"test","stream":false}'
```

**问题3：性能不如Ollama**

**解决方案：**
```bash
# 增加并行处理数
allama serve --parallel 4

# 增加最大加载模型数
allama serve --max-loaded-models 5

# 检查系统资源
allama status
```

**问题4：配置文件不兼容**

**解决方案：**
```bash
# 检查Modelfile格式
# Allama完全支持Ollama的Modelfile格式
# 如果有自定义格式，需要转换为标准格式

# 检查环境变量
env | grep OLLAMA
env | grep ALLAMA
```

### 迁移最佳实践

1. **备份优先**：迁移前务必备份所有数据和配置
2. **渐进式迁移**：不要一次性迁移，分阶段进行
3. **充分测试**：在每个阶段都进行充分测试
4. **监控性能**：密切关注系统性能和资源使用
5. **文档记录**：记录迁移过程中的所有问题和解决方案
6. **团队培训**：确保团队成员了解Allama的新功能
7. **回滚计划**：准备回滚方案，以防迁移失败

### 迁移时间估算

| 迁移场景 | 预计时间 | 说明 |
|---------|---------|------|
| 个人开发者 | 30分钟 | 安装+验证 |
| 小型团队（<10人） | 2-3天 | 安装+配置+培训 |
| 中型团队（10-50人） | 1-2周 | 安装+配置+培训+测试 |
| 大型团队（>50人） | 2-4周 | 安装+配置+培训+测试+监控 |

---

## CLI命令参考

Allama提供了一套完整的命令行接口，与Ollama保持完全一致，同时增加了企业级功能。所有命令都支持`--help`参数查看详细帮助信息。

### Ollama兼容性说明

**完全兼容的命令：**

Allama与Ollama的命令行接口完全兼容，以下命令在两个系统中的用法完全相同：

| Allama命令 | Ollama命令 | 兼容性 | 说明 |
|-----------|-----------|--------|------|
| `allama serve` | `ollama serve` | ✅ 100% | 启动服务器，参数完全相同 |
| `allama list` / `allama ls` | `ollama list` / `ollama ls` | ✅ 100% | 列出模型 |
| `allama pull` | `ollama pull` | ✅ 100% | 下载模型 |
| `allama run` | `ollama run` | ✅ 100% | 运行模型 |
| `allama show` | `ollama show` | ✅ 100% | 显示模型信息 |
| `allama rm` | `ollama rm` | ✅ 100% | 删除模型 |
| `allama ps` | `ollama ps` | ✅ 100% | 列出运行中的模型 |
| `allama create` | `ollama create` | ✅ 100% | 创建自定义模型 |
| `allama cp` | `ollama cp` | ✅ 100% | 复制模型 |
| `allama push` | `ollama push` | ✅ 100% | 推送模型 |
| `allama stop <model>` | `ollama stop <model>` | ✅ 100% | 停止运行中的模型 |
| `allama launch` | `ollama launch` | ✅ 100% | 启动集成 |
| `allama signin` | `ollama signin` | ✅ 100% | 登录账户 |
| `allama signout` | `ollama signout` | ✅ 100% | 登出账户 |
| `allama version` | `ollama version` | ✅ 100% | 显示版本信息 |

**Allama特有的命令：**

以下命令是Allama独有的，用于企业级功能管理：

| Allama命令 | 说明 | Ollama对应 |
|-----------|------|-----------|
| `allama install` | 安装Allama系统服务 | 无对应 |
| `allama uninstall` | 卸载Allama系统服务 | 无对应 |
| `allama start` | 启动Allama后台服务 | 无对应 |
| `allama stop` | 停止Allama后台服务 | 无对应 |
| `allama status` | 检查Allama服务状态 | 无对应 |
| `allama update` | 更新Allama到最新版本 | 无对应 |

**迁移建议：**

如果您正在从Ollama迁移到Allama：

1. **无需修改命令**：所有Ollama命令都可以直接在Allama中使用
2. **模型文件兼容**：可以直接使用已有的Ollama模型，无需重新下载
3. **配置文件兼容**：Modelfile等配置文件可以直接使用
4. **环境变量兼容**：可以继续使用相同的环境变量
5. **API兼容**：客户端代码无需修改，只需更改端点地址
6. **渐进式迁移**：可以先使用基础功能，再逐步启用认证和计费功能

### 服务管理命令

#### `allama serve` - 启动Allama服务器

启动Allama HTTP服务器，提供API服务。这是最常用的命令，用于启动推理服务。

**语法：**
```bash
allama serve [OPTIONS]
```

**选项：**
- `--host <HOST>`: 绑定的主机地址（默认：127.0.0.1）。支持环境变量`OLLAMA_HOST`
- `-p, --port <PORT>`: 绑定的端口号（默认：11434）
- `--parallel <NUM>`: 并行处理请求数（默认：1）。支持环境变量`OLLAMA_NUM_PARALLEL`
- `-m, --max-loaded-models <NUM>`: 最大加载模型数（默认：3）。支持环境变量`OLLAMA_MAX_LOADED_MODELS`
- `-q, --max-queue <NUM>`: 最大队列大小（默认：512）。支持环境变量`OLLAMA_MAX_QUEUE`

**使用示例：**
```bash
# 默认配置启动
./target/release/allama serve

# 指定端口启动
./target/release/allama serve --port 8080

# 监听所有网络接口
./target/release/allama serve --host 0.0.0.0 --port 8080

# 高并发配置
./target/release/allama serve --parallel 4 --max-loaded-models 5

# 使用环境变量配置
export OLLAMA_HOST=0.0.0.0
export OLLAMA_NUM_PARALLEL=8
./target/release/allama serve
```

**详细说明：**
- `--host`参数控制服务器监听的网络接口。`127.0.0.1`仅允许本地访问，`0.0.0.0`允许所有网络接口访问
- `--parallel`参数控制同时处理的请求数，增加此值可以提高吞吐量，但会增加内存和CPU使用
- `--max-loaded-models`限制同时加载到内存的模型数量，避免内存溢出
- `--max-queue`设置请求队列大小，超过此值的请求将被拒绝
- 服务器启动时会自动创建默认测试用户，并显示API Key信息

#### `allama start` - 启动Allama后台服务

以守护进程方式启动Allama服务，适合生产环境部署。

**语法：**
```bash
allama start
```

**使用示例：**
```bash
# 启动后台服务
./target/release/allama start

# 检查服务状态
./target/release/allama status
```

**详细说明：**
- 此命令将Allama作为系统服务启动，支持开机自启
- 服务日志会记录到系统日志目录
- 适合长期运行的部署场景

#### `allama stop` - 停止Allama后台服务

停止正在运行的Allama后台服务。

**语法：**
```bash
allama stop
```

**使用示例：**
```bash
# 停止后台服务
./target/release/allama stop
```

**详细说明：**
- 会优雅地关闭服务，完成当前正在处理的请求
- 不会删除已下载的模型文件
- 可以使用`start`命令重新启动服务

#### `allama status` - 检查Allama服务状态

显示Allama服务的运行状态和资源使用情况。

**语法：**
```bash
allama status
```

**使用示例：**
```bash
# 检查服务状态
./target/release/allama status
```

**详细说明：**
- 显示服务是否正在运行
- 显示已加载的模型列表
- 显示CPU、内存使用情况（如果启用了异常检测）
- 显示请求队列状态

### 模型管理命令

#### `allama list` 或 `allama ls` - 列出已安装的模型

列出所有已下载到本地的模型。

**语法：**
```bash
allama list
allama ls
```

**使用示例：**
```bash
# 列出所有模型
./target/release/allama list

# 使用简写
./target/release/allama ls
```

**详细说明：**
- 显示模型名称、大小、修改时间等信息
- 模型按字母顺序排列
- 可以快速查看系统中可用的模型

#### `allama pull` - 下载模型

从模型仓库下载指定的模型到本地。

**语法：**
```bash
allama pull <MODEL>
```

**参数：**
- `MODEL`: 要下载的模型名称（如：llama3, mistral, qwen等）

**使用示例：**
```bash
# 下载llama3模型
./target/release/allama pull llama3

# 下载mistral模型
./target/release/allama pull mistral
```

**详细说明：**
- 模型会下载到Allama的数据目录（通常是`~/.allama/models/`）
- 下载过程可能需要较长时间，取决于模型大小和网络速度
- 支持断点续传
- 下载完成后可以立即使用

#### `allama run` - 运行模型

在命令行中运行指定的模型，进行交互式对话。

**语法：**
```bash
allama run <MODEL> [OPTIONS]
```

**参数：**
- `MODEL`: 要运行的模型名称

**选项：**
- `-p, --prompt <PROMPT>`: 直接发送提示词，不进入交互模式
- `--embeddings`: 生成嵌入向量而不是文本

**使用示例：**
```bash
# 交互式运行
./target/release/allama run llama3

# 直接发送提示词
./target/release/allama run llama3 --prompt "Hello, world!"

# 生成嵌入向量
./target/release/allama run llama3 --embeddings
```

**详细说明：**
- 交互模式支持多轮对话
- 可以使用Ctrl+C退出
- 适合快速测试和调试
- 生产环境建议使用API接口

#### `allama show` - 显示模型详细信息

显示指定模型的详细信息，包括参数、大小、架构等。

**语法：**
```bash
allama show <MODEL>
```

**参数：**
- `MODEL`: 要查看的模型名称

**使用示例：**
```bash
# 查看llama3模型信息
./target/release/allama show llama3

# 查看mistral模型信息
./target/release/allama show mistral
```

**详细说明：**
- 显示模型架构信息
- 显示参数数量
- 显示量化信息
- 显示上下文长度
- 显示模型大小

#### `allama rm` - 删除模型

删除本地已下载的模型文件。

**语法：**
```bash
allama rm <MODEL>
```

**参数：**
- `MODEL`: 要删除的模型名称

**使用示例：**
```bash
# 删除llama3模型
./target/release/allama rm llama3

# 删除mistral模型
./target/release/allama rm mistral
```

**详细说明：**
- 操作不可逆，删除后需要重新下载
- 会释放磁盘空间
- 不会影响其他已加载的模型
- 如果模型正在使用，会先停止再删除

#### `allama ps` - 列出运行中的模型

列出当前正在内存中运行的模型。

**语法：**
```bash
allama ps
```

**使用示例：**
```bash
# 查看运行中的模型
./target/release/allama ps
```

**详细说明：**
- 显示模型名称、PID、内存使用等信息
- 显示模型加载时间
- 显示当前处理的请求数
- 用于监控模型运行状态

#### `allama stop <model>` - 停止运行中的模型

停止指定模型的运行，释放内存。

**语法：**
```bash
allama stop <MODEL>
```

**参数：**
- `MODEL`: 要停止的模型名称

**使用示例：**
```bash
# 停止llama3模型
./target/release/allama stop llama3
```

**详细说明：**
- 会优雅地完成当前正在处理的请求
- 释放模型占用的内存
- 不会删除模型文件，可以重新加载
- 适合内存不足时使用

#### `allama create` - 创建自定义模型

基于现有的模型创建自定义模型，可以修改参数和配置。

**语法：**
```bash
allama create <MODEL> [OPTIONS]
```

**参数：**
- `MODEL`: 新模型的名称

**选项：**
- `-f, --from <SOURCE>`: 基础模型名称

**使用示例：**
```bash
# 基于llama3创建自定义模型
./target/release/allama create my-model --from llama3
```

**详细说明：**
- 需要提供Modelfile配置文件
- 可以调整模型参数
- 支持微调和量化
- 适合需要定制化的场景

#### `allama cp` - 复制模型

复制现有的模型，创建一个副本。

**语法：**
```bash
allama cp <SOURCE> <DESTINATION>
```

**参数：**
- `SOURCE`: 源模型名称
- `DESTINATION`: 目标模型名称

**使用示例：**
```bash
# 复制llama3到my-llama3
./target/release/allama cp llama3 my-llama3
```

**详细说明：**
- 创建模型的完整副本
- 不会影响原始模型
- 适合需要多个相同模型实例的场景
- 会占用额外的磁盘空间

#### `allama push` - 推送模型到仓库

将本地模型推送到模型仓库。

**语法：**
```bash
allama push <MODEL> [OPTIONS]
```

**参数：**
- `MODEL`: 要推送的模型名称

**选项：**
- `--insecure`: 使用不安全连接（仅用于测试）

**使用示例：**
```bash
# 推送模型到仓库
./target/release/allama push my-model

# 使用不安全连接（测试用）
./target/release/allama push my-model --insecure
```

**详细说明：**
- 需要先登录到模型仓库
- 适合分享自定义模型
- 推送过程可能需要较长时间
- 支持私有仓库

### 系统管理命令

#### `allama install` - 安装Allama

执行Allama的安装程序，配置系统环境。

**语法：**
```bash
allama install [OPTIONS]
```

**选项：**
- `-d, --dir <DIRECTORY>`: 自定义安装目录

**使用示例：**
```bash
# 默认安装
./target/release/allama install

# 自定义安装目录
./target/release/allama install --dir /opt/allama
```

**详细说明：**
- 自动检测平台并执行相应安装
- 配置系统PATH
- 创建数据目录
- 注册系统服务
- 首次使用时需要运行

#### `allama uninstall` - 卸载Allama

从系统中移除Allama，删除相关文件和配置。

**语法：**
```bash
allama uninstall
```

**使用示例：**
```bash
# 卸载Allama
./target/release/allama uninstall
```

**详细说明：**
- 会询问确认
- 删除程序文件
- 保留数据目录（模型、日志等）
- 可以选择保留配置
- 适合完全移除Allama

#### `allama update` - 更新Allama

检查并更新Allama到最新版本。

**语法：**
```bash
allama update
```

**使用示例：**
```bash
# 更新到最新版本
./target/release/allama update
```

**详细说明：**
- 检查远程仓库的最新版本
- 下载新版本
- 自动备份当前版本
- 保留配置和数据
- 建议定期执行以获取最新功能和安全修复

#### `allama version` - 显示版本信息

显示Allama的版本号和构建信息。

**语法：**
```bash
allama version
```

**使用示例：**
```bash
# 显示版本信息
./target/release/allama version
```

**详细说明：**
- 显示语义化版本号
- 显示Git提交哈希（如果可用）
- 显示构建时间
- 用于诊断和报告问题

### 集成命令

#### `allama launch` - 启动集成

启动Allama与开发工具的集成，提供更好的开发体验。

**语法：**
```bash
allama launch [OPTIONS]
```

**选项：**
- `-i, --integration <NAME>`: 集成名称（opencode, claude, codex, vscode, droid）
- `-m, --model <MODEL>`: 使用的模型
- `-c, --config`: 显示配置信息

**使用示例：**
```bash
# 启动默认集成
./target/release/allama launch

# 启动特定集成
./target/release/allama launch --integration vscode

# 指定模型
./target/release/allama launch --model llama3

# 显示配置
./target/release/allama launch --config
```

**详细说明：**
- 提供与IDE的集成
- 支持代码补全
- 支持代码生成
- 提高开发效率
- 需要额外的配置

#### `allama signin` - 登录账户

登录到Ollama Cloud账户，访问云端模型和服务。

**语法：**
```bash
allama signin
```

**使用示例：**
```bash
# 登录账户
./target/release/allama signin
```

**详细说明：**
- 会打开浏览器进行认证
- 需要有效的账户
- 登录后可以访问云端模型
- 支持同步配置
- 可选功能

#### `allama signout` - 登出账户

登出Ollama Cloud账户。

**语法：**
```bash
allama signout
```

**使用示例：**
```bash
# 登出账户
./target/release/allama signout
```

**详细说明：**
- 清除本地认证信息
- 不再访问云端资源
- 可以重新登录
- 不影响本地模型

### 环境变量

Allama支持通过环境变量配置常用参数，便于脚本化和自动化部署。

| 环境变量 | 说明 | 默认值 |
|---------|------|--------|
| `OLLAMA_HOST` | 服务器监听地址 | 127.0.0.1 |
| `OLLAMA_NUM_PARALLEL` | 并行请求数 | 1 |
| `OLLAMA_MAX_LOADED_MODELS` | 最大加载模型数 | 3 |
| `OLLAMA_MAX_QUEUE` | 最大队列大小 | 512 |
| `ALLAMA_API_KEY` | 默认API Key | 无 |
| `ALLAMA_PORT` | 服务器端口 | 11434 |
| `RUST_LOG` | 日志级别 | info |

**使用示例：**
```bash
# 设置环境变量
export OLLAMA_HOST=0.0.0.0
export OLLAMA_NUM_PARALLEL=4
export RUST_LOG=debug

# 启动服务器
./target/release/allama serve
```

### 命令速查表

| 命令 | 功能 | 常用场景 |
|------|------|----------|
| `serve` | 启动服务器 | 启动API服务 |
| `start` | 启动后台服务 | 生产环境部署 |
| `stop` | 停止后台服务 | 停止服务 |
| `status` | 检查状态 | 监控服务 |
| `list` / `ls` | 列出模型 | 查看可用模型 |
| `pull` | 下载模型 | 获取新模型 |
| `run` | 运行模型 | 交互式对话 |
| `show` | 显示模型信息 | 查看模型详情 |
| `rm` | 删除模型 | 释放磁盘空间 |
| `ps` | 列出运行模型 | 监控模型 |
| `create` | 创建自定义模型 | 定制模型 |
| `cp` | 复制模型 | 创建模型副本 |
| `push` | 推送模型 | 分享模型 |
| `install` | 安装 | 首次安装 |
| `uninstall` | 卸载 | 移除Allama |
| `update` | 更新 | 升级版本 |
| `version` | 版本信息 | 查看版本 |
| `launch` | 启动集成 | IDE集成 |
| `signin` | 登录 | 云端服务 |
| `signout` | 登出 | 退出云端 |

---

## 认证系统应用案例

### Ollama与Allama在认证方面的对比

**Ollama的认证方式：**
- Ollama本身不提供用户认证系统
- 依赖反向代理（如Nginx）进行基本的IP限制
- 无法区分不同用户的使用情况
- 无法实现精细的权限控制
- 适合个人使用或受信任的局域网环境

**Allama的认证方式：**
- 内置完整的用户认证系统
- 支持API Key认证
- 可以为每个用户设置独立的速率限制和配额
- 支持用户创建、列表、管理
- 适合团队协作和生产环境

**从Ollama迁移到Allama认证系统：**

如果您正在使用Ollama并通过反向代理进行基本的访问控制，迁移到Allama的认证系统可以提供更精细的控制：

```bash
# Ollama方式：通过Nginx限制IP
# nginx.conf
location /api/ {
    allow 192.168.1.0/24;
    deny all;
    proxy_pass http://localhost:11434;
}

# Allama方式：通过API Key认证
# 无需修改Nginx配置，直接使用Allama的认证
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer user_api_key" \
  -d '{"model":"llama3","prompt":"test"}'
```

### 案例1：创建企业用户账号

**场景**：企业需要为不同部门创建独立的API访问账号，每个部门有不同的配额限制。

**实现步骤：**

```bash
# 创建研发部门账号
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{
    "username": "rd_team",
    "email": "rd@company.com",
    "rate_limit": 120,
    "monthly_quota": 5000000
  }'

# 创建市场部门账号
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{
    "username": "marketing_team",
    "email": "marketing@company.com",
    "rate_limit": 60,
    "monthly_quota": 1000000
  }'
```

**响应示例：**

```json
{
  "user_id": "user_abc123",
  "username": "rd_team",
  "email": "rd@company.com",
  "api_key": "allama_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "rate_limit": 120,
  "monthly_quota": 5000000,
  "created_at": "2026-05-03T08:00:00Z"
}
```

### 案例2：Python应用集成认证

**场景**：Python后端应用需要使用Allama API进行文本生成，需要集成认证机制。

**实现代码：**

```python
import requests
import os

class AllamaClient:
    def __init__(self, base_url="http://localhost:11435", api_key=None):
        self.base_url = base_url
        self.api_key = api_key or os.getenv("ALLAMA_API_KEY")
        
    def generate(self, model, prompt, stream=False):
        """生成文本"""
        url = f"{self.base_url}/api/generate"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "192.168.1.100"
        }
        data = {
            "model": model,
            "prompt": prompt,
            "stream": stream
        }
        response = requests.post(url, headers=headers, json=data)
        return response.json()
    
    def chat(self, model, messages, stream=False):
        """对话生成"""
        url = f"{self.base_url}/api/chat"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "192.168.1.100"
        }
        data = {
            "model": model,
            "messages": messages,
            "stream": stream
        }
        response = requests.post(url, headers=headers, json=data)
        return response.json()

# 使用示例
if __name__ == "__main__":
    # 设置API Key（从环境变量或直接设置）
    client = AllamaClient(api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm")
    
    # 生成文本
    result = client.generate("llama3", "Write a short poem about AI")
    print(f"Generated: {result['response']}")
    
    # 对话
    messages = [
        {"role": "user", "content": "What is the capital of France?"}
    ]
    result = client.chat("llama3", messages)
    print(f"Chat response: {result['message']['content']}")
```

### 案例3：Node.js应用集成认证

**场景**：Node.js Web应用需要调用Allama API进行内容生成。

**实现代码：**

```javascript
const axios = require('axios');

class AllamaClient {
    constructor(baseUrl = 'http://localhost:11435', apiKey = null) {
        this.baseUrl = baseUrl;
        this.apiKey = apiKey || process.env.ALLAMA_API_KEY;
    }

    async generate(model, prompt, stream = false) {
        const url = `${this.baseUrl}/api/generate`;
        const headers = {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.apiKey}`,
            'X-Forwarded-For': '192.168.1.100'
        };
        const data = {
            model,
            prompt,
            stream
        };
        const response = await axios.post(url, data, { headers });
        return response.data;
    }

    async chat(model, messages, stream = false) {
        const url = `${this.baseUrl}/api/chat`;
        const headers = {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.apiKey}`,
            'X-Forwarded-For': '192.168.1.100'
        };
        const data = {
            model,
            messages,
            stream
        };
        const response = await axios.post(url, data, { headers });
        return response.data;
    }
}

// 使用示例
async function main() {
    const client = new AllamaClient('http://localhost:11435', 'allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm');
    
    // 生成文本
    const genResult = await client.generate('llama3', 'Write a short story');
    console.log('Generated:', genResult.response);
    
    // 对话
    const messages = [
        { role: 'user', content: 'Explain quantum computing' }
    ];
    const chatResult = await client.chat('llama3', messages);
    console.log('Chat response:', chatResult.message.content);
}

main().catch(console.error);
```

### 案例4：多租户SaaS应用认证

**场景**：SaaS平台需要为每个租户提供独立的API Key和配额管理。

**实现架构：**

```python
import requests
import json
from typing import Dict, Optional

class TenantManager:
    def __init__(self, allama_base_url="http://localhost:11435"):
        self.base_url = allama_base_url
        self.tenants: Dict[str, dict] = {}
    
    def create_tenant(self, tenant_id: str, email: str, rate_limit: int, monthly_quota: int) -> dict:
        """为租户创建用户账号"""
        url = f"{self.base_url}/api/users"
        headers = {
            "Content-Type": "application/json",
            "X-Forwarded-For": "127.0.0.1"
        }
        data = {
            "username": f"tenant_{tenant_id}",
            "email": email,
            "rate_limit": rate_limit,
            "monthly_quota": monthly_quota
        }
        
        response = requests.post(url, headers=headers, json=data)
        user_data = response.json()
        
        self.tenants[tenant_id] = {
            "user_id": user_data["user_id"],
            "api_key": user_data["api_key"],
            "rate_limit": rate_limit,
            "monthly_quota": monthly_quota
        }
        
        return self.tenants[tenant_id]
    
    def get_tenant_api_key(self, tenant_id: str) -> Optional[str]:
        """获取租户的API Key"""
        if tenant_id in self.tenants:
            return self.tenants[tenant_id]["api_key"]
        return None
    
    def get_tenant_usage(self, tenant_id: str) -> dict:
        """获取租户使用情况"""
        api_key = self.get_tenant_api_key(tenant_id)
        if not api_key:
            return {"error": "Tenant not found"}
        
        url = f"{self.base_url}/api/billing/summary"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "X-Forwarded-For": "127.0.0.1"
        }
        
        response = requests.get(url, headers=headers)
        return response.json()

# 使用示例
manager = TenantManager()

# 创建租户
tenant1 = manager.create_tenant(
    tenant_id="acme_corp",
    email="tech@acme.com",
    rate_limit=100,
    monthly_quota=2000000
)

print(f"Created tenant: {tenant1}")

# 获取使用情况
usage = manager.get_tenant_usage("acme_corp")
print(f"Tenant usage: {usage}")
```

---

## 计费系统应用案例

### 远程计费用户管理

Allama的计费系统专为远程用户设计，提供精确的token计数、详细的计费记录和灵活的配额管理。远程计费用户通过API Key进行认证，每个用户都有独立的速率限制和月度配额。

**远程计费用户 vs 本地用户：**

| 特性 | 本地用户 | 远程计费用户 |
|------|---------|-------------|
| 认证方式 | 无需认证（IP绕过） | API Key认证 |
| 速率限制 | 无限制 | 可配置（如60 req/min） |
| 月度配额 | 无限制 | 可配置（如100,000 tokens） |
| 计费记录 | 不记录 | 详细记录 |
| 适用场景 | 开发、测试 | 生产、商业 |
| 成本追踪 | 不支持 | 支持 |

**远程计费用户特点：**
- **精确计费**: 每次API调用都记录token使用量
- **独立配额**: 每个用户有独立的月度配额
- **速率限制**: 防止单个用户过度使用资源
- **详细记录**: 包含时间戳、用户信息、模型信息、请求内容
- **成本分析**: 支持按时间范围、模型、用户等多维度分析
- **配额告警**: 接近配额上限时可以设置告警

### 创建远程计费用户

**步骤1：创建用户账号**

```bash
# 创建远程计费用户
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{
    "username": "remote_user_1",
    "email": "user1@company.com",
    "rate_limit": 120,
    "monthly_quota": 5000000
  }'
```

**参数说明：**
- `username`: 用户名（必需）
- `email`: 邮箱地址（必需）
- `rate_limit`: 速率限制，单位：requests/minute（必需）
- `monthly_quota`: 月度配额，单位：tokens（必需）

**响应示例：**
```json
{
  "user_id": "user_abc123",
  "username": "remote_user_1",
  "email": "user1@company.com",
  "api_key": "allama_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "rate_limit": 120,
  "monthly_quota": 5000000,
  "created_at": "2026-05-03T10:00:00Z"
}
```

**步骤2：分发API Key**

将返回的API Key分发给远程用户。API Key应该通过安全的方式分发，如：
- 通过加密的邮件发送
- 使用密码管理器
- 通过安全的内部系统分发

**步骤3：用户使用API Key**

远程用户使用分配的API Key进行认证：

```bash
# 远程用户使用API Key
curl -X POST http://your-server:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "X-Forwarded-For: 203.0.113.1" \
  -d '{"model":"llama3","prompt":"Hello from remote!","stream":false}'
```

### 查看计费记录

**查看用户的所有计费记录：**

```bash
# 查看计费记录（最近10条）
curl -X GET "http://localhost:11435/api/billing/records?limit=10" \
  -H "Authorization: Bearer allama_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "X-Forwarded-For: 127.0.0.1"
```

**按时间范围查询：**

```bash
# 查询特定时间范围的记录
curl -X GET "http://localhost:11435/api/billing/records?start_date=2026-05-01&end_date=2026-05-31&limit=50" \
  -H "Authorization: Bearer allama_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "X-Forwarded-For: 127.0.0.1"
```

**按模型查询：**

```bash
# 查询特定模型的记录
curl -X GET "http://localhost:11435/api/billing/records?model=llama3&limit=20" \
  -H "Authorization: Bearer allama_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "X-Forwarded-For: 127.0.0.1"
```

### 查看计费摘要

**获取用户的计费摘要：**

```bash
# 查看计费摘要
curl -X GET http://localhost:11435/api/billing/summary \
  -H "Authorization: Bearer allama_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "X-Forwarded-For: 127.0.0.1"
```

**响应示例：**
```json
{
  "total_tokens": 1500000,
  "total_requests": 5000,
  "monthly_quota": 5000000,
  "quota_usage": "30%",
  "quota_remaining": 3500000,
  "model_usage": {
    "llama3": {
      "total_tokens": 1000000,
      "total_requests": 3000
    },
    "mistral": {
      "total_tokens": 500000,
      "total_requests": 2000
    }
  }
}
```

### 配额管理

**调整用户配额：**

```bash
# 更新用户配额（需要管理员权限）
curl -X PUT http://localhost:11435/api/users/user_abc123 \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{
    "rate_limit": 200,
    "monthly_quota": 10000000
  }'
```

**配额告警：**

当用户接近配额上限时，系统会自动记录告警。可以定期查询告警记录：

```bash
# 查询配额告警
curl -X GET "http://localhost:11435/api/billing/alerts?limit=10" \
  -H "Authorization: Bearer admin_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

### 成本分析

**按用户分析成本：**

```python
import requests
import pandas as pd

def analyze_user_cost(api_key, user_id):
    """分析特定用户的成本"""
    url = f"http://localhost:11435/api/billing/records"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "X-Forwarded-For": "127.0.0.1"
    }
    params = {"user_id": user_id, "limit": 1000}
    
    response = requests.get(url, headers=headers, params=params)
    records = response.json()["records"]
    
    # 转换为DataFrame
    df = pd.DataFrame(records)
    
    # 计算成本（假设每1000 tokens = $0.001）
    cost_per_1k_tokens = 0.001
    df["cost"] = df["total_tokens"] / 1000 * cost_per_1k_tokens
    
    # 按模型统计
    cost_by_model = df.groupby("model_name")["cost"].sum()
    
    # 按日期统计
    df["date"] = pd.to_datetime(df["timestamp"]).dt.date
    cost_by_date = df.groupby("date")["cost"].sum()
    
    return {
        "total_cost": df["cost"].sum(),
        "total_tokens": df["total_tokens"].sum(),
        "cost_by_model": cost_by_model.to_dict(),
        "cost_by_date": cost_by_date.to_dict()
    }

# 使用示例
cost_analysis = analyze_user_cost("admin_api_key", "user_abc123")
print(f"Total cost: ${cost_analysis['total_cost']:.2f}")
print(f"Total tokens: {cost_analysis['total_tokens']}")
```

### 用户管理

**列出所有用户：**

```bash
# 列出所有用户
curl -X GET http://localhost:11435/api/users \
  -H "X-Forwarded-For: 127.0.0.1"
```

**查看用户详情：**

```bash
# 查看特定用户详情
curl -X GET http://localhost:11435/api/users/user_abc123 \
  -H "X-Forwarded-For: 127.0.0.1"
```

**删除用户：**

```bash
# 删除用户
curl -X DELETE http://localhost:11435/api/users/user_abc123 \
  -H "X-Forwarded-For: 127.0.0.1"
```

**重置API Key：**

```bash
# 重置用户的API Key
curl -X POST http://localhost:11435/api/users/user_abc123/reset-key \
  -H "X-Forwarded-For: 127.0.0.1"
```

### 最佳实践

**1. 合理设置配额**
- 根据用户的使用需求设置配额
- 定期监控配额使用情况
- 为重要用户预留额外配额

**2. 定期备份数据**
- 定期备份计费数据库
- 导出计费记录到外部存储
- 保留历史数据用于分析

**3. 安全管理API Key**
- 不要在代码中硬编码API Key
- 使用环境变量或密钥管理系统
- 定期轮换API Key

**4. 监控异常使用**
- 设置告警阈值
- 监控异常的请求模式
- 及时处理滥用行为

**5. 提供使用报告**
- 定期为用户提供使用报告
- 帮助用户了解配额使用情况
- 提供成本优化建议

### Ollama与Allama在计费方面的对比

**Ollama的计费方式：**
- Ollama本身不提供计费功能
- 无法追踪API使用情况
- 无法统计token消耗
- 无法进行成本分析
- 适合个人使用或免费场景

**Allama的计费方式：**
- 内置完整的计费系统
- 精确的token计数（prompt + completion）
- 详细的请求记录（时间戳、用户信息、模型信息）
- 支持按时间范围查询
- 提供统计汇总功能
- 可用于成本分析和资源规划

**从Ollama迁移到Allama计费系统：**

如果您正在使用Ollama但需要了解使用情况和成本，迁移到Allama可以获得完整的计费功能：

```bash
# Ollama方式：无法获取使用统计
# 只能通过日志文件粗略估计
grep "POST /api/generate" ~/.ollama/logs/server.log | wc -l

# Allama方式：精确的计费统计
curl -X GET http://localhost:11435/api/billing/summary \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"

# 返回详细的token统计
{
  "total_tokens": 1500000,
  "total_requests": 5000,
  "monthly_quota": 10000000,
  "quota_usage": "15%"
}
```

### 案例5：实时监控API使用量

**场景**：需要实时监控API调用情况和token使用量，用于成本控制和告警。

**实现代码：**

```python
import requests
import time
from datetime import datetime, timedelta
from typing import List, Dict

class UsageMonitor:
    def __init__(self, base_url="http://localhost:11435", api_key=None):
        self.base_url = base_url
        self.api_key = api_key
        self.alert_threshold = 0.8  # 80%配额使用时告警
    
    def get_usage_records(self, limit=100) -> List[Dict]:
        """获取使用记录"""
        url = f"{self.base_url}/api/billing/records"
        params = {"limit": limit}
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "127.0.0.1"
        }
        
        response = requests.get(url, params=params, headers=headers)
        data = response.json()
        return data.get("records", [])
    
    def get_usage_summary(self) -> Dict:
        """获取使用摘要"""
        url = f"{self.base_url}/api/billing/summary"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "127.0.0.1"
        }
        
        response = requests.get(url, headers=headers)
        return response.json()
    
    def check_quota_alert(self) -> bool:
        """检查是否需要告警"""
        summary = self.get_usage_summary()
        
        if "monthly_quota" in summary and "total_tokens" in summary:
            quota = summary["monthly_quota"]
            used = summary["total_tokens"]
            
            if quota > 0:
                usage_ratio = used / quota
                if usage_ratio >= self.alert_threshold:
                    print(f"⚠️  警告：已使用 {usage_ratio:.1%} 的月度配额 ({used}/{quota} tokens)")
                    return True
        
        return False
    
    def monitor_continuously(self, interval=60):
        """持续监控"""
        print(f"开始监控API使用情况（每{interval}秒检查一次）...")
        print("按Ctrl+C停止监控")
        
        try:
            while True:
                summary = self.get_usage_summary()
                
                print(f"\n[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}]")
                print(f"总Token数: {summary.get('total_tokens', 0)}")
                print(f"总请求数: {summary.get('total_requests', 0)}")
                print(f"月度配额: {summary.get('monthly_quota', 0)}")
                
                self.check_quota_alert()
                
                time.sleep(interval)
        except KeyboardInterrupt:
            print("\n监控已停止")

# 使用示例
if __name__ == "__main__":
    monitor = UsageMonitor(
        base_url="http://localhost:11435",
        api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm"
    )
    
    # 单次检查
    summary = monitor.get_usage_summary()
    print(f"使用摘要: {summary}")
    
    # 持续监控
    # monitor.monitor_continuously(interval=30)
```

### 案例6：按部门统计使用情况

**场景**：企业需要按部门统计API使用情况，用于成本分摊和资源规划。

**实现代码：**

```python
import requests
from typing import Dict, List
from datetime import datetime, timedelta

class DepartmentUsageReporter:
    def __init__(self, base_url="http://localhost:11435"):
        self.base_url = base_url
        self.departments = {
            "rd": "allama_rd_team_key",
            "marketing": "allama_marketing_team_key",
            "support": "allama_support_team_key"
        }
    
    def get_department_usage(self, dept_name: str, days=30) -> Dict:
        """获取指定部门的使用情况"""
        if dept_name not in self.departments:
            return {"error": f"Department {dept_name} not found"}
        
        api_key = self.departments[dept_name]
        
        # 获取最近N天的记录
        start_date = datetime.now() - timedelta(days=days)
        url = f"{self.base_url}/api/billing/records"
        params = {
            "start_date": start_date.isoformat(),
            "limit": 1000
        }
        headers = {
            "Authorization": f"Bearer {api_key}",
            "X-Forwarded-For": "127.0.0.1"
        }
        
        response = requests.get(url, params=params, headers=headers)
        records = response.json().get("records", [])
        
        # 统计
        total_tokens = sum(r["total_tokens"] for r in records)
        total_requests = len(records)
        model_usage = {}
        
        for record in records:
            model = record["model_name"]
            model_usage[model] = model_usage.get(model, 0) + record["total_tokens"]
        
        return {
            "department": dept_name,
            "period_days": days,
            "total_tokens": total_tokens,
            "total_requests": total_requests,
            "model_usage": model_usage,
            "avg_tokens_per_request": total_tokens / total_requests if total_requests > 0 else 0
        }
    
    def generate_report(self) -> Dict:
        """生成所有部门的使用报告"""
        report = {
            "generated_at": datetime.now().isoformat(),
            "departments": {}
        }
        
        for dept_name in self.departments.keys():
            usage = self.get_department_usage(dept_name)
            report["departments"][dept_name] = usage
        
        return report
    
    def print_report(self):
        """打印报告"""
        report = self.generate_report()
        
        print("=" * 60)
        print("部门API使用报告")
        print("=" * 60)
        print(f"生成时间: {report['generated_at']}")
        print()
        
        for dept_name, usage in report["departments"].items():
            print(f"部门: {dept_name.upper()}")
            print(f"  总Token数: {usage['total_tokens']:,}")
            print(f"  总请求数: {usage['total_requests']:,}")
            print(f"  平均每请求: {usage['avg_tokens_per_request']:.1f} tokens")
            print(f"  模型使用:")
            for model, tokens in usage.get('model_usage', {}).items():
                print(f"    - {model}: {tokens:,} tokens")
            print()

# 使用示例
if __name__ == "__main__":
    reporter = DepartmentUsageReporter()
    reporter.print_report()
```

### 案例7：成本预测和预算管理

**场景**：根据历史使用数据预测未来成本，帮助制定预算。

**实现代码：**

```python
import requests
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Tuple

class CostPredictor:
    def __init__(self, base_url="http://localhost:11435", api_key=None, cost_per_1k_tokens=0.001):
        self.base_url = base_url
        self.api_key = api_key
        self.cost_per_1k_tokens = cost_per_1k_tokens
    
    def get_historical_usage(self, days=30) -> List[Dict]:
        """获取历史使用数据"""
        start_date = datetime.now() - timedelta(days=days)
        url = f"{self.base_url}/api/billing/records"
        params = {
            "start_date": start_date.isoformat(),
            "limit": 10000
        }
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "127.0.0.1"
        }
        
        response = requests.get(url, params=params, headers=headers)
        return response.json().get("records", [])
    
    def calculate_daily_usage(self, records: List[Dict]) -> Dict[str, int]:
        """计算每日使用量"""
        daily_usage = {}
        
        for record in records:
            date = record["timestamp"][:10]  # YYYY-MM-DD
            daily_usage[date] = daily_usage.get(date, 0) + record["total_tokens"]
        
        return daily_usage
    
    def predict_monthly_usage(self, days=30) -> Dict:
        """预测月度使用量"""
        records = self.get_historical_usage(days)
        daily_usage = self.calculate_daily_usage(records)
        
        if not daily_usage:
            return {"error": "No usage data available"}
        
        # 计算平均每日使用量
        avg_daily = np.mean(list(daily_usage.values()))
        
        # 计算标准差（用于估算波动范围）
        std_daily = np.std(list(daily_usage.values()))
        
        # 预测30天使用量
        predicted_monthly = avg_daily * 30
        predicted_range = (
            (avg_daily - std_daily) * 30,
            (avg_daily + std_daily) * 30
        )
        
        # 计算成本
        predicted_cost = predicted_monthly / 1000 * self.cost_per_1k_tokens
        cost_range = (
            predicted_range[0] / 1000 * self.cost_per_1k_tokens,
            predicted_range[1] / 1000 * self.cost_per_1k_tokens
        )
        
        return {
            "historical_days": len(daily_usage),
            "avg_daily_tokens": round(avg_daily),
            "std_daily_tokens": round(std_daily),
            "predicted_monthly_tokens": round(predicted_monthly),
            "predicted_monthly_range": (round(predicted_range[0]), round(predicted_range[1])),
            "predicted_monthly_cost": round(predicted_cost, 2),
            "predicted_cost_range": (round(cost_range[0], 2), round(cost_range[1], 2)),
            "cost_per_1k_tokens": self.cost_per_1k_tokens
        }
    
    def print_prediction(self):
        """打印预测报告"""
        prediction = self.predict_monthly_usage()
        
        print("=" * 60)
        print("成本预测报告")
        print("=" * 60)
        print(f"历史数据天数: {prediction['historical_days']}")
        print(f"平均每日Token: {prediction['avg_daily_tokens']:,}")
        print(f"标准差: {prediction['std_daily_tokens']:,}")
        print()
        print(f"预测月度Token: {prediction['predicted_monthly_tokens']:,}")
        print(f"预测范围: {prediction['predicted_monthly_range'][0]:,} - {prediction['predicted_monthly_range'][1]:,}")
        print()
        print(f"预测月度成本: ${prediction['predicted_monthly_cost']:.2f}")
        print(f"成本范围: ${prediction['predicted_cost_range'][0]:.2f} - ${prediction['predicted_cost_range'][1]:.2f}")
        print(f"Token价格: ${prediction['cost_per_1k_tokens']:.4f}/1k tokens")
        print("=" * 60)

# 使用示例
if __name__ == "__main__":
    predictor = CostPredictor(
        base_url="http://localhost:11435",
        api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm",
        cost_per_1k_tokens=0.001
    )
    
    predictor.print_prediction()
```

---

## OpenAI兼容API应用案例

### Ollama与Allama在OpenAI兼容性方面的对比

**Ollama的OpenAI兼容性：**
- Ollama提供OpenAI兼容的API端点（/v1/chat/completions, /v1/completions, /v1/embeddings）
- 支持OpenAI SDK的基本功能
- 可以作为OpenAI的替代品使用
- 适合需要OpenAI兼容性的应用

**Allama的OpenAI兼容性：**
- 完全兼容Ollama的OpenAI兼容API
- 端点路径和参数格式完全相同
- 支持OpenAI SDK的所有功能
- 额外支持认证和计费
- 可以无缝从Ollama迁移

**从Ollama迁移到Allama的OpenAI兼容API：**

如果您正在使用Ollama的OpenAI兼容API，迁移到Allama非常简单：

```python
# Ollama方式
from openai import OpenAI
client = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")
response = client.chat.completions.create(model="llama3", messages=[...])

# Allama方式（完全相同）
from openai import OpenAI
client = OpenAI(base_url="http://localhost:11435/v1", api_key="your_allama_key")
response = client.chat.completions.create(model="llama3", messages=[...])

# 唯一的区别：Allama的API Key可以用于认证和计费
```

### 案例8：使用OpenAI Python SDK

**场景**：现有使用OpenAI SDK的应用可以无缝切换到Allama，无需修改代码。

**实现代码：**

```python
from openai import OpenAI

# 配置Allama作为OpenAI兼容端点
client = OpenAI(
    base_url="http://localhost:11435/v1",
    api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm"
)

# Chat Completions
response = client.chat.completions.create(
    model="llama3",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
    temperature=0.7,
    max_tokens=500
)

print(f"Response: {response.choices[0].message.content}")

# Completions
response = client.completions.create(
    model="llama3",
    prompt="Write a haiku about programming",
    max_tokens=100
)

print(f"Completion: {response.choices[0].text}")

# Embeddings
response = client.embeddings.create(
    model="llama3",
    input="Hello, world!"
)

print(f"Embedding dimension: {len(response.data[0].embedding)}")
```

### 案例9：使用OpenAI Node.js SDK

**场景**：Node.js应用使用OpenAI SDK连接Allama。

**实现代码：**

```javascript
const OpenAI = require('openai');

// 配置Allama作为OpenAI兼容端点
const openai = new OpenAI({
  baseURL: 'http://localhost:11435/v1',
  apiKey: 'allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm'
});

async function main() {
  // Chat Completions
  const chatResponse = await openai.chat.completions.create({
    model: 'llama3',
    messages: [
      { role: 'system', content: 'You are a helpful assistant.' },
      { role: 'user', content: 'What is machine learning?' }
    ],
    temperature: 0.7,
    max_tokens: 500
  });

  console.log('Chat response:', chatResponse.choices[0].message.content);

  // Completions
  const completionResponse = await openai.completions.create({
    model: 'llama3',
    prompt: 'Write a short story about AI',
    max_tokens: 300
  });

  console.log('Completion:', completionResponse.choices[0].text);

  // Embeddings
  const embeddingResponse = await openai.embeddings.create({
    model: 'llama3',
    input: 'Hello, world!'
  });

  console.log('Embedding dimension:', embeddingResponse.data[0].embedding.length);
}

main().catch(console.error);
```

### 案例10：LangChain集成

**场景**：使用LangChain框架构建RAG应用，后端使用Allama。

**实现代码：**

```python
from langchain.llms import OpenAI
from langchain.chat_models import ChatOpenAI
from langchain.embeddings import OpenAIEmbeddings
from langchain.chains import ConversationalRetrievalChain
from langchain.vectorstores import FAISS
from langchain.text_splitter import CharacterTextSplitter
from langchain.document_loaders import TextLoader

# 配置Allama作为OpenAI兼容端点
llm = OpenAI(
    openai_api_base="http://localhost:11435/v1",
    openai_api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm",
    model_name="llama3",
    temperature=0.7
)

chat = ChatOpenAI(
    openai_api_base="http://localhost:11435/v1",
    openai_api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm",
    model="llama3"
)

embeddings = OpenAIEmbeddings(
    openai_api_base="http://localhost:11435/v1",
    openai_api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm"
)

# 使用示例
def simple_qa():
    """简单问答"""
    response = llm("What is the capital of France?")
    print(f"Answer: {response}")

def build_rag_system():
    """构建RAG系统"""
    # 加载文档
    loader = TextLoader("documents/sample.txt")
    documents = loader.load()
    
    # 分割文档
    text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=0)
    texts = text_splitter.split_documents(documents)
    
    # 创建向量存储
    vectorstore = FAISS.from_documents(texts, embeddings)
    
    # 创建检索链
    retriever = vectorstore.as_retriever()
    qa_chain = ConversationalRetrievalChain.from_llm(
        llm=chat,
        retriever=retriever
    )
    
    # 问答
    query = "What is the main topic of the document?"
    result = qa_chain({"question": query, "chat_history": []})
    print(f"Answer: {result['answer']}")

if __name__ == "__main__":
    simple_qa()
    # build_rag_system()
```

---

## 高级功能应用案例

### Ollama与Allama在高级功能方面的对比

**Ollama的高级功能：**
- 支持流式响应
- 支持批量处理（通过并发请求）
- 基本的错误处理
- 适合个人使用和小型团队

**Allama的高级功能：**
- 完全兼容Ollama的所有高级功能
- 增强的错误处理和重试机制
- 航空级故障容错
- 异常检测和自动告警
- 审计日志和完整性保护
- 适合企业级应用

**从Ollama迁移到Allama的高级功能：**

如果您正在使用Ollama的高级功能，迁移到Allama可以获得更强的容错能力和监控：

```python
# Ollama方式：基本的流式响应
import ollama
for chunk in ollama.generate(model='llama3', prompt='test', stream=True):
    print(chunk['response'], end='', flush=True)

# Allama方式：相同的流式响应，但增加了故障容错
import requests
try:
    response = requests.post(
        'http://localhost:11435/api/generate',
        headers={
            'Content-Type': 'application/json',
            'Authorization': 'Bearer your_api_key'
        },
        json={'model': 'llama3', 'prompt': 'test', 'stream': True},
        stream=True,
        timeout=30  # 超时保护
    )
    for line in response.iter_lines():
        if line:
            chunk = json.loads(line)
            print(chunk['response'], end='', flush=True)
except requests.exceptions.Timeout:
    print("请求超时，自动重试...")
except requests.exceptions.RequestException as e:
    print(f"请求失败: {e}")
```

### 案例11：流式响应处理

**场景**：实时显示生成的文本，提供更好的用户体验。

**实现代码：**

```python
import requests
import json

def stream_generate(model, prompt, api_key):
    """流式生成文本"""
    url = "http://localhost:11435/api/generate"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
        "X-Forwarded-For": "192.168.1.100"
    }
    data = {
        "model": model,
        "prompt": prompt,
        "stream": True
    }
    
    response = requests.post(url, headers=headers, json=data, stream=True)
    
    print("流式生成开始:")
    for line in response.iter_lines():
        if line:
            try:
                chunk = json.loads(line.decode('utf-8'))
                if 'response' in chunk:
                    print(chunk['response'], end='', flush=True)
                if chunk.get('done', False):
                    print("\n生成完成")
                    break
            except json.JSONDecodeError:
                continue

# 使用示例
if __name__ == "__main__":
    stream_generate(
        model="llama3",
        prompt="Write a short story about a robot learning to love",
        api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm"
    )
```

### 案例12：批量处理与并发控制

**场景**：需要处理大量请求，同时控制并发数以避免超限。

**实现代码：**

```python
import requests
import asyncio
import aiohttp
from typing import List
from concurrent.futures import ThreadPoolExecutor, as_completed

class BatchProcessor:
    def __init__(self, base_url="http://localhost:11435", api_key=None, max_concurrent=10):
        self.base_url = base_url
        self.api_key = api_key
        self.max_concurrent = max_concurrent
        self.semaphore = asyncio.Semaphore(max_concurrent)
    
    async def async_generate(self, session, model, prompt):
        """异步生成"""
        async with self.semaphore:
            url = f"{self.base_url}/api/generate"
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.api_key}",
                "X-Forwarded-For": "192.168.1.100"
            }
            data = {
                "model": model,
                "prompt": prompt,
                "stream": False
            }
            
            async with session.post(url, headers=headers, json=data) as response:
                return await response.json()
    
    async def process_batch_async(self, prompts: List[str], model="llama3"):
        """异步批量处理"""
        async with aiohttp.ClientSession() as session:
            tasks = [
                self.async_generate(session, model, prompt)
                for prompt in prompts
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            successful = [r for r in results if not isinstance(r, Exception)]
            failed = [r for r in results if isinstance(r, Exception)]
            
            return {
                "total": len(prompts),
                "successful": len(successful),
                "failed": len(failed),
                "results": successful
            }
    
    def process_batch_sync(self, prompts: List[str], model="llama3"):
        """同步批量处理（使用线程池）"""
        url = f"{self.base_url}/api/generate"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "192.168.1.100"
        }
        
        results = []
        with ThreadPoolExecutor(max_workers=self.max_concurrent) as executor:
            futures = {
                executor.submit(
                    requests.post,
                    url,
                    headers=headers,
                    json={"model": model, "prompt": prompt, "stream": False}
                ): prompt
                for prompt in prompts
            }
            
            for future in as_completed(futures):
                try:
                    response = future.result()
                    results.append(response.json())
                except Exception as e:
                    print(f"Error processing prompt: {e}")
        
        return results

# 使用示例
if __name__ == "__main__":
    processor = BatchProcessor(
        base_url="http://localhost:11435",
        api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm",
        max_concurrent=5
    )
    
    # 准备批量提示
    prompts = [
        "What is AI?",
        "Explain machine learning",
        "What is deep learning?",
        "Define neural networks",
        "What is natural language processing?"
    ]
    
    # 异步处理
    async def main_async():
        result = await processor.process_batch_async(prompts)
        print(f"异步处理结果: {result}")
    
    asyncio.run(main_async())
    
    # 同步处理
    # results = processor.process_batch_sync(prompts)
    # print(f"同步处理结果数: {len(results)}")
```

### 案例13：错误处理和重试机制

**场景**：网络不稳定时需要自动重试，确保请求成功。

**实现代码：**

```python
import requests
import time
from typing import Optional, Callable
from functools import wraps

class AllamaAPIError(Exception):
    """Allama API错误"""
    pass

def retry_on_error(max_retries=3, delay=1, backoff=2):
    """重试装饰器"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            current_delay = delay
            
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except requests.exceptions.RequestException as e:
                    last_exception = e
                    if attempt < max_retries - 1:
                        print(f"请求失败，{current_delay}秒后重试... (尝试 {attempt + 1}/{max_retries})")
                        time.sleep(current_delay)
                        current_delay *= backoff
                    else:
                        raise AllamaAPIError(f"重试{max_retries}次后仍然失败: {e}")
                except Exception as e:
                    raise AllamaAPIError(f"请求出错: {e}")
            
            raise last_exception
        return wrapper
    return decorator

class RobustAllamaClient:
    def __init__(self, base_url="http://localhost:11435", api_key=None):
        self.base_url = base_url
        self.api_key = api_key
    
    @retry_on_error(max_retries=3, delay=1, backoff=2)
    def generate(self, model, prompt, stream=False, timeout=30):
        """带重试的文本生成"""
        url = f"{self.base_url}/api/generate"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "192.168.1.100"
        }
        data = {
            "model": model,
            "prompt": prompt,
            "stream": stream
        }
        
        response = requests.post(url, headers=headers, json=data, timeout=timeout)
        
        if response.status_code == 401:
            raise AllamaAPIError("认证失败：无效的API Key")
        elif response.status_code == 429:
            raise AllamaAPIError("速率限制：请求过于频繁")
        elif response.status_code >= 500:
            raise AllamaAPIError(f"服务器错误: {response.status_code}")
        
        response.raise_for_status()
        return response.json()
    
    @retry_on_error(max_retries=3, delay=1, backoff=2)
    def chat(self, model, messages, stream=False, timeout=30):
        """带重试的对话生成"""
        url = f"{self.base_url}/api/chat"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "192.168.1.100"
        }
        data = {
            "model": model,
            "messages": messages,
            "stream": stream
        }
        
        response = requests.post(url, headers=headers, json=data, timeout=timeout)
        
        if response.status_code == 401:
            raise AllamaAPIError("认证失败：无效的API Key")
        elif response.status_code == 429:
            raise AllamaAPIError("速率限制：请求过于频繁")
        elif response.status_code >= 500:
            raise AllamaAPIError(f"服务器错误: {response.status_code}")
        
        response.raise_for_status()
        return response.json()

# 使用示例
if __name__ == "__main__":
    client = RobustAllamaClient(
        base_url="http://localhost:11435",
        api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm"
    )
    
    try:
        result = client.generate("llama3", "Write a haiku")
        print(f"生成结果: {result['response']}")
    except AllamaAPIError as e:
        print(f"API错误: {e}")
```

---

## 故障排除

### 常见问题

**1. 认证失败 (401 Unauthorized)**

**症状：**
```json
{"error":"Unauthorized"}
```

**可能原因：**
- API Key无效或已过期
- 请求头格式错误
- API Key被撤销

**解决方案：**
```bash
# 检查API Key是否正确
echo $ALLAMA_API_KEY

# 重新获取API Key
curl -X GET http://localhost:11435/api/users \
  -H "Authorization: Bearer your_admin_key" \
  -H "X-Forwarded-For: 127.0.0.1"

# 确保请求头格式正确
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"test","stream":false}'
```

**2. 速率限制 (429 Too Many Requests)**

**症状：**
```json
{"error":"Rate limit exceeded"}
```

**可能原因：**
- 超过每分钟请求限制
- 并发请求过多

**解决方案：**
```python
import time
import requests

def rate_limited_request(url, headers, data, max_retries=3):
    """带速率限制的请求"""
    for attempt in range(max_retries):
        response = requests.post(url, headers=headers, json=data)
        
        if response.status_code == 429:
            wait_time = 2 ** attempt  # 指数退避
            print(f"速率限制，等待{wait_time}秒后重试...")
            time.sleep(wait_time)
        else:
            return response.json()
    
    raise Exception("超过最大重试次数")

# 使用示例
result = rate_limited_request(
    url="http://localhost:11435/api/generate",
    headers={
        "Content-Type": "application/json",
        "Authorization": "Bearer your_api_key",
        "X-Forwarded-For": "192.168.1.100"
    },
    data={"model":"llama3","prompt":"test","stream":false}
)
```

**3. 服务器无响应**

**症状：**
- 连接超时
- 无法连接到服务器

**可能原因：**
- 服务器未启动
- 端口被占用
- 防火墙阻止

**解决方案：**
```bash
# 检查服务器是否运行
ps aux | grep allama

# 检查端口是否被占用
lsof -i :11435

# 重启服务器
./target/release/allama serve --port 11435

# 检查防火墙
sudo ufw status
sudo ufw allow 11435
```

**4. 配额用尽**

**症状：**
```json
{"error":"Monthly quota exceeded"}
```

**解决方案：**
```bash
# 查看当前使用情况
curl -X GET http://localhost:11435/api/billing/summary \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"

# 联系管理员增加配额
# 或等待下个月配额重置
```

### 调试技巧

**1. 启用详细日志**

```bash
# 设置RUST_LOG环境变量
RUST_LOG=debug ./target/release/allama serve --port 11435
```

**2. 检查审计日志**

```bash
# 查看审计日志
cat ~/.allama/data/audit/audit.log
```

**3. 测试连接**

```bash
# 测试基本连接
curl -v http://localhost:11435/api/tags

# 测试认证
curl -v -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"test","stream":false}'
```

---

## 常见问题FAQ

### Q1: 如何获取API Key？

**A:** 有两种方式获取API Key：

1. **使用默认测试账号**：服务器启动时会自动创建默认测试用户并显示API Key
2. **创建新用户**：通过API创建新用户并获取API Key

```bash
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"username":"myuser","email":"user@example.com","rate_limit":60,"monthly_quota":1000000}'
```

### Q2: 本地请求需要认证吗？

**A:** 不需要。来自127.0.0.1、::1或localhost的请求会自动绕过认证。

```bash
# 本地请求（无需认证）
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","prompt":"test","stream":false}'
```

### Q3: 如何在生产环境中部署？

**A:** 生产环境部署建议：

1. **使用HTTPS**：配置SSL证书
2. **创建专用用户**：不要使用默认测试账号
3. **设置合理的配额**：根据业务需求设置速率限制和月度配额
4. **监控使用情况**：定期检查计费记录
5. **定期备份**：备份认证数据库和计费数据库
6. **使用反向代理**：如Nginx，提供额外的安全层

### Q4: 如何与OpenAI SDK兼容？

**A:** Allama提供OpenAI兼容的API端点：

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:11435/v1",
    api_key="your_allama_api_key"
)

# 使用方式与OpenAI完全相同
response = client.chat.completions.create(...)
```

### Q5: 如何监控API使用情况？

**A:** 使用计费API监控使用情况：

```bash
# 获取使用摘要
curl -X GET http://localhost:11435/api/billing/summary \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"

# 获取详细记录
curl -X GET "http://localhost:11435/api/billing/records?limit=100" \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

### Q6: 支持哪些模型？

**A:** Allama支持llama.cpp支持的所有模型，包括：
- LLaMA系列
- Mistral
- Qwen
- Gemma
- 等等

使用`/api/tags`端点查看可用模型：

```bash
curl http://localhost:11435/api/tags
```

### Q7: 如何提高请求吞吐量？

**A:** 提高吞吐量的方法：

1. **增加并行工作线程**：
```bash
./target/release/allama serve --parallel 8
```

2. **使用异步客户端**：参考案例12的批量处理
3. **优化模型选择**：使用更小的模型或量化版本
4. **使用流式响应**：减少延迟感知

### Q8: 数据存储在哪里？

**A:** 默认数据存储在`~/.allama/`目录：

```
~/.allama/
├── data/
│   ├── auth/
│   │   └── auth.db          # 认证数据库
│   ├── billing/
│   │   └── billing.db       # 计费数据库
│   └── audit/
│       └── audit.log        # 审计日志
```

### Q9: 如何备份和恢复数据？

**A:** 备份数据库文件：

```bash
# 备份
cp ~/.allama/data/auth/auth.db auth_backup.db
cp ~/.allama/data/billing/billing.db billing_backup.db

# 恢复
cp auth_backup.db ~/.allama/data/auth/auth.db
cp billing_backup.db ~/.allama/data/billing/billing.db
```

### Q10: 如何联系技术支持？

**A:** 
- GitHub Issues: https://github.com/arkCyber/allama/issues
- 文档: https://github.com/arkCyber/allama
- 认证指南: docs/AUTHENTICATION_GUIDE.md

---

## 附录

### A. API端点完整列表

详见README.md的API Endpoints章节。

### B. 环境变量

- `ALLAMA_BASE_URL`: Allama服务器地址
- `ALLAMA_API_KEY`: 默认API Key
- `ALLAMA_PORT`: 服务器端口
- `RUST_LOG`: 日志级别（debug, info, warn, error）

### C. 相关文档

- [认证系统指南](AUTHENTICATION_GUIDE.md)
- [README](../README.md)
- [llama.cpp文档](https://github.com/ggerganov/llama.cpp)

---

**文档版本**: 1.0  
**最后更新**: 2026-05-03  
**维护者**: Allama开发团队
