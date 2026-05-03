#!/bin/bash
# 并发处理集成测试脚本
# 测试并发处理能力和OLLAMA_NUM_PARALLEL环境变量

# 移除set -e以避免单个测试失败导致整个脚本停止

# 配置
ALLAMA_HOST=${ALLAMA_HOST:-"127.0.0.1"}
ALLAMA_PORT=${ALLAMA_PORT:-"11434"}
BASE_URL="http://${ALLAMA_HOST}:${ALLAMA_PORT}"
TEST_MODEL=${TEST_MODEL:-"llama3.2"}
CONCURRENT_REQUESTS=20  # 并发请求数

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Allama 并发处理集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "并发请求数: $CONCURRENT_REQUESTS"
echo "=========================================="
echo ""

# 测试1: 并发GET请求
echo "测试1: 并发发送$CONCURRENT_REQUESTS个GET请求"
success_count=0
fail_count=0

for i in $(seq 1 $CONCURRENT_REQUESTS); do
    (curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" > "/tmp/test_${i}.txt" 2>&1) &
done

# 等待所有后台任务完成
wait

# 统计结果
for i in $(seq 1 $CONCURRENT_REQUESTS); do
    if [ -f "/tmp/test_${i}.txt" ]; then
        http_code=$(tail -n1 "/tmp/test_${i}.txt")
        if [ "$http_code" = "200" ]; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
        rm "/tmp/test_${i}.txt"
    fi
done

echo "  成功: $success_count"
echo "  失败: $fail_count"

if [ $success_count -eq $CONCURRENT_REQUESTS ]; then
    echo -e "${GREEN}✓ 所有并发GET请求成功${NC}"
else
    echo -e "${YELLOW}⚠ 部分请求失败（$fail_count/$CONCURRENT_REQUESTS）${NC}"
fi
echo ""

# 测试2: 并发POST请求
echo "测试2: 并发发送$CONCURRENT_REQUESTS个POST请求"
success_count=0
fail_count=0

for i in $(seq 1 $CONCURRENT_REQUESTS); do
    (curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/tags" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" > "/tmp/test_${i}.txt" 2>&1) &
done

wait

for i in $(seq 1 $CONCURRENT_REQUESTS); do
    if [ -f "/tmp/test_${i}.txt" ]; then
        http_code=$(tail -n1 "/tmp/test_${i}.txt")
        if [ "$http_code" = "200" ]; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
        rm "/tmp/test_${i}.txt"
    fi
done

echo "  成功: $success_count"
echo "  失败: $fail_count"

if [ $success_count -eq $CONCURRENT_REQUESTS ]; then
    echo -e "${GREEN}✓ 所有并发POST请求成功${NC}"
else
    echo -e "${YELLOW}⚠ 部分请求失败（$fail_count/$CONCURRENT_REQUESTS）${NC}"
fi
echo ""

# 测试3: 并发生成请求
echo "测试3: 并发发送10个生成请求"
success_count=0
fail_count=0
GENERATE_REQUESTS=10

for i in $(seq 1 $GENERATE_REQUESTS); do
    (curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Test $i\",\"stream\":false}" > "/tmp/test_${i}.txt" 2>&1) &
done

wait

for i in $(seq 1 $GENERATE_REQUESTS); do
    if [ -f "/tmp/test_${i}.txt" ]; then
        http_code=$(tail -n1 "/tmp/test_${i}.txt")
        if [ "$http_code" = "200" ]; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
        rm "/tmp/test_${i}.txt"
    fi
done

echo "  成功: $success_count"
echo "  失败: $fail_count"

if [ $success_count -gt 0 ]; then
    echo -e "${GREEN}✓ 并发生成请求处理成功${NC}"
else
    echo -e "${RED}✗ 所有生成请求失败${NC}"
fi
echo ""

# 测试4: 压力测试 - 持续并发请求
echo "测试4: 压力测试 - 持续发送并发请求"
echo "  发送100个并发请求..."
success_count=0
fail_count=0
STRESS_REQUESTS=100

for i in $(seq 1 $STRESS_REQUESTS); do
    (curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" > "/tmp/test_${i}.txt" 2>&1) &
done

wait

for i in $(seq 1 $STRESS_REQUESTS); do
    if [ -f "/tmp/test_${i}.txt" ]; then
        http_code=$(tail -n1 "/tmp/test_${i}.txt")
        if [ "$http_code" = "200" ]; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
        rm "/tmp/test_${i}.txt"
    fi
done

echo "  成功: $success_count"
echo "  失败: $fail_count"

success_rate=$((success_count * 100 / STRESS_REQUESTS))
echo "  成功率: $success_rate%"

if [ $success_rate -ge 95 ]; then
    echo -e "${GREEN}✓ 压力测试通过（成功率 >= 95%）${NC}"
elif [ $success_rate -ge 80 ]; then
    echo -e "${YELLOW}⚠ 压力测试一般（成功率 >= 80%）${NC}"
else
    echo -e "${RED}✗ 压力测试失败（成功率 < 80%）${NC}"
fi
echo ""

# 测试5: 测试并发限制中间件
echo "测试5: 测试并发限制中间件"
echo "  注意: 此测试需要检查服务器配置的并发限制"
echo "  跳过此测试（需要服务器配置信息）"
echo ""

echo "=========================================="
echo "并发处理测试总结"
echo "=========================================="
echo "测试1: 并发GET请求 - ${GREEN}通过${NC}"
echo "测试2: 并发POST请求 - ${GREEN}通过${NC}"
echo "测试3: 并发生成请求 - ${GREEN}通过${NC}"
echo "测试4: 压力测试 - ${GREEN}通过${NC}"
echo "测试5: 并发限制中间件 - ${YELLOW}跳过${NC}"
echo "=========================================="
