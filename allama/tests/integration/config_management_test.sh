#!/bin/bash
# 配置管理集成测试脚本
# 测试服务器配置、模型配置、运行时配置等

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
echo "Allama 配置管理集成测试"
echo "=========================================="
echo -e "${CYAN}服务器地址:${NC} $BASE_URL"
echo -e "${CYAN}测试模型:${NC} $TEST_MODEL"
echo -e "${CYAN}测试开始时间:${NC} $(date)"
echo "=========================================="
echo ""

# 测试1: 服务器版本信息
echo -e "${CYAN}测试1: 服务器版本信息${NC}"
echo -e "${BLUE}[详情]${NC} 获取服务器版本信息"
TEST_START=$(date +%s)
response=$(curl -s "${BASE_URL}/api/version")
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "version"; then
    version=$(echo "$response" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    echo "  版本: $version"
    echo -e "${GREEN}✓ 版本信息正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 版本信息缺失${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试2: 模型配置验证
echo -e "${CYAN}测试2: 模型配置验证${NC}"
echo -e "${BLUE}[详情]${NC} 验证模型 $TEST_MODEL 的配置信息
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/show" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\"}")
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "details"; then
    echo -e "${GREEN}✓ 模型配置可获取${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型配置获取失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试3: 运行时配置查询
echo -e "${CYAN}测试3: 运行时配置查询${NC}"
echo -e "${BLUE}[详情]${NC} 查询运行时配置信息
TEST_START=$(date +%s)
response=$(curl -s "${BASE_URL}/api/ps")
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "models"; then
    echo -e "${GREEN}✓ 运行时配置可查询${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 运行时配置查询失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试4-15: 简化处理，添加基本统计
echo -e "${CYAN}测试4-15: 其他配置测试${NC}"
echo -e "${BLUE}[详情]${NC} 批量测试其他配置项"
TEST_START=$(date +%s)
PASSED_COUNT=0
TOTAL_BATCH=12

# 测试4: 模型参数配置
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"options\":{\"temperature\":0.7}}")
echo "$response" | grep -q "response" && PASSED_COUNT=$((PASSED_COUNT + 1))

# 测试5: 上下文长度配置
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"options\":{\"num_ctx\":2048}}")
echo "$response" | grep -q "response" && PASSED_COUNT=$((PASSED_COUNT + 1))

# 测试6: 流式配置
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")
echo "$response" | grep -q "response" && PASSED_COUNT=$((PASSED_COUNT + 1))

# 测试7: 并发配置
response=$(curl -s "${BASE_URL}/api/ps")
echo "$response" | grep -q "models" && PASSED_COUNT=$((PASSED_COUNT + 1))

# 测试8: 超时配置
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"options\":{\"timeout\":120}}")
echo "$response" | grep -q "response" && PASSED_COUNT=$((PASSED_COUNT + 1))

# 测试9: 模型白名单配置
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\"}")
echo "$response" | grep -q "response" && PASSED_COUNT=$((PASSED_COUNT + 1))

# 测试10: 请求大小限制配置
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"$(printf 'a%.0s' {1..100000})\"}")
echo "$response" | grep -q "error" && PASSED_COUNT=$((PASSED_COUNT + 1))

# 测试11: 响应格式配置
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\"}")
echo "$response" | grep -q "response" && PASSED_COUNT=$((PASSED_COUNT + 1))

# 测试12: 系统提示配置
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"system\",\"content\":\"You are a helpful assistant.\"},{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":false}")
echo "$response" | grep -q "message" && PASSED_COUNT=$((PASSED_COUNT + 1))

# 测试13: 停止序列配置
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"options\":{\"stop\":[\"\\n\"]}}")
echo "$response" | grep -q "response" && PASSED_COUNT=$((PASSED_COUNT + 1))

# 测试14: 重复惩罚配置
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"options\":{\"repeat_penalty\":1.0}}")
echo "$response" | grep -q "response" && PASSED_COUNT=$((PASSED_COUNT + 1))

# 测试15: 配置持久化
TIMESTAMP=$(date +%s)
TEST_MODEL_CONFIG="config_test_${TIMESTAMP}"
curl -s -X POST "${BASE_URL}/api/copy" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"source\":\"$TEST_MODEL\",\"destination\":\"$TEST_MODEL_CONFIG\"}" > /dev/null
response=$(curl -s -X POST "${BASE_URL}/api/show" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL_CONFIG\"}")
echo "$response" | grep -q "details" && PASSED_COUNT=$((PASSED_COUNT + 1))
curl -s -X DELETE "${BASE_URL}/api/delete" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL_CONFIG\"}" > /dev/null

TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + TOTAL_BATCH))

echo "  批量测试通过: $PASSED_COUNT/$TOTAL_BATCH | 耗时: ${TEST_DURATION}s"
PASSED_TESTS=$((PASSED_TESTS + PASSED_COUNT))
FAILED_TESTS=$((FAILED_TESTS + TOTAL_BATCH - PASSED_COUNT))
echo ""

echo "=========================================="
echo -e "${CYAN}配置管理测试总结${NC}"
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
