# Allama 推理功能测试示例

本目录包含完整的推理功能测试脚本和实用应用示例，用于验证 Allama 推理服务的真实功能。

## 📋 实用应用示例

### 1. `simple_chat.rs` - 简单聊天应用
**用途**: 创建一个简单的命令行聊天应用，使用 Allama 进行实时对话

**功能**:
- 实时对话交互
- 对话历史记录
- 支持特殊命令（quit、clear）
- 显示推理耗时

**运行**:
```bash
# 1. 启动推理服务
./target/debug/inference-service --host 127.0.0.1 --port 8081 --models-dir ~/.allama/models

# 2. 运行聊天应用
cargo run --example simple_chat --features inference
```

**使用说明**:
- 输入文本进行对话
- 输入 `quit` 或 `exit` 退出
- 输入 `clear` 清屏

---

### 2. `code_assistant.rs` - 代码生成助手
**用途**: 创建一个代码生成和补全助手，帮助开发者生成代码、解释代码、调试代码等

**功能**:
- 代码生成
- 代码解释
- 代码调试
- 代码重构

**运行**:
```bash
cargo run --example code_assistant --features inference
```

**使用说明**:
- 选择功能编号（1-4）
- 按照提示输入代码或描述
- 获取 AI 生成的结果

---

### 3. `document_summarizer.rs` - 文档摘要生成器
**用途**: 使用 Allama 生成文档摘要，支持长文本摘要、关键点提取、多语言摘要等

**功能**:
- 从文件生成摘要
- 从输入文本生成摘要
- 提取关键点
- 生成简短摘要
- 生成详细摘要

**运行**:
```bash
cargo run --example document_summarizer --features inference
```

**使用说明**:
- 选择功能编号（1-5）
- 输入文件路径或文本
- 获取生成的摘要

---

### 4. `qa_system.rs` - 问答系统
**用途**: 创建一个基于知识的问答系统，支持从文本中提取答案、回答事实性问题等

**功能**:
- 从文档中回答问题
- 通用问答
- 代码问答
- 数学问题解答
- 事实核查

**运行**:
```bash
cargo run --example qa_system --features inference
```

**使用说明**:
- 选择功能编号（1-5）
- 输入文档或问题
- 获取 AI 回答

---

### 5. `translator.rs` - 翻译工具
**用途**: 创建一个多语言翻译工具，支持中英互译、多语言翻译等

**功能**:
- 中文翻译成英文
- 英文翻译成中文
- 翻译成其他语言
- 翻译文件
- 批量翻译

**运行**:
```bash
cargo run --example translator --features inference
```

**使用说明**:
- 选择功能编号（1-5）
- 输入源文本和目标语言
- 获取翻译结果

---

## Ollama 对齐、批量请求与 Thinking（可无服务跑单元测试）

以下示例在 `allama/` 目录执行；带推理拆分的示例需 **`--features inference`**。详见各文件顶部英文模块说明。

| 示例 | 说明 | 测试命令 |
|------|------|----------|
| `ollama_compatible_api_client` | 构造 `/api/generate`、`/api/chat` 的 JSON；可选 `ALLAMA_HTTP_SMOKE=1` 对运行中的 `allama serve` 做 `GET /api/version`、`GET /api/tags` | `cargo test --example ollama_compatible_api_client --features inference` |
| `batch_generate_payloads` | 从 stdin 多行批量生成 `/api/generate` 请求体 | `cargo test --example batch_generate_payloads` |
| `thinking_split_app` | 使用库内 `split_thinking_and_answer`，输出 **聊天** 形状 JSON（`message` + 可选 `thinking`） | `cargo test --example thinking_split_app --features inference` |
| `thinking_generate_response` | 同上拆分逻辑，输出 **generate** 形状（`response` + 可选 `thinking`），并演示流式缓冲结束后一次性拆分 | `cargo test --example thinking_generate_response --features inference` |

一键脚本（与 CI 对齐）：在 `allama` 目录执行 `bash scripts/run_automated_tests.sh`（包含 `cargo test`、若干 example 测试与 `cargo check`）。

---

## 📋 测试脚本列表

### 1. `inference_test.sh` - 基础推理功能测试
**用途**: 测试推理服务的基本功能
**特点**:
- 使用小型测试模型（stories15M）
- 快速验证服务是否正常工作
- 测试多种参数组合
- 性能基准测试
- ✨ **新增**: 统计端点测试

**运行**:
```bash
cd /Users/arksong/llama-cpp-turboquant/allama
chmod +x examples/inference_test.sh
./examples/inference_test.sh
```

**测试内容**:
- ✓ 服务启动和健康检查
- ✓ 基础推理功能
- ✓ 不同温度参数测试
- ✓ 中文提示词测试
- ✓ 错误处理测试
- ✓ 统计端点测试
- ✓ 性能测试（5次请求）

---

### 2. `concurrent_test.sh` - 并发推理测试
**用途**: 测试并发推理功能
**特点**:
- 测试多模型并发能力
- 测试多用户并发请求
- 性能基准测试
- 压力测试
- 统计信息监控

**运行**:
```bash
cd /Users/arksong/llama-cpp-turboquant/allama
chmod +x examples/concurrent_test.sh
./examples/concurrent_test.sh
```

**测试内容**:
- ✓ 顺序请求（基准）
- ✓ 并发请求（5个）
- ✓ 统计端点
- ✓ 压力测试（10并发）
- ✓ 性能指标计算

---

### 3. `gemma4_inference_test.sh` - Gemma4 模型专项测试
**用途**: 使用真实的 Gemma4 模型进行全面测试
**特点**:
- 自动查找 Gemma4 模型
- 多场景测试（对话、代码、问答、创意）
- 支持中英文测试
- 参数影响分析

**运行**:
```bash
cd /Users/arksong/llama-cpp-turboquant/allama
chmod +x examples/gemma4_inference_test.sh
./examples/gemma4_inference_test.sh
```

**测试内容**:
- ✓ 英文对话测试
- ✓ 中文对话测试
- ✓ 代码生成测试
- ✓ 知识问答测试
- ✓ 创意写作测试
- ✓ 参数影响测试

**模型位置**:
脚本会自动在以下位置查找 Gemma4 模型：
- `../models/gemma-4-2b.gguf`
- `../models/gemma-4-4b.gguf`
- `../models/gemma4-2b-it.gguf`
- `../models/gemma4-4b-it.gguf`

---

### 4. `gemma4_26b_96k_context.rs` - Gemma4 26B 全面应用示例

**用途:** Gemma4 26B MoE 模型全面应用场景测试 (96k 上下文)

**特点:**
- 8个全面应用场景测试
- 英文/中文对话
- 代码生成与分析
- 长文档摘要
- 创意写作
- 技术问答
- 数学推理

**前置条件**:
- Gemma4 26B GGUF 模型已下载到 ../models/gemma-4-26b/
- llama-server 已编译 (位于 /Users/arksong/Allama/build/bin/llama-server)
- 系统至少 32GB RAM (推荐 64GB)

**技术说明**:
- 推理服务端口: 8082 (llama-server)
- TurboQuant/Turbo3: 已启用 (Metal 后端自动启用)
- 上下文大小: 8192 tokens (可调整)
- 模型大小: ~16GB (Q4_K_M 量化)

---

### 5. `gemma4_simple_test`

**用途:** 简单的 Gemma4 推理测试示例

**功能:**
- 假设推理服务已经在运行
- 执行健康检查
- 加载模型
- 运行推理测试（短对话、中等长度对话）
- 显示推理结果、生成速度等信息

**运行方式:**
```bash
# 1. 先启动推理服务
./target/debug/inference-service --host 127.0.0.1 --port 8081 --models-dir ~/.allama/models --max-loaded-models 1 --context-size 4096

# 2. 运行示例
cargo run --example gemma4_simple_test --features inference
```

**测试内容:**
- 短对话测试 (100 tokens)
- 中等长度对话测试 (200 tokens)

**前置条件:**
- 推理服务已编译并运行
- 测试模型已下载到 `~/.allama/models/test-model.gguf`

**技术说明:**
- 此示例使用 reqwest HTTP 客户端进行 API 请求
- 配置为使用 HTTP/1.1 协议（`.http1_only()`），因为 inference-service 使用 HTTP/1.1 而非 HTTP/2
- 如果使用 HTTP/2 会导致 "frame with invalid size" 错误

---

### 6. `gemma4_long_context.rs` - Gemma4 长上下文 Rust 示例（通用版）
**用途**: 使用 Rust 语言测试 Gemma4 模型的长上下文推理能力（支持多种模型）
**特点**:
- Rust 实现的应用示例
- 可配置上下文大小（默认 8k，可调整）
- 自动检测多种 Gemma4 模型（2B/4B/26B）
- 多场景测试（短对话、长文档摘要、代码分析、多轮对话）
- 性能指标显示
- 完整的错误处理和清理

**运行**:
```bash
cd /Users/arksong/Allama/allama
cargo run --example gemma4_long_context --features inference
```

**测试内容**:
- ✓ 短对话基准测试
- ✓ 中等长度对话
- ✓ 长文档摘要（测试长上下文）
- ✓ 代码分析（测试长上下文）
- ✓ 多轮对话（测试上下文保持）
- ✓ 服务统计信息

**前置条件**:
- Gemma4 GGUF 模型已下载到以下任一位置：
  - `../models/gemma-4-26b/` (26B model)
  - `../models/gemma-4-4b/` (4B model)
  - `../models/gemma-4-2b/` (2B model)
  - `../models/` (alternative locations)
- 推理服务已编译 (`cargo build --release --bin inference-service --features inference`)

**配置**:
- 修改代码中的 `CONTEXT_SIZE` 常量来调整上下文大小
- 默认 8k tokens，适合大多数系统
- 可根据系统内存调整为 16k、32k 或更高

---
**用途**: 测试推理服务与主服务器的完整集成
**特点**:
- 同时启动推理服务和主服务器
- 测试完整的请求链路
- 验证 OpenAI 兼容 API
- 稳定性测试

**运行**:
```bash
cd /Users/arksong/llama-cpp-turboquant/allama
chmod +x examples/end_to_end_test.sh
./examples/end_to_end_test.sh
```

**测试内容**:
- ✓ 推理服务启动
- ✓ 主服务器启动
- ✓ 服务间通信
- ✓ OpenAI API 兼容性
- ✓ 连续请求稳定性（10次）

---

## 🚀 快速开始

### 前置条件

1. **编译项目**:
```bash
cd /Users/arksong/llama-cpp-turboquant/allama
cargo build --release --features inference
```

2. **准备模型**:
   - 小型测试模型已存在: `../tinyllamas/stories15M-q4_0.gguf`
   - Gemma4 模型（可选）: 下载并放到 `../models/` 目录

3. **安装依赖**:
```bash
# 确保已安装 jq（用于 JSON 解析）
brew install jq  # macOS
# 或
sudo apt-get install jq  # Linux
```

### 运行测试

#### 方案 1: 快速测试（推荐新手）
```bash
# 使用小型模型进行快速测试
./examples/inference_test.sh
```

#### 方案 2: Gemma4 完整测试
```bash
# 使用 Gemma4 模型进行全面测试
./examples/gemma4_inference_test.sh
```

#### 方案 3: 端到端集成测试
```bash
# 测试完整的服务集成
./examples/end_to_end_test.sh
```

---

## 📊 测试结果解读

### 成功标志
- ✅ `✓` 绿色勾号 - 测试通过
- ⚠️ `⚠️` 黄色警告 - 部分功能可能不支持
- ❌ `✗` 红色叉号 - 测试失败

### 日志文件
测试会生成以下日志文件：
- `inference_service.log` - 推理服务日志
- `gemma4_service.log` - Gemma4 测试日志
- `inference_e2e.log` - 端到端推理服务日志
- `main_server_e2e.log` - 端到端主服务器日志

查看日志：
```bash
cat inference_service.log
tail -f gemma4_service.log  # 实时查看
```

---

## 🔧 故障排除

### 问题 1: 模型未找到
**错误**: `未找到测试模型`
**解决**:
```bash
# 检查模型文件
ls -lh ../tinyllamas/stories15M-q4_0.gguf
ls -lh ../models/*.gguf

# 如果没有，下载小型测试模型
# 或使用现有的词汇表模型
```

### 问题 2: 端口被占用
**错误**: `Address already in use`
**解决**:
```bash
# 查找占用端口的进程
lsof -i :8081
lsof -i :11434

# 杀死进程
kill -9 <PID>

# 或修改脚本中的端口号
```

### 问题 3: 编译失败
**错误**: `could not compile`
**解决**:
```bash
# 清理并重新编译
cargo clean
cargo build --release --features inference

# 检查 Rust 版本
rustc --version  # 需要 1.94+
```

### 问题 4: 推理超时
**错误**: 请求长时间无响应
**解决**:
- 大模型需要更长的加载时间，增加等待时间
- 检查系统资源（内存、CPU）
- 使用更小的模型进行测试

---

## 📈 性能基准

### 小型模型 (stories15M-q4_0)
- 模型大小: ~8MB
- 加载时间: <2秒
- 推理速度: 50-100 tokens/s
- 内存占用: <500MB

### Gemma4-2B
- 模型大小: ~1.5GB
- 加载时间: 5-10秒
- 推理速度: 10-30 tokens/s
- 内存占用: ~2GB

### Gemma4-4B
- 模型大小: ~3GB
- 加载时间: 10-20秒
- 推理速度: 5-15 tokens/s
- 内存占用: ~4GB

---

## 🎯 测试场景

### 场景 1: 开发环境验证
```bash
# 快速验证代码更改
./examples/inference_test.sh
```

### 场景 2: 模型质量评估
```bash
# 使用 Gemma4 评估模型质量
./examples/gemma4_inference_test.sh
```

### 场景 3: 生产环境预检
```bash
# 完整的集成测试
./examples/end_to_end_test.sh
```

---

## 📝 自定义测试

### 修改测试参数

编辑脚本中的配置部分：
```bash
# 在脚本顶部修改
INFERENCE_SERVICE_PORT=8081  # 修改端口
MODELS_DIR="../models"        # 修改模型目录
TEST_MODEL="path/to/model"    # 修改测试模型
```

### 添加新测试

在脚本中添加新的测试用例：
```bash
# Test N: 自定义测试
echo -e "\n${BLUE}测试 N: 自定义功能${NC}"
custom_request='{
  "model": "your-model.gguf",
  "prompt": "Your custom prompt",
  "max_tokens": 100,
  "temperature": 0.7
}'

custom_response=$(curl -s -X POST "http://127.0.0.1:8081/inference" \
    -H "Content-Type: application/json" \
    -d "$custom_request")

# 处理响应...
```

---

## Web search test examples (English)

These examples validate the aerospace-grade web search module and HTTP integration.

### `web_search_direct.rs`
- Prints `WebSearchService::from_environment()` status, runs `sanitize_query` checks, fingerprint sample, and `new_disabled()` search path.
- Optional live DuckDuckGo/Brave call: `ALLAMA_WEB_SEARCH_ENABLED=1 cargo run --example web_search_direct -- --live`

### `web_search_http_client.rs`
- Calls `GET /api/web_search/status` and `POST /api/web_search` against `ALLAMA_API_BASE` (default `http://127.0.0.1:11435`).
- Optional auth: `ALLAMA_API_KEY`. Pass query as first CLI arg.

### `web_search_chat_integration.rs`
- Single `POST /api/chat` with `web_search: true`. Set `ALLAMA_TEST_MODEL` if needed.

### `web_search_generate_integration.rs`
- Single `POST /api/generate` with `web_search: true` (first prompt line used as search query server-side).

**Server:** start `allama serve` with `ALLAMA_WEB_SEARCH_ENABLED=1` for HTTP examples to succeed on search paths.

---

## Automated testing (English)

- **Local:** from `allama/`, run `bash scripts/run_automated_tests.sh` (full `cargo test` + example checks).
- **CI:** repository workflow `.github/workflows/allama-crate.yml` runs `cargo test` when `allama/**` changes.
- **Web search integration tests:** `tests/web_search_automated.rs`.

---

## 🔗 相关文档

- [推理服务实现报告](../INFERENCE_SERVICE_IMPLEMENTATION.md)
- [快速启动指南](../QUICKSTART_INFERENCE.md)
- [API 文档](../INFERENCE_SERVICE_IMPLEMENTATION.md#-api-规范)

---

## 💡 最佳实践

1. **先运行基础测试**: 使用 `inference_test.sh` 验证基本功能
2. **逐步增加复杂度**: 从小模型到大模型
3. **保存测试日志**: 便于问题排查
4. **定期运行测试**: 确保代码更改不破坏功能
5. **监控资源使用**: 注意内存和 CPU 占用

---

## 🆘 获取帮助

如果遇到问题：
1. 查看日志文件
2. 检查模型文件是否存在
3. 验证端口是否可用
4. 确认系统资源充足
5. 查看相关文档

---

**最后更新**: 2026-05-07
**版本**: 1.0.0
**状态**: ✅ 可用
