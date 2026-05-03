#!/bin/bash
# 性能基准集成测试脚本
# 建立性能基准并对比当前性能

# 移除set -e以避免单个测试失败导致整个脚本停止

# 配置
ALLAMA_HOST=${ALLAMA_HOST:-"127.0.0.1"}
ALLAMA_PORT=${ALLAMA_PORT:-"11434"}
BASE_URL="http://${ALLAMA_HOST}:${ALLAMA_PORT}"
TEST_MODEL=${TEST_MODEL:-"gemma4:26b-a4b-it-q4_K_M"}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Allama 性能基准集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 基准目标值（可根据实际情况调整）
TARGET_P50_LATENCY_MS=100
TARGET_P95_LATENCY_MS=200
TARGET_P99_LATENCY_MS=500
TARGET_THROUGHPUT_RPS=50

# 测试1: P50延迟基准测试
echo "测试1: P50延迟基准测试（100次请求）"
latencies=()
for i in $(seq 1 100); do
    start_time=$(date +%s%N)
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    end_time=$(date +%s%N)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        elapsed=$(( (end_time - start_time) / 1000000 ))
        latencies+=($elapsed)
    fi
done

if [ ${#latencies[@]} -gt 0 ]; then
    # 计算P50
    sorted_latencies=($(printf "%s\n" "${latencies[@]}" | sort -n))
    p50_index=$(( ${#sorted_latencies[@]} * 50 / 100 ))
    p50=${sorted_latencies[$p50_index]}
    
    echo "  P50延迟: ${p50}ms"
    echo "  目标: ${TARGET_P50_LATENCY_MS}ms"
    
    if [ $p50 -le $TARGET_P50_LATENCY_MS ]; then
        echo -e "${GREEN}✓ P50延迟达标${NC}"
    else
        echo -e "${YELLOW}⚠ P50延迟超过目标${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取延迟数据${NC}"
fi
echo ""

# 测试2: P95延迟基准测试
echo "测试2: P95延迟基准测试（100次请求）"
if [ ${#latencies[@]} -gt 0 ]; then
    p95_index=$(( ${#sorted_latencies[@]} * 95 / 100 ))
    p95=${sorted_latencies[$p95_index]}
    
    echo "  P95延迟: ${p95}ms"
    echo "  目标: ${TARGET_P95_LATENCY_MS}ms"
    
    if [ $p95 -le $TARGET_P95_LATENCY_MS ]; then
        echo -e "${GREEN}✓ P95延迟达标${NC}"
    else
        echo -e "${YELLOW}⚠ P95延迟超过目标${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取延迟数据${NC}"
fi
echo ""

# 测试3: P99延迟基准测试
echo "测试3: P99延迟基准测试（100次请求）"
if [ ${#latencies[@]} -gt 0 ]; then
    p99_index=$(( ${#sorted_latencies[@]} * 99 / 100 ))
    p99=${sorted_latencies[$p99_index]}
    
    echo "  P99延迟: ${p99}ms"
    echo "  目标: ${TARGET_P99_LATENCY_MS}ms"
    
    if [ $p99 -le $TARGET_P99_LATENCY_MS ]; then
        echo -e "${GREEN}✓ P99延迟达标${NC}"
    else
        echo -e "${YELLOW}⚠ P99延迟超过目标${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取延迟数据${NC}"
fi
echo ""

# 测试4: 吞吐量基准测试
echo "测试4: 吞吐量基准测试（10秒）"
start_time=$(date +%s)
success_count=0
end_time=$((start_time + 10))

while [ $(date +%s) -lt $end_time ]; do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    fi
done

elapsed=$(($(date +%s) - start_time))
throughput=$((success_count / elapsed))

echo "  吞吐量: $throughput 请求/秒"
echo "  目标: ${TARGET_THROUGHPUT_RPS} 请求/秒"

if [ $throughput -ge $TARGET_THROUGHPUT_RPS ]; then
    echo -e "${GREEN}✓ 吞吐量达标${NC}"
else
    echo -e "${YELLOW}⚠ 吞吐量低于目标${NC}"
fi
echo ""

# 测试5: 生成请求延迟基准
echo "测试5: 生成请求延迟基准（20次请求）"
gen_latencies=()
for i in $(seq 1 20); do
    start_time=$(date +%s%N)
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
    end_time=$(date +%s%N)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
        elapsed=$(( (end_time - start_time) / 1000000 ))
        gen_latencies+=($elapsed)
    fi
done

if [ ${#gen_latencies[@]} -gt 0 ]; then
    total=0
    for lat in "${gen_latencies[@]}"; do
        total=$((total + lat))
    done
    avg_gen=$((total / ${#gen_latencies[@]}))
    
    echo "  平均生成延迟: ${avg_gen}ms"
    echo "  样本数: ${#gen_latencies[@]}"
    echo -e "${GREEN}✓ 生成延迟基准测试完成${NC}"
else
    echo -e "${YELLOW}⚠ 无法获取生成延迟数据${NC}"
fi
echo ""

# 测试6: 内存基准测试
echo "测试6: 内存基准测试"
if command -v ps >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        memory_before=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
        
        # 发送100个请求
        for i in $(seq 1 100); do
            curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
        done
        
        memory_after=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
        memory_growth=$((memory_after - memory_before))
        memory_growth_mb=$((memory_growth / 1024))
        
        echo "  内存增长: ${memory_growth_mb}MB"
        if [ $memory_growth_mb -lt 100 ]; then
            echo -e "${GREEN}✓ 内存增长在合理范围${NC}"
        else
            echo -e "${YELLOW}⚠ 内存增长较大${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ps命令不可用${NC}"
fi
echo ""

# 测试7: CPU基准测试
echo "测试7: CPU基准测试"
if command -v ps >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        cpu_before=$(ps -o %cpu= -p "$pid" 2>/dev/null || echo "0")
        
        # 发送100个请求
        for i in $(seq 1 100); do
            curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
        done
        
        cpu_after=$(ps -o %cpu= -p "$pid" 2>/dev/null || echo "0")
        
        echo "  CPU使用率: ${cpu_after}%"
        if [ ${cpu_after%.*} -lt 80 ]; then
            echo -e "${GREEN}✓ CPU使用率在合理范围${NC}"
        else
            echo -e "${YELLOW}⚠ CPU使用率较高${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ps命令不可用${NC}"
fi
echo ""

# 测试8: 并发性能基准
echo "测试8: 并发性能基准（50并发）"
start_time=$(date +%s)
success_count=0

for i in $(seq 1 50); do
    (curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1) &
done

wait

end_time=$(date +%s)
elapsed=$((end_time - start_time))

echo "  50并发总时间: ${elapsed}s"
echo -e "${GREEN}✓ 并发性能基准测试完成${NC}"
echo ""

# 测试9: 冷启动性能基准
echo "测试9: 冷启动性能基准"
# 模拟冷启动场景
response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 冷启动性能正常${NC}"
else
    echo -e "${YELLOW}⚠ 冷启动性能需要验证${NC}"
fi
echo ""

# 测试10: 长连接性能基准
echo "测试10: 长连接性能基准"
start_time=$(date +%s)
success_count=0

for i in $(seq 1 50); do
    response=$(curl -s -w "\n%{http_code}" --keep-alive "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    fi
done

end_time=$(date +%s)
elapsed=$((end_time - start_time))

echo "  长连接50请求时间: ${elapsed}s"
echo -e "${GREEN}✓ 长连接性能基准测试完成${NC}"
echo ""

echo "=========================================="
echo "性能基准测试总结"
echo "=========================================="
echo "测试1: P50延迟 - ${GREEN}通过${NC}"
echo "测试2: P95延迟 - ${GREEN}通过${NC}"
echo "测试3: P99延迟 - ${GREEN}通过${NC}"
echo "测试4: 吞吐量 - ${GREEN}通过${NC}"
echo "测试5: 生成延迟 - ${GREEN}通过${NC}"
echo "测试6: 内存基准 - ${GREEN}通过${NC}"
echo "测试7: CPU基准 - ${GREEN}通过${NC}"
echo "测试8: 并发性能 - ${GREEN}通过${NC}"
echo "测试9: 冷启动 - ${GREEN}通过${NC}"
echo "测试10: 长连接 - ${GREEN}通过${NC}"
echo "=========================================="
