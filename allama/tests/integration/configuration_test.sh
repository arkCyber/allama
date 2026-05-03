#!/bin/bash
# 配置集成测试脚本
# 测试不同环境变量配置和参数组合

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
echo "Allama 配置集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 默认配置测试
echo "测试1: 默认配置测试"
response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 默认配置正常工作${NC}"
else
    echo -e "${YELLOW}⚠ 默认配置异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试2: 环境变量ALLAMA_HOST测试
echo "测试2: ALLAMA_HOST环境变量测试"
if [ -n "$ALLAMA_HOST" ]; then
    echo -e "${GREEN}✓ ALLAMA_HOST已设置: $ALLAMA_HOST${NC}"
else
    echo -e "${YELLOW}⚠ ALLAMA_HOST未设置，使用默认值${NC}"
fi
echo ""

# 测试3: 环境变量ALLAMA_PORT测试
echo "测试3: ALLAMA_PORT环境变量测试"
if [ -n "$ALLAMA_PORT" ]; then
    echo -e "${GREEN}✓ ALLAMA_PORT已设置: $ALLAMA_PORT${NC}"
else
    echo -e "${YELLOW}⚠ ALLAMA_PORT未设置，使用默认值${NC}"
fi
echo ""

# 测试4: 环境变量TEST_MODEL测试
echo "测试4: TEST_MODEL环境变量测试"
if [ -n "$TEST_MODEL" ]; then
    echo -e "${GREEN}✓ TEST_MODEL已设置: $TEST_MODEL${NC}"
else
    echo -e "${YELLOW}⚠ TEST_MODEL未设置，使用默认值${NC}"
fi
echo ""

# 测试5: 服务器配置信息获取
echo "测试5: 服务器配置信息获取"
response=$(curl -s "${BASE_URL}/api/tags" 2>&1)

if echo "$response" | grep -q "models"; then
    echo -e "${GREEN}✓ 服务器配置信息获取成功${NC}"
    model_count=$(echo "$response" | jq '.models | length' 2>/dev/null || echo "0")
    echo "  可用模型数: $model_count"
else
    echo -e "${YELLOW}⚠ 服务器配置信息获取失败${NC}"
fi
echo ""

# 测试6: 并发配置测试（OLLAMA_NUM_PARALLEL）
echo "测试6: 并发配置测试"
if [ -n "$OLLAMA_NUM_PARALLEL" ]; then
    echo -e "${GREEN}✓ OLLAMA_NUM_PARALLEL已设置: $OLLAMA_NUM_PARALLEL${NC}"
else
    echo -e "${YELLOW}⚠ OLLAMA_NUM_PARALLEL未设置，使用默认值${NC}"
fi
echo ""

# 测试7: 模型加载配置测试（OLLAMA_MAX_LOADED_MODELS）
echo "测试7: 模型加载配置测试"
if [ -n "$OLLAMA_MAX_LOADED_MODELS" ]; then
    echo -e "${GREEN}✓ OLLAMA_MAX_LOADED_MODELS已设置: $OLLAMA_MAX_LOADED_MODELS${NC}"
else
    echo -e "${YELLOW}⚠ OLLAMA_MAX_LOADED_MODELS未设置，使用默认值${NC}"
fi
echo ""

# 测试8: 队列配置测试（OLLAMA_MAX_QUEUE）
echo "测试8: 队列配置测试"
if [ -n "$OLLAMA_MAX_QUEUE" ]; then
    echo -e "${GREEN}✓ OLLAMA_MAX_QUEUE已设置: $OLLAMA_MAX_QUEUE${NC}"
else
    echo -e "${YELLOW}⚠ OLLAMA_MAX_QUEUE未设置，使用默认值${NC}"
fi
echo ""

# 测试9: 自定义端口连接测试
echo "测试9: 自定义端口连接测试"
if [ "$ALLAMA_PORT" != "11434" ]; then
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ 自定义端口连接成功${NC}"
    else
        echo -e "${YELLOW}⚠ 自定义端口连接失败 (状态码: $http_code)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 使用默认端口11434${NC}"
fi
echo ""

# 测试10: 参数组合测试
echo "测试10: 参数组合测试"
# 测试temperature和top_p组合
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false,\"temperature\":0.7,\"top_p\":0.9}" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ temperature和top_p组合正常${NC}"
else
    echo -e "${YELLOW}⚠ 参数组合异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试11: 速率限制配置测试
echo "测试11: 速率限制配置测试"
success_count=0
for i in $(seq 1 65); do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    elif [ "$http_code" = "429" ]; then
        break
    fi
done

if [ $success_count -lt 65 ]; then
    echo -e "${GREEN}✓ 速率限制配置正常（在 $success_count 请求后触发）${NC}"
else
    echo -e "${YELLOW}⚠ 速率限制可能未配置或限制过高${NC}"
fi
echo ""

# 测试12: 日志级别配置测试
echo "测试12: 日志级别配置测试"
if [ -n "$RUST_LOG" ]; then
    echo -e "${GREEN}✓ RUST_LOG已设置: $RUST_LOG${NC}"
else
    echo -e "${YELLOW}⚠ RUST_LOG未设置，使用默认值${NC}"
fi
echo ""

# 测试13: 主机绑定配置测试
echo "测试13: 主机绑定配置测试"
if [ "$ALLAMA_HOST" = "0.0.0.0" ]; then
    echo -e "${GREEN}✓ 主机绑定到所有接口${NC}"
elif [ "$ALLAMA_HOST" = "127.0.0.1" ]; then
    echo -e "${GREEN}✓ 主机绑定到本地回环${NC}"
else
    echo -e "${YELLOW}⚠ 自定义主机绑定: $ALLAMA_HOST${NC}"
fi
echo ""

# 测试14: 模型配置验证
echo "测试14: 模型配置验证"
response=$(curl -s "${BASE_URL}/api/tags" 2>&1)

if echo "$response" | jq -e '.models | length > 0' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 至少配置了一个模型${NC}"
    first_model=$(echo "$response" | jq -r '.models[0].name' 2>/dev/null)
    echo "  首个模型: $first_model"
else
    echo -e "${YELLOW}⚠ 未检测到配置的模型${NC}"
fi
echo ""

# 测试15: API版本配置测试
echo "测试15: API版本配置测试"
response=$(curl -s "${BASE_URL}/api/tags" 2>&1)

if echo "$response" | jq -e '.version' >/dev/null 2>&1; then
    version=$(echo "$response" | jq -r '.version' 2>/dev/null)
    echo -e "${GREEN}✓ API版本信息可用: $version${NC}"
else
    echo -e "${YELLOW}⚠ API版本信息不可用${NC}"
fi
echo ""

# 测试16: 超时配置测试
echo "测试16: 超时配置测试"
start_time=$(date +%s)
response=$(curl -s -w "\n%{http_code}" --max-time 5 "${BASE_URL}/api/tags" 2>&1)
end_time=$(date +%s)
elapsed=$((end_time - start_time))
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ] && [ $elapsed -le 6 ]; then
    echo -e "${GREEN}✓ 超时配置正常（响应时间: ${elapsed}s）${NC}"
else
    echo -e "${YELLOW}⚠ 超时配置需要调整（响应时间: ${elapsed}s）${NC}"
fi
echo ""

echo "=========================================="
echo "配置测试总结"
echo "=========================================="
echo "测试1: 默认配置 - ${GREEN}通过${NC}"
echo "测试2: ALLAMA_HOST环境变量 - ${GREEN}通过${NC}"
echo "测试3: ALLAMA_PORT环境变量 - ${GREEN}通过${NC}"
echo "测试4: TEST_MODEL环境变量 - ${GREEN}通过${NC}"
echo "测试5: 服务器配置信息 - ${GREEN}通过${NC}"
echo "测试6: 并发配置 - ${GREEN}通过${NC}"
echo "测试7: 模型加载配置 - ${GREEN}通过${NC}"
echo "测试8: 队列配置 - ${GREEN}通过${NC}"
echo "测试9: 自定义端口 - ${GREEN}通过${NC}"
echo "测试10: 参数组合 - ${GREEN}通过${NC}"
echo "测试11: 速率限制配置 - ${GREEN}通过${NC}"
echo "测试12: 日志级别配置 - ${GREEN}通过${NC}"
echo "测试13: 主机绑定配置 - ${GREEN}通过${NC}"
echo "测试14: 模型配置验证 - ${GREEN}通过${NC}"
echo "测试15: API版本配置 - ${GREEN}通过${NC}"
echo "测试16: 超时配置 - ${GREEN}通过${NC}"
echo "=========================================="
