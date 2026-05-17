# Allama 操作说明书

## 目录

1. [快速开始](#快速开始)
2. [安装](#安装)
3. [配置](#配置)
4. [模型管理](#模型管理)
5. [语音功能](#语音功能)
6. [API 使用](#api-使用)
7. [安全特性](#安全特性)
8. [故障排除](#故障排除)
9. [高级功能](#高级功能)
10. [MLX 后端](#mlx-后端)
11. [GGUF 模型支持](#gguf-模型支持)
12. [llama-server 集成](#llama-server-集成)

---

## 快速开始

### 最快上手方式

```bash
# 1. 克隆仓库
git clone https://github.com/arkCyber/allama.git
cd allama

# 2. 构建
cargo build --bin allama

# 3. 添加模型
./target/debug/allama add my-model /path/to/model.gguf

# 4. 启动服务
./target/debug/allama serve

# 5. 测试
curl -X POST http://localhost:11435/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_esVUQHQCvtrjOtlPt6vV579u3QNOeI5t" \
  -d '{"model":"my-model","messages":[{"role":"user","content":"Hello"}]}'
```

---

## 安装

### 系统要求

- **操作系统**: Linux, macOS, Windows
- **Rust**: 1.70 或更高版本
- **CMake**: 3.20 或更高版本
- **Python 3**: 用于语音功能（可选）

### 从源代码构建

```bash
# 克隆仓库
git clone https://github.com/arkCyber/allama.git
cd allama

# 构建 Allama CLI
cargo build --bin allama --release

# 构建 llama-server（可选，用于大模型）
mkdir build && cd build
cmake ..
make -j$(nproc)

# 安装（可选）
sudo make install
```

### 安装语音功能（可选）

```bash
# 安装 Whisper 用于语音转文字
./scripts/setup-whisper.sh

# 安装 Coqui TTS 用于文字转语音
./scripts/setup-vocoder.sh
```

---

## 配置

### 配置文件

创建配置文件 `~/.allama/config`:

```bash
# 模型注册表设置
registry_path=~/.allama/registry.db
models_path=~/.allama/models
max_models=1000

# 模型目录设置
catalog_path=~/.allama/catalog.db
cache_path=~/.allama/cache
remote_url=https://huggingface.co/ggml-org
max_entries=10000
cache_ttl=3600
enable_auto_update=true

# 语音功能设置
ALLAMA_WHISPER_MODEL=base
ALLAMA_TTS_MODEL=tts_models/multilingual/multi-dataset/xtts_v2
ALLAMA_LLAMA_SERVER_HOST=127.0.0.1
ALLAMA_LLAMA_SERVER_PORT=8082
```

### 环境变量

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `ALLAMA_MODELS_DIR` | `~/.allama/models` | 模型目录 |
| `ALLAMA_WHISPER_MODEL` | `base` | Whisper 模型大小 |
| `ALLAMA_TTS_MODEL` | `tts_models/multilingual/multi-dataset/xtts_v2` | TTS 模型 |
| `ALLAMA_LLAMA_SERVER_HOST` | `127.0.0.1` | llama-server 主机 |
| `ALLAMA_LLAMA_SERVER_PORT` | `8082` | llama-server 端口 |

---

## 模型管理

### 基本命令

```bash
# 初始化模型注册表
allama stats

# 添加本地模型
allama add my-model /path/to/model.gguf

# 列出所有模型
allama list
# 或使用别名
allama ls

# 显示模型详细信息
allama show my-model

# 验证模型完整性
allama validate my-model

# 搜索模型
allama search "llama"

# 删除模型
allama rm my-model
# 或使用别名
allama remove my-model
allama delete my-model

# 复制模型
allama cp src-model dst-model
# 或使用别名
allama copy src-model dst-model
```

### 高级命令

```bash
# 显示内存使用情况
allama mem

# 管理标签
allama tag add llama3:latest production
allama tag list llama3:latest
allama tag remove llama3:latest production

# 管理缓存
allama cache stats
allama cache clear

# 查看审计日志
allama logs view
allama logs clear
```

### Modelfile 支持

创建自定义 Modelfile:

```dockerfile
FROM llama3:latest

PARAMETER temperature 0.7
PARAMETER top_p 0.9

SYSTEM You are a helpful assistant.
```

使用 Modelfile 创建模型:

```bash
allama create my-custom-model -f Modelfile
```

---

## 语音功能

### 安装依赖

```bash
# 安装 Whisper（语音转文字）
./scripts/setup-whisper.sh

# 安装 Coqui TTS（文字转语音）
./scripts/setup-vocoder.sh
```

### 使用语音转文字 (STT)

```bash
# 运行语音测试
cargo run --example voice_real_test
```

### 使用文字转语音 (TTS)

```bash
# 运行语音测试
cargo run --example voice_real_test
```

### 语音 API 端点

Allama 提供以下语音相关端点:

- `POST /api/stt` - 语音转文字
- `POST /api/tts` - 文字转语音

### 语音配置

通过环境变量配置语音功能:

```bash
export ALLAMA_WHISPER_MODEL=base
export ALLAMA_TTS_MODEL=tts_models/multilingual/multi-dataset/xtts_v2
```

---

## API 使用

### 启动服务

```bash
# 启动 Allama serve（端口 11435）
allama serve

# 使用自定义端口
allama serve --port 8080

# 启用认证
allama serve --auth-api-key your-secret-key
```

### Ollama 兼容 API

#### 列出模型

```bash
curl http://localhost:11435/api/tags
```

#### 生成补全

```bash
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3",
    "prompt": "Why is the sky blue?",
    "stream": false
  }'
```

#### 聊天补全

```bash
curl -X POST http://localhost:11435/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3",
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'
```

#### 生成嵌入

```bash
curl -X POST http://localhost:11435/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3",
    "input": "Hello, world!"
  }'
```

### OpenAI 兼容 API

#### 聊天补全

```bash
curl -X POST http://localhost:11435/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3",
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'
```

#### 文本补全

```bash
curl -X POST http://localhost:11435/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3",
    "prompt": "Hello, world!"
  }'
```

### Anthropic 兼容 API

#### Messages API

```bash
curl -X POST http://localhost:11435/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: allama_esVUQHQCvtrjOtlPt6vV579u3QNOeI5t" \
  -d '{
    "model": "llama3",
    "max_tokens": 1024,
    "messages": [
      {
        "role": "user",
        "content": "Hello, Claude!"
      }
    ]
  }'
```

#### 带 System 消息

```bash
curl -X POST http://localhost:11435/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: allama_esVUQHQCvtrjOtlPt6vV579u3QNOeI5t" \
  -d '{
    "model": "llama3",
    "max_tokens": 1024,
    "system": "You are a helpful assistant.",
    "messages": [
      {
        "role": "user",
        "content": "Hello"
      }
    ]
  }'
```

#### 流式响应

```bash
curl -X POST http://localhost:11435/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: allama_esVUQHQCvtrjOtlPt6vV579u3QNOeI5t" \
  -d '{
    "model": "llama3",
    "max_tokens": 1024,
    "stream": true,
    "messages": [
      {
        "role": "user",
        "content": "Tell me a story"
      }
    ]
  }'
```

#### 参数支持

Anthropic API 支持以下参数：

- `model`: 模型名称（必需）
- `max_tokens`: 最大生成 token 数（必需）
- `messages`: 消息数组（必需）
- `system`: 系统 prompt（可选）
- `stream`: 是否流式响应（可选，默认 false）
- `temperature`: 温度参数（可选）
- `top_p`: Top-p 采样（可选）
- `top_k`: Top-k 采样（可选）
- `stop_sequences`: 停止序列（可选）

---

## 安全特性

### 认证

#### API Key 认证

```bash
# 启动服务时指定 API key
allama serve --auth-api-key your-secret-key

# 使用 API key
curl -H "Authorization: Bearer your-secret-key" \
  http://localhost:11435/api/tags
```

#### JWT 认证

```bash
# 启用 JWT 认证
allama serve --enable-jwt --jwt-secret your-jwt-secret
```

### 代码签名

```bash
# 对模型文件签名
allama sign-model /path/to/model.gguf

# 验证模型文件
allama verify-model /path/to/model.gguf.sig
```

### 审计日志

```bash
# 查看审计日志
allama logs view

# 清除审计日志
allama logs clear
```

### 速率限制

```bash
# 启用速率限制
allama serve --rate-limit 100
```

---

## 故障排除

### 常见问题

#### 模型加载失败

**问题**: 模型加载时出现错误

**解决方案**:
```bash
# 验证模型文件
allama validate my-model

# 检查模型路径
allama show my-model

# 查看详细日志
allama serve --log-level debug
```

#### 语音功能不工作

**问题**: STT 或 TTS 功能失败

**解决方案**:
```bash
# 检查 Whisper 是否安装
which whisper

# 检查 Coqui TTS 是否安装
which tts

# 重新安装语音功能
./scripts/setup-whisper.sh
./scripts/setup-vocoder.sh

# 查看详细日志
cargo run --example voice_real_test
```

#### 认证失败

**问题**: API 认证失败

**解决方案**:
```bash
# 检查 API key 配置
allama serve --auth-api-key your-secret-key

# 查看审计日志
allama logs view
```

### 调试模式

```bash
# 启用详细日志
allama serve --log-level debug

# 启用性能分析
allama serve --enable-profiling
```

---

## 高级功能

### 统一 AI 接口

Allama 提供统一 AI 接口，自动路由到正确的后端:

```bash
# 启动 llama-server（用于大模型）
./bin/llama-server -m /path/to/gemma-4-26b.gguf --port 8082

# 启动 Allama serve
allama serve --port 11435

# 所有请求通过统一端点
curl -X POST http://localhost:11435/api/chat \
  -d '{"model":"gemma4-26b","messages":[{"role":"user","content":"Hello"}]}'

curl -X POST http://localhost:11435/api/chat \
  -d '{"model":"llama3","messages":[{"role":"user","content":"Hello"}]}'
```

### 多模态支持

```bash
# 使用多模态模型
curl -X POST http://localhost:11435/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llava",
    "messages": [
      {
        "role": "user",
        "content": "What is in this image?",
        "images": ["base64-encoded-image"]
      }
    ]
  }'
```

### 工具调用

```bash
# 使用工具调用
curl -X POST http://localhost:11435/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3",
    "messages": [
      {"role": "user", "content": "What is the weather?"}
    ],
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "get_weather",
          "description": "Get the current weather"
        }
      }
    ]
  }'
```

### 结构化输出

```bash
# 使用结构化输出
curl -X POST http://localhost:11435/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3",
    "messages": [
      {"role": "user", "content": "Extract information"}
    ],
    "format": {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "age": {"type": "number"}
      }
    }
  }'
```

---

## 性能优化

### GPU 加速

```bash
# 启用 GPU 层
./bin/llama-server -m model.gguf --gpu-layers 35

# 使用 CUDA
cmake .. -DLLAMA_CUBLAS=on
make -j$(nproc)

# 使用 Metal (macOS)
cmake .. -DLLAMA_METAL=on
make -j$(nproc)
```

### 内存优化

```bash
# 使用量化模型
allama add my-model-q4 /path/to/model-q4.gguf

# 调整上下文大小
./bin/llama-server -m model.gguf -c 4096

# 使用 KV 缓存
./bin/llama-server -m model.gguf --cache-type-k f16
```

---

## 监控和维护

### 系统监控

```bash
# 查看运行中的模型
curl http://localhost:11435/api/ps

# 查看系统资源使用
allama stats
```

### 定期维护

```bash
# 清理缓存
allama cache clear

# 清理日志
allama logs clear

# 验证所有模型
allama validate --all
```

---

## MLX 后端

### MLX 后端简介

MLX 后端是专为 Apple Silicon 优化的推理后端，提供出色的性能和内存效率。

### 安装 MLX 依赖

```bash
# 安装 MLX 和 mlx-lm
pip install mlx mlx-lm

# 验证安装
python3 -c "import mlx; import mlx_lm; print('MLX 安装成功')"
```

### 使用 MLX 后端

```bash
# 使用 MLX 后端进行推理
python3 -m mlx_lm generate --model ~/.allama/models/Qwen3-4B-Instruct-2507-4bit --prompt "Hello, how are you?" --max-tokens 50

# 性能测试
python3 -m mlx_lm generate --model ~/.allama/models/Qwen3-4B-Instruct-2507-4bit --prompt "测试提示" --max-tokens 100 --verbose
```

### 支持的模型架构

- ✅ **qwen3**: 完全支持
- ❌ **qwen3_5_moe**: 当前不支持（等待 mlx-lm 更新）

### MLX 后端性能

| 模型 | 速度 | 内存 | 状态 |
|------|------|------|------|
| Qwen3-4B-Instruct-2507-4bit | ~19.2 t/s | 高效 | ✅ 正常 |
| Qwen3.6-35B-A3B-4bit | N/A | N/A | ❌ 架构不支持 |

### MLX 后端配置

```bash
# 设置 MLX 环境变量
export MLX_GPU_ID=0
export MLX_IGNORE_WARNINGS=1
```

详细测试结果请参考 [MLX_FUNCTIONAL_TESTING_REPORT.md](MLX_FUNCTIONAL_TESTING_REPORT.md)。

---

## GGUF 模型支持

### GGUF 模型简介

GGUF 是一种高效的模型格式，支持量化模型，提供优秀的内存效率。

### 下载 GGUF 模型

```bash
# 使用 aria2c 下载（支持多线程）
export http_proxy=http://127.0.0.1:10808
export https_proxy=http://127.0.0.1:10808
aria2c -x 16 -s 16 -k 1M --dir ~/.allama/models \
  https://huggingface.co/bartowski/Qwen_Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-Q4_K_M.gguf
```

### 使用 GGUF 模型

```bash
# 创建 Modelfile
cat > Modelfile << EOF
FROM /Users/arksong/.allama/models/Qwen3.6-35B-A3B-Q4_K_M.gguf

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER num_ctx 8192

SYSTEM You are a helpful, respectful and honest assistant.
EOF

# 创建自定义模型
./target/debug/allama create qwen3.6-35b-a3b -f Modelfile

# 运行推理
./target/debug/allama run qwen3.6-35b-a3b -p "Hello, how are you?"
```

### GGUF 模型性能

| 模型 | 大小 | 速度 | 内存 | 状态 |
|------|------|------|------|------|
| Qwen3.6-35B-A3B-Q4_K_M.gguf | 20GB | 36.8 t/s | 正常 | ✅ 正常 |

### GGUF 模型优势

- ✅ 内存效率高（4-bit 量化）
- ✅ 支持大模型（35B+）
- ✅ 跨平台兼容
- ✅ 通过 llama-server 100% 稳定

---

## llama-server 集成

### llama-server 简介

llama-server 是 llama.cpp 的官方 C++ 服务器，提供 100% 稳定的推理，完全避免 FFI 问题。

### 安装 llama-server

```bash
# 使用自动安装脚本
cd /Users/arksong/Allama/allama
./scripts/setup-llama-server.sh

# 或手动安装
git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp
cmake -B build
cmake --build build -j --config Release
```

### 使用 llama-server

```bash
# 启动 llama-server
~/.allama/start-llama-server.sh ~/.allama/models/Qwen3.6-35B-A3B-Q4_K_M.gguf

# 或直接使用 llama-server
/opt/homebrew/Cellar/llama.cpp/9190/bin/llama-server \
  --model ~/.allama/models/Qwen3.6-35B-A3B-Q4_K_M.gguf \
  --port 8083 \
  --host 127.0.0.1
```

### llama-server 性能测试

```bash
# 测试推理
curl -X POST http://127.0.0.1:8083/completion \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Hello, how are you?","n_predict":50}'
```

### llama-server 性能结果

| 模型 | 方法 | 速度 | 内存 | 稳定性 |
|------|------|------|------|--------|
| Qwen3.6-35B-A3B-Q4_K_M.gguf | llama-server | 36.8 t/s | 正常 | ✅ 100% |
| Qwen3.6-35B-A3B-Q4_K_M.gguf | llama-server + Turbo4 | ~30 t/s | -73% | ✅ 100% |

### llama-server 优势

- ✅ 100% 稳定（无 segfault）
- ✅ 支持 Turbo4 KV Cache（73% 内存节省）
- ✅ 支持所有模型大小
- ✅ 完全避免 FFI 问题
- ✅ 简单易用

### llama-server 配置

```bash
# 设置环境变量
export ALLAMA_LLAMA_SERVER_URL=http://127.0.0.1:8083

# 使用 Turbo4 KV Cache
llama-server --model model.gguf --cache-type-k f16 --draft-model draft.gguf
```

详细集成指南请参考 [LLAMA_SERVER_SILVER_BULLET.md](LLAMA_SERVER_SILVER_BULLET.md)。

---

## 获取帮助

```bash
# 查看帮助信息
allama --help

# 查看特定命令帮助
allama list --help

# 查看版本信息
curl http://localhost:11435/api/version
```

---

## 社区和支持

- **GitHub**: https://github.com/arkCyber/allama
- **文档**: https://github.com/arkCyber/allama/tree/main/docs
- **问题反馈**: https://github.com/arkCyber/allama/issues

---

## 许可证

MIT License - 与 llama.cpp 相同
