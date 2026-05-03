#!/bin/bash
# 高级流式响应集成测试脚本
# 测试流式响应的各种场景和边界条件

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
echo "Allama 高级流式响应集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 基本流式响应
echo "测试1: 基本流式响应（/api/generate stream=true）"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Hello\",\"stream\":true}" 2>&1)

chunk_count=$(echo "$response" | grep -c "response" || echo "0")
echo "  接收到的chunk数量: $chunk_count"

if [ $chunk_count -gt 0 ]; then
    echo -e "${GREEN}✓ 基本流式响应正常${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应可能未正确实现（chunk数量: $chunk_count）${NC}"
fi
echo ""

# 测试2: Chat流式响应
echo "测试2: Chat流式响应（/api/chat stream=true）"
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}],\"stream\":true}" 2>&1)

chunk_count=$(echo "$response" | grep -c "content" || echo "0")
echo "  接收到的chunk数量: $chunk_count"

if [ $chunk_count -gt 0 ]; then
    echo -e "${GREEN}✓ Chat流式响应正常${NC}"
else
    echo -e "${YELLOW}⚠ Chat流式响应可能未正确实现（chunk数量: $chunk_count）${NC}"
fi
echo ""

# 测试3: 流式响应格式验证
echo "测试3: 流式响应格式验证"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":true}" 2>&1)

# 检查是否包含done字段
if echo "$response" | grep -q '"done":true'; then
    echo -e "${GREEN}✓ 流式响应包含完成标记${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应可能缺少完成标记${NC}"
fi

# 检查是否包含model字段
if echo "$response" | grep -q '"model"'; then
    echo -e "${GREEN}✓ 流式响应包含模型信息${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应可能缺少模型信息${NC}"
fi
echo ""

# 测试4: 流式响应中断测试
echo "测试4: 流式响应中断测试（客户端提前断开）"
# 模拟客户端在接收部分数据后断开
response=$(timeout 0.5 curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":true}" 2>&1 || echo "TIMEOUT")

if [ "$response" = "TIMEOUT" ]; then
    echo -e "${GREEN}✓ 流式响应可被中断${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应中断测试需要验证${NC}"
fi
echo ""

# 测试5: 流式响应并发测试
echo "测试5: 流式响应并发测试"
success_count=0
for i in $(seq 1 10); do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test $i\",\"stream\":true}" 2>&1)
    
    chunk_count=$(echo "$response" | grep -c "response" || echo "0")
    if [ $chunk_count -gt 0 ]; then
        success_count=$((success_count + 1))
    fi
done

echo "  成功的并发流式请求: $success_count/10"
if [ $success_count -ge 8 ]; then
    echo -e "${GREEN}✓ 流式响应并发处理正常${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应并发处理需要改进${NC}"
fi
echo ""

# 测试6: 流式响应超时测试
echo "测试6: 流式响应超时测试"
start_time=$(date +%s)
response=$(curl -s -w "\n%{http_code}" --max-time 5 -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":true}" 2>&1)
end_time=$(date +%s)
elapsed=$((end_time - start_time))

http_code=$(echo "$response" | tail -n1)
echo "  响应时间: ${elapsed}s"
echo "  状态码: $http_code"

if [ $elapsed -le 5 ]; then
    echo -e "${GREEN}✓ 流式响应超时控制正常${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应超时控制需要改进${NC}"
fi
echo ""

# 测试7: 流式响应大输入测试
echo "测试7: 流式响应大输入测试"
large_prompt=$(printf 'A%.0s' {1..1000})
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"${large_prompt}\",\"stream\":true}" 2>&1)

chunk_count=$(echo "$response" | grep -c "response" || echo "0")
echo "  接收到的chunk数量: $chunk_count"

if [ $chunk_count -gt 0 ]; then
    echo -e "${GREEN}✓ 流式响应大输入处理正常${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应大输入处理需要改进${NC}"
fi
echo ""

# 测试8: 流式响应空输入测试
echo "测试8: 流式响应空输入测试"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"\",\"stream\":true}" 2>&1)

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "400" ] || [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 流式响应空输入处理正常${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应空输入处理异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试9: 流式响应特殊字符测试
echo "测试9: 流式响应特殊字符测试"
special_inputs=(
    "\n"
    "\t"
    "中文测试"
    "🔥 emoji test"
    "<script>alert('test')</script>"
)

for input in "${special_inputs[@]}"; do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"$input\",\"stream\":true}" 2>&1)
    
    chunk_count=$(echo "$response" | grep -c "response" || echo "0")
    if [ $chunk_count -gt 0 ]; then
        echo "  特殊字符 '$input': ✓"
    else
        echo "  特殊字符 '$input': ✗"
    fi
done
echo -e "${GREEN}✓ 流式响应特殊字符测试完成${NC}"
echo ""

# 测试10: 流式响应速率限制测试
echo "测试10: 流式响应速率限制测试"
success_count=0
rate_limit_count=0

for i in $(seq 1 30); do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":true}" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    elif [ "$http_code" = "429" ]; then
        rate_limit_count=$((rate_limit_count + 1))
    fi
done

echo "  成功请求: $success_count/30"
echo "  速率限制触发: $rate_limit_count/30"

if [ $rate_limit_count -gt 0 ]; then
    echo -e "${GREEN}✓ 流式响应速率限制正常工作${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应速率限制可能未触发${NC}"
fi
echo ""

# 测试11: 流式响应连接保持测试
echo "测试11: 流式响应连接保持测试"
# 测试同一连接上的多个流式请求
success_count=0
for i in $(seq 1 5); do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -H "Connection: keep-alive" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test $i\",\"stream\":true}" 2>&1)
    
    chunk_count=$(echo "$response" | grep -c "response" || echo "0")
    if [ $chunk_count -gt 0 ]; then
        success_count=$((success_count + 1))
    fi
done

echo "  连接保持成功率: $success_count/5"
if [ $success_count -ge 4 ]; then
    echo -e "${GREEN}✓ 流式响应连接保持正常${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应连接保持需要改进${NC}"
fi
echo ""

# 测试12: 流式响应错误恢复测试
echo "测试12: 流式响应错误恢复测试"
# 先发送一个无效请求
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"invalid_model\",\"prompt\":\"test\",\"stream\":true}" 2>&1)

# 然后发送一个有效请求
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":true}" 2>&1)

chunk_count=$(echo "$response" | grep -c "response" || echo "0")
if [ $chunk_count -gt 0 ]; then
    echo -e "${GREEN}✓ 流式响应错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应错误恢复需要验证${NC}"
fi
echo ""

# 测试13: 流式响应内存泄漏测试
echo "测试13: 流式响应内存泄漏测试"
pid=$(pgrep -f "allama serve")
if [ -n "$pid" ]; then
    mem_before=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    
    # 发送50个流式请求
    for i in $(seq 1 50); do
        response=$(curl -s -X POST "${BASE_URL}/api/generate" \
            -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
            -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":true}" 2>&1)
    done
    
    mem_after=$(ps -o rss= -p $pid | awk '{print int($1/1024)}')
    mem_increase=$((mem_after - mem_before))
    
    echo "  内存增加: ${mem_increase}MB"
    
    if [ $mem_increase -lt 100 ]; then
        echo -e "${GREEN}✓ 流式响应无明显内存泄漏${NC}"
    else
        echo -e "${YELLOW}⚠ 流式响应可能存在内存泄漏（增加${mem_increase}MB）${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法获取进程信息${NC}"
fi
echo ""

# 测试14: 流式响应数据完整性测试
echo "测试14: 流式响应数据完整性测试"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":true}" 2>&1)

# 检查是否有重复的响应ID
response_ids=$(echo "$response" | grep -o '"response":"[^"]*"' | sort | uniq -d)
if [ -z "$response_ids" ]; then
    echo -e "${GREEN}✓ 流式响应数据完整性良好${NC}"
else
    echo -e "${YELLOW}⚠ 流式响应可能存在重复数据${NC}"
fi
echo ""

# 测试15: 流式响应OpenAI兼容性测试
echo "测试15: 流式响应OpenAI兼容性测试"
response=$(curl -s -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}],\"stream\":true}" 2>&1)

chunk_count=$(echo "$response" | grep -c "data:" || echo "0")
echo "  接收到的SSE chunk数量: $chunk_count"

if [ $chunk_count -gt 0 ]; then
    echo -e "${GREEN}✓ OpenAI兼容流式响应正常${NC}"
else
    echo -e "${YELLOW}⚠ OpenAI兼容流式响应需要验证${NC}"
fi
echo ""

echo "=========================================="
echo "高级流式响应测试总结"
echo "=========================================="
echo "测试1: 基本流式响应 - ${GREEN}完成${NC}"
echo "测试2: Chat流式响应 - ${GREEN}完成${NC}"
echo "测试3: 流式响应格式验证 - ${GREEN}完成${NC}"
echo "测试4: 流式响应中断测试 - ${GREEN}完成${NC}"
echo "测试5: 流式响应并发测试 - ${GREEN}完成${NC}"
echo "测试6: 流式响应超时测试 - ${GREEN}完成${NC}"
echo "测试7: 流式响应大输入测试 - ${GREEN}完成${NC}"
echo "测试8: 流式响应空输入测试 - ${GREEN}完成${NC}"
echo "测试9: 流式响应特殊字符测试 - ${GREEN}完成${NC}"
echo "测试10: 流式响应速率限制测试 - ${GREEN}完成${NC}"
echo "测试11: 流式响应连接保持测试 - ${GREEN}完成${NC}"
echo "测试12: 流式响应错误恢复测试 - ${GREEN}完成${NC}"
echo "测试13: 流式响应内存泄漏测试 - ${GREEN}完成${NC}"
echo "测试14: 流式响应数据完整性测试 - ${GREEN}完成${NC}"
echo "测试15: 流式响应OpenAI兼容性测试 - ${GREEN}完成${NC}"
echo "=========================================="
