#!/bin/bash
# 性能基准测试脚本
# 测试响应时间、吞吐量、资源使用等性能指标

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
echo "Allama 性能基准测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 单请求响应时间
echo "测试1: 单请求响应时间（GET /api/tags）"
total_time=0
iterations=100

for i in $(seq 1 $iterations); do
    start_time=$(date +%s%N)
    response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
    end_time=$(date +%s%N)
    elapsed=$(( (end_time - start_time) / 1000000 ))
    total_time=$((total_time + elapsed))
done

avg_time=$((total_time / iterations))
echo "  平均响应时间: ${avg_time}ms"
echo "  总请求数: $iterations"
echo "  总耗时: ${total_time}ms"

if [ $avg_time -lt 100 ]; then
    echo -e "${GREEN}✓ 响应时间优秀 (< 100ms)${NC}"
elif [ $avg_time -lt 500 ]; then
    echo -e "${YELLOW}⚠ 响应时间一般 (< 500ms)${NC}"
else
    echo -e "${RED}✗ 响应时间较慢 (> 500ms)${NC}"
fi
echo ""

# 测试2: POST请求响应时间
echo "测试2: POST请求响应时间（/api/generate）"
total_time=0
iterations=50

for i in $(seq 1 $iterations); do
    start_time=$(date +%s%N)
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
    end_time=$(date +%s%N)
    elapsed=$(( (end_time - start_time) / 1000000 ))
    total_time=$((total_time + elapsed))
done

avg_time=$((total_time / iterations))
echo "  平均响应时间: ${avg_time}ms"
echo "  总请求数: $iterations"
echo "  总耗时: ${total_time}ms"

if [ $avg_time -lt 500 ]; then
    echo -e "${GREEN}✓ 响应时间优秀 (< 500ms)${NC}"
elif [ $avg_time -lt 2000 ]; then
    echo -e "${YELLOW}⚠ 响应时间一般 (< 2s)${NC}"
else
    echo -e "${RED}✗ 响应时间较慢 (> 2s)${NC}"
fi
echo ""

# 测试3: 吞吐量测试（并发请求）
echo "测试3: 吞吐量测试（并发请求）"
concurrent_levels=(1 5 10 20)

for level in "${concurrent_levels[@]}"; do
    start_time=$(date +%s)
    success_count=0
    
    for i in $(seq 1 $level); do
        response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
        http_code=$(echo "$response" | tail -n1)
        
        if [ "$http_code" = "200" ]; then
            success_count=$((success_count + 1))
        fi
    done
    
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    
    if [ $elapsed -gt 0 ]; then
        throughput=$((success_count / elapsed))
    else
        throughput=$success_count
    fi
    
    echo "  并发级别 $level: 成功 $success_count/$level, 耗时 ${elapsed}s, 吞吐量 ${throughput} req/s"
done
echo -e "${GREEN}✓ 吞吐量测试完成${NC}"
echo ""

# 测试4: 持续负载测试
echo "测试4: 持续负载测试（30秒）"
start_time=$(date +%s)
end_time=$((start_time + 30))
success_count=0
total_requests=0

while [ $(date +%s) -lt $end_time ]; do
    response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    total_requests=$((total_requests + 1))
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    fi
    
    sleep 0.1
done

actual_duration=$((end_time - start_time))
throughput=$((success_count / actual_duration))
success_rate=$((success_count * 100 / total_requests))

echo "  持续时间: ${actual_duration}s"
echo "  总请求数: $total_requests"
echo "  成功请求数: $success_count"
echo "  成功率: ${success_rate}%"
echo "  平均吞吐量: ${throughput} req/s"

if [ $success_rate -ge 95 ]; then
    echo -e "${GREEN}✓ 持续负载测试通过（成功率 >= 95%）${NC}"
else
    echo -e "${YELLOW}⚠ 持续负载测试部分失败（成功率: ${success_rate}%）${NC}"
fi
echo ""

# 测试5: 内存使用监控
echo "测试5: 内存使用监控"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    mem_mb=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    echo "  进程PID: $pid"
    echo "  内存使用: ${mem_mb}MB"
    
    if [ $mem_mb -lt 500 ]; then
        echo -e "${GREEN}✓ 内存使用正常 (< 500MB)${NC}"
    elif [ $mem_mb -lt 1000 ]; then
        echo -e "${YELLOW}⚠ 内存使用偏高 (< 1GB)${NC}"
    else
        echo -e "${RED}✗ 内存使用过高 (> 1GB)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试6: CPU使用监控
echo "测试6: CPU使用监控"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    cpu_percent=$(ps -o %cpu= -p $pid | awk '{print int($1)}')
    echo "  进程PID: $pid"
    echo "  CPU使用: ${cpu_percent}%"
    
    if [ $cpu_percent -lt 50 ]; then
        echo -e "${GREEN}✓ CPU使用正常 (< 50%)${NC}"
    elif [ $cpu_percent -lt 80 ]; then
        echo -e "${YELLOW}⚠ CPU使用偏高 (< 80%)${NC}"
    else
        echo -e "${RED}✗ CPU使用过高 (> 80%)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试7: 连接建立时间
echo "测试7: 连接建立时间"
total_time=0
iterations=50

for i in $(seq 1 $iterations); do
    start_time=$(date +%s%N)
    response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
    end_time=$(date +%s%N)
    elapsed=$(( (end_time - start_time) / 1000000 ))
    total_time=$((total_time + elapsed))
done

avg_connect_time=$((total_time / iterations))
echo "  平均连接建立时间: ${avg_connect_time}ms"

if [ $avg_connect_time -lt 10 ]; then
    echo -e "${GREEN}✓ 连接建立时间优秀 (< 10ms)${NC}"
elif [ $avg_connect_time -lt 50 ]; then
    echo -e "${YELLOW}⚠ 连接建立时间一般 (< 50ms)${NC}"
else
    echo -e "${RED}✗ 连接建立时间较慢 (> 50ms)${NC}"
fi
echo ""

# 测试8: 不同负载下的响应时间
echo "测试8: 不同负载下的响应时间"
load_levels=(1 10 50 100)

for level in "${load_levels[@]}"; do
    total_time=0
    success_count=0
    
    for i in $(seq 1 $level); do
        start_time=$(date +%s%N)
        response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
        end_time=$(date +%s%N)
        elapsed=$(( (end_time - start_time) / 1000000 ))
        total_time=$((total_time + elapsed))
        
        http_code=$(echo "$response" | tail -n1)
        if [ "$http_code" = "200" ]; then
            success_count=$((success_count + 1))
        fi
    done
    
    if [ $success_count -gt 0 ]; then
        avg_time=$((total_time / success_count))
        echo "  负载级别 $level: 平均响应时间 ${avg_time}ms, 成功率 $((success_count * 100 / level))%"
    else
        echo "  负载级别 $level: 所有请求失败"
    fi
done
echo -e "${GREEN}✓ 负载测试完成${NC}"
echo ""

# 测试9: 冷启动性能
echo "测试9: 冷启动性能（模拟模型加载）"
start_time=$(date +%s%N)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
end_time=$(date +%s%N)
elapsed=$(( (end_time - start_time) / 1000000 ))

echo "  冷启动响应时间: ${elapsed}ms"

if [ $elapsed -lt 1000 ]; then
    echo -e "${GREEN}✓ 冷启动性能优秀 (< 1s)${NC}"
elif [ $elapsed -lt 5000 ]; then
    echo -e "${YELLOW}⚠ 冷启动性能一般 (< 5s)${NC}"
else
    echo -e "${RED}✗ 冷启动性能较慢 (> 5s)${NC}"
fi
echo ""

# 测试10: 长时间运行稳定性
echo "测试10: 长时间运行稳定性（60秒）"
start_time=$(date +%s)
end_time=$((start_time + 60))
success_count=0
total_requests=0
response_times=()

while [ $(date +%s) -lt $end_time ]; do
    req_start=$(date +%s%N)
    response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
    req_end=$(date +%s%N)
    req_elapsed=$(( (req_end - req_start) / 1000000 ))
    
    http_code=$(echo "$response" | tail -n1)
    total_requests=$((total_requests + 1))
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
        response_times+=($req_elapsed)
    fi
    
    sleep 0.2
done

actual_duration=$((end_time - start_time))
success_rate=$((success_count * 100 / total_requests))

# 计算响应时间的标准差
if [ ${#response_times[@]} -gt 0 ]; then
    sum=0
    for time in "${response_times[@]}"; do
        sum=$((sum + time))
    done
    avg=$((sum / ${#response_times[@]}))
    
    sum_sq=0
    for time in "${response_times[@]}"; do
        diff=$((time - avg))
        sum_sq=$((sum_sq + diff * diff))
    done
    std_dev=$((sum_sq / ${#response_times[@]}))
    std_dev=$((std_dev ** 0.5))
else
    avg=0
    std_dev=0
fi

echo "  持续时间: ${actual_duration}s"
echo "  总请求数: $total_requests"
echo "  成功率: ${success_rate}%"
echo "  平均响应时间: ${avg}ms"
echo "  响应时间标准差: ${std_dev}ms"

if [ $success_rate -ge 95 ] && [ $std_dev -lt 100 ]; then
    echo -e "${GREEN}✓ 长时间运行稳定（成功率 >= 95%, 标准差 < 100ms）${NC}"
else
    echo -e "${YELLOW}⚠ 长时间运行稳定性需要改进${NC}"
fi
echo ""

echo "=========================================="
echo "性能基准测试总结"
echo "=========================================="
echo "测试1: 单请求响应时间 - ${GREEN}完成${NC}"
echo "测试2: POST请求响应时间 - ${GREEN}完成${NC}"
echo "测试3: 吞吐量测试 - ${GREEN}完成${NC}"
echo "测试4: 持续负载测试 - ${GREEN}完成${NC}"
echo "测试5: 内存使用监控 - ${GREEN}完成${NC}"
echo "测试6: CPU使用监控 - ${GREEN}完成${NC}"
echo "测试7: 连接建立时间 - ${GREEN}完成${NC}"
echo "测试8: 不同负载响应时间 - ${GREEN}完成${NC}"
echo "测试9: 冷启动性能 - ${GREEN}完成${NC}"
echo "测试10: 长时间运行稳定性 - ${GREEN}完成${NC}"
echo "=========================================="
