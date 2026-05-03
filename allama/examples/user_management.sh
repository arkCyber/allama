#!/bin/bash
# Allama 用户管理示例脚本
# 演示如何创建用户、管理API key、使用认证

set -e

# 配置
BASE_URL="${ALLAMA_BASE_URL:-http://127.0.0.1:11435}"

echo "=========================================="
echo "Allama 用户管理示例"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "=========================================="
echo ""

# 示例1: 创建用户
echo "示例1: 创建用户"
echo "=========================================="
echo "命令:"
echo "curl -X POST ${BASE_URL}/api/users \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"
echo "    \"username\": \"demo_user\","
echo "    \"email\": \"demo@example.com\","
echo "    \"rate_limit\": 60,"
echo "    \"monthly_quota\": 1000000"
echo "  }'"
echo ""
echo "执行中..."
response=$(curl -s -X POST "${BASE_URL}/api/users" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "demo_user",
        "email": "demo@example.com",
        "rate_limit": 60,
        "monthly_quota": 1000000
    }' 2>&1)
echo "响应:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"
echo ""

# 提取API key
API_KEY=$(echo "$response" | grep -o '"api_key":"[^"]*"' | cut -d'"' -f4)
echo "提取的API Key: ${API_KEY:0:20}..."
echo ""

# 示例2: 使用API Key进行认证请求
echo "示例2: 使用API Key进行认证请求"
echo "=========================================="
echo "命令:"
echo "curl -X POST ${BASE_URL}/api/generate \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'Authorization: Bearer ${API_KEY}' \\"
echo "  -H 'X-Forwarded-For: 192.168.1.100' \\"
echo "  -d '{"
echo "    \"model\": \"llama3\","
echo "    \"prompt\": \"Hello, world!\","
echo "    \"stream\": false"
echo "  }'"
echo ""
echo "执行中..."
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.100" \
    -d '{
        "model": "llama3",
        "prompt": "Hello, world!",
        "stream": false
    }' 2>&1)
echo "响应:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"
echo ""

# 示例3: 本地请求（无需认证）
echo "示例3: 本地请求（无需认证）"
echo "=========================================="
echo "命令:"
echo "curl -X POST ${BASE_URL}/api/generate \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'X-Forwarded-For: 127.0.0.1' \\"
echo "  -d '{"
echo "    \"model\": \"llama3\","
echo "    \"prompt\": \"Hello, world!\","
echo "    \"stream\": false"
echo "  }'"
echo ""
echo "执行中..."
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 127.0.0.1" \
    -d '{
        "model": "llama3",
        "prompt": "Hello, world!",
        "stream": false
    }' 2>&1)
echo "响应:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"
echo ""

# 示例4: 列出所有用户（需要认证）
echo "示例4: 列出所有用户（需要认证）"
echo "=========================================="
echo "命令:"
echo "curl -X GET ${BASE_URL}/api/users \\"
echo "  -H 'Authorization: Bearer ${API_KEY}' \\"
echo "  -H 'X-Forwarded-For: 127.0.0.1'"
echo ""
echo "执行中..."
response=$(curl -s -X GET "${BASE_URL}/api/users" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "X-Forwarded-For: 127.0.0.1" 2>&1)
echo "响应:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"
echo ""

# 示例5: 使用OpenAI兼容端点
echo "示例5: 使用OpenAI兼容端点"
echo "=========================================="
echo "命令:"
echo "curl -X POST ${BASE_URL}/v1/chat/completions \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'Authorization: Bearer ${API_KEY}' \\"
echo "  -H 'X-Forwarded-For: 192.168.1.101' \\"
echo "  -d '{"
echo "    \"model\": \"llama3\","
echo "    \"messages\": ["
echo "      {\"role\": \"user\", \"content\": \"Hello!\"}"
echo "    ]"
echo "  }'"
echo ""
echo "执行中..."
response=$(curl -s -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.101" \
    -d '{
        "model": "llama3",
        "messages": [
            {"role": "user", "content": "Hello!"}
        ]
    }' 2>&1)
echo "响应:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"
echo ""

# 示例6: 查询计费记录
echo "示例6: 查询计费记录（需要认证）"
echo "=========================================="
echo "命令:"
echo "curl -X GET \"${BASE_URL}/api/billing/records?limit=5\" \\"
echo "  -H 'Authorization: Bearer ${API_KEY}' \\"
echo "  -H 'X-Forwarded-For: 127.0.0.1'"
echo ""
echo "执行中..."
response=$(curl -s -X GET "${BASE_URL}/api/billing/records?limit=5" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "X-Forwarded-For: 127.0.0.1" 2>&1)
echo "响应:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"
echo ""

echo "=========================================="
echo "示例执行完成"
echo "=========================================="
echo ""
echo "提示:"
echo "1. 将API Key存储在环境变量中: export ALLAMA_API_KEY=\"${API_KEY}\""
echo "2. 在生产环境中使用HTTPS"
echo "3. 定期轮换API Key"
echo "4. 参考文档: docs/AUTHENTICATION_GUIDE.md"
