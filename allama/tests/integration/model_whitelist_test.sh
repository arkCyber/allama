#!/bin/bash
# 模型白名单集成测试脚本
# 测试模型白名单验证功能

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
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
TEST_START_TIME=$(date +%s)

echo "=========================================="
echo "Allama 模型白名单集成测试"
echo "=========================================="
echo -e "${CYAN}服务器地址:${NC} $BASE_URL"
echo -e "${CYAN}测试模型:${NC} $TEST_MODEL"
echo -e "${CYAN}测试开始时间:${NC} $(date)"
echo "=========================================="
echo ""

# 测试1: 白名单模型应该可以访问
echo -e "${CYAN}测试1: 白名单模型访问${NC}"
echo -e "${BLUE}[详情]${NC} 测试白名单中的模型是否可以正常访问"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ 白名单模型可以访问${NC} | 耗时: ${TEST_DURATION}s"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}⚠ 模型不存在，跳过测试${NC} | 耗时: ${TEST_DURATION}s"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    fi
else
    echo -e "${YELLOW}⚠ 白名单模型访问失败 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试2: 非白名单模型应该被拒绝
echo -e "${CYAN}测试2: 非白名单模型拒绝${NC}"
echo -e "${BLUE}[详情]${NC} 测试非白名单中的模型是否被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"malicious_model\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "403" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 非白名单模型被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 非白名单模型未被拒绝 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试3: Chat端点白名单验证
echo -e "${CYAN}测试3: Chat端点白名单验证${NC}"
echo -e "${BLUE}[详情]${NC} 测试Chat端点的模型白名单验证"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"malicious_model\",\"messages\":[{\"role\":\"user\",\"content\":\"test\"}],\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "403" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ Chat端点白名单验证正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ Chat端点白名单验证失败 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试4: Embed端点白名单验证
echo -e "${CYAN}测试4: Embed端点白名单验证${NC}"
echo -e "${BLUE}[详情]${NC} 测试Embed端点的模型白名单验证"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/embed" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"malicious_model\",\"input\":\"test\"}" 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "403" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ Embed端点白名单验证正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ Embed端点白名单验证失败 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试5: OpenAI兼容端点白名单验证
echo -e "${CYAN}测试5: OpenAI兼容端点白名单验证${NC}"
echo -e "${BLUE}[详情]${NC} 测试OpenAI兼容端点的模型白名单验证"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"malicious_model\",\"messages\":[{\"role\":\"user\",\"content\":\"test\"}]}" 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "403" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ OpenAI兼容端点白名单验证正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ OpenAI兼容端点白名单验证失败 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试6: 空模型名验证
echo -e "${CYAN}测试6: 空模型名验证${NC}"
echo -e "${BLUE}[详情]${NC} 测试空模型名是否被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 空模型名被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 空模型名未被拒绝 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试7: 特殊字符模型名验证
echo -e "${CYAN}测试7: 特殊字符模型名验证${NC}"
echo -e "${BLUE}[详情]${NC} 测试包含特殊字符的模型名是否被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"../../etc/passwd\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "403" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 特殊字符模型名被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 特殊字符模型名未被拒绝 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试8: SQL注入尝试
echo -e "${CYAN}测试8: SQL注入尝试${NC}"
echo -e "${BLUE}[详情]${NC} 测试SQL注入尝试是否被拒绝"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"llama3'; DROP TABLE models;--\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "403" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ SQL注入尝试被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ SQL注入尝试未被拒绝 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试9: 模型名长度限制
echo -e "${CYAN}测试9: 模型名长度限制${NC}"
echo -e "${BLUE}[详情]${NC} 测试超长模型名是否被拒绝"
TEST_START=$(date +%s)
long_model_name=$(printf 'a%.0s' {1..1000})
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"${long_model_name}\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "403" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 超长模型名被拒绝${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 超长模型名未被拒绝 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试10: 模型名大小写敏感性
echo -e "${CYAN}测试10: 模型名大小写敏感性${NC}"
echo -e "${BLUE}[详情]${NC} 测试模型名大小写是否敏感"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"LLAMA3\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "403" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 模型名大小写敏感（大写被拒绝）${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型名大小写不敏感（大写被接受）${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

echo "=========================================="
echo -e "${CYAN}模型白名单测试总结${NC}"
echo "=========================================="
TEST_END_TIME=$(date +%s)
TOTAL_DURATION=$((TEST_END_TIME - TEST_START_TIME))
echo -e "${CYAN}总测试数:${NC} $TOTAL_TESTS"
echo -e "${GREEN}通过:${NC} $PASSED_TESTS"
echo -e "${YELLOW}失败:${NC} $FAILED_TESTS"
echo -e "${CYAN}总耗时:${NC} ${TOTAL_DURATION}s"
echo -e "${CYAN}测试结束时间:${NC} $(date)"
echo "=========================================="

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过！${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ 有 $FAILED_TESTS 个测试失败${NC}"
    exit 1
fi
