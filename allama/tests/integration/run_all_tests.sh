#!/bin/bash
# Allama 集成测试主运行脚本
# 运行所有集成测试并生成测试报告

# 移除set -e以避免单个测试失败导致整个脚本停止

# 配置
ALLAMA_HOST=${ALLAMA_HOST:-"127.0.0.1"}
ALLAMA_PORT=${ALLAMA_PORT:-"11434"}
BASE_URL="http://${ALLAMA_HOST}:${ALLAMA_PORT}"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$TEST_DIR/../docs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Allama 集成测试套件"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试时间: $(date)"
echo "=========================================="
echo ""

# 检查服务器是否运行
echo "检查服务器连接..."
if curl -s --connect-timeout 5 "$BASE_URL/api/tags" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 服务器连接正常${NC}"
else
    echo -e "${RED}✗ 无法连接到服务器${NC}"
    echo "请确保服务器正在运行: $BASE_URL"
    exit 1
fi
echo ""

# 创建报告目录
mkdir -p "$REPORT_DIR"

# 初始化测试报告
REPORT_FILE="$REPORT_DIR/test_results_${TIMESTAMP}.md"
echo "# Allama 集成测试报告" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**测试时间:** $(date)" >> "$REPORT_FILE"
echo "**服务器地址:** $BASE_URL" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "## 测试结果" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 运行各个测试
TESTS=(
    "api_tests.sh:API端点测试"
    "rate_limit_test.sh:速率限制测试"
    "concurrency_test.sh:并发处理测试"
    "input_validation_test.sh:输入验证测试"
    "graceful_degradation_test.sh:优雅降级测试"
    "model_management_test.sh:模型管理命令测试"
    "inference_performance_test.sh:推理性能测试"
    "streaming_test.sh:流式响应测试"
    "e2e_inference_test.sh:端到端推理测试"
    "security_test.sh:安全测试"
    "load_test.sh:负载测试"
    "fault_tolerance_test.sh:容错测试"
    "boundary_test.sh:边界测试"
    "configuration_test.sh:配置测试"
    "monitoring_test.sh:监控测试"
    "log_test.sh:日志测试"
    "compatibility_test.sh:兼容性测试"
    "benchmark_test.sh:性能基准测试"
    "data_consistency_test.sh:数据一致性测试"
    "resource_leak_test.sh:资源泄漏测试"
    "multi_model_test.sh:多模型测试"
    "network_test.sh:网络测试"
    "error_handling_test.sh:错误处理测试"
    "crash_recovery_test.sh:崩溃恢复测试"
    "security_advanced_test.sh:高级安全测试"
    "performance_benchmark_test.sh:性能基准测试"
    "streaming_advanced_test.sh:高级流式响应测试"
    "consistency_advanced_test.sh:高级数据一致性测试"
    "model_lifecycle_test.sh:模型生命周期测试"
    "config_management_test.sh:配置管理测试"
    "api_compatibility_test.sh:API兼容性测试"
    "resource_management_test.sh:资源管理测试"
    "error_recovery_test.sh:错误恢复测试"
    "audit_log_test.sh:审计日志测试"
    "model_whitelist_test.sh:模型白名单测试"
    "billing_test.sh:计费统计测试"
    "auth_test.sh:认证系统测试"
    "multi_endpoint_auth_test.sh:多端点认证测试"
)

TOTAL_RUN=0
TOTAL_PASSED=0
TOTAL_FAILED=0

for test in "${TESTS[@]}"; do
    IFS=':' read -r script_name test_name <<< "$test"
    script_path="$TEST_DIR/$script_name"
    
    if [ -f "$script_path" ]; then
        echo "=========================================="
        echo "运行: $test_name"
        echo "=========================================="
        
        TOTAL_RUN=$((TOTAL_RUN + 1))
        
        # 运行测试并捕获输出（去除颜色代码）
        if bash "$script_path" 2>&1 | LC_ALL=C sed 's/\x1b\[[0-9;]*m//g' | tee -a "$REPORT_FILE"; then
            echo -e "${GREEN}✓ $test_name 通过${NC}"
            TOTAL_PASSED=$((TOTAL_PASSED + 1))
            echo "" >> "$REPORT_FILE"
            echo "**结果:** 通过 ✓" >> "$REPORT_FILE"
        else
            echo -e "${RED}✗ $test_name 失败${NC}"
            TOTAL_FAILED=$((TOTAL_FAILED + 1))
            echo "" >> "$REPORT_FILE"
            echo "**结果:** 失败 ✗" >> "$REPORT_FILE"
        fi
        echo "" >> "$REPORT_FILE"
        echo ""
    else
        echo -e "${YELLOW}⚠ 测试脚本不存在: $script_name${NC}"
    fi
done

# 生成总结
echo "=========================================="
echo "测试总结"
echo "=========================================="
echo "总测试数: $TOTAL_RUN"
echo -e "通过: ${GREEN}$TOTAL_PASSED${NC}"
echo -e "失败: ${RED}$TOTAL_FAILED${NC}"
echo "=========================================="

# 添加总结到报告
echo "" >> "$REPORT_FILE"
echo "## 总结" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **总测试数:** $TOTAL_RUN" >> "$REPORT_FILE"
echo "- **通过:** $TOTAL_PASSED" >> "$REPORT_FILE"
echo "- **失败:** $TOTAL_FAILED" >> "$REPORT_FILE"

if [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "${GREEN}所有测试通过！${NC}"
    echo "" >> "$REPORT_FILE"
    echo "**状态:** 全部通过 ✓" >> "$REPORT_FILE"
    exit 0
else
    echo -e "${RED}部分测试失败${NC}"
    echo "" >> "$REPORT_FILE"
    echo "**状态:** 部分失败 ✗" >> "$REPORT_FILE"
    exit 1
fi
