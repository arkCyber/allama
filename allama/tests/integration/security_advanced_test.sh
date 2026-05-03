#!/bin/bash
# 高级安全集成测试脚本
# 测试安全漏洞、注入攻击、权限控制等

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
echo "Allama 高级安全集成测试"
echo "=========================================="
echo "服务器地址: $BASE_URL"
echo "测试模型: $TEST_MODEL"
echo "=========================================="
echo ""

# 测试1: SQL注入尝试
echo "测试1: SQL注入尝试"
sql_payloads=(
    "'; DROP TABLE users; --"
    "' OR '1'='1"
    "1' UNION SELECT * FROM users--"
    "'; EXEC xp_cmdshell('dir'); --"
)

for payload in "${sql_payloads[@]}"; do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"$payload\",\"stream\":false}" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
        echo "  SQL注入 '$payload': ✓ (被正确处理)"
    else
        echo "  SQL注入 '$payload': ✗ (状态码: $http_code)"
    fi
done
echo -e "${GREEN}✓ SQL注入测试完成${NC}"
echo ""

# 测试2: XSS攻击尝试
echo "测试2: XSS攻击尝试"
xss_payloads=(
    "<script>alert('XSS')</script>"
    "<img src=x onerror=alert('XSS')>"
    "<svg onload=alert('XSS')>"
    "javascript:alert('XSS')"
    "<iframe src='javascript:alert(1)'>"
)

for payload in "${xss_payloads[@]}"; do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"$payload\",\"stream\":false}" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
        echo "  XSS '$payload': ✓ (被正确处理)"
    else
        echo "  XSS '$payload': ✗ (状态码: $http_code)"
    fi
done
echo -e "${GREEN}✓ XSS攻击测试完成${NC}"
echo ""

# 测试3: 命令注入尝试
echo "测试3: 命令注入尝试"
cmd_payloads=(
    "; ls -la"
    "| cat /etc/passwd"
    "`whoami`"
    "\$(cat /etc/passwd)"
    "; rm -rf /"
)

for payload in "${cmd_payloads[@]}"; do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"$payload\",\"stream\":false}" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
        echo "  命令注入 '$payload': ✓ (被正确处理)"
    else
        echo "  命令注入 '$payload': ✗ (状态码: $http_code)"
    fi
done
echo -e "${GREEN}✓ 命令注入测试完成${NC}"
echo ""

# 测试4: 路径遍历尝试
echo "测试4: 路径遍历尝试"
path_payloads=(
    "../../../etc/passwd"
    "..\\..\\..\\windows\\system32"
    "/etc/passwd"
    "C:\\Windows\\System32\\config"
    "./../../etc/passwd"
)

for payload in "${path_payloads[@]}"; do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"$payload\",\"stream\":false}" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
        echo "  路径遍历 '$payload': ✓ (被正确处理)"
    else
        echo "  路径遍历 '$payload': ✗ (状态码: $http_code)"
    fi
done
echo -e "${GREEN}✓ 路径遍历测试完成${NC}"
echo ""

# 测试5: SSRF尝试
echo "测试5: 服务器端请求伪造尝试"
ssrf_payloads=(
    "http://127.0.0.1:22"
    "http://localhost:8080"
    "http://169.254.169.254/latest/meta-data/"
    "http://internal.server"
    "file:///etc/passwd"
)

for payload in "${ssrf_payloads[@]}"; do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"$payload\",\"stream\":false}" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
        echo "  SSRF '$payload': ✓ (被正确处理)"
    else
        echo "  SSRF '$payload': ✗ (状态码: $http_code)"
    fi
done
echo -e "${GREEN}✓ SSRF测试完成${NC}"
echo ""

# 测试6: 头部注入尝试
echo "测试6: 头部注入尝试"
header_injection_payloads=(
    "test\r\nX-Injected-Header: malicious"
    "test%0d%0aX-Injected-Header: malicious"
    "test\nX-Injected-Header: malicious"
)

for payload in "${header_injection_payloads[@]}"; do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -H "X-Custom-Header: $payload" \
        -d "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"stream\":false}" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
        echo "  头部注入 '$payload': ✓ (被正确处理)"
    else
        echo "  头部注入 '$payload': ✗ (状态码: $http_code)"
    fi
done
echo -e "${GREEN}✓ 头部注入测试完成${NC}"
echo ""

# 测试7: JSON注入尝试
echo "测试7: JSON注入尝试"
json_payloads=(
    "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"malicious\":\"value\"}"
    "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"__proto__\":{\"malicious\":true}}"
    "{\"model\":\"$TEST_MODEL\",\"prompt\":\"test\",\"constructor\":{\"prototype\":{\"malicious\":true}}}"
)

for payload in "${json_payloads[@]}"; do
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/generate" \
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1" \
        -d "$payload" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
        echo "  JSON注入: ✓ (被正确处理)"
    else
        echo "  JSON注入: ✗ (状态码: $http_code)"
    fi
done
echo -e "${GREEN}✓ JSON注入测试完成${NC}"
echo ""

# 测试8: 速率限制绕过尝试
echo "测试8: 速率限制绕过尝试"
echo "  发送100个快速请求..."
success_count=0
for i in $(seq 1 100); do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/tags" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "429" ]; then
        success_count=$((success_count + 1))
    fi
done

if [ $success_count -eq 100 ]; then
    echo -e "${YELLOW}⚠ 速率限制可能未生效（所有请求都成功）${NC}"
else
    echo -e "${GREEN}✓ 速率限制正常工作（成功: $success_count/100）${NC}"
fi
echo ""

# 测试9: 越权访问尝试
echo "测试9: 越权访问尝试"
# 尝试访问管理端点（如果存在）
admin_endpoints=(
    "/admin"
    "/api/admin"
    "/api/config"
    "/api/settings"
    "/api/users"
)

for endpoint in "${admin_endpoints[@]}"; do
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}${endpoint}" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "401" ] || [ "$http_code" = "403" ] || [ "$http_code" = "404" ]; then
        echo "  管理端点 $endpoint: ✓ (被正确拒绝)"
    else
        echo "  管理端点 $endpoint: ⚠ (状态码: $http_code)"
    fi
done
echo -e "${GREEN}✓ 越权访问测试完成${NC}"
echo ""

# 测试10: 敏感信息泄露检查
echo "测试10: 敏感信息泄露检查"
sensitive_keywords=(
    "password"
    "secret"
    "token"
    "api_key"
    "private_key"
    "database"
)

response=$(curl -s "${BASE_URL}/api/tags")
leaked=false

for keyword in "${sensitive_keywords[@]}"; do
    if echo "$response" | grep -qi "$keyword"; then
        echo "  检测到敏感关键词: $keyword"
        leaked=true
    fi
done

if [ "$leaked" = false ]; then
    echo -e "${GREEN}✓ 未检测到敏感信息泄露${NC}"
else
    echo -e "${YELLOW}⚠ 可能存在敏感信息泄露${NC}"
fi
echo ""

echo "=========================================="
echo "高级安全测试总结"
echo "=========================================="
echo "测试1: SQL注入 - ${GREEN}完成${NC}"
echo "测试2: XSS攻击 - ${GREEN}完成${NC}"
echo "测试3: 命令注入 - ${GREEN}完成${NC}"
echo "测试4: 路径遍历 - ${GREEN}完成${NC}"
echo "测试5: SSRF - ${GREEN}完成${NC}"
echo "测试6: 头部注入 - ${GREEN}完成${NC}"
echo "测试7: JSON注入 - ${GREEN}完成${NC}"
echo "测试8: 速率限制绕过 - ${GREEN}完成${NC}"
echo "测试9: 越权访问 - ${GREEN}完成${NC}"
echo "测试10: 敏感信息泄露 - ${GREEN}完成${NC}"
echo "=========================================="
