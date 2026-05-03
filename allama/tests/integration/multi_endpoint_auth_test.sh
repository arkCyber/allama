#!/bin/bash
# Aerospace-level multi-endpoint authentication integration test
# Tests authentication across all API endpoints

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${ALLAMA_BASE_URL:-http://127.0.0.1:11435}"
TEST_MODEL="${ALLAMA_TEST_MODEL:-llama3}"
TEST_DIR="/tmp/allama_multi_auth_test"

echo "=========================================="
echo -e "${CYAN}Allama 多端点认证系统集成测试${NC}"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "测试开始时间: $(date)"
echo "=========================================="
echo ""

# Initialize counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Create test directory
mkdir -p "$TEST_DIR"

# 测试1: 创建用户并获取API Key
echo -e "${CYAN}测试1: 创建用户并获取API Key${NC}"
echo -e "${BLUE}[详情]${NC} 测试POST /api/users创建新用户"
TEST_START=$(date +%s)
# 使用随机用户名避免冲突
RANDOM_SUFFIX=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
response=$(curl -s -X POST "${BASE_URL}/api/users" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"multitest_${RANDOM_SUFFIX}\",\"email\":\"multi_${RANDOM_SUFFIX}@example.com\",\"rate_limit\":60,\"monthly_quota\":1000000}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "api_key"; then
    TEST_API_KEY=$(echo "$response" | grep -o '"api_key":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✓ 用户创建成功${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${CYAN}[API Key]${NC} ${TEST_API_KEY:0:20}..."
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ 用户创建失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TEST_API_KEY=""
fi
echo ""

# 测试2: /api/generate - 本地请求无需认证
echo -e "${CYAN}测试2: /api/generate - 本地请求无需认证${NC}"
echo -e "${BLUE}[详情]${NC} 测试本地请求（127.0.0.1）不需要API key"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "response\|done"; then
    echo -e "${GREEN}✓ /api/generate 本地请求无需认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /api/generate 本地请求失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试3: /api/generate - 远程请求需要认证（无API key）
echo -e "${CYAN}测试3: /api/generate - 远程请求需要认证（无API key）${NC}"
echo -e "${BLUE}[详情]${NC} 测试远程请求没有API key时被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.100" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ /api/generate 远程请求无API key被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /api/generate 远程请求认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[HTTP Code]${NC} $http_code"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试4: /api/generate - 远程请求使用有效API key
echo -e "${CYAN}测试4: /api/generate - 远程请求使用有效API key${NC}"
echo -e "${BLUE}[详情]${NC} 测试远程请求使用有效API key时成功"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.100" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "response\|done"; then
    echo -e "${GREEN}✓ /api/generate 远程请求有效API key成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /api/generate 远程请求有效API key失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试5: /api/chat - 本地请求无需认证
echo -e "${CYAN}测试5: /api/chat - 本地请求无需认证${NC}"
echo -e "${BLUE}[详情]${NC} 测试chat本地请求不需要API key"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"${TEST_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "message\|done"; then
    echo -e "${GREEN}✓ /api/chat 本地请求无需认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /api/chat 本地请求失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试6: /api/chat - 远程请求需要认证
echo -e "${CYAN}测试6: /api/chat - 远程请求需要认证${NC}"
echo -e "${BLUE}[详情]${NC} 测试chat远程请求没有API key时被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.101" \
    -d "{\"model\":\"${TEST_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ /api/chat 远程请求无API key被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /api/chat 远程请求认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[HTTP Code]${NC} $http_code"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试7: /api/chat - 远程请求使用有效API key
echo -e "${CYAN}测试7: /api/chat - 远程请求使用有效API key${NC}"
echo -e "${BLUE}[详情]${NC} 测试chat远程请求使用有效API key时成功"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.101" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -d "{\"model\":\"${TEST_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "message\|done"; then
    echo -e "${GREEN}✓ /api/chat 远程请求有效API key成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /api/chat 远程请求有效API key失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试8: /api/embed - 本地请求无需认证
echo -e "${CYAN}测试8: /api/embed - 本地请求无需认证${NC}"
echo -e "${BLUE}[详情]${NC} 测试embed本地请求不需要API key"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/embed" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"${TEST_MODEL}\",\"input\":\"Hello world\"}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "embeddings\|embedding"; then
    echo -e "${GREEN}✓ /api/embed 本地请求无需认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /api/embed 本地请求失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试9: /api/embed - 远程请求需要认证
echo -e "${CYAN}测试9: /api/embed - 远程请求需要认证${NC}"
echo -e "${BLUE}[详情]${NC} 测试embed远程请求没有API key时被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/embed" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.102" \
    -d "{\"model\":\"${TEST_MODEL}\",\"input\":\"Hello world\"}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ /api/embed 远程请求无API key被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /api/embed 远程请求认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[HTTP Code]${NC} $http_code"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试10: /api/embed - 远程请求使用有效API key
echo -e "${CYAN}测试10: /api/embed - 远程请求使用有效API key${NC}"
echo -e "${BLUE}[详情]${NC} 测试embed远程请求使用有效API key时成功"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/embed" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.102" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -d "{\"model\":\"${TEST_MODEL}\",\"input\":\"Hello world\"}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "embeddings\|embedding"; then
    echo -e "${GREEN}✓ /api/embed 远程请求有效API key成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /api/embed 远程请求有效API key失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试11: /v1/chat/completions - 本地请求无需认证
echo -e "${CYAN}测试11: /v1/chat/completions - 本地请求无需认证${NC}"
echo -e "${BLUE}[详情]${NC} 测试OpenAI chat completions本地请求不需要API key"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"${TEST_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "choices\|id"; then
    echo -e "${GREEN}✓ /v1/chat/completions 本地请求无需认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /v1/chat/completions 本地请求失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试12: /v1/chat/completions - 远程请求需要认证
echo -e "${CYAN}测试12: /v1/chat/completions - 远程请求需要认证${NC}"
echo -e "${BLUE}[详情]${NC} 测试OpenAI chat completions远程请求没有API key时被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.103" \
    -d "{\"model\":\"${TEST_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ /v1/chat/completions 远程请求无API key被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /v1/chat/completions 远程请求认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[HTTP Code]${NC} $http_code"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试13: /v1/chat/completions - 远程请求使用有效API key
echo -e "${CYAN}测试13: /v1/chat/completions - 远程请求使用有效API key${NC}"
echo -e "${BLUE}[详情]${NC} 测试OpenAI chat completions远程请求使用有效API key时成功"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.103" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -d "{\"model\":\"${TEST_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "choices\|id"; then
    echo -e "${GREEN}✓ /v1/chat/completions 远程请求有效API key成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /v1/chat/completions 远程请求有效API key失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试14: /v1/completions - 远程请求需要认证
echo -e "${CYAN}测试14: /v1/completions - 远程请求需要认证${NC}"
echo -e "${BLUE}[详情]${NC} 测试OpenAI completions远程请求没有API key时被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/completions" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.104" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\"}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ /v1/completions 远程请求无API key被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /v1/completions 远程请求认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[HTTP Code]${NC} $http_code"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试15: /v1/embeddings - 远程请求需要认证
echo -e "${CYAN}测试15: /v1/embeddings - 远程请求需要认证${NC}"
echo -e "${BLUE}[详情]${NC} 测试OpenAI embeddings远程请求没有API key时被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/embeddings" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.105" \
    -d "{\"model\":\"${TEST_MODEL}\",\"input\":\"Hello world\"}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ /v1/embeddings 远程请求无API key被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ /v1/embeddings 远程请求认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[HTTP Code]${NC} $http_code"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 清理
rm -rf "$TEST_DIR"

echo "=========================================="
echo -e "${CYAN}多端点认证系统测试总结${NC}"
echo "=========================================="
echo -e "${CYAN}总测试数:${NC} $TOTAL_TESTS"
echo -e "${GREEN}通过:${NC} $PASSED_TESTS"
echo -e "${RED}失败:${NC} $FAILED_TESTS"
echo "=========================================="

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过！${NC}"
    exit 0
else
    echo -e "${RED}✗ 有 $FAILED_TESTS 个测试失败${NC}"
    exit 1
fi
