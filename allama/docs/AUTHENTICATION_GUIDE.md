# Allama 用户认证系统使用指南

## 概述

Allama 提供完整的用户认证系统，支持远程用户认证和API key管理。本地请求（127.0.0.1）无需认证，远程请求需要有效的API key。

## 默认测试账号

为了方便快速测试，Allama 在服务器启动时会自动创建一个默认测试用户：

**默认测试用户信息：**
- **用户名**: `test_user`
- **邮箱**: `test@allama.ai`
- **速率限制**: 60 requests/minute
- **月度配额**: 100,000 tokens
- **API Key**: 服务器启动时自动生成并显示在控制台

**使用默认测试账号：**

服务器启动时会显示类似以下信息：
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

您可以直接使用显示的API Key进行测试：

```bash
curl -X POST http://your-server:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"Hello, world!","stream":false}'
```

**注意事项：**
- 默认测试账号仅用于开发和测试
- 生产环境应创建独立的用户账号
- 默认账号的API Key在服务器启动时生成，每次重启可能不同
- 可以通过API创建更多用户账号

## 认证策略

### 本地请求（无需认证）
- 来源IP：127.0.0.1, ::1, localhost
- 请求头：`X-Forwarded-For: 127.0.0.1` 或 `X-Real-IP: 127.0.0.1`
- 适用场景：本地开发、测试

### 远程请求（需要认证）
- 来源IP：非本地IP
- 认证方式：Bearer Token (API key)
- 适用场景：生产环境、远程访问

## 用户管理

### 1. 创建用户

**请求：**
```bash
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "myuser",
    "email": "user@example.com",
    "rate_limit": 60,
    "monthly_quota": 1000000
  }'
```

**响应：**
```json
{
  "user_id": "user_1234567890",
  "username": "myuser",
  "email": "user@example.com",
  "api_key": "allama_abcdefghijklmnopqrstuvwxyz123456",
  "rate_limit": 60,
  "monthly_quota": 1000000,
  "created_at": "2026-05-03T08:00:00Z"
}
```

**参数说明：**
- `username`: 用户名（必填，唯一）
- `email`: 邮箱地址（必填）
- `rate_limit`: 速率限制（请求/分钟）
- `monthly_quota`: 月度token配额

### 2. 列出所有用户

**请求：**
```bash
curl -X GET http://localhost:11435/api/users \
  -H "X-Forwarded-For: 127.0.0.1"
```

**响应：**
```json
{
  "users": [
    {
      "user_id": "user_1234567890",
      "username": "myuser",
      "email": "user@example.com",
      "rate_limit": 60,
      "monthly_quota": 1000000,
      "created_at": "2026-05-03T08:00:00Z",
      "is_active": true
    }
  ]
}
```

## API Key 使用

### 认证方式

在HTTP请求头中添加：
```
Authorization: Bearer your_api_key_here
```

### 使用示例

#### 1. 生成文本（/api/generate）

```bash
curl -X POST http://your-server:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456" \
  -d '{
    "model": "llama3",
    "prompt": "Hello, world!",
    "stream": false
  }'
```

#### 2. 聊天完成（/api/chat）

```bash
curl -X POST http://your-server:11435/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456" \
  -d '{
    "model": "llama3",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "stream": false
  }'
```

#### 3. 嵌入生成（/api/embed）

```bash
curl -X POST http://your-server:11435/api/embed \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456" \
  -d '{
    "model": "llama3",
    "input": "Hello, world!"
  }'
```

#### 4. OpenAI兼容端点

**Chat Completions:**
```bash
curl -X POST http://your-server:11435/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456" \
  -d '{
    "model": "llama3",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

**Completions:**
```bash
curl -X POST http://your-server:11435/v1/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456" \
  -d '{
    "model": "llama3",
    "prompt": "Hello, world!"
  }'
```

**Embeddings:**
```bash
curl -X POST http://your-server:11435/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456" \
  -d '{
    "model": "llama3",
    "input": "Hello, world!"
  }'
```

## 管理端点

管理端点也需要认证：

### 模型管理

**删除模型：**
```bash
curl -X DELETE http://your-server:11435/api/delete \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456" \
  -d '{"model": "llama3"}'
```

**拉取模型：**
```bash
curl -X POST http://your-server:11435/api/pull \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456" \
  -d '{"model": "llama3"}'
```

**停止模型：**
```bash
curl -X POST http://your-server:11435/api/stop \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456" \
  -d '{"model": "llama3"}'
```

### 计费查询

**获取计费记录：**
```bash
curl -X GET "http://your-server:11435/api/billing/records" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456"
```

**获取计费摘要：**
```bash
curl -X GET "http://your-server:11435/api/billing/summary" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456"
```

**获取模型统计：**
```bash
curl -X GET "http://your-server:11435/api/billing/stats/llama3" \
  -H "Authorization: Bearer allama_abcdefghijklmnopqrstuvwxyz123456"
```

## 错误处理

### 401 Unauthorized

**原因：**
- 未提供API key
- API key无效
- API key已过期

**响应：**
```json
{
  "error": "Unauthorized",
  "message": "API key required"
}
```

### 解决方法

1. 检查请求头是否包含 `Authorization: Bearer your_api_key`
2. 确认API key格式正确（以 `allama_` 开头）
3. 联系管理员获取有效的API key

## 安全建议

1. **保护API Key**
   - 不要在客户端代码中硬编码API key
   - 使用环境变量或密钥管理服务存储API key
   - 定期轮换API key

2. **使用HTTPS**
   - 生产环境必须使用HTTPS
   - 防止API key在传输过程中被截获

3. **限制速率**
   - 为每个用户设置合理的速率限制
   - 防止滥用和DDoS攻击

4. **监控使用**
   - 定期检查计费记录
   - 监控异常使用模式

## 完整示例

### Python示例

```python
import requests

# 1. 创建用户
response = requests.post(
    "http://localhost:11435/api/users",
    json={
        "username": "myuser",
        "email": "user@example.com",
        "rate_limit": 60,
        "monthly_quota": 1000000
    }
)
user_data = response.json()
api_key = user_data["api_key"]

# 2. 使用API key进行认证请求
headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {api_key}"
}

response = requests.post(
    "http://localhost:11435/api/generate",
    headers=headers,
    json={
        "model": "llama3",
        "prompt": "Hello, world!",
        "stream": false
    }
)
print(response.json())
```

### JavaScript/Node.js示例

```javascript
const axios = require('axios');

// 1. 创建用户
async function createUser() {
  const response = await axios.post('http://localhost:11435/api/users', {
    username: 'myuser',
    email: 'user@example.com',
    rate_limit: 60,
    monthly_quota: 1000000
  });
  return response.data.api_key;
}

// 2. 使用API key进行认证请求
async function generateText(apiKey) {
  const response = await axios.post(
    'http://localhost:11435/api/generate',
    {
      model: 'llama3',
      prompt: 'Hello, world!',
      stream: false
    },
    {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      }
    }
  );
  return response.data;
}

// 使用
(async () => {
  const apiKey = await createUser();
  const result = await generateText(apiKey);
  console.log(result);
})();
```

## 故障排除

### 问题：本地请求被拒绝

**原因：** 请求未包含本地IP标识头

**解决方法：**
```bash
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","prompt":"Hello"}'
```

### 问题：远程请求返回401

**原因：** 未提供或API key无效

**解决方法：**
```bash
curl -X POST http://your-server:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key_here" \
  -d '{"model":"llama3","prompt":"Hello"}'
```

## 附录

### 端点认证矩阵

| 端点 | 方法 | 认证要求 | 说明 |
|------|------|----------|------|
| /api/tags | GET | 无 | 公开 |
| /api/tags/:model | GET | 无 | 公开 |
| /api/ps | GET | 无 | 公开 |
| /api/version | GET | 无 | 公开 |
| /api/users | POST | 无 | 公开注册 |
| /api/users | GET | 是 | 管理端点 |
| /api/generate | POST | 是 | 本地除外 |
| /api/chat | POST | 是 | 本地除外 |
| /api/embed | POST | 是 | 本地除外 |
| /api/show | POST | 是 | 管理端点 |
| /api/delete | DELETE | 是 | 管理端点 |
| /api/pull | POST | 是 | 管理端点 |
| /api/push | POST | 是 | 管理端点 |
| /api/create | POST | 是 | 管理端点 |
| /api/copy | POST | 是 | 管理端点 |
| /api/stop | POST | 是 | 管理端点 |
| /api/billing/* | GET | 是 | 管理端点 |
| /v1/chat/completions | POST | 是 | 本地除外 |
| /v1/completions | POST | 是 | 本地除外 |
| /v1/embeddings | POST | 是 | 本地除外 |
