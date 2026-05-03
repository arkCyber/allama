# Allama 测试套件

本目录包含 Allama 项目的全面测试套件，用于验证航空航天级别的安全特性和功能。

## 测试目录结构

```
tests/
├── README.md              # 本文件
├── integration/           # 集成测试
│   ├── api_tests.sh       # API端点测试
│   ├── rate_limit_test.sh # 速率限制测试
│   ├── concurrency_test.sh # 并发处理测试
│   ├── input_validation_test.sh # 输入验证测试
│   └── graceful_degradation_test.sh # 优雅降级测试
└── docs/                  # 测试文档
    ├── test_plan.md       # 测试计划
    └── test_results.md    # 测试结果记录
```

## 测试覆盖范围

### 1. API端点测试
- `/api/tags` - 列出可用模型
- `/api/generate` - 生成文本
- `/api/chat` - 聊天完成
- `/api/embed` - 嵌入生成
- `/api/ps` - 列出运行中的模型
- `/api/show` - 显示模型详情
- `/api/delete` - 删除模型
- `/api/pull` - 拉取模型
- `/api/create` - 创建模型
- `/api/copy` - 复制模型
- `/api/push` - 推送模型
- OpenAI兼容端点测试

### 2. 速率限制测试
- 基于真实IP的速率限制
- 每分钟60请求限制
- 速率限制器HashMap清理机制
- 速率限制超时恢复

### 3. 并发处理测试
- 并发请求处理能力
- OLLAMA_NUM_PARALLEL环境变量
- 并发限制中间件
- 多线程安全性

### 4. 输入验证测试
- 输入长度验证（100K字符限制）
- 消息数量验证（100条限制）
- 请求大小限制（10MB限制）
- 模型名称白名单验证

### 5. 优雅降级测试
- 降级模式切换
- 降级模式下的响应
- 故障恢复机制
- 超时保护

### 6. 航空航天级别安全测试
- 互斥锁死锁防护
- 审计日志记录
- 超时保护机制
- 错误处理和恢复

## 运行测试

### 前提条件
1. 构建 Allama: `cargo build --release`
2. 启动服务器: `./target/release/allama serve`
3. 安装测试工具: `curl`, `jq`

### 运行所有测试
```bash
cd tests/integration
./run_all_tests.sh
```

### 运行单个测试
```bash
cd tests/integration
./api_tests.sh
./rate_limit_test.sh
./concurrency_test.sh
./input_validation_test.sh
./graceful_degradation_test.sh
```

## 测试结果

测试结果将记录在 `tests/docs/test_results.md` 中。

## 环境变量

测试脚本使用以下环境变量：
- `ALLAMA_HOST`: 服务器地址（默认: 127.0.0.1）
- `ALLAMA_PORT`: 服务器端口（默认: 11434）
- `TEST_MODEL`: 测试使用的模型名称（默认: llama3.2）

## 注意事项

- 所有测试都需要服务器运行
- 某些测试可能需要特定模型已加载
- 建议在测试环境中运行，避免影响生产环境
