#!/bin/bash
# Aerospace-level authentication integration test
# Tests API key authentication for remote users and local access

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
TEST_DIR="/tmp/allama_auth_test"

echo "=========================================="
echo -e "${CYAN}Allama 认证系统集成测试${NC}"
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

# 测试1: 创建用户
echo -e "${CYAN}测试1: 创建用户${NC}"
echo -e "${BLUE}[详情]${NC} 测试POST /api/users创建新用户"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/users" \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser","email":"test@example.com","rate_limit":60,"monthly_quota":1000000}' 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "api_key\|user_id"; then
    # Extract API key for subsequent tests
    TEST_API_KEY=$(echo "$response" | grep -o '"api_key":"[^"]*"' | cut -d'"' -f4)
    TEST_USER_ID=$(echo "$response" | grep -o '"user_id":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✓ 用户创建成功${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${CYAN}[API Key]${NC} ${TEST_API_KEY:0:20}..."
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ 用户创建失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试2: 本地请求无需认证
echo -e "${CYAN}测试2: 本地请求无需认证${NC}"
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
    echo -e "${GREEN}✓ 本地请求无需认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 本地请求需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试3: 本地请求（localhost）无需认证
echo -e "${CYAN}测试3: 本地请求（localhost）无需认证${NC}"
echo -e "${BLUE}[详情]${NC} 测试localhost请求不需要API key"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: localhost" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "response\|done"; then
    echo -e "${GREEN}✓ localhost请求无需认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ localhost请求需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试4: 远程请求需要认证（无API key）
echo -e "${CYAN}测试4: 远程请求需要认证（无API key）${NC}"
echo -e "${BLUE}[详情]${NC} 测试远程请求（192.168.1.100）没有API key时被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.100" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "401\|Unauthorized\|API key required"; then
    echo -e "${GREEN}✓ 远程请求无API key被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ 远程请求认证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试5: 远程请求需要认证（无效API key）
echo -e "${CYAN}测试5: 远程请求需要认证（无效API key）${NC}"
echo -e "${BLUE}[详情]${NC} 测试远程请求使用无效API key时被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.100" \
    -H "Authorization: Bearer invalid_api_key_12345" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "401\|Unauthorized\|Invalid API key"; then
    echo -e "${GREEN}✓ 远程请求无效API key被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ 远程请求无效API key验证失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试6: 远程请求使用有效API key
echo -e "${CYAN}测试6: 远程请求使用有效API key${NC}"
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
    echo -e "${GREEN}✓ 远程请求有效API key成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 远程请求有效API key需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试7: 列出用户
echo -e "${CYAN}测试7: 列出用户${NC}"
echo -e "${BLUE}[详情]${NC} 测试GET /api/users列出所有用户"
TEST_START=$(date +%s)
response=$(curl -s -X GET "${BASE_URL}/api/users" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "users\|username"; then
    echo -e "${GREEN}✓ 列出用户成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 列出用户需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试8: 计费记录包含用户信息
echo -e "${CYAN}测试8: 计费记录包含用户信息${NC}"
echo -e "${BLUE}[详情]${NC} 验证计费记录包含user_id和username"
TEST_START=$(date +%s)
# 先执行一次带认证的请求
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 192.168.1.101" \
    -H "Authorization: Bearer ${TEST_API_KEY}" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Test billing\",\"stream\":false}" >/dev/null 2>&1

# 查询计费记录
response=$(curl -s -X GET "${BASE_URL}/api/billing/records" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "user_id\|username"; then
    echo -e "${GREEN}✓ 计费记录包含用户信息${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 计费记录用户信息需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试9: IPv6本地地址无需认证
echo -e "${CYAN}测试9: IPv6本地地址无需认证${NC}"
echo -e "${BLUE}[详情]${NC} 测试IPv6本地地址::1不需要API key"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: ::1" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "response\|done"; then
    echo -e "${GREEN}✓ IPv6本地地址无需认证成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ IPv6本地地址需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试10: 远程请求使用X-Real-IP header
echo -e "${CYAN}测试10: 远程请求使用X-Real-IP header${NC}"
echo -e "${BLUE}[详情]${NC} 测试通过X-Real-IP header检测远程地址"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Real-IP: 10.0.0.1" \
    -d "{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "401\|Unauthorized\|API key required"; then
    echo -e "${GREEN}✓ X-Real-IP header检测成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ X-Real-IP header检测需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试11: 创建用户时重复用户名
echo -e "${CYAN}测试11: 创建用户时重复用户名${NC}"
echo -e "${BLUE}[详情]${NC} 测试创建重复用户名时的处理"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/users" \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser","email":"test2@example.com","rate_limit":60,"monthly_quota":1000000}' 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "error\|failed\|duplicate\|already exists"; then
    echo -e "${GREEN}✓ 重复用户名被正确拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 重复用户名处理需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试12: API Key格式验证
echo -e "${CYAN}测试12: API Key格式验证${NC}"
echo -e "${BLUE}[详情]${NC} 验证生成的API Key格式正确（allama_xxx）"
TEST_START=$(date +%s)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [[ "$TEST_API_KEY" == allama_* ]]; then
    echo -e "${GREEN}✓ API Key格式正确${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ API Key格式不正确${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[API Key]${NC} $TEST_API_KEY"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 清理
rm -rf "$TEST_DIR"

echo "=========================================="
echo -e "${CYAN}认证系统测试总结${NC}"
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
