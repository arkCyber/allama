#!/bin/bash
# API端点集成测试脚本
# 测试所有Allama API端点的功能

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

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 测试函数
test_api() {
    local test_name=$1
    local endpoint=$2
    local method=$3
    local data=$4
    local expected_status=$5
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo "测试 $TOTAL_TESTS: $test_name"
    echo "  端点: $endpoint"
    echo "  方法: $method"
    echo -n "  执行中... "
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" --max-time 30 "${BASE_URL}${endpoint}" 2>&1)
    elif [ "$method" = "POST" ]; then
        response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}${endpoint}" \
            -H "Content-Type: application/json" \
            -H "X-Forwarded-For: 127.0.0.1" \
            -d "$data" \
            --max-time 60 2>&1)
    elif [ "$method" = "DELETE" ]; then
        response=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}${endpoint}" \
            -H "X-Forwarded-For: 127.0.0.1" \
            --max-time 30 2>&1)
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1 2>/dev/null || echo "$response" | head -n $(( $(echo "$response" | wc -l) - 1 )) 2>/dev/null || echo "")
    
    if [ "$http_code" = "$expected_status" ]; then
        echo -e "${GREEN}通过${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo "  状态码: $http_code"
        echo "  响应: $body" | head -c 200
        echo ""
    else
        echo -e "${RED}失败${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "  期望状态码: $expected_status, 实际: $http_code"
        echo "  响应: $body"
    fi
    echo ""
}

echo "=========================================="
echo "Allama API端点集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 1. 测试 /api/tags - 列出可用模型
test_api "列出可用模型" "/api/tags" "GET" "" "200"

# 2. 测试 /api/generate - 生成文本
test_api "生成文本" "/api/generate" "POST" \
    "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Hello\",\"stream\":false}" \
    "200"

# 3. 测试 /api/chat - 聊天完成
test_api "聊天完成" "/api/chat" "POST" \
    "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":false}" \
    "200"

# 4. 测试 /api/embed - 嵌入生成
test_api "嵌入生成" "/api/embed" "POST" \
    "{\"model\":\"$TEST_MODEL\",\"input\":\"Hello world\"}" \
    "200"

# 5. 测试 /api/ps - 列出运行中的模型
test_api "列出运行中的模型" "/api/ps" "GET" "" "200"

# 6. 测试 /api/show - 显示模型详情
test_api "显示模型详情" "/api/show" "POST" \
    "{\"model\":\"$TEST_MODEL\"}" \
    "200"

# 7. 测试 /api/version - 版本信息
test_api "版本信息" "/api/version" "GET" "" "200"

# 8. 测试 OpenAI 兼容端点 - chat completions
test_api "OpenAI chat completions" "/v1/chat/completions" "POST" \
    "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}" \
    "200"

# 9. 测试 OpenAI 兼容端点 - completions
test_api "OpenAI completions" "/v1/completions" "POST" \
    "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Hello\"}" \
    "200"

# 10. 测试 OpenAI 兼容端点 - embeddings
test_api "OpenAI embeddings" "/v1/embeddings" "POST" \
    "{\"model\":\"$TEST_MODEL\",\"input\":\"Hello world\"}" \
    "200"

# 11. 测试无效端点 - 应返回404
test_api "无效端点404" "/api/invalid" "GET" "" "404"

# 12. 测试无效JSON - 应返回400
test_api "无效JSON400" "/api/generate" "POST" \
    "invalid json" \
    "400"

echo ""
echo "=========================================="
echo "测试总结"
echo "=========================================="
echo "总测试数: $TOTAL_TESTS"
echo -e "通过: ${GREEN}$PASSED_TESTS${NC}"
echo -e "失败: ${RED}$FAILED_TESTS${NC}"
echo "=========================================="

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}所有测试通过！${NC}"
    exit 0
else
    echo -e "${RED}部分测试失败${NC}"
    exit 1
fi
