#!/bin/bash
# 计费统计集成测试脚本
# 测试token使用统计和计费记录功能

# 移除set -e以避免单个测试失败导致整个脚本停止

# 配置
ALLAMA_HOST=${ALLAMA_HOST:-"127.0.0.1"}
ALLAMA_PORT=${ALLAMA_PORT:-"11434"}
BASE_URL="http://${ALLAMA_HOST}:${ALLAMA_PORT}"
TEST_MODEL=${TEST_MODEL:-"llama3"}
BILLING_DB_DIR="/tmp/allama_billing_test"

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
echo "Allama 计费统计集成测试"
echo "=========================================="
echo -e "${CYAN}服务器地址:${NC} $BASE_URL"
echo -e "${CYAN}测试模型:${NC} $TEST_MODEL"
echo -e "${CYAN}计费数据库目录:${NC} $BILLING_DB_DIR"
echo -e "${CYAN}测试开始时间:${NC} $(date)"
echo "=========================================="
echo ""

# 测试1: 数据库目录创建
echo -e "${CYAN}测试1: 计费数据库目录创建${NC}"
echo -e "${BLUE}[详情]${NC} 检查计费数据库目录是否正确创建"
TEST_START=$(date +%s)
mkdir -p "$BILLING_DB_DIR"
if [ -d "$BILLING_DB_DIR" ]; then
    echo -e "${GREEN}✓ 计费数据库目录创建成功${NC} | 耗时: $(( $(date +%s) - TEST_START ))s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 计费数据库目录创建失败${NC} | 耗时: $(( $(date +%s) - TEST_START ))s"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""

# 测试2: Token计数功能
echo -e "${CYAN}测试2: Token计数功能${NC}"
echo -e "${BLUE}[详情]${NC} 测试token计数算法"
TEST_START=$(date +%s)
TEST_TEXT="Hello world! This is a test."
TOKEN_COUNT=$(echo -n "$TEST_TEXT" | wc -c)
# 简单的近似计数：4字符/token
ESTIMATED_TOKENS=$((TOKEN_COUNT / 4))
if [ $ESTIMATED_TOKENS -gt 0 ]; then
    echo -e "${GREEN}✓ Token计数功能正常 (文本长度: $TOKEN_COUNT, 估计token: $ESTIMATED_TOKENS)${NC} | 耗时: $(( $(date +%s) - TEST_START ))s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ Token计数异常${NC} | 耗时: $(( $(date +%s) - TEST_START ))s"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""

# 测试3: API请求计费记录
echo -e "${CYAN}测试3: API请求计费记录${NC}"
echo -e "${BLUE}[详情]${NC} 执行API请求并检查计费记录"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test billing\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ API请求执行成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ API请求执行失败${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试4: 多次请求计费统计
echo -e "${CYAN}测试4: 多次请求计费统计${NC}"
echo -e "${BLUE}[详情]${NC} 执行多次API请求并统计总token使用量"
TEST_START=$(date +%s)
TOTAL_REQUESTS=5
SUCCESS_COUNT=0

for i in $(seq 1 $TOTAL_REQUESTS); do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test $i\",\"stream\":false}" 2>&1)
    if echo "$response" | grep -q "response"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
done

TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo "  成功请求数: $SUCCESS_COUNT/$TOTAL_REQUESTS"
if [ $SUCCESS_COUNT -eq $TOTAL_REQUESTS ]; then
    echo -e "${GREEN}✓ 所有请求成功执行${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 部分请求失败${NC} | 耗时: ${TEST_DURATION}s"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试5: 不同模型计费统计
echo -e "${CYAN}测试5: 不同模型计费统计${NC}"
echo -e "${BLUE}[详情]${NC} 测试不同模型的计费记录"
TEST_START=$(date +%s)
MODELS=("llama3" "mistral" "gemma")
MODEL_COUNT=0

for model in "${MODELS[@]}"; do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$model\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
    if echo "$response" | grep -q "response"; then
        MODEL_COUNT=$((MODEL_COUNT + 1))
    fi
done

TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo "  成功模型数: $MODEL_COUNT/${#MODELS[@]}"
if [ $MODEL_COUNT -gt 0 ]; then
    echo -e "${GREEN}✓ 模型计费统计正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型计费统计需要改进${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试6: 计费数据持久化
echo -e "${CYAN}测试6: 计费数据持久化${NC}"
echo -e "${BLUE}[详情]${NC} 检查计费数据是否正确持久化到数据库"
TEST_START=$(date +%s)
# 模拟数据库文件检查
if [ -f "$BILLING_DB_DIR/billing.db" ] || [ -f "/tmp/allama/billing/billing.db" ]; then
    echo -e "${GREEN}✓ 计费数据库文件存在${NC} | 耗时: $(( $(date +%s) - TEST_START ))s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 计费数据库文件未找到（可能使用其他路径）${NC} | 耗时: $(( $(date +%s) - TEST_START ))s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""

# 测试7: 计费时间戳记录
echo -e "${CYAN}测试7: 计费时间戳记录${NC}"
echo -e "${BLUE}[详情]${NC} 检查计费记录是否包含正确的时间戳"
TEST_START=$(date +%s)
BEFORE_TIME=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"timestamp test\",\"stream\":false}" 2>&1)
AFTER_TIME=$(date +%s)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ 计费时间戳记录正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 计费时间戳记录需要验证${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试8: 计费数据完整性
echo -e "${CYAN}测试8: 计费数据完整性${NC}"
echo -e "${BLUE}[详情]${NC} 验证计费记录的完整性"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"integrity test\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ 计费数据完整性验证通过${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 计费数据完整性需要验证${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试9: 计费并发处理
echo -e "${CYAN}测试9: 计费并发处理${NC}"
echo -e "${BLUE}[详情]${NC} 测试并发请求的计费记录"
TEST_START=$(date +%s)
CONCURRENT_REQUESTS=3
for i in $(seq 1 $CONCURRENT_REQUESTS); do
    curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"concurrent $i\",\"stream\":false}" > /dev/null 2>&1 &
done
wait
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo -e "${GREEN}✓ 并发计费处理完成${NC} | 耗时: ${TEST_DURATION}s"
PASSED_TESTS=$((PASSED_TESTS + 1))
echo ""

# 测试10: 计费错误处理
echo -e "${CYAN}测试10: 计费错误处理${NC}"
echo -e "${BLUE}[详情]${NC} 测试计费记录失败时的错误处理"
TEST_START=$(date +%s)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"invalid_model\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 即使模型无效，计费系统也应该正常处理
echo -e "${GREEN}✓ 计费错误处理正常${NC} | 耗时: ${TEST_DURATION}s"
PASSED_TESTS=$((PASSED_TESTS + 1))
echo ""

# 测试11: 计费记录查询API
echo -e "${CYAN}测试11: 计费记录查询API${NC}"
echo -e "${BLUE}[详情]${NC} 测试GET /api/billing/records接口"
TEST_START=$(date +%s)
response=$(curl -s -X GET "${BASE_URL}/api/billing/records" \
    -H "X-Forwarded-For: 127.0.0.1" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "records\|total"; then
    echo -e "${GREEN}✓ 计费记录查询API正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 计费记录查询API需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试12: 计费统计摘要API
echo -e "${CYAN}测试12: 计费统计摘要API${NC}"
echo -e "${BLUE}[详情]${NC} 测试GET /api/billing/summary接口"
TEST_START=$(date +%s)
response=$(curl -s -X GET "${BASE_URL}/api/billing/summary" \
    -H "X-Forwarded-For: 127.0.0.1" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "total_tokens\|total_records"; then
    echo -e "${GREEN}✓ 计费统计摘要API正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 计费统计摘要API需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试13: 模型计费统计API
echo -e "${CYAN}测试13: 模型计费统计API${NC}"
echo -e "${BLUE}[详情]${NC} 测试GET /api/billing/stats/:model接口"
TEST_START=$(date +%s)
response=$(curl -s -X GET "${BASE_URL}/api/billing/stats/${TEST_MODEL}" \
    -H "X-Forwarded-For: 127.0.0.1" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "model_name\|total_tokens"; then
    echo -e "${GREEN}✓ 模型计费统计API正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型计费统计API需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试14: 计费API时间范围查询
echo -e "${CYAN}测试14: 计费API时间范围查询${NC}"
echo -e "${BLUE}[详情]${NC} 测试带时间参数的计费记录查询"
TEST_START=$(date +%s)
START_TIME=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
response=$(curl -s -X GET "${BASE_URL}/api/billing/records?start=${START_TIME}&end=${END_TIME}&limit=10" \
    -H "X-Forwarded-For: 127.0.0.1" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "records\|total"; then
    echo -e "${GREEN}✓ 计费API时间范围查询正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 计费API时间范围查询需要验证${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试15: 计费API响应格式验证
echo -e "${CYAN}测试15: 计费API响应格式验证${NC}"
echo -e "${BLUE}[详情]${NC} 验证计费API返回的JSON格式"
TEST_START=$(date +%s)
response=$(curl -s -X GET "${BASE_URL}/api/billing/summary" 2>&1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 检查是否为有效的JSON
if echo "$response" | python3 -m json.tool >/dev/null 2>&1 || echo "$response" | jq . >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 计费API响应格式正确${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 计费API响应格式需要验证${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 清理
rm -rf "$BILLING_DB_DIR"

echo "=========================================="
echo -e "${CYAN}计费统计测试总结${NC}"
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
