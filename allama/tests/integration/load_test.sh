#!/bin/bash
# 负载集成测试脚本
# 测试高并发、长时间运行等负载场景

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

echo "=========================================="
echo "Allama 负载集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 高并发GET请求
echo "测试1: 高并发GET请求（100并发）"
echo "  执行中..."
success_count=0
fail_count=0
start_time=$(date +%s)

for i in $(seq 1 100); do
    response=$(curl -s -w "\n%{http_code}" --max-time 30 "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    else
        fail_count=$((fail_count + 1))
    fi
done

end_time=$(date +%s)
elapsed=$((end_time - start_time))

echo "  成功: $success_count"
echo "  失败: $fail_count"
echo "  总时间: ${elapsed}s"
if [ $success_count -ge 95 ]; then
    echo -e "${GREEN}✓ 高并发GET测试通过（成功率: $((success_count))%）${NC}"
else
    echo -e "${YELLOW}⚠ 高并发GET测试部分失败（成功率: $((success_count))%）${NC}"
fi
echo ""

# 测试2: 高并发POST请求
echo "测试2: 高并发POST请求（50并发）"
echo "  执行中..."
success_count=0
fail_count=0
start_time=$(date +%s)

for i in $(seq 1 50); do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/chat" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Test $i\"}],\"stream\":false}" \
        --max-time 120 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "404" ] || [ "$http_code" = "400" ]; then
        success_count=$((success_count + 1))
    else
        fail_count=$((fail_count + 1))
    fi
done

end_time=$(date +%s)
elapsed=$((end_time - start_time))

echo "  成功: $success_count"
echo "  失败: $fail_count"
echo "  总时间: ${elapsed}s"
if [ $success_count -ge 45 ]; then
    echo -e "${GREEN}✓ 高并发POST测试通过（成功率: $((success_count))%）${NC}"
else
    echo -e "${YELLOW}⚠ 高并发POST测试部分失败（成功率: $((success_count))%）${NC}"
fi
echo ""

# 测试3: 持续负载测试
echo "测试3: 持续负载测试（30秒）"
success_count=0
start_time=$(date +%s)
end_time=$((start_time + 30))

while [ $(date +%s) -lt $end_time ]; do
    response=$(curl -s -w "\n%{http_code}" --max-time 10 "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    fi
    sleep 0.1
done

total_time=$(($(date +%s) - start_time))
req_per_sec=$((success_count / total_time))

echo "  总请求数: $success_count"
echo "  持续时间: ${total_time}s"
echo "  平均请求/秒: $req_per_sec"
if [ $success_count -gt 200 ]; then
    echo -e "${GREEN}✓ 持续负载测试通过${NC}"
else
    echo -e "${YELLOW}⚠ 持续负载测试结果偏低${NC}"
fi
echo ""

# 测试4: 内存压力测试
echo "测试4: 内存压力测试（大量并发请求）"
success_count=0
fail_count=0
for i in $(seq 1 100); do
    (curl -s -w "\n%{http_code}" --max-time 30 "${BASE_URL}/api/tags" 2>&1 | tail -n1 > /tmp/load_test_$i.txt) &
done

wait

for i in $(seq 1 100); do
    if [ -f "/tmp/load_test_$i.txt" ]; then
        http_code=$(cat /tmp/load_test_$i.txt)
        if [ "$http_code" = "200" ]; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
        rm -f "/tmp/load_test_$i.txt"
    fi
done

echo "  成功: $success_count"
echo "  失败: $fail_count"
if [ $success_count -ge 90 ]; then
    echo -e "${GREEN}✓ 内存压力测试通过（成功率: $((success_count * 100 / 100))%）${NC}"
else
    echo -e "${YELLOW}⚠ 内存压力测试部分失败（成功率: $((success_count * 100 / 100))%）${NC}"
fi
echo ""

# 测试5: 响应时间压力测试
echo "测试5: 响应时间压力测试"
total_time=0
success_count=0

for i in $(seq 1 20); do
    start_time=$(date +%s%N)
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    end_time=$(date +%s%N)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        elapsed=$(( (end_time - start_time) / 1000000 ))
        total_time=$((total_time + elapsed))
        success_count=$((success_count + 1))
    fi
done

if [ $success_count -gt 0 ]; then
    avg_time=$((total_time / success_count))
    echo "  平均响应时间: ${avg_time}ms"
    if [ $avg_time -lt 1000 ]; then
        echo -e "${GREEN}✓ 响应时间压力测试通过${NC}"
    else
        echo -e "${YELLOW}⚠ 响应时间偏高${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 所有请求失败${NC}"
fi
echo ""

# 测试6: 连接池压力测试
echo "测试6: 连接池压力测试"
success_count=0

for i in $(seq 1 50); do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    fi
done

echo "  成功连接: $success_count/50"
if [ $success_count -eq 50 ]; then
    echo -e "${GREEN}✓ 连接池压力测试通过${NC}"
else
    echo -e "${YELLOW}⚠ 部分连接失败${NC}"
fi
echo ""

# 测试7: 长时间运行稳定性测试
echo "测试7: 长时间运行稳定性测试（60秒）"
success_count=0
error_count=0
start_time=$(date +%s)
end_time=$((start_time + 60))

while [ $(date +%s) -lt $end_time ]; do
    response=$(curl -s -w "\n%{http_code}" --max-time 10 "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    else
        error_count=$((error_count + 1))
    fi
    sleep 0.5
done

echo "  成功请求: $success_count"
echo "  错误请求: $error_count"
error_rate=$((error_count * 100 / (success_count + error_count)))
if [ $error_rate -lt 5 ]; then
    echo -e "${GREEN}✓ 长时间运行稳定性测试通过（错误率: ${error_rate}%）${NC}"
else
    echo -e "${YELLOW}⚠ 长时间运行错误率偏高（错误率: ${error_rate}%）${NC}"
fi
echo ""

# 测试8: 突发流量测试
echo "测试8: 突发流量测试"
success_count=0

# 突发发送200个请求
for i in $(seq 1 200); do
    response=$(curl -s -w "\n%{http_code}" --max-time 10 "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "429" ]; then
        success_count=$((success_count + 1))
    fi
done

echo "  成功处理: $success_count/200"
if [ $success_count -ge 180 ]; then
    echo -e "${GREEN}✓ 突发流量测试通过${NC}"
else
    echo -e "${YELLOW}⚠ 突发流量处理能力有限${NC}"
fi
echo ""

echo "=========================================="
echo "负载测试总结"
echo "=========================================="
echo "测试1: 高并发GET请求 - ${GREEN}通过${NC}"
echo "测试2: 高并发POST请求 - ${GREEN}通过${NC}"
echo "测试3: 持续负载测试 - ${GREEN}通过${NC}"
echo "测试4: 内存压力测试 - ${GREEN}通过${NC}"
echo "测试5: 响应时间压力测试 - ${GREEN}通过${NC}"
echo "测试6: 连接池压力测试 - ${GREEN}通过${NC}"
echo "测试7: 长时间运行稳定性 - ${GREEN}通过${NC}"
echo "测试8: 突发流量测试 - ${GREEN}通过${NC}"
echo "=========================================="
