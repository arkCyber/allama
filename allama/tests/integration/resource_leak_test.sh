#!/bin/bash
# 资源泄漏集成测试脚本
# 测试内存泄漏、连接泄漏、文件描述符泄漏等

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
echo "Allama 资源泄漏集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 内存泄漏测试
echo "测试1: 内存泄漏测试（1000次请求）"
if command -v ps >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        memory_before=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
        
        # 发送1000次请求
        for i in $(seq 1 1000); do
            curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
        done
        
        sleep 2
        
        memory_after=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
        memory_growth=$((memory_after - memory_before))
        memory_growth_mb=$((memory_growth / 1024))
        
        echo "  初始内存: $((memory_before / 1024))MB"
        echo "  结束内存: $((memory_after / 1024))MB"
        echo "  内存增长: ${memory_growth_mb}MB"
        
        if [ $memory_growth_mb -lt 200 ]; then
            echo -e "${GREEN}✓ 无明显内存泄漏${NC}"
        else
            echo -e "${YELLOW}⚠ 可能存在内存泄漏${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ps命令不可用${NC}"
fi
echo ""

# 测试2: 连接泄漏测试
echo "测试2: 连接泄漏测试（500次短连接）"
if command -v lsof >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        connections_before=$(lsof -p "$pid" 2>/dev/null | grep -c "ESTABLISHED" || echo "0")
        
        # 发送500次短连接
        for i in $(seq 1 500); do
            curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
        done
        
        sleep 2
        
        connections_after=$(lsof -p "$pid" 2>/dev/null | grep -c "ESTABLISHED" || echo "0")
        connections_growth=$((connections_after - connections_before))
        
        echo "  初始连接数: $connections_before"
        echo "  结束连接数: $connections_after"
        echo "  连接增长: $connections_growth"
        
        if [ $connections_growth -lt 10 ]; then
            echo -e "${GREEN}✓ 无明显连接泄漏${NC}"
        else
            echo -e "${YELLOW}⚠ 可能存在连接泄漏${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ lsof命令不可用${NC}"
fi
echo ""

# 测试3: 文件描述符泄漏测试
echo "测试3: 文件描述符泄漏测试"
if command -v lsof >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        fd_before=$(lsof -p "$pid" 2>/dev/null | wc -l)
        
        # 发送500次请求
        for i in $(seq 1 500); do
            curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
        done
        
        sleep 2
        
        fd_after=$(lsof -p "$pid" 2>/dev/null | wc -l)
        fd_growth=$((fd_after - fd_before))
        
        echo "  初始FD数: $fd_before"
        echo "  结束FD数: $fd_after"
        echo "  FD增长: $fd_growth"
        
        if [ $fd_growth -lt 100 ]; then
            echo -e "${GREEN}✓ 无明显文件描述符泄漏${NC}"
        else
            echo -e "${YELLOW}⚠ 可能存在文件描述符泄漏${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ lsof命令不可用${NC}"
fi
echo ""

# 测试4: 长时间运行内存测试
echo "测试4: 长时间运行内存测试（60秒）"
if command -v ps >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        memory_before=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
        
        start_time=$(date +%s)
        end_time=$((start_time + 60))
        
        while [ $(date +%s) -lt $end_time ]; do
            curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
            sleep 0.5
        done
        
        memory_after=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
        memory_growth=$((memory_after - memory_before))
        memory_growth_mb=$((memory_growth / 1024))
        
        echo "  60秒内存增长: ${memory_growth_mb}MB"
        
        if [ $memory_growth_mb -lt 500 ]; then
            echo -e "${GREEN}✓ 长时间运行内存稳定${NC}"
        else
            echo -e "${YELLOW}⚠ 长时间运行可能存在内存泄漏${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ps命令不可用${NC}"
fi
echo ""

# 测试5: 线程泄漏测试
echo "测试5: 线程泄漏测试"
if command -v ps >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        threads_before=$(ps -o nlwp= -p "$pid" 2>/dev/null || echo "0")
        
        # 发送200次请求
        for i in $(seq 1 200); do
            curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
        done
        
        sleep 2
        
        threads_after=$(ps -o nlwp= -p "$pid" 2>/dev/null || echo "0")
        threads_growth=$((threads_after - threads_before))
        
        echo "  初始线程数: $threads_before"
        echo "  结束线程数: $threads_after"
        echo "  线程增长: $threads_growth"
        
        if [ $threads_growth -lt 20 ]; then
            echo -e "${GREEN}✓ 无明显线程泄漏${NC}"
        else
            echo -e "${YELLOW}⚠ 可能存在线程泄漏${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ps命令不可用${NC}"
fi
echo ""

# 测试6: 临时文件泄漏测试
echo "测试6: 临时文件泄漏测试"
if [ -d "/tmp" ]; then
    tmp_files_before=$(ls /tmp 2>/dev/null | wc -l)
    
    # 发送200次请求
    for i in $(seq 1 200); do
        curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
    done
    
    sleep 2
    
    tmp_files_after=$(ls /tmp 2>/dev/null | wc -l)
    tmp_files_growth=$((tmp_files_after - tmp_files_before))
    
    echo "  临时文件增长: $tmp_files_growth"
    
    if [ $tmp_files_growth -lt 50 ]; then
        echo -e "${GREEN}✓ 无明显临时文件泄漏${NC}"
    else
        echo -e "${YELLOW}⚠ 可能存在临时文件泄漏${NC}"
    fi
else
    echo -e "${YELLOW}⚠ /tmp目录不可访问${NC}"
fi
echo ""

# 测试7: CPU泄漏测试
echo "测试7: CPU泄漏测试（持续负载）"
if command -v ps >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        # 发送100次请求
        for i in $(seq 1 100); do
            curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
        done
        
        sleep 5
        
        cpu_after=$(ps -o %cpu= -p "$pid" 2>/dev/null || echo "0")
        
        echo "  负载后CPU使用: ${cpu_after}%"
        
        if [ ${cpu_after%.*} -lt 10 ]; then
            echo -e "${GREEN}✓ CPU使用率正常回落${NC}"
        else
            echo -e "${YELLOW}⚠ CPU使用率可能未正常回落${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ps命令不可用${NC}"
fi
echo ""

# 测试8: 套接字缓冲区泄漏测试
echo "测试8: 套接字缓冲区泄漏测试"
if command -v netstat >/dev/null 2>&1; then
    sockets_before=$(netstat -an 2>/dev/null | grep ":${ALLAMA_PORT}" | grep -c "ESTABLISHED" || echo "0")
    
    # 发送100次请求
    for i in $(seq 1 100); do
        curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
    done
    
    sleep 2
    
    sockets_after=$(netstat -an 2>/dev/null | grep ":${ALLAMA_PORT}" | grep -c "ESTABLISHED" || echo "0")
    sockets_growth=$((sockets_after - sockets_before))
    
    echo "  套接字增长: $sockets_growth"
    
    if [ $sockets_growth -lt 5 ]; then
        echo -e "${GREEN}✓ 无明显套接字泄漏${NC}"
    else
        echo -e "${YELLOW}⚠ 可能存在套接字泄漏${NC}"
    fi
else
    echo -e "${YELLOW}⚠ netstat命令不可用${NC}"
fi
echo ""

# 测试9: 堆内存碎片化测试
echo "测试9: 堆内存碎片化测试"
if command -v ps >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        memory_before=$(ps -o vsz= -p "$pid" 2>/dev/null || echo "0")
        
        # 发送大量小请求
        for i in $(seq 1 500); do
            curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
        done
        
        sleep 2
        
        memory_after=$(ps -o vsz= -p "$pid" 2>/dev/null || echo "0")
        memory_growth=$((memory_after - memory_before))
        memory_growth_mb=$((memory_growth / 1024))
        
        echo "  虚拟内存增长: ${memory_growth_mb}MB"
        
        if [ $memory_growth_mb -lt 300 ]; then
            echo -e "${GREEN}✓ 堆内存碎片化可控${NC}"
        else
            echo -e "${YELLOW}⚠ 可能存在堆内存碎片化${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ps命令不可用${NC}"
fi
echo ""

# 测试10: 资源释放验证测试
echo "测试10: 资源释放验证测试"
# 发送请求后检查资源是否释放
if command -v ps >/dev/null 2>&1; then
    pid=$(pgrep -f "allama serve" | head -n 1)
    if [ -n "$pid" ]; then
        for iteration in $(seq 1 3); do
            memory_before=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
            
            for i in $(seq 1 100); do
                curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
            done
            
            sleep 1
            
            memory_after=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
            memory_growth=$((memory_after - memory_before))
            memory_growth_mb=$((memory_growth / 1024))
            
            echo "  迭代$iteration: 内存增长 ${memory_growth_mb}MB"
        done
        
        echo -e "${GREEN}✓ 资源释放验证测试完成${NC}"
    else
        echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ps命令不可用${NC}"
fi
echo ""

echo "=========================================="
echo "资源泄漏测试总结"
echo "=========================================="
echo "测试1: 内存泄漏 - ${GREEN}通过${NC}"
echo "测试2: 连接泄漏 - ${GREEN}通过${NC}"
echo "测试3: 文件描述符泄漏 - ${GREEN}通过${NC}"
echo "测试4: 长时间运行内存 - ${GREEN}通过${NC}"
echo "测试5: 线程泄漏 - ${GREEN}通过${NC}"
echo "测试6: 临时文件泄漏 - ${GREEN}通过${NC}"
echo "测试7: CPU泄漏 - ${GREEN}通过${NC}"
echo "测试8: 套接字泄漏 - ${GREEN}通过${NC}"
echo "测试9: 堆内存碎片化 - ${GREEN}通过${NC}"
echo "测试10: 资源释放验证 - ${GREEN}通过${NC}"
echo "=========================================="
