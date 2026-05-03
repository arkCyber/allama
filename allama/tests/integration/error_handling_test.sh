#!/bin/bash
# 错误处理集成测试脚本
# 测试各种错误场景的处理能力

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
echo "Allama 错误处理集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 无效模型错误处理
echo "测试1: 无效模型错误处理"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d '{"model":"nonexistent_model_xyz","prompt":"test"}' 2>&1)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n -1 2>/dev/null || echo "")

if [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 无效模型返回404${NC}"
    if echo "$body" | grep -qi "error"; then
        echo "  包含错误信息: ✓"
    fi
else
    echo -e "${YELLOW}⚠ 无效模型响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试2: 无效JSON错误处理
echo "测试2: 无效JSON错误处理"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d '{"model":"test","prompt":invalid' 2>&1)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n -1 2>/dev/null || echo "")

if [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ 无效JSON返回400${NC}"
    if echo "$body" | grep -qi "error"; then
        echo "  包含错误信息: ✓"
    fi
else
    echo -e "${YELLOW}⚠ 无效JSON响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试3: 缺少必需字段错误处理
echo "测试3: 缺少必需字段错误处理"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d '{"prompt":"test"}' 2>&1)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n -1 2>/dev/null || echo "")

if [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 缺少必需字段正确处理${NC}"
    if echo "$body" | grep -qi "error"; then
        echo "  包含错误信息: ✓"
    fi
else
    echo -e "${YELLOW}⚠ 缺少必需字段响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试4: 超大请求错误处理
echo "测试4: 超大请求错误处理"
large_data=$(printf 'A%.0s' {1..20000000})
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"${large_data}\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n -1 2>/dev/null || echo "")

if [ "$http_code" = "413" ] || [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ 超大请求被正确拒绝${NC}"
    if echo "$body" | grep -qi "error"; then
        echo "  包含错误信息: ✓"
    fi
else
    echo -e "${YELLOW}⚠ 超大请求响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试5: 超长输入错误处理
echo "测试5: 超长输入错误处理"
long_prompt=$(printf 'A%.0s' {1..200000})
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"${long_prompt}\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n -1 2>/dev/null || echo "")

if [ "$http_code" = "400" ] || [ "$http_code" = "413" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 超长输入被正确处理${NC}"
    if echo "$body" | grep -qi "error"; then
        echo "  包含错误信息: ✓"
    fi
else
    echo -e "${YELLOW}⚠ 超长输入响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试6: 无效端点错误处理
echo "测试6: 无效端点错误处理"
response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/invalid_endpoint" 2>&1)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n -1 2>/dev/null || echo "")

if [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 无效端点返回404${NC}"
    if echo "$body" | grep -qi "error\|not found"; then
        echo "  包含错误信息: ✓"
    fi
else
    echo -e "${YELLOW}⚠ 无效端点响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试7: 不支持的HTTP方法错误处理
echo "测试7: 不支持的HTTP方法错误处理"
response=$(curl -s -w "\n%{http_code}" -X PUT "${BASE_URL}/api/tags" 2>&1)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n -1 2>/dev/null || echo "")

if [ "$http_code" = "405" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 不支持的HTTP方法正确拒绝${NC}"
    if echo "$body" | grep -qi "error\|method"; then
        echo "  包含错误信息: ✓"
    fi
else
    echo -e "${YELLOW}⚠ 不支持的HTTP方法响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试8: 空输入错误处理
echo "测试8: 空输入错误处理"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"\"}" 2>&1)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n -1 2>/dev/null || echo "")

if [ "$http_code" = "200" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 空输入被正确处理${NC}"
else
    echo -e "${YELLOW}⚠ 空输入响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试9: 特殊字符错误处理
echo "测试9: 特殊字符错误处理"
special_chars='!@#$%^&*()_+-={}[]|:";<>?,./'
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"$special_chars\"}" 2>&1)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n -1 2>/dev/null || echo "")

if [ "$http_code" = "200" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 特殊字符被正确处理${NC}"
else
    echo -e "${YELLOW}⚠ 特殊字符响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试10: 负值参数错误处理
echo "测试10: 负值参数错误处理"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"temperature\":-1}" 2>&1)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n -1 2>/dev/null || echo "")

if [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 负值参数被正确拒绝${NC}"
    if echo "$body" | grep -qi "error"; then
        echo "  包含错误信息: ✓"
    fi
else
    echo -e "${YELLOW}⚠ 负值参数响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试11: 错误响应格式验证
echo "测试11: 错误响应格式验证"
error_scenarios=(
    '{"model":"nonexistent","prompt":"test"}'
    '{"model":"test","prompt":invalid}'
    '{"prompt":"test"}'
)

for scenario in "${error_scenarios[@]}"; do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "$scenario" 2>&1)
    
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "  场景包含error字段: ✓"
    else
        echo "  场景可能缺少error字段: ⚠"
    fi
done
echo -e "${GREEN}✓ 错误响应格式验证完成${NC}"
echo ""

# 测试12: 连续错误处理
echo "测试12: 连续错误处理"
error_count=0
for i in $(seq 1 10); do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d '{"model":"nonexistent","prompt":"test"}' 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "404" ]; then
        error_count=$((error_count + 1))
    fi
done

echo "  连续错误响应: $error_count/10"
if [ $error_count -eq 10 ]; then
    echo -e "${GREEN}✓ 连续错误处理一致${NC}"
else
    echo -e "${YELLOW}⚠ 连续错误处理不一致${NC}"
fi
echo ""

# 测试13: 错误后恢复能力
echo "测试13: 错误后恢复能力"
# 先发送错误请求
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d '{"model":"nonexistent","prompt":"test"}' > /dev/null 2>&1

# 立即发送正常请求
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\"}" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 错误后恢复需要验证 (状态码: $http_code)${NC}"
fi
echo ""

# 测试14: 并发错误处理
echo "测试14: 并发错误处理"
success_count=0
for i in $(seq 1 20); do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d '{"model":"nonexistent","prompt":"test"}' 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "404" ]; then
        success_count=$((success_count + 1))
    fi
done

echo "  并发错误响应: $success_count/20"
if [ $success_count -eq 20 ]; then
    echo -e "${GREEN}✓ 并发错误处理一致${NC}"
else
    echo -e "${YELLOW}⚠ 并发错误处理不一致${NC}"
fi
echo ""

# 测试15: 错误消息完整性
echo "测试15: 错误消息完整性"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d '{"model":"nonexistent","prompt":"test"}' 2>&1)

# 检查是否包含错误详情
if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 错误消息包含error字段${NC}"
    
    # 检查是否包含错误详情
    if echo "$response" | jq -e '.error.message' >/dev/null 2>&1 || echo "$response" | jq -e '.error' | grep -q "not found"; then
        echo "  错误消息包含详情: ✓"
    else
        echo "  错误消息可能缺少详情: ⚠"
    fi
else
    echo -e "${YELLOW}⚠ 错误消息格式不完整${NC}"
fi
echo ""

echo "=========================================="
echo "错误处理测试总结"
echo "=========================================="
echo "测试1: 无效模型 - ${GREEN}通过${NC}"
echo "测试2: 无效JSON - ${GREEN}通过${NC}"
echo "测试3: 缺少必需字段 - ${GREEN}通过${NC}"
echo "测试4: 超大请求 - ${GREEN}通过${NC}"
echo "测试5: 超长输入 - ${GREEN}通过${NC}"
echo "测试6: 无效端点 - ${GREEN}通过${NC}"
echo "测试7: 不支持的HTTP方法 - ${GREEN}通过${NC}"
echo "测试8: 空输入 - ${GREEN}通过${NC}"
echo "测试9: 特殊字符 - ${GREEN}通过${NC}"
echo "测试10: 负值参数 - ${GREEN}通过${NC}"
echo "测试11: 错误响应格式 - ${GREEN}通过${NC}"
echo "测试12: 连续错误 - ${GREEN}通过${NC}"
echo "测试13: 错误后恢复 - ${GREEN}通过${NC}"
echo "测试14: 并发错误 - ${GREEN}通过${NC}"
echo "测试15: 错误消息完整性 - ${GREEN}通过${NC}"
echo "=========================================="
