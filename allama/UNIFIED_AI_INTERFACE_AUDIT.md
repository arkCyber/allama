# Allama 统一 AI 接口审计报告

## 审计日期
2026-05-11

## 审计目标
审计 Allama serve 代码架构，设计统一 AI 接口方案，实现模型路由，方便用户通过 Allama serve 调用所有 AI 模型。

---

## 1. 当前架构审计

### 1.1 服务架构

| 服务 | 端口 | 模型 | API 类型 | 状态 |
|------|------|------|----------|------|
| allama serve | 11435 | gemma4-e2b, gemma4-26b-moe, gemma4-4b | Ollama 兼容 | ✅ 运行 |
| llama-server | 8082 | gemma-4-26B-A4B-it-Q4_K_M.gguf | OpenAI 兼容 | ✅ 运行 |

### 1.2 allama serve 代码架构

#### ServerState 结构
```rust
pub struct ServerState {
    pub model_manager: ModelManager,
    pub loaded_models: Arc<TokioMutex<HashMap<String, ModelState>>>,
    pub audit_logger: Arc<TokioMutex<AuditLogger>>,
    pub rate_limiter: Arc<TokioMutex<HashMap<String, RateLimitInfo>>>,
    pub graceful_degradation: Arc<GracefulDegradation>,
    pub billing_manager: Arc<TokioMutex<Option<BillingManager>>>,
    pub auth_manager: Arc<TokioMutex<Option<AuthManager>>>,
}
```

#### 当前 API 端点
- `GET /api/tags` - 列出模型
- `POST /api/generate` - 生成文本
- `POST /api/chat` - 对话（当前返回模拟响应）
- `POST /api/embed` - 嵌入
- `GET /api/tags/:model` - 模型信息

#### 模型白名单
```rust
const MODEL_WHITELIST: &[&str] = &[
    "llama2", "llama3", "llama3:latest", "llama3:8b", "llama3:70b",
    "mistral", "mistral:latest", "mistral:7b",
    "gemma", "gemma:latest", "gemma:7b",
    "qwen", "qwen:latest", "qwen:14b",
];
```

### 1.3 当前问题

| 问题 | 描述 | 影响 |
|------|------|------|
| 模型路由缺失 | chat 函数返回模拟响应，没有真正调用推理 | 无法使用 |
| 服务分散 | llama-server 和 allama serve 分离 | 用户需要知道多个端口 |
| 白名单限制 | Gemma4 模型不在白名单中 | 无法调用 Gemma4 26B |
| 推理引擎未集成 | 内置推理引擎未在 chat/generate 中使用 | 功能不完整 |

---

## 2. 统一接口设计方案

### 2.1 设计目标

1. **统一入口**: 用户只需通过 allama serve (端口 11435) 调用所有 AI 模型
2. **智能路由**: 根据模型名称自动路由到正确的后端
3. **向后兼容**: 保持 Ollama 兼容 API 接口
4. **透明转发**: 对用户透明，无需知道后端实现细节

### 2.2 模型路由规则

| 模型名称模式 | 后端服务 | 端口 | API 格式 |
|-------------|----------|------|----------|
| gemma4-26b, gemma-4-26b | llama-server | 8082 | OpenAI 兼容 |
| gemma4-e2b, gemma4-4b | allama 内置推理 | - | 内置 |
| 其他 | allama 内置推理 | - | 内置 |

### 2.3 架构设计

```
用户请求
    ↓
allama serve (11435)
    ↓
模型路由器
    ↓
┌───────────────┬───────────────┐
│               │               │
llama-server    内置推理引擎    其他服务
(8082)         (inference)    (可选)
│               │               │
└───────────────┴───────────────┘
    ↓
统一响应
```

### 2.4 实现方案

#### 方案 A: HTTP 转发（推荐）
- 优点：简单、灵活、易于维护
- 实现：在 chat/generate 函数中添加 HTTP 客户端
- 适用：所有外部服务

#### 方案 B: 内置推理引擎集成
- 优点：性能更好、更可控
- 实现：集成现有的 inference 模块
- 适用：本地模型

#### 方案 C: 混合模式
- 优点：兼顾性能和灵活性
- 实现：根据模型类型选择方案 A 或 B
- 适用：复杂场景

**推荐方案**: 方案 C（混合模式）

---

## 3. 代码实现计划

### 3.1 添加 HTTP 客户端

在 `Cargo.toml` 中添加依赖：
```toml
[dependencies]
reqwest = { version = "0.11", features = ["json"] }
```

### 3.2 添加模型路由配置

在 `server/mod.rs` 中添加：
```rust
/// Model backend configuration
#[derive(Debug, Clone)]
struct ModelBackend {
    backend_type: BackendType,
    endpoint: String,
}

#[derive(Debug, Clone)]
enum BackendType {
    LlamaServer,  // llama-server (端口 8082)
    Internal,     // 内置推理引擎
    External,     // 其他外部服务
}

/// Model routing configuration
const MODEL_ROUTES: &[(&str, ModelBackend)] = &[
    ("gemma4-26b", ModelBackend {
        backend_type: BackendType::LlamaServer,
        endpoint: "http://127.0.0.1:8082".to_string(),
    }),
    ("gemma-4-26b", ModelBackend {
        backend_type: BackendType::LlamaServer,
        endpoint: "http://127.0.0.1:8082".to_string(),
    }),
    // 其他模型使用内置推理引擎
];
```

### 3.3 实现路由函数

```rust
impl ServerState {
    /// Get model backend configuration
    fn get_model_backend(&self, model_name: &str) -> Option<&ModelBackend> {
        MODEL_ROUTES.iter().find(|(name, _)| model_name.contains(name))
            .map(|(_, backend)| backend)
    }

    /// Route chat request to appropriate backend
    async fn route_chat_request(
        &self,
        req: ChatRequest,
        headers: HeaderMap,
    ) -> Result<ChatResponse, StatusCode> {
        let backend = self.get_model_backend(&req.model)
            .unwrap_or(&ModelBackend {
                backend_type: BackendType::Internal,
                endpoint: String::new(),
            });

        match backend.backend_type {
            BackendType::LlamaServer => {
                self.forward_to_llama_server(req, &backend.endpoint).await
            }
            BackendType::Internal => {
                self.handle_internal_inference(req).await
            }
            BackendType::External => {
                self.forward_to_external(req, &backend.endpoint).await
            }
        }
    }

    /// Forward request to llama-server
    async fn forward_to_llama_server(
        &self,
        req: ChatRequest,
        endpoint: &str,
    ) -> Result<ChatResponse, StatusCode> {
        let client = reqwest::Client::new();
        let url = format!("{}/v1/chat/completions", endpoint);

        let request_body = serde_json::json!({
            "model": req.model,
            "messages": req.messages,
            "max_tokens": 1000,
        });

        let response = client
            .post(&url)
            .json(&request_body)
            .send()
            .await
            .map_err(|_| StatusCode::BAD_GATEWAY)?;

        let response_json: serde_json::Value = response
            .json()
            .await
            .map_err(|_| StatusCode::BAD_GATEWAY)?;

        // Parse llama-server response and convert to Ollama format
        let content = response_json["choices"][0]["message"]["content"]
            .as_str()
            .unwrap_or("");

        Ok(ChatResponse {
            model: req.model,
            message: ChatMessage {
                role: "assistant".to_string(),
                content: content.to_string(),
            },
            done: true,
        })
    }

    /// Handle internal inference
    async fn handle_internal_inference(
        &self,
        req: ChatRequest,
    ) -> Result<ChatResponse, StatusCode> {
        // TODO: Integrate with internal inference engine
        Ok(ChatResponse {
            model: req.model,
            message: ChatMessage {
                role: "assistant".to_string(),
                content: "Internal inference not yet implemented".to_string(),
            },
            done: true,
        })
    }

    /// Forward to external service
    async fn forward_to_external(
        &self,
        req: ChatRequest,
        endpoint: &str,
    ) -> Result<ChatResponse, StatusCode> {
        // TODO: Implement external service forwarding
        Ok(ChatResponse {
            model: req.model,
            message: ChatMessage {
                role: "assistant".to_string(),
                content: "External forwarding not yet implemented".to_string(),
            },
            done: true,
        })
    }
}
```

### 3.4 更新 chat 函数

```rust
async fn chat(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<ChatRequest>,
) -> impl IntoResponse {
    // ... 现有的验证逻辑 ...

    // 使用路由函数处理请求
    match state.route_chat_request(req, headers).await {
        Ok(response) => Json(response).into_response(),
        Err(status) => status.into_response(),
    }
}
```

### 3.5 更新模型白名单

```rust
const MODEL_WHITELIST: &[&str] = &[
    "llama2", "llama3", "llama3:latest", "llama3:8b", "llama3:70b",
    "mistral", "mistral:latest", "mistral:7b",
    "gemma", "gemma:latest", "gemma:7b",
    "qwen", "qwen:latest", "qwen:14b",
    "gemma4-26b", "gemma-4-26b",  // 添加 Gemma4 26B
    "gemma4-e2b", "gemma4-4b",     // 添加其他 Gemma4 模型
];
```

---

## 4. 实现步骤

### 阶段 1: 基础架构
1. ✅ 审计现有代码
2. ✅ 设计统一接口方案
3. ⏳ 添加 HTTP 客户端依赖
4. ⏳ 实现模型路由配置
5. ⏳ 实现路由函数

### 阶段 2: llama-server 集成
1. ⏳ 实现 llama-server 转发
2. ⏳ 测试 Gemma4 26B 调用
3. ⏳ 处理流式响应

### 阶段 3: 内置推理集成
1. ⏳ 集成内置推理引擎
2. ⏳ 测试其他模型调用
3. ⏳ 性能优化

### 阶段 4: 测试和文档
1. ⏳ 端到端测试
2. ⏳ 编写使用文档
3. ⏳ 更新 API 文档

---

## 5. 预期效果

### 5.1 用户体验

**之前**:
```bash
# 用户需要知道多个端口
curl http://127.0.0.1:11435/api/chat  # allama serve
curl http://127.0.0.1:8082/v1/chat/completions  # llama-server
```

**之后**:
```bash
# 用户只需知道一个端口
curl http://127.0.0.1:11435/api/chat  # 统一入口，自动路由
```

### 5.2 功能特性

| 特性 | 状态 |
|------|------|
| 统一入口 | ✅ 设计完成 |
| 智能路由 | ✅ 设计完成 |
| 模型白名单扩展 | ✅ 设计完成 |
| llama-server 集成 | ✅ 设计完成 |
| 内置推理集成 | ⏳ 待实现 |
| 流式响应支持 | ⏳ 待实现 |

---

## 6. 下一步行动

1. 添加 reqwest 依赖到 Cargo.toml
2. 实现模型路由配置
3. 实现 llama-server 转发功能
4. 更新 chat 函数使用路由
5. 测试 Gemma4 26B 调用
6. 集成内置推理引擎

---

**审计完成时间**: 2026-05-11
**审计状态**: ✅ 完成
**方案设计**: ✅ 完成
**代码实现**: ⏳ 待进行
