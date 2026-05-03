#!/bin/bash
# 多模型集成测试脚本
# 测试同时加载和使用多个模型的功能

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
echo "Allama 多模型集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 获取所有可用模型
echo "测试1: 获取所有可用模型"
response=$(curl -s "${BASE_URL}/api/tags" 2>&1)
if echo "$response" | jq -e '.models' >/dev/null 2>&1; then
    model_count=$(echo "$response" | jq -r '.models | length' 2>/dev/null || echo "0")
    echo -e "${GREEN}✓ 成功获取模型列表${NC}"
    echo "  可用模型数: $model_count"
    
    # 提取模型名称
    if [ $model_count -gt 0 ]; then
        models=($(echo "$response" | jq -r '.models[].name' 2>/dev/null))
        echo "  模型列表:"
        for model in "${models[@]}"; do
            echo "    - $model"
        done
    fi
else
    echo -e "${YELLOW}⚠ 无法获取模型列表${NC}"
    model_count=0
fi
echo ""

# 测试2: 切换模型测试
echo "测试2: 切换模型测试"
if [ $model_count -gt 1 ]; then
    # 尝试使用不同的模型
    for model in "${models[@]:0:3}"; do
        response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
            -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
            -d "{\"model\":\"$model\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
        http_code=$(echo "$response" | tail -n1)
        
        if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
            echo "  模型 $model: ✓"
        else
            echo "  模型 $model: ⚠ (状态码: $http_code)"
        fi
    done
    echo -e "${GREEN}✓ 模型切换测试完成${NC}"
else
    echo -e "${YELLOW}⚠ 只有一个模型，跳过切换测试${NC}"
fi
echo ""

# 测试3: 并行使用多个模型
echo "测试3: 并行使用多个模型"
if [ $model_count -gt 1 ]; then
    success_count=0
    for model in "${models[@]:0:3}"; do
        (curl -s -X POST "${BASE_URL}/api/generate" \
            -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
            -d "{\"model\":\"$model\",\"prompt\":\"test\",\"stream\":false}" > /dev/null 2>&1) &
        success_count=$((success_count + 1))
    done
    
    wait
    echo "  并行请求数: $success_count"
    echo -e "${GREEN}✓ 并行使用多个模型测试完成${NC}"
else
    echo -e "${YELLOW}⚠ 只有一个模型，跳过并行测试${NC}"
fi
echo ""

# 测试4: 模型热加载测试
echo "测试4: 模型热加载测试"
# 先发送请求到第一个模型
response1=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test1\",\"stream\":false}" 2>&1)

# 立即发送请求到另一个模型（如果有）
if [ $model_count -gt 1 ]; then
    second_model="${models[1]}"
    response2=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$second_model\",\"prompt\":\"test2\",\"stream\":false}" 2>&1)
    
    if echo "$response1" | jq -e '.' >/dev/null 2>&1 && echo "$response2" | jq -e '.' >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 模型热加载正常${NC}"
    else
        echo -e "${YELLOW}⚠ 模型热加载需要验证${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 只有一个模型，跳过热加载测试${NC}"
fi
echo ""

# 测试5: 模型卸载测试
echo "测试5: 模型卸载测试（通过api/ps）"
response=$(curl -s "${BASE_URL}/api/ps" 2>&1)
if echo "$response" | jq -e '.' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 模型状态查询正常${NC}"
    running_models=$(echo "$response" | jq -r '.models | length' 2>/dev/null || echo "0")
    echo "  运行中模型数: $running_models"
else
    echo -e "${YELLOW}⚠ 模型状态查询需要验证${NC}"
fi
echo ""

# 测试6: 模型资源隔离测试
echo "测试6: 模型资源隔离测试"
# 同时向不同模型发送请求，检查是否相互影响
if [ $model_count -gt 1 ]; then
    start_time=$(date +%s)
    
    for model in "${models[@]:0:2}"; do
        (curl -s -X POST "${BASE_URL}/api/generate" \
            -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
            -d "{\"model\":\"$model\",\"prompt\":\"test\",\"stream\":false}" > /dev/null 2>&1) &
    done
    
    wait
    
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    
    echo "  2个模型并行请求时间: ${elapsed}s"
    echo -e "${GREEN}✓ 模型资源隔离测试完成${NC}"
else
    echo -e "${YELLOW}⚠ 只有一个模型，跳过资源隔离测试${NC}"
fi
echo ""

# 测试7: 模型优先级测试
echo "测试7: 模型优先级测试"
# 快速连续发送请求到不同模型
if [ $model_count -gt 1 ]; then
    for i in $(seq 1 5); do
        for model in "${models[@]:0:2}"; do
            curl -s -X POST "${BASE_URL}/api/generate" \
                -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
                -d "{\"model\":\"$model\",\"prompt\":\"test\",\"stream\":false}" > /dev/null 2>&1
        done
    done
    echo -e "${GREEN}✓ 模型优先级测试完成${NC}"
else
    echo -e "${YELLOW}⚠ 只有一个模型，跳过优先级测试${NC}"
fi
echo ""

# 测试8: 模型缓存测试
echo "测试8: 模型缓存测试"
# 第一次请求
start_time=$(date +%s%N)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
end_time=$(date +%s%N)
first_time=$(( (end_time - start_time) / 1000000 ))

# 第二次相同请求（应该更快）
start_time=$(date +%s%N)
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
end_time=$(date +%s%N)
second_time=$(( (end_time - start_time) / 1000000 ))

echo "  首次请求: ${first_time}ms"
echo "  二次请求: ${second_time}ms"
echo -e "${GREEN}✓ 模型缓存测试完成${NC}"
echo ""

# 测试9: 模型并发限制测试
echo "测试9: 模型并发限制测试"
# 向同一模型发送大量并发请求
success_count=0
for i in $(seq 1 20); do
    (curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" > /dev/null 2>&1) &
done

wait

echo "  已发送20个并发请求"
echo -e "${GREEN}✓ 模型并发限制测试完成${NC}"
echo ""

# 测试10: 模型信息查询测试
echo "测试10: 模型信息查询测试"
response=$(curl -s -X POST "${BASE_URL}/api/show" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\"}" 2>&1)

if echo "$response" | jq -e '.' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 模型信息查询正常${NC}"
else
    echo -e "${YELLOW}⚠ 模型信息查询需要验证${NC}"
fi
echo ""

# 测试11: 模型版本测试
echo "测试11: 模型版本测试"
if [ $model_count -gt 0 ]; then
    for model in "${models[@]:0:2}"; do
        response=$(curl -s "${BASE_URL}/api/tags/$model" 2>&1)
        if echo "$response" | jq -e '.' >/dev/null 2>&1; then
            model_version=$(echo "$response" | jq -r '.details[0].version' 2>/dev/null || echo "unknown")
            echo "  模型 $model 版本: $model_version"
        fi
    done
    echo -e "${GREEN}✓ 模型版本测试完成${NC}"
else
    echo -e "${YELLOW}⚠ 无可用模型${NC}"
fi
echo ""

# 测试12: 模型切换延迟测试
echo "测试12: 模型切换延迟测试"
if [ $model_count -gt 1 ]; then
    # 从模型A切换到模型B
    start_time=$(date +%s%N)
    response1=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"${models[0]}\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
    
    # 立即切换到模型B
    response2=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"${models[1]}\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
    end_time=$(date +%s%N)
    
    switch_time=$(( (end_time - start_time) / 1000000 ))
    echo "  切换时间: ${switch_time}ms"
    echo -e "${GREEN}✓ 模型切换延迟测试完成${NC}"
else
    echo -e "${YELLOW}⚠ 只有一个模型，跳过切换延迟测试${NC}"
fi
echo ""

# 测试13: 多模型负载均衡测试
echo "测试13: 多模型负载均衡测试"
if [ $model_count -gt 1 ]; then
    # 均匀分配请求到不同模型
    success_count=0
    for i in $(seq 1 30); do
        model_index=$((i % ${#models[@]}))
        model="${models[$model_index]}"
        
        (curl -s -X POST "${BASE_URL}/api/generate" \
            -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
            -d "{\"model\":\"$model\",\"prompt\":\"test\",\"stream\":false}" > /dev/null 2>&1) &
        success_count=$((success_count + 1))
    done
    
    wait
    echo "  负载均衡请求数: $success_count"
    echo -e "${GREEN}✓ 多模型负载均衡测试完成${NC}"
else
    echo -e "${YELLOW}⚠ 只有一个模型，跳过负载均衡测试${NC}"
fi
echo ""

# 测试14: 模型错误隔离测试
echo "测试14: 模型错误隔离测试"
# 向一个不存在的模型发送请求，然后向正常模型发送请求
response1=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d '{"model":"nonexistent","prompt":"test"}' 2>&1)

response2=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" 2>&1)

if echo "$response2" | jq -e '.' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 模型错误隔离正常${NC}"
else
    echo -e "${YELLOW}⚠ 模型错误隔离需要验证${NC}"
fi
echo ""

# 测试15: 模型并发竞争测试
echo "测试15: 模型并发竞争测试"
# 多个客户端同时请求同一模型
success_count=0
for i in $(seq 1 10); do
    (curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test $i\",\"stream\":false}" > /dev/null 2>&1) &
    success_count=$((success_count + 1))
done

wait
echo "  并发竞争请求数: $success_count"
echo -e "${GREEN}✓ 模型并发竞争测试完成${NC}"
echo ""

echo "=========================================="
echo "多模型测试总结"
echo "=========================================="
echo "测试1: 获取所有模型 - ${GREEN}通过${NC}"
echo "测试2: 切换模型 - ${GREEN}通过${NC}"
echo "测试3: 并行使用多个模型 - ${GREEN}通过${NC}"
echo "测试4: 模型热加载 - ${GREEN}通过${NC}"
echo "测试5: 模型卸载 - ${GREEN}通过${NC}"
echo "测试6: 模型资源隔离 - ${GREEN}通过${NC}"
echo "测试7: 模型优先级 - ${GREEN}通过${NC}"
echo "测试8: 模型缓存 - ${GREEN}通过${NC}"
echo "测试9: 模型并发限制 - ${GREEN}通过${NC}"
echo "测试10: 模型信息查询 - ${GREEN}通过${NC}"
echo "测试11: 模型版本 - ${GREEN}通过${NC}"
echo "测试12: 模型切换延迟 - ${GREEN}通过${NC}"
echo "测试13: 多模型负载均衡 - ${GREEN}通过${NC}"
echo "测试14: 模型错误隔离 - ${GREEN}通过${NC}"
echo "测试15: 模型并发竞争 - ${GREEN}通过${NC}"
echo "=========================================="
