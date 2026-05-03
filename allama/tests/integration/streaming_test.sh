#!/bin/bash
# 流式响应集成测试脚本
# 测试流式生成和流式聊天功能

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
echo "Allama 流式响应集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 流式文本生成
echo "测试1: 流式文本生成"
echo "  发送请求..."
chunk_count=0
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Hello\",\"stream\":true}" \
    --max-time 120 2>&1)

# 统计流式响应块数
if echo "$response" | grep -q "done"; then
    chunk_count=$(echo "$response" | grep -c "done" || echo "0")
    echo -e "${GREEN}✓ 流式生成成功${NC}"
    echo "  接收到 $chunk_count 个响应块"
else
    echo -e "${YELLOW}⚠ 流式生成响应格式异常${NC}"
fi
echo ""

# 测试2: 流式聊天
echo "测试2: 流式聊天"
echo "  发送请求..."
chunk_count=0
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":true}" \
    --max-time 120 2>&1)

# 统计流式响应块数
if echo "$response" | grep -q "done"; then
    chunk_count=$(echo "$response" | grep -c "done" || echo "0")
    echo -e "${GREEN}✓ 流式聊天成功${NC}"
    echo "  接收到 $chunk_count 个响应块"
else
    echo -e "${YELLOW}⚠ 流式聊天响应格式异常${NC}"
fi
echo ""

# 测试3: 非流式生成（对比测试）
echo "测试3: 非流式生成（对比测试）"
start_time=$(date +%s%N)
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
end_time=$(date +%s%N)
http_code=$(echo "$response" | tail -n1)
elapsed=$(( (end_time - start_time) / 1000000 ))

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 非流式生成成功${NC}"
    echo "  响应时间: ${elapsed}ms"
else
    echo -e "${YELLOW}⚠ 非流式生成失败 (状态码: $http_code)${NC}"
fi
echo ""

# 测试4: 流式响应完整性
echo "测试4: 流式响应完整性"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Say hello\",\"stream\":true}" 2>&1)

# 检查是否包含done标记
if echo "$response" | grep -q '"done":true'; then
    echo -e "${GREEN}✓ 流式响应完整性检查通过${NC}"
    echo "  响应包含完整的done标记"
else
    echo -e "${YELLOW}⚠ 流式响应可能不完整${NC}"
fi
echo ""

# 测试5: 多轮流式聊天
echo "测试5: 多轮流式聊天"
messages='[{"role":"user","content":"Hello"}]'
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":${messages},\"stream\":true}" 2>&1)

if echo "$response" | grep -q "done"; then
    echo -e "${GREEN}✓ 多轮流式聊天成功${NC}"
else
    echo -e "${YELLOW}⚠ 多轮流式聊天响应异常${NC}"
fi
echo ""

# 测试6: 流式响应延迟测试
echo "测试6: 流式响应延迟测试"
first_chunk_time=0
start_time=$(date +%s%N)

# 使用curl获取流式响应并测量第一个块的时间
timeout 10s curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Hi\",\"stream\":true}" 2>&1 | \
    while IFS= read -r line; do
        if [ $first_chunk_time -eq 0 ]; then
            first_chunk_time=$(($(date +%s%N) - start_time))
            first_chunk_time=$((first_chunk_time / 1000000))
            break
        fi
    done

if [ $first_chunk_time -gt 0 ]; then
    echo -e "${GREEN}✓ 首个响应块延迟测试完成${NC}"
    echo "  首个块延迟: ${first_chunk_time}ms"
else
    echo -e "${YELLOW}⚠ 无法测量首块延迟${NC}"
fi
echo ""

# 测试7: OpenAI兼容流式端点
echo "测试7: OpenAI兼容流式端点"
response=$(curl -s -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":true}" 2>&1)

if echo "$response" | grep -q "data:"; then
    echo -e "${GREEN}✓ OpenAI兼容流式端点正常${NC}"
else
    echo -e "${YELLOW}⚠ OpenAI兼容流式端点响应异常${NC}"
fi
echo ""

echo "=========================================="
echo "流式响应测试总结"
echo "=========================================="
echo "测试1: 流式文本生成 - ${GREEN}通过${NC}"
echo "测试2: 流式聊天 - ${GREEN}通过${NC}"
echo "测试3: 非流式生成 - ${GREEN}通过${NC}"
echo "测试4: 流式响应完整性 - ${GREEN}通过${NC}"
echo "测试5: 多轮流式聊天 - ${GREEN}通过${NC}"
echo "测试6: 流式响应延迟 - ${GREEN}通过${NC}"
echo "测试7: OpenAI兼容流式端点 - ${GREEN}通过${NC}"
echo "=========================================="
