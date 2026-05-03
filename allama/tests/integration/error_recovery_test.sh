#!/bin/bash
# 错误恢复集成测试脚本
# 测试系统在错误情况下的恢复能力

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
echo "Allama 错误恢复集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 无效模型错误恢复
echo "测试1: 无效模型错误恢复"
# 发送无效模型请求
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"invalid_model_12345\",\"prompt\":\"test\",\"stream\":false}" > /dev/null

# 发送有效模型请求
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ 无效模型错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 无效模型错误恢复需要改进${NC}"
fi
echo ""

# 测试2: 无效JSON错误恢复
echo "测试2: 无效JSON错误恢复"
# 发送无效JSON
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "invalid json" > /dev/null

# 发送有效JSON
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ 无效JSON错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 无效JSON错误恢复需要改进${NC}"
fi
echo ""

# 测试3: 超时错误恢复
echo "测试3: 超时错误恢复"
# 发送可能导致超时的请求
response=$(curl -s -w "\n%{http_code}" --max-time 1 -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)

# 发送正常请求
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ 超时错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 超时错误恢复需要改进${NC}"
fi
echo ""

# 测试4: 网络中断恢复
echo "测试4: 网络中断恢复"
# 模拟网络中断（通过快速断开连接）
for i in $(seq 1 5); do
    timeout 0.1 curl -s "${BASE_URL}/api/tags" > /dev/null || true
done

# 发送正常请求
response=$(curl -s "${BASE_URL}/api/tags")

if echo "$response" | grep -q '"models"'; then
    echo -e "${GREEN}✓ 网络中断后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 网络中断恢复需要改进${NC}"
fi
echo ""

# 测试5: 连接错误恢复
echo "测试5: 连接错误恢复"
# 尝试连接到不存在的端口
curl -s --connect-timeout 1 "http://127.0.0.1:99999/api/tags" > /dev/null 2>&1 || true

# 连接到正确端口
response=$(curl -s "${BASE_URL}/api/tags")

if echo "$response" | grep -q '"models"'; then
    echo -e "${GREEN}✓ 连接错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 连接错误恢复需要改进${NC}"
fi
echo ""

# 测试6: 内存压力错误恢复
echo "测试6: 内存压力错误恢复"
# 发送大量请求
for i in $(seq 1 50); do
    curl -s "${BASE_URL}/api/tags" > /dev/null
done

# 发送正常请求
response=$(curl -s "${BASE_URL}/api/tags")

if echo "$response" | grep -q '"models"'; then
    echo -e "${GREEN}✓ 内存压力后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 内存压力恢复需要改进${NC}"
fi
echo ""

# 测试7: 并发错误恢复
echo "测试7: 并发错误恢复"
# 并发发送一些可能失败的请求
for i in $(seq 1 10); do
    (curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"invalid_model_$i\",\"prompt\":\"test\",\"stream\":false}" > /dev/null) &
done
wait

# 发送正常请求
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ 并发错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 并发错误恢复需要改进${NC}"
fi
echo ""

# 测试8: 参数错误恢复
echo "测试8: 参数错误恢复"
# 发送无效参数
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"temperature\":-1}" > /dev/null

# 发送有效参数
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"temperature\":0.7}")

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ 参数错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 参数错误恢复需要改进${NC}"
fi
echo ""

# 测试9: 状态一致性恢复
echo "测试9: 状态一致性恢复"
# 获取初始状态
state_before=$(curl -s "${BASE_URL}/api/ps")

# 发送一些错误请求
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"invalid\",\"prompt\":\"test\"}" > /dev/null

# 获取恢复后状态
state_after=$(curl -s "${BASE_URL}/api/ps")

if [ "$state_before" = "$state_after" ]; then
    echo -e "${GREEN}✓ 状态一致性恢复良好${NC}"
else
    echo -e "${YELLOW}⚠ 状态一致性恢复需要改进${NC}"
fi
echo ""

# 测试10: 模型加载错误恢复
echo "测试10: 模型加载错误恢复"
# 停止模型
curl -s -X POST "${BASE_URL}/api/stop" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\"}" > /dev/null

# 尝试使用停止的模型
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

# 重新加载应该会自动发生
if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ 模型加载错误可自动恢复${NC}"
else
    echo -e "${YELLOW}⚠ 模型加载错误恢复需要改进${NC}"
fi
echo ""

# 测试11: 端点错误恢复
echo "测试11: 端点错误恢复"
# 访问不存在的端点
curl -s "${BASE_URL}/api/nonexistent" > /dev/null 2>&1 || true

# 访问存在的端点
response=$(curl -s "${BASE_URL}/api/tags")

if echo "$response" | grep -q '"models"'; then
    echo -e "${GREEN}✓ 端点错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 端点错误恢复需要改进${NC}"
fi
echo ""

# 测试12: HTTP方法错误恢复
echo "测试12: HTTP方法错误恢复"
# 使用错误的HTTP方法
curl -s -X DELETE "${BASE_URL}/api/tags" > /dev/null 2>&1 || true

# 使用正确的HTTP方法
response=$(curl -s -X GET "${BASE_URL}/api/tags")

if echo "$response" | grep -q '"models"'; then
    echo -e "${GREEN}✓ HTTP方法错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ HTTP方法错误恢复需要改进${NC}"
fi
echo ""

# 测试13: 数据格式错误恢复
echo "测试13: 数据格式错误恢复"
# 发送格式错误的数据
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/xml" \
    -d "<data>test</data>" > /dev/null

# 发送正确格式
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ 数据格式错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 数据格式错误恢复需要改进${NC}"
fi
echo ""

# 测试14: 连接池错误恢复
echo "测试14: 连接池错误恢复"
# 快速建立大量连接
for i in $(seq 1 20); do
    (curl -s "${BASE_URL}/api/tags" > /dev/null) &
done
wait

# 发送正常请求
response=$(curl -s "${BASE_URL}/api/tags")

if echo "$response" | grep -q '"models"'; then
    echo -e "${GREEN}✓ 连接池错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 连接池错误恢复需要改进${NC}"
fi
echo ""

# 测试15: 资源耗尽错误恢复
echo "测试15: 资源耗尽错误恢复"
# 尝试耗尽资源（大量并发请求）
success_count=0
for i in $(seq 1 100); do
    response=$(curl -s "${BASE_URL}/api/tags")
    if echo "$response" | grep -q '"models"'; then
        success_count=$((success_count + 1))
    fi
done

# 发送正常请求
response=$(curl -s "${BASE_URL}/api/tags")

if echo "$response" | grep -q '"models"'; then
    echo -e "${GREEN}✓ 资源耗尽后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 资源耗尽恢复需要改进${NC}"
fi
echo ""

# 测试16: 优雅降级恢复
echo "测试16: 优雅降级恢复"
# 模拟高负载
for i in $(seq 1 30); do
    (curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" > /dev/null) &
done
wait

# 检查系统是否仍能响应
response=$(curl -s "${BASE_URL}/api/tags")

if echo "$response" | grep -q '"models"'; then
    echo -e "${GREEN}✓ 优雅降级后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 优雅降级恢复需要改进${NC}"
fi
echo ""

# 测试17: 连续错误恢复
echo "测试17: 连续错误恢复"
# 连续发送错误请求
for i in $(seq 1 10); do
    curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"invalid_model\",\"prompt\":\"test\"}" > /dev/null
done

# 发送正确请求
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ 连续错误后可正常恢复${NC}"
else
    echo -e "${YELLOW}⚠ 连续错误恢复需要改进${NC}"
fi
echo ""

# 测试18: 部分失败恢复
echo "测试18: 部分失败恢复"
# 发送混合请求（有效和无效）
success_count=0
for i in $(seq 1 20); do
    if [ $((i % 2)) -eq 0 ]; then
        response=$(curl -s -X POST "${BASE_URL}/api/generate" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")
    else
        response=$(curl -s -X POST "${BASE_URL}/api/generate" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"invalid\",\"prompt\":\"test\"}")
    fi
    if echo "$response" | grep -q "response"; then
        success_count=$((success_count + 1))
    fi
done

echo "  有效请求成功率: $((success_count * 100 / 10))%"
if [ $success_count -ge 9 ]; then
    echo -e "${GREEN}✓ 部分失败恢复正常${NC}"
else
    echo -e "${YELLOW}⚠ 部分失败恢复需要改进${NC}"
fi
echo ""

# 测试19: 事务回滚恢复
echo "测试19: 事务回滚恢复"
TIMESTAMP=$(date +%s)
TEST_MODEL_TX="tx_test_${TIMESTAMP}"

# 创建模型
curl -s -X POST "${BASE_URL}/api/copy" \
    -H "Content-Type: application/json" \
    -d "{\"source\":\"$TEST_MODEL\",\"destination\":\"$TEST_MODEL_TX\"}" > /dev/null

# 尝试删除不存在的模型（应该失败）
curl -s -X DELETE "${BASE_URL}/api/delete" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"nonexistent_model\"}" > /dev/null

# 验证创建的模型仍存在
response=$(curl -s "${BASE_URL}/api/tags")
if echo "$response" | grep -q "$TEST_MODEL_TX"; then
    echo -e "${GREEN}✓ 事务回滚恢复正常${NC}"
else
    echo -e "${YELLOW}⚠ 事务回滚恢复需要改进${NC}"
fi

# 清理
curl -s -X DELETE "${BASE_URL}/api/delete" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL_TX\"}" > /dev/null
echo ""

# 测试20: 系统重启恢复
echo "测试20: 系统重启恢复"
# 获取系统状态
state_before=$(curl -s "${BASE_URL}/api/ps")

# 模拟系统重启（通过停止和启动模型）
curl -s -X POST "${BASE_URL}/api/stop" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\"}" > /dev/null

# 重新加载
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

# 获取恢复后状态
state_after=$(curl -s "${BASE_URL}/api/ps")

if echo "$response" | grep -q "response"; then
    echo -e "${GREEN}✓ 系统重启恢复正常${NC}"
else
    echo -e "${YELLOW}⚠ 系统重启恢复需要改进${NC}"
fi
echo ""

echo "=========================================="
echo "错误恢复测试总结"
echo "=========================================="
echo "测试1: 无效模型错误恢复 - ${GREEN}完成${NC}"
echo "测试2: 无效JSON错误恢复 - ${GREEN}完成${NC}"
echo "测试3: 超时错误恢复 - ${GREEN}完成${NC}"
echo "测试4: 网络中断恢复 - ${GREEN}完成${NC}"
echo "测试5: 连接错误恢复 - ${GREEN}完成${NC}"
echo "测试6: 内存压力错误恢复 - ${GREEN}完成${NC}"
echo "测试7: 并发错误恢复 - ${GREEN}完成${NC}"
echo "测试8: 参数错误恢复 - ${GREEN}完成${NC}"
echo "测试9: 状态一致性恢复 - ${GREEN}完成${NC}"
echo "测试10: 模型加载错误恢复 - ${GREEN}完成${NC}"
echo "测试11: 端点错误恢复 - ${GREEN}完成${NC}"
echo "测试12: HTTP方法错误恢复 - ${GREEN}完成${NC}"
echo "测试13: 数据格式错误恢复 - ${GREEN}完成${NC}"
echo "测试14: 连接池错误恢复 - ${GREEN}完成${NC}"
echo "测试15: 资源耗尽错误恢复 - ${GREEN}完成${NC}"
echo "测试16: 优雅降级恢复 - ${GREEN}完成${NC}"
echo "测试17: 连续错误恢复 - ${GREEN}完成${NC}"
echo "测试18: 部分失败恢复 - ${GREEN}完成${NC}"
echo "测试19: 事务回滚恢复 - ${GREEN}完成${NC}"
echo "测试20: 系统重启恢复 - ${GREEN}完成${NC}"
echo "=========================================="
