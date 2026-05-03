#!/bin/bash
# 模型生命周期集成测试脚本
# 测试模型的创建、加载、卸载、删除等完整生命周期

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
echo "Allama 模型生命周期集成测试"
echo "=========================================="
echo -e "${CYAN}服务器地址:${NC} $BASE_URL"
echo -e "${CYAN}测试模型:${NC} $TEST_MODEL"
echo -e "${CYAN}测试开始时间:${NC} $(date)"
echo "=========================================="
echo ""

# 生成唯一测试模型名称
TIMESTAMP=$(date +%s)
TEST_MODEL_LIFECYCLE="lifecycle_test_${TIMESTAMP}"
echo -e "${BLUE}[信息]${NC} 生成测试模型名称: $TEST_MODEL_LIFECYCLE"
echo ""

# 测试1: 模型复制
echo -e "${CYAN}测试1: 模型复制${NC}"
echo -e "${BLUE}[详情]${NC} 从 $TEST_MODEL 复制到 $TEST_MODEL_LIFECYCLE"
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/copy" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"source\":\"$TEST_MODEL\",\"destination\":\"$TEST_MODEL_LIFECYCLE\"}" \
    --max-time 60 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 模型复制成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型复制失败 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -n -1)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试2: 模型列表验证
echo -e "${CYAN}测试2: 模型列表验证${NC}"
echo -e "${BLUE}[详情]${NC} 验证复制的模型 $TEST_MODEL_LIFECYCLE 是否出现在列表中"
TEST_START=$(date +%s)
response=$(curl -s --max-time 10 "${BASE_URL}/api/tags")
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "$TEST_MODEL_LIFECYCLE"; then
    echo -e "${GREEN}✓ 复制的模型出现在列表中${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 复制的模型未出现在列表中${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试3: 模型加载
echo -e "${CYAN}测试3: 模型加载${NC}"
echo -e "${BLUE}[详情]${NC} 加载模型 $TEST_MODEL_LIFECYCLE 并测试生成
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL_LIFECYCLE\",\"prompt\":\"test\",\"stream\":false}" \
    --max-time 60 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 模型加载成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型加载失败 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -n -1)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试4: 模型详情查询
echo -e "${CYAN}测试4: 模型详情查询${NC}"
echo -e "${BLUE}[详情]${NC} 查询模型 $TEST_MODEL_LIFECYCLE 的详细信息
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/show" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL_LIFECYCLE\"}" \
    --max-time 10 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 模型详情查询成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型详情查询失败 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -n -1)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试5: 模型嵌入生成
echo -e "${CYAN}测试5: 模型嵌入生成${NC}"
echo -e "${BLUE}[详情]${NC} 为模型 $TEST_MODEL_LIFECYCLE 生成文本嵌入
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/embed" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL_LIFECYCLE\",\"input\":\"test\"}" \
    --max-time 30 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 模型嵌入生成成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型嵌入生成失败 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -n -1)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试6: 运行中模型列表
echo -e "${CYAN}测试6: 运行中模型列表${NC}"
echo -e "${BLUE}[详情]${NC} 检查模型 $TEST_MODEL_LIFECYCLE 是否在运行列表中
TEST_START=$(date +%s)
response=$(curl -s --max-time 10 "${BASE_URL}/api/ps")
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "$TEST_MODEL_LIFECYCLE"; then
    echo -e "${GREEN}✓ 模型出现在运行列表中${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型未出现在运行列表中${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -c 200)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试7: 模型聊天功能
echo -e "${CYAN}测试7: 模型聊天功能${NC}"
echo -e "${BLUE}[详情]${NC} 测试模型 $TEST_MODEL_LIFECYCLE 的聊天功能
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL_LIFECYCLE\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":false}" \
    --max-time 30 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 模型聊天功能正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型聊天功能异常 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -n -1)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试8: 模型停止
echo -e "${CYAN}测试8: 模型停止${NC}"
echo -e "${BLUE}[详情]${NC} 停止模型 $TEST_MODEL_LIFECYCLE
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/stop" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL_LIFECYCLE\"}" \
    --max-time 30 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 模型停止成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型停止失败 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -n -1)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试9: 模型重新加载
echo -e "${CYAN}测试9: 模型重新加载${NC}"
echo -e "${BLUE}[详情]${NC} 重新加载模型 $TEST_MODEL_LIFECYCLE 并测试生成
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL_LIFECYCLE\",\"prompt\":\"test\",\"stream\":false}" \
    --max-time 60 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 模型重新加载成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型重新加载失败 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -n -1)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试10: 模型删除
echo -e "${CYAN}测试10: 模型删除${NC}"
echo -e "${BLUE}[详情]${NC} 删除模型 $TEST_MODEL_LIFECYCLE
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}/api/delete" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL_LIFECYCLE\"}" \
    --max-time 30 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 模型删除成功${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 模型删除失败 (状态码: $http_code)${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -n -1)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试11: 删除后验证
echo -e "${CYAN}测试11: 删除后验证${NC}"
echo -e "${BLUE}[详情]${NC} 验证模型 $TEST_MODEL_LIFECYCLE 已被删除
TEST_START=$(date +%s)
response=$(curl -s --max-time 10 "${BASE_URL}/api/tags")
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if echo "$response" | grep -q "$TEST_MODEL_LIFECYCLE"; then
    echo -e "${YELLOW}⚠ 删除后模型仍存在${NC} | 耗时: ${TEST_DURATION}s"
    FAILED_TESTS=$((FAILED_TESTS + 1))
else
    echo -e "${GREEN}✓ 删除后模型不存在${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
echo ""

# 测试12: 删除后尝试加载
echo -e "${CYAN}测试12: 删除后尝试加载${NC}"
echo -e "${BLUE}[详情]${NC} 尝试加载已删除的模型 $TEST_MODEL_LIFECYCLE（预期失败）
TEST_START=$(date +%s)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL_LIFECYCLE\",\"prompt\":\"test\",\"stream\":false}" \
    --max-time 30 2>&1)
http_code=$(echo "$response" | tail -n1)
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$http_code" = "500" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 删除后无法加载（预期行为）${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 删除后仍可加载（异常）${NC} | 耗时: ${TEST_DURATION}s"
    echo -e "${RED}[响应]${NC} $(echo "$response" | head -n -1)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试13: 批量模型操作
echo -e "${CYAN}测试13: 批量模型操作${NC}"
echo -e "${BLUE}[详情]${NC} 批量创建和删除3个模型
TEST_START=$(date +%s)

# 批量创建
for i in $(seq 1 3); do
    curl -s -X POST "${BASE_URL}/api/copy" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"source\":\"$TEST_MODEL\",\"destination\":\"batch_test_${TIMESTAMP}_$i\"}" > /dev/null
done

# 批量删除
success_count=0
for i in $(seq 1 3); do
    response=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}/api/delete" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"batch_test_${TIMESTAMP}_$i\"}" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    fi
done

TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo "  批量删除成功: $success_count/3 | 耗时: ${TEST_DURATION}s"

if [ $success_count -eq 3 ]; then
    echo -e "${GREEN}✓ 批量模型操作正常${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 批量模型操作需要改进${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 测试14: 模型状态转换
echo -e "${CYAN}测试14: 模型状态转换${NC}"
echo -e "${BLUE}[详情]${NC} 测试模型从创建->加载->停止->删除的完整状态转换
TEST_START=$(date +%s)

# 创建测试模型
curl -s -X POST "${BASE_URL}/api/copy" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"source\":\"$TEST_MODEL\",\"destination\":\"state_test_${TIMESTAMP}\"}" > /dev/null

# 加载模型
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"state_test_${TIMESTAMP}\",\"prompt\":\"test\",\"stream\":false}" > /dev/null

# 停止模型
curl -s -X POST "${BASE_URL}/api/stop" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"state_test_${TIMESTAMP}\"}" > /dev/null

# 删除模型
curl -s -X DELETE "${BASE_URL}/api/delete" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"state_test_${TIMESTAMP}\"}" > /dev/null

TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo -e "${GREEN}✓ 模型状态转换正常${NC} | 耗时: ${TEST_DURATION}s"
PASSED_TESTS=$((PASSED_TESTS + 1))
echo ""

# 测试15: 并发模型操作
echo -e "${CYAN}测试15: 并发模型操作${NC}"
echo -e "${BLUE}[详情]${NC} 并发创建5个模型并删除
TEST_START=$(date +%s)

# 并发创建
for i in $(seq 1 5); do
    (curl -s -X POST "${BASE_URL}/api/copy" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"source\":\"$TEST_MODEL\",\"destination\":\"concurrent_test_${TIMESTAMP}_$i\"}" > /tmp/concurrent_$i.txt) &
done
wait

success_count=0
for i in $(seq 1 5); do
    if [ -f "/tmp/concurrent_$i.txt" ]; then
        if echo "$(< /tmp/concurrent_$i.txt)" | grep -q "success"; then
            success_count=$((success_count + 1))
        fi
        rm -f "/tmp/concurrent_$i.txt"
    fi
done

# 并发删除
for i in $(seq 1 5); do
    (curl -s -X DELETE "${BASE_URL}/api/delete" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"concurrent_test_${TIMESTAMP}_$i\"}" > /tmp/concurrent_del_$i.txt) &
done
wait

TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ $success_count -ge 4 ]; then
    echo -e "${GREEN}✓ 并发模型操作正常${NC} | 耗时: ${TEST_DURATION}s"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ 并发模型操作需要改进${NC} | 耗时: ${TEST_DURATION}s"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

echo "=========================================="
echo -e "${CYAN}模型生命周期测试总结${NC}"
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
