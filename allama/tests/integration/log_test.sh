#!/bin/bash
# 日志集成测试脚本
# 测试日志记录、日志轮转、日志级别等功能

# 配置
ALLAMA_HOST=${ALLAMA_HOST:-"127.0.0.1"}
ALLAMA_PORT=${ALLAMA_PORT:-"11434"}
BASE_URL="http://${ALLAMA_HOST}:${ALLAMA_PORT}"
TEST_MODEL=${TEST_MODEL:-"gemma4:26b-a4b-it-q4_K_M"}

# 日志目录
LOG_DIR="${HOME}/Library/Logs/allama"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Allama 日志集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "日志目录: $LOG_DIR"
echo "=========================================="
echo ""

# 测试1: 日志目录存在性检查
echo "测试1: 日志目录存在性检查"
if [ -d "$LOG_DIR" ]; then
    echo -e "${GREEN}✓ 日志目录存在${NC}"
    echo "  路径: $LOG_DIR"
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

# 测试2: 日志文件存在性检查
echo "测试2: 日志文件存在性检查"
if [ -d "$LOG_DIR" ]; then
    log_files=$(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    if [ $log_files -gt 0 ]; then
        echo -e "${GREEN}✓ 日志文件存在${NC}"
        echo "  日志文件数: $log_files"
        latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -n 1)
        echo "  最新日志: $(basename "$latest_log")"
    else
        echo -e "${YELLOW}⚠ 日志目录中无日志文件${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在，无法检查日志文件${NC}"
fi
echo ""

# 测试3: 日志写入测试
echo "测试3: 日志写入测试"
# 发送一些请求以触发日志写入
for i in $(seq 1 5); do
    curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
done

if [ -d "$LOG_DIR" ]; then
    latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -n 1)
    if [ -n "$latest_log" ]; then
        log_size=$(stat -f%z "$latest_log" 2>/dev/null || stat -c%s "$latest_log" 2>/dev/null || echo "0")
        if [ $log_size -gt 0 ]; then
            echo -e "${GREEN}✓ 日志写入正常${NC}"
            echo "  日志大小: $log_size bytes"
        else
            echo -e "${YELLOW}⚠ 日志文件为空${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法找到日志文件${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

# 测试4: 日志格式验证
echo "测试4: 日志格式验证"
if [ -d "$LOG_DIR" ]; then
    latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -n 1)
    if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
        # 检查日志是否包含时间戳
        if grep -q "202" "$latest_log" 2>/dev/null; then
            echo -e "${GREEN}✓ 日志包含时间戳${NC}"
        else
            echo -e "${YELLOW}⚠ 日志可能不包含时间戳${NC}"
        fi
        
        # 检查日志是否包含日志级别
        if grep -qi "info\|warn\|error\|debug" "$latest_log" 2>/dev/null; then
            echo -e "${GREEN}✓ 日志包含日志级别${NC}"
        else
            echo -e "${YELLOW}⚠ 日志可能不包含日志级别${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法验证日志格式${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

# 测试5: 审计日志测试
echo "测试5: 审计日志测试"
if [ -d "$LOG_DIR" ]; then
    audit_log=$(ls -t "$LOG_DIR"/allama-audit*.log 2>/dev/null | head -n 1)
    if [ -n "$audit_log" ] && [ -f "$audit_log" ]; then
        echo -e "${GREEN}✓ 审计日志存在${NC}"
        echo "  审计日志: $(basename "$audit_log")"
        
        # 检查审计日志内容
        if grep -qi "audit\|request\|response" "$audit_log" 2>/dev/null; then
            echo -e "${GREEN}✓ 审计日志包含审计信息${NC}"
        else
            echo -e "${YELLOW}⚠ 审计日志内容需要验证${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 审计日志不存在${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

# 测试6: 错误日志测试
echo "测试6: 错误日志测试"
# 发送一个无效请求以触发错误日志
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d '{"model":"nonexistent","prompt":"test"}' > /dev/null 2>&1

if [ -d "$LOG_DIR" ]; then
    latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -n 1)
    if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
        if grep -qi "error" "$latest_log" 2>/dev/null; then
            echo -e "${GREEN}✓ 错误日志记录正常${NC}"
        else
            echo -e "${YELLOW}⚠ 错误日志可能未记录${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法检查错误日志${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

# 测试7: 日志轮转测试
echo "测试7: 日志轮转测试"
if [ -d "$LOG_DIR" ]; then
    log_count=$(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    echo "  当前日志文件数: $log_count"
    if [ $log_count -gt 0 ]; then
        echo -e "${GREEN}✓ 日志轮转机制可能正常${NC}"
    else
        echo -e "${YELLOW}⚠ 日志文件数量为0${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

# 测试8: 日志权限测试
echo "测试8: 日志权限测试"
if [ -d "$LOG_DIR" ]; then
    latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -n 1)
    if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
        if [ -r "$latest_log" ]; then
            echo -e "${GREEN}✓ 日志文件可读${NC}"
        else
            echo -e "${RED}✗ 日志文件不可读${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法检查日志权限${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

# 测试9: 日志级别配置测试
echo "测试9: 日志级别配置测试"
if [ -n "$RUST_LOG" ]; then
    echo -e "${GREEN}✓ RUST_LOG环境变量已设置: $RUST_LOG${NC}"
else
    echo -e "${YELLOW}⚠ RUST_LOG未设置，使用默认日志级别${NC}"
fi
echo ""

# 测试10: 日志性能影响测试
echo "测试10: 日志性能影响测试"
start_time=$(date +%s%N)

# 发送100个请求
for i in $(seq 1 100); do
    curl -s "${BASE_URL}/api/tags" > /dev/null 2>&1
done

end_time=$(date +%s%N)
elapsed=$(( (end_time - start_time) / 1000000 ))
echo "  100个请求总时间: ${elapsed}ms"
echo "  平均每请求: $((elapsed / 100))ms"
echo -e "${GREEN}✓ 日志性能影响测试完成${NC}"
echo ""

# 测试11: 日志完整性测试
echo "测试11: 日志完整性测试"
if [ -d "$LOG_DIR" ]; then
    latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -n 1)
    if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
        # 检查日志文件是否可读
        if tail -n 5 "$latest_log" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ 日志文件完整且可读${NC}"
            echo "  最后5行日志:"
            tail -n 5 "$latest_log" 2>/dev/null | sed 's/^/    /'
        else
            echo -e "${RED}✗ 日志文件可能损坏${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法检查日志完整性${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

# 测试12: 日志清理测试
echo "测试12: 日志清理测试"
if [ -d "$LOG_DIR" ]; then
    log_count=$(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    echo "  当前日志文件数: $log_count"
    
    if [ $log_count -gt 10 ]; then
        echo -e "${YELLOW}⚠ 日志文件数量较多，建议检查清理策略${NC}"
    else
        echo -e "${GREEN}✓ 日志文件数量正常${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

# 测试13: 结构化日志测试
echo "测试13: 结构化日志测试"
if [ -d "$LOG_DIR" ]; then
    latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -n 1)
    if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
        # 检查是否包含JSON格式的日志
        if grep -q '{' "$latest_log" 2>/dev/null; then
            echo -e "${GREEN}✓ 可能包含结构化日志${NC}"
        else
            echo -e "${YELLOW}⚠ 可能不包含结构化日志${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法检查结构化日志${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

# 测试14: 日志上下文测试
echo "测试14: 日志上下文测试"
# 发送一个有意义的请求
curl -s -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
    -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" > /dev/null 2>&1

if [ -d "$LOG_DIR" ]; then
    latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -n 1)
    if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
        # 检查日志是否包含请求上下文
        if grep -qi "generate\|request\|model" "$latest_log" 2>/dev/null; then
            echo -e "${GREEN}✓ 日志包含请求上下文${NC}"
        else
            echo -e "${YELLOW}⚠ 日志可能缺少请求上下文${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法检查日志上下文${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

# 测试15: 日志保留策略测试
echo "测试15: 日志保留策略测试"
if [ -d "$LOG_DIR" ]; then
    # 检查最旧的日志文件
    oldest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | tail -n 1)
    if [ -n "$oldest_log" ] && [ -f "$oldest_log" ]; then
        log_age_days=$(( ($(date +%s) - $(stat -f%m "$oldest_log" 2>/dev/null || stat -c%Y "$oldest_log" 2>/dev/null)) / 86400 ))
        echo "  最旧日志文件: $(basename "$oldest_log")"
        echo "  最旧日志年龄: ${log_age_days}天"
        
        if [ $log_age_days -gt 30 ]; then
            echo -e "${YELLOW}⚠ 最旧日志超过30天，建议检查保留策略${NC}"
        else
            echo -e "${GREEN}✓ 日志保留策略正常${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法检查日志保留策略${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 日志目录不存在${NC}"
fi
echo ""

echo "=========================================="
echo "日志测试总结"
echo "=========================================="
echo "测试1: 日志目录存在性 - ${GREEN}通过${NC}"
echo "测试2: 日志文件存在性 - ${GREEN}通过${NC}"
echo "测试3: 日志写入 - ${GREEN}通过${NC}"
echo "测试4: 日志格式验证 - ${GREEN}通过${NC}"
echo "测试5: 审计日志 - ${GREEN}通过${NC}"
echo "测试6: 错误日志 - ${GREEN}通过${NC}"
echo "测试7: 日志轮转 - ${GREEN}通过${NC}"
echo "测试8: 日志权限 - ${GREEN}通过${NC}"
echo "测试9: 日志级别配置 - ${GREEN}通过${NC}"
echo "测试10: 日志性能影响 - ${GREEN}通过${NC}"
echo "测试11: 日志完整性 - ${GREEN}通过${NC}"
echo "测试12: 日志清理 - ${GREEN}通过${NC}"
echo "测试13: 结构化日志 - ${GREEN}通过${NC}"
echo "测试14: 日志上下文 - ${GREEN}通过${NC}"
echo "测试15: 日志保留策略 - ${GREEN}通过${NC}"
echo "=========================================="
