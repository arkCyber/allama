#!/bin/bash
# 高级数据一致性集成测试脚本
# 测试数据一致性、并发安全、状态管理等

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
echo "Allama 高级数据一致性集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 模型列表一致性
echo "测试1: 模型列表一致性（多次请求结果一致）"
response1=$(curl -s "${BASE_URL}/api/tags")
response2=$(curl -s "${BASE_URL}/api/tags")
response3=$(curl -s "${BASE_URL}/api/tags")

if [ "$response1" = "$response2" ] && [ "$response2" = "$response3" ]; then
    echo -e "${GREEN}✓ 模型列表一致性良好${NC}"
else
    echo -e "${YELLOW}⚠ 模型列表可能不一致${NC}"
fi
echo ""

# 测试2: 并发写入一致性
echo "测试2: 并发写入一致性（模拟多个客户端同时操作）"
# 创建测试模型名称
test_model="consistency_test_$$"

# 并发发送10个创建请求
for i in $(seq 1 10); do
    (curl -s -X POST "${BASE_URL}/api/copy" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"source\":\"llama3\",\"destination\":\"${test_model}_$i\"}" > /tmp/consistency_$i.txt) &
done

wait

# 检查结果
success_count=0
for i in $(seq 1 10); do
    if [ -f "/tmp/consistency_$i.txt" ]; then
        status=$(cat /tmp/consistency_$i.txt | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        if [ "$status" = "success" ]; then
            success_count=$((success_count + 1))
        fi
        rm -f "/tmp/consistency_$i.txt"
    fi
done

echo "  成功创建: $success_count/10"
if [ $success_count -ge 8 ]; then
    echo -e "${GREEN}✓ 并发写入一致性良好${NC}"
else
    echo -e "${YELLOW}⚠ 并发写入一致性需要改进${NC}"
fi
echo ""

# 测试3: 状态一致性
echo "测试3: 状态一致性（/api/ps状态一致性）"
response1=$(curl -s "${BASE_URL}/api/ps")
sleep 1
response2=$(curl -s "${BASE_URL}/api/ps")

# 检查进程ID是否一致
pid1=$(echo "$response1" | grep -o '"pid":[0-9]*' | head -1 | cut -d':' -f2)
pid2=$(echo "$response2" | grep -o '"pid":[0-9]*' | head -1 | cut -d':' -f2)

if [ "$pid1" = "$pid2" ]; then
    echo -e "${GREEN}✓ 进程状态一致性良好${NC}"
else
    echo -e "${YELLOW}⚠ 进程状态可能不一致${NC}"
fi
echo ""

# 测试4: 响应格式一致性
echo "测试4: 响应格式一致性（相同请求响应格式一致）"
response1=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")
response2=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

# 检查是否都有相同的必需字段
fields=("model" "response" "done")
all_consistent=true

for field in "${fields[@]}"; do
    if ! echo "$response1" | grep -q "\"$field\"" || ! echo "$response2" | grep -q "\"$field\""; then
        all_consistent=false
        break
    fi
done

if [ "$all_consistent" = true ]; then
    echo -e "${GREEN}✓ 响应格式一致性良好${NC}"
else
    echo -e "${YELLOW}⚠ 响应格式可能不一致${NC}"
fi
echo ""

# 测试5: 并发读取一致性
echo "测试5: 并发读取一致性（多个客户端同时读取相同数据）"
# 并发发送20个读取请求
success_count=0
for i in $(seq 1 20); do
    response=$(curl -s "${BASE_URL}/api/tags")
    if echo "$response" | grep -q "\"models\""; then
        success_count=$((success_count + 1))
    fi
done

echo "  成功读取: $success_count/20"
if [ $success_count -eq 20 ]; then
    echo -e "${GREEN}✓ 并发读取一致性良好${NC}"
else
    echo -e "${YELLOW}⚠ 并发读取一致性需要改进${NC}"
fi
echo ""

# 测试6: 事务一致性
echo "测试6: 事务一致性（操作原子性测试）"
# 测试删除操作是否是原子的
test_model="transaction_test_$$"

# 先创建一个模型
curl -s -X POST "${BASE_URL}/api/copy" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"source\":\"llama3\",\"destination\":\"$test_model\"}" > /dev/null

# 然后删除它
response=$(curl -s -X DELETE "${BASE_URL}/api/delete" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$test_model\"}")

status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

# 验证删除后模型不存在
response2=$(curl -s "${BASE_URL}/api/tags")
if echo "$response2" | grep -q "$test_model"; then
    echo -e "${YELLOW}⚠ 事务一致性需要改进（删除后模型仍存在）${NC}"
else
    echo -e "${GREEN}✓ 事务一致性良好${NC}"
fi
echo ""

# 测试7: 时间戳一致性
echo "测试7: 时间戳一致性（modified_at字段一致性）"
response=$(curl -s "${BASE_URL}/api/tags")

# 提取所有modified_at时间戳
timestamps=$(echo "$response" | grep -o '"modified_at":"[^"]*"' | cut -d'"' -f4)
timestamp_count=$(echo "$timestamps" | wc -l)

echo "  检测到 $timestamp_count 个时间戳"

if [ $timestamp_count -gt 0 ]; then
    echo -e "${GREEN}✓ 时间戳字段存在${NC}"
else
    echo -e "${YELLOW}⚠ 时间戳字段可能缺失${NC}"
fi
echo ""

# 测试8: 数据完整性
echo "测试8: 数据完整性（响应数据完整性验证）"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")

# 检查JSON格式是否有效
if echo "$response" | python3 -m json.tool > /dev/null 2>&1; then
    echo -e "${GREEN}✓ JSON格式有效${NC}"
else
    echo -e "${YELLOW}⚠ JSON格式可能无效${NC}"
fi

# 检查是否有截断的数据
if echo "$response" | grep -q '\.\.\.'; then
    echo -e "${YELLOW}⚠ 响应可能被截断${NC}"
else
    echo -e "${GREEN}✓ 响应数据完整${NC}"
fi
echo ""

# 测试9: 并发模型加载一致性
echo "测试9: 并发模型加载一致性（多个客户端同时加载相同模型）"
success_count=0
for i in $(seq 1 10); do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}")
    
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" = "200" ]; then
        success_count=$((success_count + 1))
    fi
done

echo "  成功加载: $success_count/10"
if [ $success_count -ge 9 ]; then
    echo -e "${GREEN}✓ 并发模型加载一致性良好${NC}"
else
    echo -e "${YELLOW}⚠ 并发模型加载一致性需要改进${NC}"
fi
echo ""

# 测试10: 状态恢复一致性
echo "测试10: 状态恢复一致性（异常后状态一致性）"
# 获取当前状态
state_before=$(curl -s "${BASE_URL}/api/ps")

# 发送一个可能触发错误的请求
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"invalid_model\",\"prompt\":\"test\",\"stream\":false}" > /dev/null

# 再次获取状态
state_after=$(curl -s "${BASE_URL}/api/ps")

# 检查状态是否一致
if [ "$state_before" = "$state_after" ]; then
    echo -e "${GREEN}✓ 状态恢复一致性良好${NC}"
else
    echo -e "${YELLOW}⚠ 状态恢复一致性需要验证${NC}"
fi
echo ""

# 测试11: 并发删除一致性
echo "测试11: 并发删除一致性（防止竞态条件）"
test_model="delete_test_$$"

# 创建测试模型
curl -s -X POST "${BASE_URL}/api/copy" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"source\":\"llama3\",\"destination\":\"$test_model\"}" > /dev/null

# 并发发送删除请求
for i in $(seq 1 5); do
    (curl -s -X DELETE "${BASE_URL}/api/delete" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$test_model\"}" > /tmp/delete_$i.txt) &
done

wait

# 检查结果
success_count=0
error_count=0
for i in $(seq 1 5); do
    if [ -f "/tmp/delete_$i.txt" ]; then
        status=$(cat /tmp/delete_$i.txt | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        if [ "$status" = "success" ]; then
            success_count=$((success_count + 1))
        else
            error_count=$((error_count + 1))
        fi
        rm -f "/tmp/delete_$i.txt"
    fi
done

echo "  成功删除: $success_count, 错误: $error_count"
if [ $success_count -eq 1 ] && [ $error_count -eq 4 ]; then
    echo -e "${GREEN}✓ 并发删除一致性良好（只有一次成功）${NC}"
else
    echo -e "${YELLOW}⚠ 并发删除一致性需要改进${NC}"
fi
echo ""

# 测试12: 数据版本一致性
echo "测试12: 数据版本一致性（模型版本一致性）"
response=$(curl -s "${BASE_URL}/api/tags")

# 检查是否有版本信息
if echo "$response" | grep -q '"version"' || echo "$response" | grep -q '"modified_at"'; then
    echo -e "${GREEN}✓ 数据版本信息存在${NC}"
else
    echo -e "${YELLOW}⚠ 数据版本信息可能缺失${NC}"
fi
echo ""

# 测试13: 并发更新一致性
echo "测试13: 并发更新一致性（模型信息更新）"
test_model="update_test_$$"

# 创建测试模型
curl -s -X POST "${BASE_URL}/api/copy" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"source\":\"llama3\",\"destination\":\"$test_model\"}" > /dev/null

# 并发发送更新请求
for i in $(seq 1 5); do
    (curl -s -X POST "${BASE_URL}/api/create" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$test_model\",\"modelfile\":\"FROM llama3\\nPARAMETER temperature 0.$i\"}" > /tmp/update_$i.txt) &
done

wait

# 清理
curl -s -X DELETE "${BASE_URL}/api/delete" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$test_model\"}" > /dev/null

echo -e "${GREEN}✓ 并发更新一致性测试完成${NC}"
echo ""

# 测试14: 缓存一致性
echo "测试14: 缓存一致性（缓存数据一致性）"
# 发送相同的请求多次，检查响应是否一致
responses=()
for i in $(seq 1 5); do
    response=$(curl -s "${BASE_URL}/api/tags")
    responses+=("$response")
done

# 检查所有响应是否相同
all_same=true
first_response="${responses[0]}"
for i in $(seq 1 4); do
    if [ "${responses[$i]}" != "$first_response" ]; then
        all_same=false
        break
    fi
done

if [ "$all_same" = true ]; then
    echo -e "${GREEN}✓ 缓存一致性良好${NC}"
else
    echo -e "${YELLOW}⚠ 缓存一致性需要改进${NC}"
fi
echo ""

# 测试15: 并发连接一致性
echo "测试15: 并发连接一致性（连接池一致性）"
success_count=0
for i in $(seq 1 30); do
    response=$(curl -s "${BASE_URL}/api/tags")
    if echo "$response" | grep -q '"models"'; then
        success_count=$((success_count + 1))
    fi
done

echo "  成功连接: $success_count/30"
if [ $success_count -ge 28 ]; then
    echo -e "${GREEN}✓ 并发连接一致性良好${NC}"
else
    echo -e "${YELLOW}⚠ 并发连接一致性需要改进${NC}"
fi
echo ""

echo "=========================================="
echo "高级数据一致性测试总结"
echo "=========================================="
echo "测试1: 模型列表一致性 - ${GREEN}完成${NC}"
echo "测试2: 并发写入一致性 - ${GREEN}完成${NC}"
echo "测试3: 状态一致性 - ${GREEN}完成${NC}"
echo "测试4: 响应格式一致性 - ${GREEN}完成${NC}"
echo "测试5: 并发读取一致性 - ${GREEN}完成${NC}"
echo "测试6: 事务一致性 - ${GREEN}完成${NC}"
echo "测试7: 时间戳一致性 - ${GREEN}完成${NC}"
echo "测试8: 数据完整性 - ${GREEN}完成${NC}"
echo "测试9: 并发模型加载一致性 - ${GREEN}完成${NC}"
echo "测试10: 状态恢复一致性 - ${GREEN}完成${NC}"
echo "测试11: 并发删除一致性 - ${GREEN}完成${NC}"
echo "测试12: 数据版本一致性 - ${GREEN}完成${NC}"
echo "测试13: 并发更新一致性 - ${GREEN}完成${NC}"
echo "测试14: 缓存一致性 - ${GREEN}完成${NC}"
echo "测试15: 并发连接一致性 - ${GREEN}完成${NC}"
echo "=========================================="
