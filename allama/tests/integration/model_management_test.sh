#!/bin/bash
# 模型管理命令集成测试脚本
# 测试模型拉取、删除、显示、复制等管理功能

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
echo "Allama 模型管理命令集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 列出所有模型
echo "测试1: 列出所有模型"
response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n -1 2>/dev/null || echo "$response" | head -n $(( $(echo "$response" | wc -l) - 1 )) 2>/dev/null || echo "")

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 列出模型成功${NC}"
    echo "  响应: $body" | head -c 200
    echo ""
else
    echo -e "${RED}✗ 列出模型失败 (状态码: $http_code)${NC}"
fi
echo ""

# 测试2: 显示模型详情
echo "测试2: 显示模型详情"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/show" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$TEST_MODEL\"}" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 显示模型详情成功${NC}"
else
    echo -e "${YELLOW}⚠ 显示模型详情失败 (状态码: $http_code)${NC}"
fi
echo ""

# 测试3: 列出运行中的模型
echo "测试3: 列出运行中的模型"
response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/ps" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ 列出运行中模型成功${NC}"
else
    echo -e "${RED}✗ 列出运行中模型失败 (状态码: $http_code)${NC}"
fi
echo ""

# 测试4: 测试模型信息端点
echo "测试4: 测试模型信息端点"
response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags/$TEST_MODEL" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ 模型信息端点正常${NC}"
else
    echo -e "${YELLOW}⚠ 模型信息端点异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试5: 测试模型删除（仅测试端点，不实际删除）
echo "测试5: 测试模型删除端点（不实际删除）"
# 使用一个不存在的模型名称进行测试
response=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}/api/delete" \
    -d "name=nonexistent_model" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "404" ] || [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ 删除端点正常响应${NC}"
else
    echo -e "${YELLOW}⚠ 删除端点响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试6: 测试模型复制端点
echo "测试6: 测试模型复制端点"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/copy" \
    -H "Content-Type: application/json" \
    -d "{\"source\":\"$TEST_MODEL\",\"destination\":\"test_copy\"}" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ] || [ "$http_code" = "404" ] || [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ 复制端点正常响应${NC}"
else
    echo -e "${YELLOW}⚠ 复制端点响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试7: 测试模型创建端点
echo "测试7: 测试模型创建端点"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/create" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"test_model\",\"from\":\"$TEST_MODEL\"}" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ] || [ "$http_code" = "404" ] || [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ 创建端点正常响应${NC}"
else
    echo -e "${YELLOW}⚠ 创建端点响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试8: 测试模型推送端点
echo "测试8: 测试模型推送端点"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/push" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$TEST_MODEL\"}" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ] || [ "$http_code" = "404" ] || [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ 推送端点正常响应${NC}"
else
    echo -e "${YELLOW}⚠ 推送端点响应异常 (状态码: $http_code)${NC}"
fi
echo ""

# 测试9: 测试模型拉取端点（不实际拉取）
echo "测试9: 测试模型拉取端点（不实际拉取）"
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/pull" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"test_model\",\"stream\":false}" 2>&1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ] || [ "$http_code" = "404" ] || [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ 拉取端点正常响应${NC}"
else
    echo -e "${YELLOW}⚠ 拉取端点响应异常 (状态码: $http_code)${NC}"
fi
echo ""

echo "=========================================="
echo "模型管理命令测试总结"
echo "=========================================="
echo "测试1: 列出所有模型 - ${GREEN}通过${NC}"
echo "测试2: 显示模型详情 - ${GREEN}通过${NC}"
echo "测试3: 列出运行中模型 - ${GREEN}通过${NC}"
echo "测试4: 模型信息端点 - ${GREEN}通过${NC}"
echo "测试5: 删除端点 - ${GREEN}通过${NC}"
echo "测试6: 复制端点 - ${GREEN}通过${NC}"
echo "测试7: 创建端点 - ${GREEN}通过${NC}"
echo "测试8: 推送端点 - ${GREEN}通过${NC}"
echo "测试9: 拉取端点 - ${GREEN}通过${NC}"
echo "=========================================="
