# Allama 用户开发与应用文档手册

## 目录

1. [快速开始](#快速开始)
2. [安装指南](#安装指南)
3. [CLI命令参考](#cli命令参考)
4. [认证系统应用案例](#认证系统应用案例)
5. [计费系统应用案例](#计费系统应用案例)
6. [OpenAI兼容API应用案例](#openai兼容api应用案例)
7. [高级功能应用案例](#高级功能应用案例)
8. [故障排除](#故障排除)
9. [常见问题FAQ](#常见问题faq)

---

## 快速开始

### 5分钟快速体验

Allama是一个航空级安全的LLM推理服务器，支持用户认证、计费和OpenAI兼容API。本指南将帮助您在5分钟内快速体验Allama的核心功能，包括服务器启动、API调用、认证测试和使用统计查看。

**前提条件：**
- 已安装Rust 1.70或更高版本
- 至少8GB可用内存
- 网络连接（用于下载模型）
- 终端或命令行访问权限

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

## CLI命令参考

Allama提供了一套完整的命令行接口，与Ollama保持一致，同时增加了企业级功能。所有命令都支持`--help`参数查看详细帮助信息。

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
