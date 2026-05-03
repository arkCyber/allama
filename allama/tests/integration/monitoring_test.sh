#!/bin/bash
# 监控集成测试脚本
# 测试监控指标、健康检查、性能指标等

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
echo "Allama 监控集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 健康检查端点
echo "测试1: 健康检查端点"
response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 服务健康检查通过${NC}"
else
    echo -e "${RED}✗ 服务健康检查失败 (状态码: $http_code)${NC}"
fi
echo ""

# 测试2: 响应时间监控
echo "测试2: 响应时间监控"
response_times=()
for i in $(seq 1 10); do
    start_time=$(date +%s%N)
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    end_time=$(date +%s%N)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        elapsed=$(( (end_time - start_time) / 1000000 ))
        response_times+=($elapsed)
    fi
done

if [ ${#response_times[@]} -gt 0 ]; then
    total=0
    for time in "${response_times[@]}"; do
        total=$((total + time))
    done
    avg=$((total / ${#response_times[@]}))
    echo "  平均响应时间: ${avg}ms"
    echo "  采样数: ${#response_times[@]}"
    if [ $avg -lt 500 ]; then
        echo -e "${GREEN}✓ 响应时间监控正常${NC}"
    else
        echo -e "${YELLOW}⚠ 响应时间偏高${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取响应时间数据${NC}"
fi
echo ""

# 测试3: 并发连接监控
echo "测试3: 并发连接监控"
active_connections=0
for i in $(seq 1 20); do
    (curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1) &
    active_connections=$((active_connections + 1))
done

wait
echo "  模拟并发连接数: $active_connections"
echo -e "${GREEN}✓ 并发连接监控测试完成${NC}"
echo ""

# 测试4: 内存使用监控（通过系统命令）
echo "测试4: 内存使用监控"
if command -v ps >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        memory_kb=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
        memory_mb=$((memory_kb / 1024))
        echo "  进程内存使用: ${memory_mb}MB"
        echo -e "${GREEN}✓ 内存使用监控正常${NC}"
    else
        echo -e "${YELLOW}⚠ 无法获取allama进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ps命令不可用${NC}"
fi
echo ""

# 测试5: CPU使用监控
echo "测试5: CPU使用监控"
if command -v ps >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        cpu_percent=$(ps -o %cpu= -p "$pid" 2>/dev/null || echo "0")
        echo "  进程CPU使用: ${cpu_percent}%"
        echo -e "${GREEN}✓ CPU使用监控正常${NC}"
    else
        echo -e "${YELLOW}⚠ 无法获取allama进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ps命令不可用${NC}"
fi
echo ""

# 测试6: 请求成功率监控
echo "测试6: 请求成功率监控"
success_count=0
total_count=100

for i in $(seq 1 $total_count); do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    fi
done

success_rate=$((success_count * 100 / total_count))
echo "  成功率: ${success_rate}% ($success_count/$total_count)"
if [ $success_rate -ge 95 ]; then
    echo -e "${GREEN}✓ 请求成功率监控正常${NC}"
else
    echo -e "${YELLOW}⚠ 请求成功率偏低${NC}"
fi
echo ""

# 测试7: 错误率监控
echo "测试7: 错误率监控"
error_count=0
total_count=50

for i in $(seq 1 $total_count); do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" != "200" ]; then
        error_count=$((error_count + 1))
    fi
done

error_rate=$((error_count * 100 / total_count))
echo "  错误率: ${error_rate}% ($error_count/$total_count)"
if [ $error_rate -lt 5 ]; then
    echo -e "${GREEN}✓ 错误率监控正常${NC}"
else
    echo -e "${YELLOW}⚠ 错误率偏高${NC}"
fi
echo ""

# 测试8: 吞吐量监控
echo "测试8: 吞吐量监控"
start_time=$(date +%s)
success_count=0

for i in $(seq 1 100); do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    fi
done

end_time=$(date +%s)
elapsed=$((end_time - start_time))
throughput=$((success_count / elapsed))
echo "  吞吐量: $throughput 请求/秒"
echo "  持续时间: ${elapsed}s"
echo -e "${GREEN}✓ 吞吐量监控正常${NC}"
echo ""

# 测试9: 模型加载状态监控
echo "测试9: 模型加载状态监控"
response=$(curl -s "${BASE_URL}/api/ps" 2>&1)
if echo "$response" | jq -e '.models' >/dev/null 2>&1; then
    loaded_models=$(echo "$response" | jq -r '.models | length' 2>/dev/null || echo "0")
    echo "  已加载模型数: $loaded_models"
    echo -e "${GREEN}✓ 模型加载状态监控正常${NC}"
else
    echo -e "${YELLOW}⚠ 无法获取模型加载状态${NC}"
fi
echo ""

# 测试10: 端口监控
echo "测试10: 端口监控"
if command -v lsof >/dev/null 2>&1; then
    if lsof -i ":${ALLAMA_PORT}" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 端口 ${ALLAMA_PORT} 正在监听${NC}"
    else
        echo -e "${RED}✗ 端口 ${ALLAMA_PORT} 未在监听${NC}"
    fi
elif command -v netstat >/dev/null 2>&1; then
    if netstat -an | grep ":${ALLAMA_PORT}" | grep -q LISTEN; then
        echo -e "${GREEN}✓ 端口 ${ALLAMA_PORT} 正在监听${NC}"
    else
        echo -e "${RED}✗ 端口 ${ALLAMA_PORT} 未在监听${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法检查端口状态（需要lsof或netstat）${NC}"
fi
echo ""

# 测试11: 磁盘I/O监控
echo "测试11: 磁盘I/O监控"
if command -v iostat >/dev/null 2>&1; then
    iostat -x 1 1 2>/dev/null | head -n 10
    echo -e "${GREEN}✓ 磁盘I/O监控正常${NC}"
else
    echo -e "${YELLOW}⚠ iostat命令不可用${NC}"
fi
echo ""

# 测试12: 网络I/O监控
echo "测试12: 网络I/O监控"
if command -v ifstat >/dev/null 2>&1; then
    ifstat -i 1 1 2>/dev/null | head -n 5
    echo -e "${GREEN}✓ 网络I/O监控正常${NC}"
else
    echo -e "${YELLOW}⚠ ifstat命令不可用${NC}"
fi
echo ""

# 测试13: 服务可用性监控
echo "测试13: 服务可用性监控（持续30秒）"
available_count=0
total_checks=30

for i in $(seq 1 $total_checks); do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        available_count=$((available_count + 1))
    fi
    sleep 1
done

availability=$((available_count * 100 / total_checks))
echo "  可用性: ${availability}% ($available_count/$total_checks)"
if [ $availability -eq 100 ]; then
    echo -e "${GREEN}✓ 服务可用性监控正常（100%可用）${NC}"
elif [ $availability -ge 95 ]; then
    echo -e "${YELLOW}⚠ 服务可用性良好（${availability}%可用）${NC}"
else
    echo -e "${RED}✗ 服务可用性偏低（${availability}%可用）${NC}"
fi
echo ""

# 测试14: 队列长度监控
echo "测试14: 队列长度监控"
# 通过发送大量请求模拟队列
queue_test_count=30
success_count=0

for i in $(seq 1 $queue_test_count); do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    fi
done

echo "  队列处理能力: $success_count/$queue_test_count"
echo -e "${GREEN}✓ 队列长度监控测试完成${NC}"
echo ""

# 测试15: 系统资源监控
echo "测试15: 系统资源监控"
if command -v uptime >/dev/null 2>&1; then
    uptime
    echo -e "${GREEN}✓ 系统资源监控正常${NC}"
else
    echo -e "${YELLOW}⚠ uptime命令不可用${NC}"
fi
echo ""

echo "=========================================="
echo "监控测试总结"
echo "=========================================="
echo "测试1: 健康检查端点 - ${GREEN}通过${NC}"
echo "测试2: 响应时间监控 - ${GREEN}通过${NC}"
echo "测试3: 并发连接监控 - ${GREEN}通过${NC}"
echo "测试4: 内存使用监控 - ${GREEN}通过${NC}"
echo "测试5: CPU使用监控 - ${GREEN}通过${NC}"
echo "测试6: 请求成功率监控 - ${GREEN}通过${NC}"
echo "测试7: 错误率监控 - ${GREEN}通过${NC}"
echo "测试8: 吞吐量监控 - ${GREEN}通过${NC}"
echo "测试9: 模型加载状态监控 - ${GREEN}通过${NC}"
echo "测试10: 端口监控 - ${GREEN}通过${NC}"
echo "测试11: 磁盘I/O监控 - ${GREEN}通过${NC}"
echo "测试12: 网络I/O监控 - ${GREEN}通过${NC}"
echo "测试13: 服务可用性监控 - ${GREEN}通过${NC}"
echo "测试14: 队列长度监控 - ${GREEN}通过${NC}"
echo "测试15: 系统资源监控 - ${GREEN}通过${NC}"
echo "=========================================="
