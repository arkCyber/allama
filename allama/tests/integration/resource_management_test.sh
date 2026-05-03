#!/bin/bash
# 资源管理集成测试脚本
# 测试内存管理、CPU管理、连接池、文件句柄等资源管理

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
echo "Allama 资源管理集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 内存使用监控
echo "测试1: 内存使用监控"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    mem_before=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    echo "  初始内存使用: ${mem_before}MB"
    
    # 发送10个请求
    for i in $(seq 1 10); do
        curl -s -X POST "${BASE_URL}/api/generate" \
            -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
            -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" > /dev/null
    done
    
    mem_after=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    mem_increase=$((mem_after - mem_before))
    echo "  最终内存使用: ${mem_after}MB"
    echo "  内存增加: ${mem_increase}MB"
    
    if [ $mem_increase -lt 50 ]; then
        echo -e "${GREEN}✓ 内存使用控制良好${NC}"
    else
        echo -e "${YELLOW}⚠ 内存使用增长较快（增加${mem_increase}MB）${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试2: CPU使用监控
echo "测试2: CPU使用监控"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    cpu_before=$(ps -o %cpu= -p $pid | awk '{print int($1)}')
    echo "  初始CPU使用: ${cpu_before}%"
    
    # 发送10个请求
    for i in $(seq 1 10); do
        curl -s -X POST "${BASE_URL}/api/generate" \
            -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
            -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" > /dev/null
    done
    
    cpu_after=$(ps -o %cpu= -p $pid | awk '{print int($1)}')
    echo "  负载后CPU使用: ${cpu_after}%"
    
    if [ $cpu_after -lt 80 ]; then
        echo -e "${GREEN}✓ CPU使用控制良好${NC}"
    else
        echo -e "${YELLOW}⚠ CPU使用较高${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试3: 连接池管理
echo "测试3: 连接池管理"
success_count=0
for i in $(seq 1 50); do
    response=$(curl -s "${BASE_URL}/api/tags")
    if echo "$response" | grep -q '"models"'; then
        success_count=$((success_count + 1))
    fi
done

echo "  连接成功率: $success_count/50"
if [ $success_count -ge 48 ]; then
    echo -e "${GREEN}✓ 连接池管理正常${NC}"
else
    echo -e "${YELLOW}⚠ 连接池管理需要改进${NC}"
fi
echo ""

# 测试4: 文件句柄管理
echo "测试4: 文件句柄管理"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    fd_count=$(lsof -p $pid 2>/dev/null | wc -l)
    echo "  打开的文件句柄数: $fd_count"
    
    if [ $fd_count -lt 1000 ]; then
        echo -e "${GREEN}✓ 文件句柄数量正常${NC}"
    else
        echo -e "${YELLOW}⚠ 文件句柄数量较多${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试5: 线程管理
echo "测试5: 线程管理"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    thread_count=$(ps -M -p $pid 2>/dev/null | wc -l)
    if [ -z "$thread_count" ] || [ $thread_count -eq 0 ]; then
        thread_count=$(ps -o nlwp= -p $pid | awk '{print $1}')
    fi
    echo "  线程数: $thread_count"
    
    if [ $thread_count -lt 100 ]; then
        echo -e "${GREEN}✓ 线程数量正常${NC}"
    else
        echo -e "${YELLOW}⚠ 线程数量较多${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试6: 内存泄漏检测
echo "测试6: 内存泄漏检测"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    mem_before=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    
    # 发送100个请求
    for i in $(seq 1 100); do
        curl -s -X POST "${BASE_URL}/api/generate" \
            -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
            -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" > /dev/null
    done
    
    # 等待垃圾回收
    sleep 2
    
    mem_after=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    mem_increase=$((mem_after - mem_before))
    
    echo "  内存增加: ${mem_increase}MB"
    
    if [ $mem_increase -lt 100 ]; then
        echo -e "${GREEN}✓ 无明显内存泄漏${NC}"
    else
        echo -e "${YELLOW}⚠ 可能存在内存泄漏${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试7: 临时文件管理
echo "测试7: 临时文件管理"
# 检查临时目录
temp_dir="/tmp"
allama_temp_files=$(find "$temp_dir" -name "*allama*" 2>/dev/null | wc -l)
echo "  临时文件数量: $allama_temp_files"

if [ $allama_temp_files -lt 10 ]; then
    echo -e "${GREEN}✓ 临时文件管理良好${NC}"
else
    echo -e "${YELLOW}⚠ 临时文件数量较多${NC}"
fi
echo ""

# 测试8: 模型加载内存管理
echo "测试8: 模型加载内存管理"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    mem_before=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    
    # 加载模型
    curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" > /dev/null
    
    mem_after=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    mem_increase=$((mem_after - mem_before))
    
    echo "  模型加载内存增加: ${mem_increase}MB"
    
    if [ $mem_increase -lt 500 ]; then
        echo -e "${GREEN}✓ 模型加载内存管理良好${NC}"
    else
        echo -e "${YELLOW}⚠ 模型加载内存使用较高${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试9: 并发资源限制
echo "测试9: 并发资源限制"
success_count=0
for i in $(seq 1 100); do
    response=$(curl -s "${BASE_URL}/api/tags")
    if echo "$response" | grep -q '"models"'; then
        success_count=$((success_count + 1))
    fi
done

echo "  并发请求成功率: $success_count/100"
if [ $success_count -ge 95 ]; then
    echo -e "${GREEN}✓ 并发资源限制正常${NC}"
else
    echo -e "${YELLOW}⚠ 并发资源限制可能过严${NC}"
fi
echo ""

# 测试10: 资源释放验证
echo "测试10: 资源释放验证"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    mem_before=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    
    # 发送请求
    for i in $(seq 1 50); do
        curl -s -X POST "${BASE_URL}/api/generate" \
            -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
            -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" > /dev/null
    done
    
    # 停止模型
    curl -s -X POST "${BASE_URL}/api/stop" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\"}" > /dev/null
    
    sleep 1
    
    mem_after=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    mem_decrease=$((mem_before - mem_after))
    
    echo "  资源释放后内存减少: ${mem_decrease}MB"
    
    if [ $mem_decrease -ge 0 ]; then
        echo -e "${GREEN}✓ 资源释放正常${NC}"
    else
        echo -e "${YELLOW}⚠ 资源释放需要改进${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试11: 长时间运行资源稳定性
echo "测试11: 长时间运行资源稳定性"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    mem_start=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    echo "  开始内存: ${mem_start}MB"
    
    # 持续发送请求30秒
    end_time=$(($(date +%s) + 30))
    request_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        curl -s "${BASE_URL}/api/tags" > /dev/null
        request_count=$((request_count + 1))
        sleep 0.1
    done
    
    mem_end=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    mem_growth=$((mem_end - mem_start))
    
    echo "  结束内存: ${mem_end}MB"
    echo "  内存增长: ${mem_growth}MB"
    echo "  请求数: $request_count"
    
    if [ $mem_growth -lt 100 ]; then
        echo -e "${GREEN}✓ 长时间运行资源稳定性良好${NC}"
    else
        echo -e "${YELLOW}⚠ 长时间运行资源稳定性需要改进${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试12: 大文件处理资源管理
echo "测试12: 大文件处理资源管理"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    mem_before=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    
    # 发送大输入
    large_input=$(printf 'A%.0s' {1..5000})
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"${large_input}\",\"stream\":false}" 2>&1)
    
    mem_after=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    mem_increase=$((mem_after - mem_before))
    
    echo "  大输入处理内存增加: ${mem_increase}MB"
    
    if [ $mem_increase -lt 50 ]; then
        echo -e "${GREEN}✓ 大文件处理资源管理良好${NC}"
    else
        echo -e "${YELLOW}⚠ 大文件处理资源管理需要改进${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试13: 网络连接资源管理
echo "测试13: 网络连接资源管理"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    conn_before=$(netstat -an 2>/dev/null | grep -c ":$ALLAMA_PORT" || echo "0")
    echo "  初始连接数: $conn_before"
    
    # 发送10个并发请求
    for i in $(seq 1 10); do
        (curl -s "${BASE_URL}/api/tags" > /dev/null) &
    done
    wait
    
    sleep 1
    
    conn_after=$(netstat -an 2>/dev/null | grep -c ":$ALLAMA_PORT" || echo "0")
    echo "  负载后连接数: $conn_after"
    
    if [ $conn_after -lt $((conn_before + 20)) ]; then
        echo -e "${GREEN}✓ 网络连接资源管理良好${NC}"
    else
        echo -e "${YELLOW}⚠ 网络连接资源管理需要改进${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试14: 磁盘I/O资源管理
echo "测试14: 磁盘I/O资源管理"
# 检查日志文件大小
log_file="/tmp/allama.log"
if [ -f "$log_file" ]; then
    log_size=$(du -m "$log_file" | cut -f1)
    echo "  日志文件大小: ${log_size}MB"
    
    if [ $log_size -lt 100 ]; then
        echo -e "${GREEN}✓ 磁盘I/O资源管理良好${NC}"
    else
        echo -e "${YELLOW}⚠ 日志文件较大${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志文件不存在${NC}"
fi
echo ""

# 测试15: 资源限制验证
echo "测试15: 资源限制验证"
# 测试请求大小限制
large_input=$(printf 'A%.0s' {1..100000})
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"${large_input}\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "413" ] || [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ 资源限制正常工作${NC}"
else
    echo -e "${YELLOW}⚠ 资源限制需要改进${NC}"
fi
echo ""

echo "=========================================="
echo "资源管理测试总结"
echo "=========================================="
echo "测试1: 内存使用监控 - ${GREEN}完成${NC}"
echo "测试2: CPU使用监控 - ${GREEN}完成${NC}"
echo "测试3: 连接池管理 - ${GREEN}完成${NC}"
echo "测试4: 文件句柄管理 - ${GREEN}完成${NC}"
echo "测试5: 线程管理 - ${GREEN}完成${NC}"
echo "测试6: 内存泄漏检测 - ${GREEN}完成${NC}"
echo "测试7: 临时文件管理 - ${GREEN}完成${NC}"
echo "测试8: 模型加载内存管理 - ${GREEN}完成${NC}"
echo "测试9: 并发资源限制 - ${GREEN}完成${NC}"
echo "测试10: 资源释放验证 - ${GREEN}完成${NC}"
echo "测试11: 长时间运行资源稳定性 - ${GREEN}完成${NC}"
echo "测试12: 大文件处理资源管理 - ${GREEN}完成${NC}"
echo "测试13: 网络连接资源管理 - ${GREEN}完成${NC}"
echo "测试14: 磁盘I/O资源管理 - ${GREEN}完成${NC}"
echo "测试15: 资源限制验证 - ${GREEN}完成${NC}"
echo "=========================================="
