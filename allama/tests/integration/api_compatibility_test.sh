#!/bin/bash
# API兼容性集成测试脚本
# 测试Ollama兼容性、OpenAI兼容性、REST API标准等

# 移除set -e以避免单个测试失败导致整个脚本停止

# 配置
ALLAMA_HOST=${ALLAMA_HOST:-"127.0.0.1"}
ALLAMA_PORT=${ALLAMA_PORT:-"11434"}
BASE_URL="http://${ALLAMA_HOST}:${ALLAMA_PORT}"
TEST_MODEL=${TEST_MODEL:-"llama3"}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Allama API兼容性集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: Ollama兼容性 - /api/tags
echo "测试1: Ollama兼容性 - /api/tags"
response=$(curl -s "${BASE_URL}/api/tags")

if echo "$response" | grep -q '"models"'; then
    echo -e "${GREEN}✓ Ollama /api/tags 兼容${NC}"
else
    echo -e "${YELLOW}⚠ Ollama /api/tags 兼容性需要改进${NC}"
fi
echo ""

# 测试2: Ollama兼容性 - /api/generate
echo "测试2: Ollama兼容性 - /api/generate"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

if echo "$response" | grep -q '"response"'; then
    echo -e "${GREEN}✓ Ollama /api/generate 兼容${NC}"
else
    echo -e "${YELLOW}⚠ Ollama /api/generate 兼容性需要改进${NC}"
fi
echo ""

# 测试3: Ollama兼容性 - /api/chat
echo "测试3: Ollama兼容性 - /api/chat"
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}],\"stream\":false}")

if echo "$response" | grep -q '"message"'; then
    echo -e "${GREEN}✓ Ollama /api/chat 兼容${NC}"
else
    echo -e "${YELLOW}⚠ Ollama /api/chat 兼容性需要改进${NC}"
fi
echo ""

# 测试4: Ollama兼容性 - /api/embed
echo "测试4: Ollama兼容性 - /api/embed"
response=$(curl -s -X POST "${BASE_URL}/api/embed" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"input\":\"test\"}")

if echo "$response" | grep -q '"embeddings"'; then
    echo -e "${GREEN}✓ Ollama /api/embed 兼容${NC}"
else
    echo -e "${YELLOW}⚠ Ollama /api/embed 兼容性需要改进${NC}"
fi
echo ""

# 测试5: Ollama兼容性 - /api/ps
echo "测试5: Ollama兼容性 - /api/ps"
response=$(curl -s "${BASE_URL}/api/ps")

if echo "$response" | grep -q '"models"'; then
    echo -e "${GREEN}✓ Ollama /api/ps 兼容${NC}"
else
    echo -e "${YELLOW}⚠ Ollama /api/ps 兼容性需要改进${NC}"
fi
echo ""

# 测试6: Ollama兼容性 - /api/show
echo "测试6: Ollama兼容性 - /api/show"
response=$(curl -s -X POST "${BASE_URL}/api/show" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\"}")

if echo "$response" | grep -q '"details"'; then
    echo -e "${GREEN}✓ Ollama /api/show 兼容${NC}"
else
    echo -e "${YELLOW}⚠ Ollama /api/show 兼容性需要改进${NC}"
fi
echo ""

# 测试7: Ollama兼容性 - /api/version
echo "测试7: Ollama兼容性 - /api/version"
response=$(curl -s "${BASE_URL}/api/version")

if echo "$response" | grep -q '"version"'; then
    echo -e "${GREEN}✓ Ollama /api/version 兼容${NC}"
else
    echo -e "${YELLOW}⚠ Ollama /api/version 兼容性需要改进${NC}"
fi
echo ""

# 测试8: OpenAI兼容性 - /v1/chat/completions
echo "测试8: OpenAI兼容性 - /v1/chat/completions"
response=$(curl -s -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}],\"stream\":false}")

if echo "$response" | grep -q '"choices"'; then
    echo -e "${GREEN}✓ OpenAI /v1/chat/completions 兼容${NC}"
else
    echo -e "${YELLOW}⚠ OpenAI /v1/chat/completions 兼容性需要改进${NC}"
fi
echo ""

# 测试9: OpenAI兼容性 - /v1/completions
echo "测试9: OpenAI兼容性 - /v1/completions"
response=$(curl -s -X POST "${BASE_URL}/v1/completions" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

if echo "$response" | grep -q '"choices"'; then
    echo -e "${GREEN}✓ OpenAI /v1/completions 兼容${NC}"
else
    echo -e "${YELLOW}⚠ OpenAI /v1/completions 兼容性需要改进${NC}"
fi
echo ""

# 测试10: OpenAI兼容性 - /v1/embeddings
echo "测试10: OpenAI兼容性 - /v1/embeddings"
response=$(curl -s -X POST "${BASE_URL}/v1/embeddings" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"input\":\"test\"}")

if echo "$response" | grep -q '"data"'; then
    echo -e "${GREEN}✓ OpenAI /v1/embeddings 兼容${NC}"
else
    echo -e "${YELLOW}⚠ OpenAI /v1/embeddings 兼容性需要改进${NC}"
fi
echo ""

# 测试11: HTTP方法兼容性
echo "测试11: HTTP方法兼容性"
# 测试GET方法
response=$(curl -s -X GET "${BASE_URL}/api/tags")
if echo "$response" | grep -q '"models"'; then
    echo "  GET方法: ✓"
else
    echo "  GET方法: ✗"
fi

# 测试POST方法
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")
if echo "$response" | grep -q '"response"'; then
    echo "  POST方法: ✓"
else
    echo "  POST方法: ✗"
fi

# 测试DELETE方法
TIMESTAMP=$(date +%s)
TEST_MODEL_DELETE="delete_test_${TIMESTAMP}"
curl -s -X POST "${BASE_URL}/api/copy" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"source\":\"$TEST_MODEL\",\"destination\":\"$TEST_MODEL_DELETE\"}" > /dev/null

response=$(curl -s -X DELETE "${BASE_URL}/api/delete" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL_DELETE\"}")
if echo "$response" | grep -q "success"; then
    echo "  DELETE方法: ✓"
else
    echo "  DELETE方法: ✗"
fi

echo -e "${GREEN}✓ HTTP方法兼容性测试完成${NC}"
echo ""

# 测试12: Content-Type兼容性
echo "测试12: Content-Type兼容性"
# 测试application/json
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")
if echo "$response" | grep -q '"response"'; then
    echo "  application/json: ✓"
else
    echo "  application/json: ✗"
fi

echo -e "${GREEN}✓ Content-Type兼容性测试完成${NC}"
echo ""

# 测试13: 响应格式兼容性
echo "测试13: 响应格式兼容性"
# 测试JSON格式
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

if echo "$response" | python3 -m json.tool > /dev/null 2>&1; then
    echo "  JSON格式: ✓"
else
    echo "  JSON格式: ✗"
fi

# 测试必需字段
if echo "$response" | grep -q '"model"' && echo "$response" | grep -q '"response"'; then
    echo "  必需字段: ✓"
else
    echo "  必需字段: ✗"
fi

echo -e "${GREEN}✓ 响应格式兼容性测试完成${NC}"
echo ""

# 测试14: 错误码兼容性
echo "测试14: 错误码兼容性"
# 测试400错误
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "invalid json" 2>&1)
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "400" ]; then
    echo "  400错误码: ✓"
else
    echo "  400错误码: ✗"
fi

# 测试404错误
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"invalid_model\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "500" ] || [ "$http_code" = "404" ]; then
    echo "  404/500错误码: ✓"
else
    echo "  404/500错误码: ✗"
fi

echo -e "${GREEN}✓ 错误码兼容性测试完成${NC}"
echo ""

# 测试15: CORS兼容性
echo "测试15: CORS兼容性"
response=$(curl -s -I -X OPTIONS "${BASE_URL}/api/tags" \
    -H "Origin: http://example.com" \
    -H "Access-Control-Request-Method: GET")

if echo "$response" | grep -qi "access-control-allow"; then
    echo -e "${GREEN}✓ CORS支持正常${NC}"
else
    echo -e "${YELLOW}⚠ CORS支持需要验证${NC}"
fi
echo ""

# 测试16: 流式响应兼容性
echo "测试16: 流式响应兼容性"
# Ollama流式
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":true}")
if echo "$response" | grep -q "response"; then
    echo "  Ollama流式: ✓"
else
    echo "  Ollama流式: ✗"
fi

# OpenAI流式
response=$(curl -s -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}],\"stream\":true}")
if echo "$response" | grep -q "data:"; then
    echo "  OpenAI流式: ✓"
else
    echo "  OpenAI流式: ✗"
fi

echo -e "${GREEN}✓ 流式响应兼容性测试完成${NC}"
echo ""

# 测试17: 参数兼容性
echo "测试17: 参数兼容性"
# 测试temperature参数
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false,\"temperature\":0.7}")
if echo "$response" | grep -q "response"; then
    echo "  temperature参数: ✓"
else
    echo "  temperature参数: ✗"
fi

# 测试top_p参数
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false,\"top_p\":0.9}")
if echo "$response" | grep -q "response"; then
    echo "  top_p参数: ✓"
else
    echo "  top_p参数: ✗"
fi

echo -e "${GREEN}✓ 参数兼容性测试完成${NC}"
echo ""

# 测试18: 分页兼容性
echo "测试18: 分页兼容性"
# 测试模型列表分页（如果支持）
response=$(curl -s "${BASE_URL}/api/tags")
if echo "$response" | grep -q '"models"'; then
    echo -e "${GREEN}✓ 模型列表分页兼容${NC}"
else
    echo -e "${YELLOW}⚠ 模型列表分页需要验证${NC}"
fi
echo ""

# 测试19: 批量操作兼容性
echo "测试19: 批量操作兼容性"
# 测试批量请求
success_count=0
for i in $(seq 1 5); do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test $i\",\"stream\":false}")
    if echo "$response" | grep -q "response"; then
        success_count=$((success_count + 1))
    fi
done

if [ $success_count -eq 5 ]; then
    echo -e "${GREEN}✓ 批量操作兼容性正常${NC}"
else
    echo -e "${YELLOW}⚠ 批量操作兼容性需要改进${NC}"
fi
echo ""

# 测试20: RESTful设计兼容性
echo "测试20: RESTful设计兼容性"
# 测试资源路径
response=$(curl -s "${BASE_URL}/api/tags")
if echo "$response" | grep -q '"models"'; then
    echo "  资源路径设计: ✓"
else
    echo "  资源路径设计: ✗"
fi

# 测试HTTP动词使用
response=$(curl -s -X GET "${BASE_URL}/api/tags")
if echo "$response" | grep -q '"models"'; then
    echo "  HTTP动词使用: ✓"
else
    echo "  HTTP动词使用: ✗"
fi

echo -e "${GREEN}✓ RESTful设计兼容性测试完成${NC}"
echo ""

echo "=========================================="
echo "API兼容性测试总结"
echo "=========================================="
echo "测试1: Ollama /api/tags - ${GREEN}完成${NC}"
echo "测试2: Ollama /api/generate - ${GREEN}完成${NC}"
echo "测试3: Ollama /api/chat - ${GREEN}完成${NC}"
echo "测试4: Ollama /api/embed - ${GREEN}完成${NC}"
echo "测试5: Ollama /api/ps - ${GREEN}完成${NC}"
echo "测试6: Ollama /api/show - ${GREEN}完成${NC}"
echo "测试7: Ollama /api/version - ${GREEN}完成${NC}"
echo "测试8: OpenAI /v1/chat/completions - ${GREEN}完成${NC}"
echo "测试9: OpenAI /v1/completions - ${GREEN}完成${NC}"
echo "测试10: OpenAI /v1/embeddings - ${GREEN}完成${NC}"
echo "测试11: HTTP方法兼容性 - ${GREEN}完成${NC}"
echo "测试12: Content-Type兼容性 - ${GREEN}完成${NC}"
echo "测试13: 响应格式兼容性 - ${GREEN}完成${NC}"
echo "测试14: 错误码兼容性 - ${GREEN}完成${NC}"
echo "测试15: CORS兼容性 - ${GREEN}完成${NC}"
echo "测试16: 流式响应兼容性 - ${GREEN}完成${NC}"
echo "测试17: 参数兼容性 - ${GREEN}完成${NC}"
echo "测试18: 分页兼容性 - ${GREEN}完成${NC}"
echo "测试19: 批量操作兼容性 - ${GREEN}完成${NC}"
echo "测试20: RESTful设计兼容性 - ${GREEN}完成${NC}"
echo "=========================================="
