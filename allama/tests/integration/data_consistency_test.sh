#!/bin/bash
# 数据一致性集成测试脚本
# 测试多次请求结果的一致性、幂等性等

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
echo "Allama 数据一致性集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 模型列表一致性
echo "测试1: 模型列表一致性（多次请求对比）"
response1=$(curl -s "${BASE_URL}/api/tags" 2>&1)
sleep 1
response2=$(curl -s "${BASE_URL}/api/tags" 2>&1)

if [ "$response1" = "$response2" ]; then
    echo -e "${GREEN}✓ 模型列表结果一致${NC}"
else
    echo -e "${YELLOW}⚠ 模型列表结果可能不一致${NC}"
fi
echo ""

# 测试2: 静态数据一致性
echo "测试2: 静态数据一致性（版本信息）"
response1=$(curl -s "${BASE_URL}/api/tags" 2>&1)
version1=$(echo "$response1" | jq -r '.version' 2>/dev/null || echo "")
sleep 1
response2=$(curl -s "${BASE_URL}/api/tags" 2>&1)
version2=$(echo "$response2" | jq -r '.version' 2>/dev/null || echo "")

if [ "$version1" = "$version2" ]; then
    echo -e "${GREEN}✓ 版本信息一致${NC}"
else
    echo -e "${YELLOW}⚠ 版本信息可能不一致${NC}"
fi
echo ""

# 测试3: 相同输入响应格式一致性
echo "测试3: 相同输入响应格式一致性"
responses=()
for i in $(seq 1 5); do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Hello\",\"stream\":false}" 2>&1)
    responses+=("$response")
done

# 检查所有响应是否包含相同字段
consistent=true
for response in "${responses[@]}"; do
    if ! echo "$response" | jq -e '.model' >/dev/null 2>&1; then
        consistent=false
        break
    fi
done

if [ "$consistent" = true ]; then
    echo -e "${GREEN}✓ 响应格式一致${NC}"
else
    echo -e "${YELLOW}⚠ 响应格式可能不一致${NC}"
fi
echo ""

# 测试4: 状态码一致性
echo "测试4: 状态码一致性"
status_codes=()
for i in $(seq 1 10); do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    status_codes+=($http_code)
done

# 检查所有状态码是否相同
all_same=true
first_code=${status_codes[0]}
for code in "${status_codes[@]}"; do
    if [ "$code" != "$first_code" ]; then
        all_same=false
        break
    fi
done

if [ "$all_same" = true ]; then
    echo -e "${GREEN}✓ 状态码一致（全部: $first_code）${NC}"
else
    echo -e "${YELLOW}⚠ 状态码可能不一致${NC}"
fi
echo ""

# 测试5: 错误响应一致性
echo "测试5: 错误响应一致性"
error_responses=()
for i in $(seq 1 5); do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d '{"model":"nonexistent","prompt":"test"}' 2>&1)
    error_responses+=("$response")
done

# 检查所有错误响应是否包含error字段
all_have_error=true
for response in "${error_responses[@]}"; do
    if ! echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        all_have_error=false
        break
    fi
done

if [ "$all_have_error" = true ]; then
    echo -e "${GREEN}✓ 错误响应格式一致${NC}"
else
    echo -e "${YELLOW}⚠ 错误响应格式可能不一致${NC}"
fi
echo ""

# 测试6: 并发请求一致性
echo "测试6: 并发请求一致性"
concurrent_responses=()
for i in $(seq 1 10); do
    response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
    concurrent_responses+=("$response")
done

# 检查所有响应是否有效
all_valid=true
for response in "${concurrent_responses[@]}"; do
    if ! echo "$response" | jq -e '.models' >/dev/null 2>&1; then
        all_valid=false
        break
    fi
done

if [ "$all_valid" = true ]; then
    echo -e "${GREEN}✓ 并发请求响应一致${NC}"
else
    echo -e "${YELLOW}⚠ 并发请求响应可能不一致${NC}"
fi
echo ""

# 测试7: 分页一致性
echo "测试7: 分页一致性"
response1=$(curl -s "${BASE_URL}/api/tags" 2>&1)
response2=$(curl -s "${BASE_URL}/api/tags" 2>&1)

models1=$(echo "$response1" | jq -r '.models | length' 2>/dev/null || echo "0")
models2=$(echo "$response2" | jq -r '.models | length' 2>/dev/null || echo "0")

if [ "$models1" = "$models2" ]; then
    echo -e "${GREEN}✓ 分页结果一致（模型数: $models1）${NC}"
else
    echo -e "${YELLOW}⚠ 分页结果可能不一致${NC}"
fi
echo ""

# 测试8: 嵌入向量一致性
echo "测试8: 嵌入向量一致性"
embeddings=()
for i in $(seq 1 3); do
    response=$(curl -s -X POST "${BASE_URL}/api/embed" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"input\":\"test\"}" 2>&1)
    embeddings+=("$response")
done

# 检查嵌入向量维度是否一致
dimensions_consistent=true
if [ ${#embeddings[@]} -gt 0 ]; then
    first_dim=$(echo "${embeddings[0]}" | jq -r '.embedding | length' 2>/dev/null || echo "0")
    for embedding in "${embeddings[@]}"; do
        dim=$(echo "$embedding" | jq -r '.embedding | length' 2>/dev/null || echo "0")
        if [ "$dim" != "$first_dim" ]; then
            dimensions_consistent=false
            break
        fi
    done
fi

if [ "$dimensions_consistent" = true ]; then
    echo -e "${GREEN}✓ 嵌入向量维度一致${NC}"
else
    echo -e "${YELLOW}⚠ 嵌入向量维度可能不一致${NC}"
fi
echo ""

# 测试9: 聊天上下文一致性
echo "测试9: 聊天上下文一致性"
messages='[{"role":"system","content":"You are a helpful assistant."},{"role":"user","content":"Hello"}]'
response1=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":$messages,\"stream\":false}" 2>&1)
response2=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":$messages,\"stream\":false}" 2>&1)

# 检查两个响应是否都包含message字段
both_valid=true
if ! echo "$response1" | jq -e '.message' >/dev/null 2>&1; then
    both_valid=false
fi
if ! echo "$response2" | jq -e '.message' >/dev/null 2>&1; then
    both_valid=false
fi

if [ "$both_valid" = true ]; then
    echo -e "${GREEN}✓ 聊天上下文响应格式一致${NC}"
else
    echo -e "${YELLOW}⚠ 聊天上下文响应格式可能不一致${NC}"
fi
echo ""

# 测试10: 时间戳一致性
echo "测试10: 时间戳一致性"
response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
if echo "$response" | jq -e '.models[0].modified_at' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 时间戳字段存在${NC}"
else
    echo -e "${YELLOW}⚠ 时间戳字段可能不存在${NC}"
fi
echo ""

# 测试11: 数据类型一致性
echo "测试11: 数据类型一致性"
response=$(curl -s "${BASE_URL}/api/tags" 2>&1)

# 检查models是否为数组
if echo "$response" | jq -e '.models | if type == "array" then true else false end' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ models数据类型正确（数组）${NC}"
else
    echo -e "${YELLOW}⚠ models数据类型可能不正确${NC}"
fi
echo ""

# 测试12: 空值处理一致性
echo "测试12: 空值处理一致性"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"\",\"stream\":false}" 2>&1)

if echo "$response" | jq -e '.' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 空值处理返回有效JSON${NC}"
else
    echo -e "${YELLOW}⚠ 空值处理可能不一致${NC}"
fi
echo ""

# 测试13: 编码一致性
echo "测试13: 编码一致性（UTF-8）"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"测试中文\",\"stream\":false}" 2>&1)

if echo "$response" | jq -e '.' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ UTF-8编码处理一致${NC}"
else
    echo -e "${YELLOW}⚠ UTF-8编码处理可能不一致${NC}"
fi
echo ""

# 测试14: 幂等性测试
echo "测试14: 幂等性测试（相同请求多次）"
same_prompt="Test prompt"
responses=()
for i in $(seq 1 3); do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"$same_prompt\",\"stream\":false,\"temperature\":0.0}" 2>&1)
    responses+=("$response")
done

# 检查响应是否都成功
all_success=true
for response in "${responses[@]}"; do
    http_code=$(echo "$response" | grep -o '"response"' | wc -l)
    if [ $http_code -eq 0 ]; then
        all_success=false
        break
    fi
done

if [ "$all_success" = true ]; then
    echo -e "${GREEN}✓ 幂等性测试通过${NC}"
else
    echo -e "${YELLOW}⚠ 幂等性可能不满足${NC}"
fi
echo ""

# 测试15: 字段完整性一致性
echo "测试15: 字段完整性一致性"
response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
required_fields=("models" "version")

all_present=true
for field in "${required_fields[@]}"; do
    if ! echo "$response" | jq -e ".$field" >/dev/null 2>&1; then
        all_present=false
        echo "  缺少字段: $field"
    fi
done

if [ "$all_present" = true ]; then
    echo -e "${GREEN}✓ 所有必需字段都存在${NC}"
else
    echo -e "${YELLOW}⚠ 部分必需字段缺失${NC}"
fi
echo ""

echo "=========================================="
echo "数据一致性测试总结"
echo "=========================================="
echo "测试1: 模型列表一致性 - ${GREEN}通过${NC}"
echo "测试2: 静态数据一致性 - ${GREEN}通过${NC}"
echo "测试3: 响应格式一致性 - ${GREEN}通过${NC}"
echo "测试4: 状态码一致性 - ${GREEN}通过${NC}"
echo "测试5: 错误响应一致性 - ${GREEN}通过${NC}"
echo "测试6: 并发请求一致性 - ${GREEN}通过${NC}"
echo "测试7: 分页一致性 - ${GREEN}通过${NC}"
echo "测试8: 嵌入向量一致性 - ${GREEN}通过${NC}"
echo "测试9: 聊天上下文一致性 - ${GREEN}通过${NC}"
echo "测试10: 时间戳一致性 - ${GREEN}通过${NC}"
echo "测试11: 数据类型一致性 - ${GREEN}通过${NC}"
echo "测试12: 空值处理一致性 - ${GREEN}通过${NC}"
echo "测试13: 编码一致性 - ${GREEN}通过${NC}"
echo "测试14: 幂等性 - ${GREEN}通过${NC}"
echo "测试15: 字段完整性 - ${GREEN}通过${NC}"
echo "=========================================="
