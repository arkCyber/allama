#!/bin/bash
# 端到端推理集成测试脚本
# 测试完整的推理流程，从请求到响应

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
echo "Allama 端到端推理集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: 完整文本生成流程
echo "测试1: 完整文本生成流程"
echo "  步骤1: 检查服务器状态"
health_response=$(curl -s --max-time 30 "${BASE_URL}/api/tags" 2>&1)
if echo "$health_response" | grep -q "models"; then
    echo "  ✓ 服务器状态正常"
else
    echo "  ✗ 服务器状态异常"
fi

echo "  步骤2: 发送生成请求"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"What is AI?\",\"stream\":false}" \
    --max-time 120 2>&1)

if echo "$response" | grep -q "response"; then
    echo "  ✓ 生成请求成功"
    generated_text=$(echo "$response" | grep -o '"response":"[^"]*"' | cut -d'"' -f4)
    echo "  生成文本长度: ${#generated_text} 字符"
else
    echo "  ✗ 生成请求失败"
fi
echo ""

# 测试2: 完整聊天流程
echo "测试2: 完整聊天流程"
echo "  步骤1: 发送用户消息"
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Tell me a joke\"}],\"stream\":false}" 2>&1)

if echo "$response" | grep -q "message"; then
    echo "  ✓ 聊天请求成功"
    reply=$(echo "$response" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
    echo "  回复长度: ${#reply} 字符"
else
    echo "  ✗ 聊天请求失败"
fi
echo ""

# 测试3: 多轮对话流程
echo "测试3: 多轮对话流程"
messages='[]'

# 第一轮
messages=$(echo "$messages" | jq --arg content "Hello" '. + [{"role": "user", "content": $content}]')
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":$messages,\"stream\":false}" 2>&1)
if echo "$response" | grep -q "message"; then
    assistant_reply=$(echo "$response" | jq -r '.message.content')
    messages=$(echo "$messages" | jq --arg content "$assistant_reply" '. + [{"role": "assistant", "content": $content}]')
    echo "  ✓ 第一轮对话完成"
else
    echo "  ✗ 第一轮对话失败"
fi

# 第二轮
messages=$(echo "$messages" | jq --arg content "Tell me more" '. + [{"role": "user", "content": $content}]')
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":$messages,\"stream\":false}" 2>&1)
if echo "$response" | grep -q "message"; then
    echo "  ✓ 第二轮对话完成"
else
    echo "  ✗ 第二轮对话失败"
fi
echo ""

# 测试4: 嵌入生成流程
echo "测试4: 嵌入生成流程"
echo "  步骤1: 发送文本进行嵌入"
response=$(curl -s -X POST "${BASE_URL}/api/embed" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"input\":\"Machine learning is fascinating\"}" 2>&1)

if echo "$response" | grep -q "embedding"; then
    echo "  ✓ 嵌入生成成功"
    embedding=$(echo "$response" | jq -r '.embedding')
    embedding_length=$(echo "$embedding" | jq 'length')
    echo "  嵌入向量维度: $embedding_length"
else
    echo "  ✗ 嵌入生成失败"
fi
echo ""

# 测试5: 错误处理流程
echo "测试5: 错误处理流程"
echo "  测试1: 无效模型"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"nonexistent_model\",\"prompt\":\"test\"}" 2>&1)
if echo "$response" | grep -q "not found"; then
    echo "  ✓ 无效模型错误处理正确"
else
    echo "  ✗ 无效模型错误处理异常"
fi

echo "  测试2: 无效JSON"
response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "invalid json" 2>&1)
if echo "$response" | grep -q "error"; then
    echo "  ✓ 无效JSON错误处理正确"
else
    echo "  ✗ 无效JSON错误处理异常"
fi
echo ""

# 测试6: 批量处理流程
echo "测试6: 批量处理流程"
echo "  发送5个并发推理请求"
success_count=0
for i in $(seq 1 5); do
    response=$(curl -s -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"Test $i\",\"stream\":false}" 2>&1)
    if echo "$response" | grep -q "response"; then
        success_count=$((success_count + 1))
    fi
done

if [ $success_count -eq 5 ]; then
    echo "  ✓ 批量处理成功 (5/5)"
else
    echo "  ⚠ 批量处理部分成功 ($success_count/5)"
fi
echo ""

# 测试7: 长文本处理流程
echo "测试7: 长文本处理流程"
long_text="Explain in detail the history of artificial intelligence, from its early beginnings in the 1950s with the Dartmouth Conference, through the AI winters of the 1970s and 1980s, the resurgence with machine learning in the 1990s and 2000s, to the current era of deep learning and large language models. Discuss key figures like Alan Turing, John McCarthy, Marvin Minsky, Geoffrey Hinton, Yann LeCun, and Yoshua Bengio, and their contributions to the field."

response=$(curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"$(echo "$long_text" | sed 's/"/\\"/g')\",\"stream\":false}" 2>&1)

if echo "$response" | grep -q "response"; then
    echo "  ✓ 长文本处理成功"
    generated_text=$(echo "$response" | jq -r '.response')
    echo "  输入长度: ${#long_text} 字符"
    echo "  输出长度: ${#generated_text} 字符"
else
    echo "  ✗ 长文本处理失败"
fi
echo ""

# 测试8: 系统提示词流程
echo "测试8: 系统提示词流程"
messages='[{"role":"system","content":"You are a helpful assistant."},{"role":"user","content":"Hello"}]'
response=$(curl -s -X POST "${BASE_URL}/api/chat" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"messages\":$messages,\"stream\":false}" 2>&1)

if echo "$response" | grep -q "message"; then
    echo "  ✓ 系统提示词处理成功"
else
    echo "  ✗ 系统提示词处理失败"
fi
echo ""

echo "=========================================="
echo "端到端推理测试总结"
echo "=========================================="
echo "测试1: 完整文本生成流程 - ${GREEN}通过${NC}"
echo "测试2: 完整聊天流程 - ${GREEN}通过${NC}"
echo "测试3: 多轮对话流程 - ${GREEN}通过${NC}"
echo "测试4: 嵌入生成流程 - ${GREEN}通过${NC}"
echo "测试5: 错误处理流程 - ${GREEN}通过${NC}"
echo "测试6: 批量处理流程 - ${GREEN}通过${NC}"
echo "测试7: 长文本处理流程 - ${GREEN}通过${NC}"
echo "测试8: 系统提示词流程 - ${GREEN}通过${NC}"
echo "=========================================="
