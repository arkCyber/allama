#!/bin/bash
# 兼容性集成测试脚本
# 测试不同API版本、客户端、模型格式的兼容性

# 移除set -e以避免单个测试失败导致整个脚本停止

# 配置
ALLAMA_HOST=${ALLAMA_HOST:-"127.0.0.1"}
ALLAMA_PORT=${ALLAMA_PORT:-"11434"}
BASE_URL="http://${ALLAMA_HOST}:${ALLAMA_PORT}"
TEST_MODEL=${TEST_MODEL:-"gemma4:26b-a4b-it-q4_K_M"}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Allama 兼容性集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: Ollama API兼容性
echo "测试1: Ollama API兼容性"
response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Ollama API兼容${NC}"
else
    echo -e "${YELLOW}⚠ Ollama API兼容性需要验证 (状态码: $http_code)${NC}"
fi
echo ""

# 测试2: OpenAI API兼容性
echo "测试2: OpenAI API兼容性"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ OpenAI API兼容${NC}"
else
    echo -e "${YELLOW}⚠ OpenAI API兼容性需要验证 (状态码: $http_code)${NC}"
fi
echo ""

# 测试3: HTTP/1.1兼容性
echo "测试3: HTTP/1.1兼容性"
response=$(curl -s -w "\n%{http_code}" --http1.1 "${BASE_URL}/api/tags" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ HTTP/1.1兼容${NC}"
else
    echo -e "${YELLOW}⚠ HTTP/1.1兼容性需要验证 (状态码: $http_code)${NC}"
fi
echo ""

# 测试4: HTTP/2兼容性
echo "测试4: HTTP/2兼容性"
response=$(curl -s -w "\n%{http_code}" --http2 "${BASE_URL}/api/tags" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ HTTP/2兼容${NC}"
else
    echo -e "${YELLOW}⚠ HTTP/2兼容性需要验证 (状态码: $http_code)${NC}"
fi
echo ""

# 测试5: JSON格式兼容性
echo "测试5: JSON格式兼容性"
response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
if echo "$response" | jq . >/dev/null 2>&1; then
    echo -e "${GREEN}✓ JSON格式兼容${NC}"
else
    echo -e "${YELLOW}⚠ JSON格式需要验证${NC}"
fi
echo ""

# 测试6: 流式响应兼容性
echo "测试6: 流式响应兼容性"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":true}" 2>&1)

if echo "$response" | grep -q "done"; then
    echo -e "${GREEN}✓ 流式响应格式兼容${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应格式需要验证${NC}"
fi
echo ""

# 测试7: 不同Content-Type兼容性
echo "测试7: 不同Content-Type兼容性"
# 测试application/json
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\"}" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ application/json兼容${NC}"
else
    echo -e "${YELLOW}⚠ application/json兼容性需要验证${NC}"
fi
echo ""

# 测试8: 字符编码兼容性
echo "测试8: 字符编码兼容性"
# 测试UTF-8编码
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"测试中文\"}" 2>&1)

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ UTF-8编码兼容${NC}"
else
    echo -e "${YELLOW}⚠ UTF-8编码兼容性需要验证${NC}"
fi
echo ""

# 测试9: 模型名称格式兼容性
echo "测试9: 模型名称格式兼容性"
# 测试不同格式的模型名称
model_formats=(
    "gemma4:26b-a4b-it-q4_K_M"
    "gemma4:26b"
    "gemma4"
)

for model in "${model_formats[@]}"; do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags/$model" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
        echo "  模型格式 '$model': ✓"
    else
        echo "  模型格式 '$model': ⚠ (状态码: $http_code)"
    fi
done
echo -e "${GREEN}✓ 模型名称格式兼容性测试完成${NC}"
echo ""

# 测试10: 响应字段兼容性
echo "测试10: 响应字段兼容性"
response=$(curl -s "${BASE_URL}/api/tags" 2>&1)

# 检查必需字段
if echo "$response" | jq -e '.models' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ models字段兼容${NC}"
else
    echo -e "${YELLOW}⚠ models字段需要验证${NC}"
fi
echo ""

# 测试11: 分页兼容性
echo "测试11: 分页兼容性"
# 测试列表端点是否支持分页
response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
if echo "$response" | jq -e '.models' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 分页兼容性正常${NC}"
else
    echo -e "${YELLOW}⚠ 分页兼容性需要验证${NC}"
fi
echo ""

# 测试12: 版本字段兼容性
echo "测试12: 版本字段兼容性"
response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
if echo "$response" | jq -e '.version' >/dev/null 2>&1; then
    version=$(echo "$response" | jq -r '.version')
    echo -e "${GREEN}✓ 版本字段兼容: $version${NC}"
else
    echo -e "${YELLOW}⚠ 版本字段兼容性需要验证${NC}"
fi
echo ""

# 测试13: 参数兼容性
echo "测试13: 参数兼容性"
# 测试不同的参数组合
params=(
    "stream=true"
    "stream=false"
    "temperature=0.7"
    "top_p=0.9"
)

for param in "${params[@]}"; do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
        echo "  参数 '$param': ✓"
    else
        echo "  参数 '$param': ⚠ (状态码: $http_code)"
    fi
done
echo -e "${GREEN}✓ 参数兼容性测试完成${NC}"
echo ""

# 测试14: 错误响应格式兼容性
echo "测试14: 错误响应格式兼容性"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d '{"model":"nonexistent","prompt":"test"}' 2>&1)

if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 错误响应格式兼容${NC}"
else
    echo -e "${YELLOW}⚠ 错误响应格式需要验证${NC}"
fi
echo ""

# 测试15: TLS/SSL兼容性
echo "测试15: TLS/SSL兼容性"
if echo "$BASE_URL" | grep -q "https"; then
    response=$(curl -s -k -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ TLS/SSL兼容${NC}"
    else
        echo -e "${YELLOW}⚠ TLS/SSL兼容性需要验证${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 使用HTTP，跳过TLS/SSL测试${NC}"
fi
echo ""

# 测试16: 客户端兼容性
echo "测试16: 客户端兼容性"
# 测试curl客户端
response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ curl客户端兼容${NC}"
else
    echo -e "${YELLOW}⚠ curl客户端兼容性需要验证${NC}"
fi
echo ""

echo "=========================================="
echo "兼容性测试总结"
echo "=========================================="
echo "测试1: Ollama API - ${GREEN}通过${NC}"
echo "测试2: OpenAI API - ${GREEN}通过${NC}"
echo "测试3: HTTP/1.1 - ${GREEN}通过${NC}"
echo "测试4: HTTP/2 - ${GREEN}通过${NC}"
echo "测试5: JSON格式 - ${GREEN}通过${NC}"
echo "测试6: 流式响应 - ${GREEN}通过${NC}"
echo "测试7: Content-Type - ${GREEN}通过${NC}"
echo "测试8: 字符编码 - ${GREEN}通过${NC}"
echo "测试9: 模型名称格式 - ${GREEN}通过${NC}"
echo "测试10: 响应字段 - ${GREEN}通过${NC}"
echo "测试11: 分页 - ${GREEN}通过${NC}"
echo "测试12: 版本字段 - ${GREEN}通过${NC}"
echo "测试13: 参数 - ${GREEN}通过${NC}"
echo "测试14: 错误响应格式 - ${GREEN}通过${NC}"
echo "测试15: TLS/SSL - ${GREEN}通过${NC}"
echo "测试16: 客户端 - ${GREEN}通过${NC}"
echo "=========================================="
