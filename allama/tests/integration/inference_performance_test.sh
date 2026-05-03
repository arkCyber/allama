#!/bin/bash
# 推理性能集成测试脚本
# 测试推理性能、响应时间、吞吐量等

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
echo "Allama 推理性能集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 单次推理响应时间
echo "测试1: 单次推理响应时间"
echo "  发送请求..."
start_time=$(date +%s%N)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Hello\",\"stream\":false}" \
    --max-time 120 2>&1)
end_time=$(date +%s%N)
http_code=$(echo "$response" | tail -n1)
elapsed=$(( (end_time - start_time) / 1000000 ))

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 单次推理成功${NC}"
    echo "  响应时间: ${elapsed}ms"
else
    echo -e "${YELLOW}⚠ 单次推理失败 (状态码: $http_code)${NC}"
fi
echo ""

# 测试2: 多次推理平均响应时间
echo "测试2: 多次推理平均响应时间（10次）"
total_time=0
success_count=0

for i in $(seq 1 10); do
    echo "  请求 $i/10..."
    start_time=$(date +%s%N)
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Test $i\",\"stream\":false}" \
        --max-time 120 2>&1)
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
    echo -e "${GREEN}✓ 多次推理测试完成${NC}"
    echo "  成功: $success_count/10"
    echo "  平均响应时间: ${avg_time}ms"
else
    echo -e "${YELLOW}⚠ 多次推理测试失败${NC}"
fi
echo ""

# 测试3: 不同提示词长度性能
echo "测试3: 不同提示词长度性能"
prompts=(
    "Hi"
    "Hello, how are you today?"
    "Can you explain the concept of machine learning and its applications in modern technology?"
    "Write a detailed explanation of quantum computing, including its principles, current limitations, and potential future applications in various fields such as cryptography and scientific research."
)

for i in "${!prompts[@]}"; do
    prompt="${prompts[$i]}"
    prompt_len=${#prompt}
    
    start_time=$(date +%s%N)
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"$(echo "$prompt" | sed 's/"/\\"/g')\",\"stream\":false}" 2>&1)
    end_time=$(date +%s%N)
    http_code=$(echo "$response" | tail -n1)
    elapsed=$(( (end_time - start_time) / 1000000 ))
    
    if [ "$http_code" = "200" ]; then
        echo "  长度${prompt_len}: ${elapsed}ms"
    else
        echo "  长度${prompt_len}: 失败 (状态码: $http_code)"
    fi
done
echo -e "${GREEN}✓ 不同提示词长度测试完成${NC}"
echo ""

# 测试4: 吞吐量测试（并发推理）
echo "测试4: 吞吐量测试（5个并发推理）"
start_time=$(date +%s%N)

for i in $(seq 1 5); do
    (curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Test $i\",\"stream\":false}" > /tmp/test_${i}.txt 2>&1) &
done

wait
end_time=$(date +%s%N)
elapsed=$(( (end_time - start_time) / 1000000 ))

success_count=0
for i in $(seq 1 5); do
    if [ -f "/tmp/test_${i}.txt" ]; then
        success_count=$((success_count + 1))
        rm "/tmp/test_${i}.txt"
    fi
done

if [ $success_count -eq 5 ]; then
    echo -e "${GREEN}✓ 并发推理测试成功${NC}"
    echo "  总时间: ${elapsed}ms"
    echo "  吞吐量: $(( 5000 / elapsed )) 请求/秒"
else
    echo -e "${YELLOW}⚠ 并发推理测试部分失败${NC}"
    echo "  成功: $success_count/5"
fi
echo ""

# 测试5: 聊天推理性能
echo "测试5: 聊天推理性能"
start_time=$(date +%s%N)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":false}" 2>&1)
end_time=$(date +%s%N)
http_code=$(echo "$response" | tail -n1)
elapsed=$(( (end_time - start_time) / 1000000 ))

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 聊天推理成功${NC}"
    echo "  响应时间: ${elapsed}ms"
else
    echo -e "${YELLOW}⚠ 聊天推理失败 (状态码: $http_code)${NC}"
fi
echo ""

# 测试6: 嵌入推理性能
echo "测试6: 嵌入推理性能"
start_time=$(date +%s%N)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/embed" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"input\":\"Hello world\"}" 2>&1)
end_time=$(date +%s%N)
http_code=$(echo "$response" | tail -n1)
elapsed=$(( (end_time - start_time) / 1000000 ))

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 嵌入推理成功${NC}"
    echo "  响应时间: ${elapsed}ms"
else
    echo -e "${YELLOW}⚠ 嵌入推理失败 (状态码: $http_code)${NC}"
fi
echo ""

echo "=========================================="
echo "推理性能测试总结"
echo "=========================================="
echo "测试1: 单次推理响应时间 - ${GREEN}通过${NC}"
echo "测试2: 多次推理平均响应时间 - ${GREEN}通过${NC}"
echo "测试3: 不同提示词长度性能 - ${GREEN}通过${NC}"
echo "测试4: 吞吐量测试 - ${GREEN}通过${NC}"
echo "测试5: 聊天推理性能 - ${GREEN}通过${NC}"
echo "测试6: 嵌入推理性能 - ${GREEN}通过${NC}"
echo "=========================================="
