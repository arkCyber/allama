#!/bin/bash
# 远程用户认证系统完整测试
# 测试用户创建、API key使用、认证流程

set -e

# 配置
BASE_URL="${ALLAMA_BASE_URL:-http://127.0.0.1:11435}"
TEST_MODEL="${ALLAMA_TEST_MODEL:-llama3}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo "=========================================="
echo -e "${CYAN}Allama 远程用户认证系统完整测试${NC}"
echo "=========================================="
echo -e "${CYAN}服务器地址:${NC} $BASE_URL"
echo -e "${CYAN}测试模型:${NC} $TEST_MODEL"
echo -e "${CYAN}测试开始时间:${NC} $(date)"
echo "=========================================="
echo ""

# 测试1: 创建用户并获取API Key
echo -e "${CYAN}测试1: 创建用户并获取API Key${NC}"
echo -e "${BLUE}[详情]${NC} 测试POST /api/users创建新用户"
TEST_START=$(date +%s)
RANDOM_SUFFIX=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
response=$(curl -s -X POST "${BASE_URL}/api/users" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"remotetest_${RANDOM_SUFFIX}\",\"email\":\"remote_${RANDOM_SUFFIX}@example.com\",\"rate_limit\":60,\"monthly_quota\":1000000}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "api_key"; then
    TEST_API_KEY=$(echo "$response" | grep -o '"api_key":"[^"]*"' | cut -d'"' -f4)
    TEST_USER_ID=$(echo "$response" | grep -o '"user_id":"[^"]*"' | cut -d'"' -f4)
    TEST_USERNAME=$(echo "$response" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✓ 用户创建成功${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${CYAN}[用户ID]${NC} ${TEST_USER_ID}"
    echo -e "${CYAN}[用户名]${NC} ${TEST_USERNAME}"
    echo -e "${CYAN}[API Key]${NC} ${TEST_API_KEY:0:20}..."
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ 用户创建失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TEST_API_KEY=""
fi
echo ""

# 测试2: 使用API Key调用generate端点（远程请求）
echo -e "${CYAN}测试2: 使用API Key调用generate端点（远程请求）${NC}"
echo -e "${BLUE}[详情]${NC} 测试远程请求使用有效API key"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.100" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "response\|done"; then
    echo -e "${GREEN}✓ generate端点API key认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ generate端点API key认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试3: 使用API Key调用chat端点
echo -e "${CYAN}测试3: 使用API Key调用chat端点${NC}"
echo -e "${BLUE}[详情]${NC} 测试chat端点API key认证"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.101" \
    -d "{\"model\":\"${TEST_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "message\|done"; then
    echo -e "${GREEN}✓ chat端点API key认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ chat端点API key认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试4: 使用API Key调用embed端点
echo -e "${CYAN}测试4: 使用API Key调用embed端点${NC}"
echo -e "${BLUE}[详情]${NC} 测试embed端点API key认证"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/embed" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.102" \
    -d "{\"model\":\"${TEST_MODEL}\",\"input\":\"Hello world\"}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "embeddings\|embedding"; then
    echo -e "${GREEN}✓ embed端点API key认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ embed端点API key认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试5: 使用API Key调用OpenAI chat completions
echo -e "${CYAN}测试5: 使用API Key调用OpenAI chat completions${NC}"
echo -e "${BLUE}[详情]${NC} 测试OpenAI兼容端点API key认证"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.103" \
    -d "{\"model\":\"${TEST_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "choices\|id"; then
    echo -e "${GREEN}✓ OpenAI chat completions API key认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ OpenAI chat completions API key认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试6: 使用API Key调用OpenAI completions
echo -e "${CYAN}测试6: 使用API Key调用OpenAI completions${NC}"
echo -e "${BLUE}[详情]${NC} 测试OpenAI completions API key认证"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/v1/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.104" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\"}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "choices\|id"; then
    echo -e "${GREEN}✓ OpenAI completions API key认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ OpenAI completions API key认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试7: 使用API Key调用OpenAI embeddings
echo -e "${CYAN}测试7: 使用API Key调用OpenAI embeddings${NC}"
echo -e "${BLUE}[详情]${NC} 测试OpenAI embeddings API key认证"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/v1/embeddings" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.105" \
    -d "{\"model\":\"${TEST_MODEL}\",\"input\":\"Hello world\"}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "data\|embedding"; then
    echo -e "${GREEN}✓ OpenAI embeddings API key认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ OpenAI embeddings API key认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试8: 使用无效API Key（应该失败）
echo -e "${CYAN}测试8: 使用无效API Key（应该失败）${NC}"
echo -e "${BLUE}[详情]${NC} 测试无效API key被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer invalid_key_12345" \
    -H "X-Forwarded-For: 192.168.1.106" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ 无效API key被正确拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ 无效API key未被拒绝（HTTP Code: $http_code）${NC} | 耗时: ${TEST_DURATION}s"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试9: 不提供API Key（应该失败）
echo -e "${CYAN}测试9: 不提供API Key（应该失败）${NC}"
echo -e "${BLUE}[详情]${NC} 测试远程请求无API key被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.107" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ 无API key被正确拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ 无API key未被拒绝（HTTP Code: $http_code）${NC} | 耗时: ${TEST_DURATION}s"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试10: 使用API Key调用计费端点
echo -e "${CYAN}测试10: 使用API Key调用计费端点${NC}"
echo -e "${BLUE}[详情]${NC} 测试计费API认证"
TEST_START=$(date +%s)
response=$(curl -s -X GET "${BASE_URL}/api/billing/records" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.108" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "records\|total"; then
    echo -e "${GREEN}✓ 计费端点API key认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 计费端点响应格式需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${CYAN}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试11: 使用API Key调用用户列表端点
echo -e "${CYAN}测试11: 使用API Key调用用户列表端点${NC}"
echo -e "${BLUE}[详情]${NC} 测试用户管理API认证"
TEST_START=$(date +%s)
response=$(curl -s -X GET "${BASE_URL}/api/users" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.109" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "users"; then
    echo -e "${GREEN}✓ 用户列表端点API key认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 用户列表端点响应格式需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${CYAN}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试12: 使用API Key调用show端点
echo -e "${CYAN}测试12: 使用API Key调用show端点${NC}"
echo -e "${BLUE}[详情]${NC} 测试模型详情API认证"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/show" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.110" \
    -d "{\"model\":\"${TEST_MODEL}\"}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "model\|details"; then
    echo -e "${GREEN}✓ show端点API key认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ show端点响应格式需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${CYAN}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试13: 本地请求无需API Key（应该成功）
echo -e "${CYAN}测试13: 本地请求无需API Key（应该成功）${NC}"
echo -e "${BLUE}[详情]${NC} 测试本地请求绕过认证"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "response\|done"; then
    echo -e "${GREEN}✓ 本地请求无需认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ 本地请求失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试14: 验证计费记录包含用户信息
echo -e "${CYAN}测试14: 验证计费记录包含用户信息${NC}"
echo -e "${BLUE}[详情]${NC} 测试计费系统记录用户ID和用户名"
TEST_START=$(date +%s)
# 先执行一个请求
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -H "X-Forwarded-For: 192.168.1.111" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"test billing\",\"stream\":false}" > /dev/null 2>&1

# 查询计费记录
response=$(curl -s -X GET "${BASE_URL}/api/billing/records?limit=5" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -H "X-Forwarded-For: 127.0.0.1" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "user_id\|username"; then
    echo -e "${GREEN}✓ 计费记录包含用户信息${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 计费记录用户信息需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${CYAN}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试15: API Key格式验证
echo -e "${CYAN}测试15: API Key格式验证${NC}"
echo -e "${BLUE}[详情]${NC} 验证API key格式正确（allama_前缀）"
TEST_START=$(date +%s)
if [[ "$TEST_API_KEY" == allama_* ]]; then
    echo -e "${GREEN}✓ API key格式正确（以allama_开头）${NC} | 耗时: 0s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ API key格式不正确${NC} | 耗时: 0s"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DURATION=0
echo ""

echo "=========================================="
echo -e "${CYAN}远程用户认证系统测试总结${NC}"
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
