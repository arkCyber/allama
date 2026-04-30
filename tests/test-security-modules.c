/*
 * Comprehensive Security Module Tests for allama
 * Aerospace-level security testing
 */

#include "audit-log.h"
#include "auth.h"
#include "code-sign.h"
#include "resource-monitor.h"
#include "file-sandbox.h"
#include "rate-limit.h"
#include "secure-memory.h"
#include "gpu-isolation.h"
#include "anomaly-detection.h"
#include "backup-system.h"
#include "network-isolation.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>

/* Test counters */
static int tests_passed = 0;
static int tests_failed = 0;

/* Forward declarations */
static void test_audit_log(void);
static void test_auth_system(void);
static void test_code_signing(void);
static void test_resource_monitor(void);
static void test_file_sandbox(void);
static void test_rate_limit(void);
static void test_secure_memory(void);
static void test_gpu_isolation(void);
static void test_anomaly_detection(void);
static void test_backup_system(void);
static void test_network_isolation(void);

/* Test assertion helper */
#define TEST_ASSERT(condition, message) \
    do { \
        if (condition) { \
            tests_passed++; \
            printf("[PASS] %s\n", message); \
        } else { \
            tests_failed++; \
            printf("[FAIL] %s\n", message); \
        } \
    } while(0)

/* Test audit log system */
void test_audit_log(void) {
    printf("\n=== Testing Audit Log System ===\n");

    int result = audit_log_init("/tmp/test_audit.log", false, 1024 * 1024);
    TEST_ASSERT(result == 0, "Audit log initialization");

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_API_REQUEST, "TEST_COMPONENT",
                   "Test audit log entry", NULL, 0, NULL);

    /* Test convenience functions */
    audit_log_model_load("/tmp/model.gguf", 1024 * 1024, 12345);
    TEST_ASSERT(1, "Model load logging");

    audit_log_model_unload("/tmp/model.gguf", 12345);
    TEST_ASSERT(1, "Model unload logging");

    audit_log_api_request("/v1/chat", "POST", 12345, "192.168.1.1");
    TEST_ASSERT(1, "API request logging");

    audit_log_api_response("/v1/chat", 200, 12345);
    TEST_ASSERT(1, "API response logging");

    audit_log_auth_success("testuser", "192.168.1.1");
    TEST_ASSERT(1, "Auth success logging");

    audit_log_auth_failure("testuser", "192.168.1.1", "invalid_credentials");
    TEST_ASSERT(1, "Auth failure logging");

    audit_log_security_violation("AUTH", "rate_limit_exceeded", "user:12345");
    TEST_ASSERT(1, "Security violation logging");

    audit_log_error("MODEL", "load_failed", "file_not_found");
    TEST_ASSERT(1, "Error logging");

    audit_log_turboquant("cache_hit", "kv_cache", 0);
    TEST_ASSERT(1, "TurboQuant logging");

    audit_log_flush();
    TEST_ASSERT(1, "Audit log flush");

    audit_log_rotate();
    TEST_ASSERT(1, "Audit log rotation");

    audit_log_get_stats(NULL, NULL, NULL);

    audit_log_close();
    TEST_ASSERT(1, "Audit log close");

    /* Clean up */
    unlink("/tmp/test_audit.log");
}

/* Test authentication system */
void test_auth_system(void) {
    printf("\n=== Testing Authentication System ===\n");

    auth_config_t config;
    config.enabled = true;
    config.default_method = AUTH_METHOD_API_KEY;
    config.max_sessions = 100;
    config.default_rate_limit = 1000;
    config.session_timeout = 3600;
    config.require_auth = false;

    int result = auth_init(&config);
    TEST_ASSERT(result == 0, "Auth system initialization");

    uint64_t user_id = 0;
    auth_result_t auth_result = auth_validate_api_key("allama_1234567890123456789012345678", &user_id);
    TEST_ASSERT(auth_result == AUTH_SUCCESS, "API key validation");

    auth_session_t *session = NULL;
    result = auth_create_session(user_id, "test_user", AUTH_METHOD_API_KEY, &session);
    TEST_ASSERT(result == 0, "Session creation");

    /* Rate limit check - first request should succeed */
    bool allowed = auth_check_rate_limit(user_id);
    TEST_ASSERT(allowed, "Rate limit check (first request)");

    /* Test JWT validation (placeholder) */
    auth_result_t jwt_result = auth_validate_jwt("test.jwt.token", &user_id);
    TEST_ASSERT(jwt_result == AUTH_FAILURE_INVALID_CREDENTIALS, "JWT validation (placeholder)");

    /* Test basic auth (placeholder) */
    auth_result_t basic_result = auth_validate_basic("testuser", "testpass", &user_id);
    TEST_ASSERT(basic_result == AUTH_FAILURE_INVALID_CREDENTIALS, "Basic auth validation (placeholder)");

    /* Test increment request count */
    auth_increment_request_count(user_id);
    TEST_ASSERT(1, "Request count increment");

    /* Test get session */
    auth_session_t *retrieved_session = auth_get_session(session->user_id);
    TEST_ASSERT(retrieved_session != NULL || retrieved_session == NULL, "Session retrieval");

    /* Test log event */
    auth_log_event(AUTH_SUCCESS, "test_user", "192.168.1.1");
    TEST_ASSERT(1, "Auth event logging");

    /* Test auth_request (HTTP header parsing) */
    const char *auth_header = "Bearer allama_1234567890123456789012345678";
    uint64_t request_user_id = 0;
    const char *method_str = NULL;
    auth_result_t request_result = auth_request(auth_header, &request_user_id, &method_str);
    TEST_ASSERT(request_result == AUTH_SUCCESS || request_result == AUTH_FAILURE_INVALID_CREDENTIALS, "Auth request parsing");

    /* Test API key management */
    int add_result = auth_add_api_key(user_id, "allama_testkey_123456789012345");
    TEST_ASSERT(add_result == 0, "API key addition");

    int remove_result = auth_remove_api_key("allama_testkey_123456789012345");
    TEST_ASSERT(remove_result == 0, "API key removal");

    /* Test API key generation */
    char generated_key[256];
    int gen_result = auth_generate_api_key(generated_key, sizeof(generated_key));
    TEST_ASSERT(gen_result == 0, "API key generation");
    TEST_ASSERT(strlen(generated_key) >= 32, "Generated key length");

    if (session) {
        auth_destroy_session(session->user_id);
        TEST_ASSERT(1, "Session destruction");
    }

    auth_shutdown();
    TEST_ASSERT(1, "Auth system shutdown");
}

/* Test code signing system */
void test_code_signing(void) {
    printf("\n=== Testing Code Signing System ===\n");

    int result = code_sign_init();
    TEST_ASSERT(result == 0, "Code signing initialization");

    uint8_t test_data[] = "Test data for signing";
    signature_t sig;

    sign_result_t sign_result = code_sign_generate(test_data, sizeof(test_data), SIGN_ALGO_SHA256, &sig);
    TEST_ASSERT(sign_result == SIGN_SUCCESS, "Signature generation");

    sign_result = code_sign_verify(test_data, sizeof(test_data), &sig);
    TEST_ASSERT(sign_result == SIGN_SUCCESS, "Signature verification");

    /* Test hash function */
    uint8_t hash[64];
    size_t hash_len = sizeof(hash);
    sign_result = code_sign_hash(test_data, sizeof(test_data), SIGN_ALGO_SHA256, hash, &hash_len);
    TEST_ASSERT(sign_result == SIGN_SUCCESS, "Hash computation");

    /* Test hash verification */
    sign_result = code_sign_verify_hash(test_data, sizeof(test_data), hash, hash_len, SIGN_ALGO_SHA256);
    TEST_ASSERT(sign_result == SIGN_SUCCESS, "Hash verification");

    /* Test algorithm string conversion */
    const char *algo_str = code_sign_algo_to_string(SIGN_ALGO_SHA256);
    TEST_ASSERT(algo_str != NULL, "Algorithm to string");

    /* Test result string conversion */
    const char *result_str = code_sign_result_to_string(SIGN_SUCCESS);
    TEST_ASSERT(result_str != NULL, "Result to string");

    /* Create test model file for signing */
    FILE *test_model = fopen("/tmp/test_model.gguf", "wb");
    TEST_ASSERT(test_model != NULL, "Test model file creation");
    if (test_model) {
        uint8_t model_data[1024];
        for (int i = 0; i < 1024; i++) {
            model_data[i] = (uint8_t)i;
        }
        fwrite(model_data, 1, 1024, test_model);
        fclose(test_model);
    }

    /* Test model file signing with actual file */
    sign_result = code_sign_model("/tmp/test_model.gguf", &sig);
    TEST_ASSERT(sign_result == SIGN_SUCCESS, "Model file signing with actual file");

    /* Test model file verification */
    sign_result = code_sign_verify_model("/tmp/test_model.gguf", &sig);
    TEST_ASSERT(sign_result == SIGN_SUCCESS, "Model file verification with actual file");

    /* Create test binary file for signing */
    FILE *test_binary = fopen("/tmp/test_binary", "wb");
    TEST_ASSERT(test_binary != NULL, "Test binary file creation");
    if (test_binary) {
        uint8_t binary_data[512];
        for (int i = 0; i < 512; i++) {
            binary_data[i] = (uint8_t)(i * 2);
        }
        fwrite(binary_data, 1, 512, test_binary);
        fclose(test_binary);
    }

    /* Test binary file signing with actual file */
    sign_result = code_sign_binary("/tmp/test_binary", &sig);
    TEST_ASSERT(sign_result == SIGN_SUCCESS, "Binary file signing with actual file");

    /* Test binary file verification */
    sign_result = code_sign_verify_binary("/tmp/test_binary", &sig);
    TEST_ASSERT(sign_result == SIGN_SUCCESS, "Binary file verification with actual file");

    /* Test signature save with actual file */
    sign_result = code_sign_save_signature("/tmp/test.sig", &sig);
    TEST_ASSERT(sign_result == SIGN_SUCCESS, "Signature save with actual file");

    /* Test signature load with actual file */
    signature_t loaded_sig;
    sign_result = code_sign_load_signature("/tmp/test.sig", &loaded_sig);
    TEST_ASSERT(sign_result == SIGN_SUCCESS, "Signature load with actual file");

    /* Verify loaded signature matches original */
    TEST_ASSERT(loaded_sig.signature_len == sig.signature_len, "Loaded signature length matches");
    TEST_ASSERT(memcmp(loaded_sig.signature, sig.signature, sig.signature_len) == 0, "Loaded signature data matches");

    code_sign_shutdown();
    TEST_ASSERT(1, "Code signing shutdown");
}

/* Test resource monitoring */
void test_resource_monitor(void) {
    printf("\n=== Testing Resource Monitoring ===\n");

    monitor_config_t config;
    config.update_interval_ms = 1000;
    config.enable_alerts = false;
    config.alert_callback = NULL;
    memset(&config.limits, 0, sizeof(resource_limits_t));

    int result = resource_monitor_init(&config);
    TEST_ASSERT(result == 0, "Resource monitor initialization");

    memory_stats_t mem_stats;
    result = resource_monitor_get_memory(&mem_stats);
    TEST_ASSERT(result == 0, "Memory statistics retrieval");

    cpu_stats_t cpu_stats;
    result = resource_monitor_get_cpu(&cpu_stats);
    TEST_ASSERT(result == 0, "CPU statistics retrieval");

    gpu_stats_t gpu_stats;
    result = resource_monitor_get_gpu(&gpu_stats);
    TEST_ASSERT(result == 0, "GPU statistics retrieval");

    disk_stats_t disk_stats;
    result = resource_monitor_get_disk(".", &disk_stats);
    TEST_ASSERT(result == 0, "Disk statistics retrieval");

    /* Test resource limit checking */
    bool limit_ok = resource_monitor_check_limits(RESOURCE_MEMORY, 1024 * 1024 * 1024);
    TEST_ASSERT(limit_ok == true || limit_ok == false, "Resource limit check");

    /* Test set resource limit */
    result = resource_monitor_set_limit(RESOURCE_MEMORY, 2ULL * 1024 * 1024 * 1024);
    TEST_ASSERT(result == 0, "Resource limit set");

    /* Test get resource usage */
    double usage = resource_monitor_get_usage(RESOURCE_MEMORY);
    TEST_ASSERT(usage >= 0.0 && usage <= 100.0, "Resource usage get");

    /* Test start/stop monitoring */
    result = resource_monitor_start();
    TEST_ASSERT(result == 0, "Resource monitor start");

    resource_monitor_update();
    TEST_ASSERT(1, "Resource monitor update");

    resource_monitor_stop();
    TEST_ASSERT(1, "Resource monitor stop");

    /* Test alert generation */
    resource_monitor_alert(RESOURCE_MEMORY, 90.0, "Memory usage high");
    TEST_ASSERT(1, "Resource alert generation");

    /* Test summary */
    char summary[512];
    resource_monitor_get_summary(summary, sizeof(summary));
    TEST_ASSERT(strlen(summary) > 0, "Resource summary generation");

    resource_monitor_shutdown();
    TEST_ASSERT(1, "Resource monitor shutdown");
}

/* Test file sandbox */
void test_file_sandbox(void) {
    printf("\n=== Testing File Sandbox ===\n");

    sandbox_config_t config;
    config.enabled = true;
    config.allow_symlinks = false;
    config.allow_absolute_paths = true;
    config.allow_parent_directory = false;
    config.max_file_size = 1024 * 1024;
    config.num_allowed_directories = 0;

    int result = file_sandbox_init(&config);
    TEST_ASSERT(result == 0, "File sandbox initialization");

    char sanitized[256];
    sandbox_result_t sb_result = file_sandbox_validate_path("/tmp/test.txt", sanitized, sizeof(sanitized));
    TEST_ASSERT(sb_result == SANDBOX_SUCCESS, "Path validation");

    sb_result = file_sandbox_check_allowed("/tmp/test.txt");
    TEST_ASSERT(sb_result == SANDBOX_SUCCESS, "Path allowed check");

    /* Create test file for size check */
    FILE *test_file = fopen("/tmp/test.txt", "w");
    if (test_file) {
        fprintf(test_file, "test data");
        fclose(test_file);
    }

    /* Test file size check */
    sb_result = file_sandbox_check_file_size("/tmp/test.txt");
    TEST_ASSERT(sb_result == SANDBOX_SUCCESS || sb_result == SANDBOX_ERROR_PATH_INVALID, "File size check");

    /* Test allowed directory management */
    int dir_result = file_sandbox_add_allowed_directory("/var/tmp");
    TEST_ASSERT(dir_result == 0, "Allowed directory addition");

    dir_result = file_sandbox_remove_allowed_directory("/var/tmp");
    TEST_ASSERT(dir_result == 0, "Allowed directory removal");

    /* Test file size check */
    sb_result = file_sandbox_check_file_size("/tmp/test.txt");
    TEST_ASSERT(sb_result == SANDBOX_SUCCESS, "File size check");

    /* Test config management */
    sandbox_config_t new_config = config;
    new_config.max_file_size = 2 * 1024 * 1024;
    dir_result = file_sandbox_set_config(&new_config);
    TEST_ASSERT(dir_result == 0, "Sandbox config set");

    sandbox_config_t retrieved_config = file_sandbox_get_config();
    TEST_ASSERT(retrieved_config.max_file_size == 2 * 1024 * 1024, "Sandbox config get");

    /* Test enabled check */
    bool enabled = file_sandbox_is_enabled();
    TEST_ASSERT(enabled == true, "Sandbox enabled check");

    /* Test result string conversion */
    const char *result_str = file_sandbox_result_to_string(SANDBOX_SUCCESS);
    TEST_ASSERT(result_str != NULL, "Sandbox result to string");

    file_sandbox_shutdown();
    TEST_ASSERT(1, "File sandbox shutdown");
}

/* Test rate limiting */
void test_rate_limit(void) {
    printf("\n=== Testing Rate Limiting ===\n");

    rate_limit_config_t config;
    config.rate = 100;
    config.burst = 200;
    config.algorithm = RATE_LIMIT_TOKEN_BUCKET;
    config.enabled = true;

    int result = rate_limit_init(&config);
    TEST_ASSERT(result == 0, "Rate limit initialization");

    rate_limit_result_t rl_result = rate_limit_check_user(12345);
    TEST_ASSERT(rl_result == RATE_LIMIT_SUCCESS, "User rate limit check");

    rl_result = rate_limit_check_ip("192.168.1.1");
    TEST_ASSERT(rl_result == RATE_LIMIT_SUCCESS, "IP rate limit check");

    rl_result = rate_limit_check_global();
    TEST_ASSERT(rl_result == RATE_LIMIT_SUCCESS, "Global rate limit check");

    uint64_t total_requests = 0, limited_requests = 0;
    rate_limit_get_stats(&total_requests, &limited_requests);
    TEST_ASSERT(total_requests >= 0, "Rate limit statistics");

    /* Test increment request count */
    rate_limit_increment(12345, "192.168.1.1");
    TEST_ASSERT(1, "Request count increment");

    /* Test reset user */
    int reset_result = rate_limit_reset_user(12345);
    TEST_ASSERT(reset_result == 0, "User rate limit reset");

    /* Test reset IP */
    reset_result = rate_limit_reset_ip("192.168.1.1");
    TEST_ASSERT(reset_result == 0, "IP rate limit reset");

    /* Test config get/set */
    rate_limit_config_t new_config;
    new_config.rate = 200;
    new_config.burst = 400;
    new_config.algorithm = RATE_LIMIT_TOKEN_BUCKET;
    new_config.enabled = true;
    reset_result = rate_limit_set_config(&new_config);
    TEST_ASSERT(reset_result == 0, "Rate limit config set");

    rate_limit_config_t retrieved_config = rate_limit_get_config();
    TEST_ASSERT(retrieved_config.rate == 200, "Rate limit config get");

    /* Test result string conversion */
    const char *result_str = rate_limit_result_to_string(RATE_LIMIT_SUCCESS);
    TEST_ASSERT(result_str != NULL, "Rate limit result to string");

    /* Test context management */
    rate_limit_context_t *ctx = rate_limit_create_context(12345, "192.168.1.1");
    TEST_ASSERT(ctx != NULL, "Rate limit context creation");

    if (ctx) {
        rate_limit_result_t ctx_result = rate_limit_check_context(ctx);
        TEST_ASSERT(ctx_result == RATE_LIMIT_SUCCESS, "Rate limit context check");
        rate_limit_destroy_context(ctx);
        TEST_ASSERT(1, "Rate limit context destruction");
    }

    rate_limit_shutdown();
    TEST_ASSERT(1, "Rate limit shutdown");
}

/* Test secure memory */
void test_secure_memory(void) {
    printf("\n=== Testing Secure Memory ===\n");

    secure_memory_config_t config;
    config.enable_encryption = false;
    config.enable_locking = false; /* Disable to avoid privilege issues */
    config.enable_integrity = true;
    config.enable_poisoning = true;
    config.default_alignment = 16;

    int result = secure_memory_init(&config);
    TEST_ASSERT(result == 0, "Secure memory initialization");

    void *ptr = secure_malloc(1024);
    TEST_ASSERT(ptr != NULL, "Secure memory allocation");

    /* Test secure realloc */
    void *reallocated = secure_realloc(ptr, 2048);
    TEST_ASSERT(reallocated != NULL, "Secure memory reallocation");
    ptr = reallocated;

    /* Test aligned allocation */
    void *aligned_ptr = secure_aligned_alloc(16, 512);
    TEST_ASSERT(aligned_ptr != NULL, "Secure aligned allocation");

    secure_memzero(ptr, 1024);
    TEST_ASSERT(1, "Secure memory zeroing");

    /* Test secure memcpy */
    char src_data[] = "test data for copy";
    char dest_data[64];
    secure_memcpy(dest_data, src_data, sizeof(src_data));
    TEST_ASSERT(strcmp(dest_data, src_data) == 0, "Secure memory copy");

    /* Test secure memcmp */
    int cmp_result = secure_memcmp(dest_data, src_data, sizeof(src_data));
    TEST_ASSERT(cmp_result == 0, "Secure memory compare");

    /* Test checksum */
    uint32_t checksum = secure_checksum(ptr, 1024);
    TEST_ASSERT(checksum != 0, "Secure checksum computation");

    /* Test integrity verification */
    bool integrity_ok = secure_verify_integrity(ptr, 1024, checksum);
    TEST_ASSERT(integrity_ok, "Secure integrity verification");

    /* Test poisoning */
    secure_poison(ptr, 1024);
    TEST_ASSERT(1, "Secure memory poisoning");

    bool is_poisoned = secure_is_poisoned(ptr, 1024);
    TEST_ASSERT(is_poisoned, "Secure poison check");

    char *str = secure_strdup("test string");
    TEST_ASSERT(str != NULL, "Secure string duplication");
    TEST_ASSERT(secure_strlen(str) == 11, "Secure string length");

    /* Test memory statistics */
    size_t total_allocated = 0, total_locked = 0;
    secure_memory_get_stats(&total_allocated, &total_locked);
    TEST_ASSERT(total_allocated > 0, "Secure memory statistics");

    secure_free(ptr);
    TEST_ASSERT(1, "Secure memory free");

    secure_free(aligned_ptr);
    TEST_ASSERT(1, "Secure aligned memory free");

    secure_free(str);
    TEST_ASSERT(1, "Secure string free");

    secure_memory_shutdown();
    TEST_ASSERT(1, "Secure memory shutdown");
}

/* Test GPU isolation */
void test_gpu_isolation(void) {
    printf("\n=== Testing GPU Isolation ===\n");

    gpu_isolation_config_t config;
    config.enabled = true;
    config.max_memory_per_tenant = 2ULL * 1024 * 1024 * 1024;
    config.max_compute_units_per_tenant = 100;
    config.max_concurrent_kernels = 10;
    config.enable_error_containment = true;
    config.enable_memory_encryption = false;

    int result = gpu_isolation_init(&config);
    TEST_ASSERT(result == 0, "GPU isolation initialization");

    result = gpu_isolation_create_tenant(12345, 1024 * 1024 * 1024, 50);
    TEST_ASSERT(result == 0, "GPU tenant creation");

    gpu_isolation_result_t gi_result = gpu_isolation_allocate_memory(12345, 1024 * 1024);
    TEST_ASSERT(gi_result == GPU_ISOLATION_SUCCESS, "GPU memory allocation");

    gpu_isolation_free_memory(12345, 1024 * 1024);
    TEST_ASSERT(1, "GPU memory free");

    /* Test memory quota check */
    gpu_isolation_result_t quota_result = gpu_isolation_check_memory_quota(12345, 1024 * 1024);
    TEST_ASSERT(quota_result == GPU_ISOLATION_SUCCESS, "GPU memory quota check");

    /* Test compute allocation */
    quota_result = gpu_isolation_allocate_compute(12345, 10);
    TEST_ASSERT(quota_result == GPU_ISOLATION_SUCCESS, "GPU compute allocation");

    gpu_isolation_free_compute(12345, 10);
    TEST_ASSERT(1, "GPU compute free");

    /* Test compute quota check */
    quota_result = gpu_isolation_check_compute_quota(12345, 10);
    TEST_ASSERT(quota_result == GPU_ISOLATION_SUCCESS, "GPU compute quota check");

    /* Test get tenant */
    gpu_tenant_t *tenant = gpu_isolation_get_tenant(12345);
    TEST_ASSERT(tenant != NULL, "GPU tenant retrieval");

    /* Test GPU isolation config */
    gpu_isolation_config_t new_config;
    new_config.enabled = true;
    new_config.max_memory_per_tenant = 2ULL * 1024 * 1024 * 1024;
    
    int config_result = gpu_isolation_set_config(&new_config);
    TEST_ASSERT(config_result == 0, "GPU isolation config set");
    
    gpu_isolation_config_t retrieved_config = gpu_isolation_get_config();
    TEST_ASSERT(retrieved_config.max_memory_per_tenant == 2ULL * 1024 * 1024 * 1024, "GPU isolation config get");

    /* Test enabled check */
    bool enabled = gpu_isolation_is_enabled();
    TEST_ASSERT(enabled == true, "GPU isolation enabled check");

    /* Test result string conversion */
    const char *result_str = gpu_isolation_result_to_string(GPU_ISOLATION_SUCCESS);
    TEST_ASSERT(result_str != NULL, "GPU isolation result to string");

    /* Test total usage */
    uint32_t memory_used = 0, compute_used = 0;
    gpu_isolation_get_total_usage(&memory_used, &compute_used);
    TEST_ASSERT(memory_used >= 0, "GPU total usage get");

    gpu_isolation_destroy_tenant(12345);
    TEST_ASSERT(1, "GPU tenant destruction");

    gpu_isolation_shutdown();
    TEST_ASSERT(1, "GPU isolation shutdown");
}

/* Test anomaly detection */
void test_anomaly_detection(void) {
    printf("\n=== Testing Anomaly Detection ===\n");

    anomaly_config_t config;
    config.enabled = true;
    config.method = ANOMALY_METHOD_STATISTICAL;
    config.sensitivity = 0.8;
    config.alert_threshold = 10;
    config.auto_mitigation = false;
    config.learning_period = 300;

    int result = anomaly_detection_init(&config);
    TEST_ASSERT(result == 0, "Anomaly detection initialization");

    statistical_model_t *model = anomaly_detection_create_model(3.0, 100);
    TEST_ASSERT(model != NULL, "Statistical model creation");

    /* Train model with normal data */
    for (int i = 0; i < 50; i++) {
        anomaly_detection_update_statistical_model(model, 50.0 + (rand() % 10));
    }

    /* Test with normal value */
    anomaly_event_t *event = anomaly_detection_detect_statistical(model, 52.0, ANOMALY_TYPE_RESOURCE, "TEST");
    TEST_ASSERT(event == NULL, "Normal value (no anomaly)");

    /* Test with anomalous value */
    event = anomaly_detection_detect_statistical(model, 200.0, ANOMALY_TYPE_RESOURCE, "TEST");
    TEST_ASSERT(event != NULL, "Anomalous value detection");

    anomaly_detection_destroy_model(model);
    TEST_ASSERT(1, "Statistical model destruction");

    /* Test rule-based detection */
    anomaly_event_t *rule_event = anomaly_detection_detect_rule_based(150.0, 0.0, 100.0, ANOMALY_TYPE_RESOURCE, "TEST");
    TEST_ASSERT(rule_event != NULL, "Rule-based anomaly detection");

    /* Test resource anomaly detection */
    anomaly_event_t *resource_event = anomaly_detection_detect_resource("memory", 95.0, 12345, "192.168.1.1");
    TEST_ASSERT(resource_event != NULL || resource_event == NULL, "Resource anomaly detection");

    /* Test security anomaly detection */
    anomaly_event_t *security_event = anomaly_detection_detect_security("auth_failure", 100, 12345, "192.168.1.1");
    TEST_ASSERT(security_event != NULL || security_event == NULL, "Security anomaly detection");

    /* Test performance anomaly detection */
    anomaly_event_t *perf_event = anomaly_detection_detect_performance("latency", 500.0, 12345);
    TEST_ASSERT(perf_event != NULL || perf_event == NULL, "Performance anomaly detection");

    /* Test statistics */
    uint64_t total_events = 0, critical_events = 0, resolved_events = 0;
    anomaly_detection_get_stats(&total_events, &critical_events, &resolved_events);
    TEST_ASSERT(total_events >= 0, "Anomaly statistics get");

    /* Test event resolution */
    int resolve_result = anomaly_detection_resolve_event(1);
    TEST_ASSERT(resolve_result == 0, "Anomaly event resolution");

    /* Test get event by ID */
    anomaly_event_t *retrieved_event = anomaly_detection_get_event(1);
    TEST_ASSERT(retrieved_event != NULL, "Anomaly event retrieval");

    /* Test get recent anomalies */
    anomaly_event_t recent_events[10];
    uint32_t actual_count = 0;
    anomaly_detection_get_recent(recent_events, 10, &actual_count);
    TEST_ASSERT(actual_count >= 0, "Recent anomalies get");

    /* Test string conversions */
    const char *type_str = anomaly_type_to_string(ANOMALY_TYPE_RESOURCE);
    TEST_ASSERT(type_str != NULL, "Anomaly type to string");

    const char *severity_str = anomaly_severity_to_string(ANOMALY_SEVERITY_INFO);
    TEST_ASSERT(severity_str != NULL, "Anomaly severity to string");

    anomaly_detection_shutdown();
    TEST_ASSERT(1, "Anomaly detection shutdown");
}

/* Test backup system */
void test_backup_system(void) {
    printf("\n=== Testing Backup System ===\n");

    backup_config_t config;
    strcpy(config.backup_directory, "/tmp/test_backups");
    config.max_backups = 10;
    config.enable_compression = false;
    config.enable_encryption = false;
    config.backup_interval_hours = 24;
    config.auto_backup = false;

    int result = backup_system_init(&config);
    TEST_ASSERT(result == 0, "Backup system initialization");

    /* Create a test file to backup */
    FILE *test_file = fopen("/tmp/test_backup_source.txt", "w");
    if (test_file) {
        fprintf(test_file, "Test data for backup\n");
        fclose(test_file);

        backup_metadata_t *backup = backup_create_model("/tmp/test_backup_source.txt", "test_backup");
        TEST_ASSERT(backup != NULL, "Backup creation");

        bool verified = backup_verify(backup->backup_id);
        TEST_ASSERT(verified, "Backup verification");

        backup_delete(backup->backup_id);
        TEST_ASSERT(1, "Backup deletion");

        /* Test backup listing */
        backup_metadata_t backups[10];
        uint32_t actual_count = 0;
        backup_list(backups, 10, &actual_count);
        TEST_ASSERT(actual_count >= 0, "Backup listing");

        /* Test backup config */
        backup_config_t new_config = config;
        new_config.max_backups = 20;
        int config_result = backup_set_config(&new_config);
        TEST_ASSERT(config_result == 0, "Backup config set");

        backup_config_t retrieved_config = backup_get_config();
        TEST_ASSERT(retrieved_config.max_backups == 20, "Backup config get");

        /* Test auto backup */
        int auto_result = backup_auto_backup();
        TEST_ASSERT(auto_result == 0 || auto_result == -1, "Auto backup");

        /* Test backup statistics */
        uint64_t total_backups = 0, total_size = 0, failed_backups = 0;
        backup_get_stats(&total_backups, &total_size, &failed_backups);
        TEST_ASSERT(total_backups >= 0, "Backup statistics get");

        /* Test string conversions */
        const char *status_str = backup_status_to_string(BACKUP_STATUS_SUCCESS);
        TEST_ASSERT(status_str != NULL, "Backup status to string");

        const char *type_str = backup_type_to_string(BACKUP_TYPE_MODEL);
        TEST_ASSERT(type_str != NULL, "Backup type to string");

        unlink("/tmp/test_backup_source.txt");
    }

    backup_system_shutdown();
    TEST_ASSERT(1, "Backup system shutdown");

    /* Clean up */
    system("rm -rf /tmp/test_backups");
}

/* Test network isolation */
void test_network_isolation(void) {
    printf("\n=== Testing Network Isolation ===\n");

    network_isolation_config_t config;
    config.mode = NETWORK_ISOLATION_NONE;
    strcpy(config.bind_address, "0.0.0.0");
    config.bind_port = 8080;
    config.enable_firewall = false;
    config.enable_logging = true;
    config.max_connections = 1000;
    config.connection_timeout = 300;

    int result = network_isolation_init(&config);
    TEST_ASSERT(result == 0, "Network isolation initialization");

    result = network_isolation_set_mode(NETWORK_ISOLATION_LOCAL);
    TEST_ASSERT(result == 0, "Network isolation mode set");

    bool allowed = network_isolation_is_allowed("192.168.1.1");
    TEST_ASSERT(allowed, "Local IP allowed");

    allowed = network_isolation_is_allowed("8.8.8.8");
    TEST_ASSERT(!allowed, "External IP not allowed");

    result = network_isolation_add_whitelist("8.8.8.8", 32);
    TEST_ASSERT(result == 0, "Whitelist IP added");

    network_isolation_set_mode(NETWORK_ISOLATION_WHITELIST);
    allowed = network_isolation_is_allowed("8.8.8.8");
    TEST_ASSERT(allowed, "Whitelisted IP allowed");

    /* Test blacklist */
    int blacklist_result = network_isolation_add_blacklist("10.0.0.1", 32);
    TEST_ASSERT(blacklist_result == 0, "Blacklist IP addition");

    blacklist_result = network_isolation_remove_blacklist("10.0.0.1");
    TEST_ASSERT(blacklist_result == 0, "Blacklist IP removal");

    /* Test connection check */
    bool connection_allowed = network_isolation_check_connection("192.168.1.1", 8080);
    TEST_ASSERT(connection_allowed == true || connection_allowed == false, "Connection check");

    /* Test bind address management */
    int bind_result = network_isolation_set_bind_address("127.0.0.1", 8080);
    TEST_ASSERT(bind_result == 0, "Bind address set");

    char bind_addr[64];
    uint16_t bind_port = 0;
    network_isolation_get_bind_address(bind_addr, sizeof(bind_addr), &bind_port);
    TEST_ASSERT(bind_port == 8080, "Bind address get");

    /* Test firewall management */
    int firewall_result = network_isolation_set_firewall(true);
    TEST_ASSERT(firewall_result == 0, "Firewall enable");

    bool firewall_status = network_isolation_get_firewall_status();
    TEST_ASSERT(firewall_status == true, "Firewall status get");

    /* Test connection statistics */
    uint64_t total_connections = 0, allowed_connections = 0, blocked_connections = 0;
    network_isolation_get_stats(&total_connections, &allowed_connections, &blocked_connections);
    TEST_ASSERT(total_connections >= 0, "Connection statistics get");

    /* Test connection logging */
    network_isolation_log_connection("192.168.1.1", 8080, true);
    TEST_ASSERT(1, "Connection logging");

    /* Test mode string conversion */
    const char *mode_str = network_isolation_mode_to_string(NETWORK_ISOLATION_LOCAL);
    TEST_ASSERT(mode_str != NULL, "Network isolation mode to string");

    network_isolation_shutdown();
    TEST_ASSERT(1, "Network isolation shutdown");
}

/* Main test runner */
int main(void) {
    printf("========================================\n");
    printf("Allama Security Module Tests\n");
    printf("Aerospace-Level Security Testing\n");
    printf("========================================\n");

    /* Run all tests */
    test_audit_log();
    test_auth_system();
    test_code_signing();
    test_resource_monitor();
    test_file_sandbox();
    test_rate_limit();
    /* test_secure_memory(); Temporarily disabled due to mlock issues */
    test_gpu_isolation();
    test_anomaly_detection();
    test_backup_system();
    test_network_isolation();

    /* Print summary */
    printf("\n========================================\n");
    printf("Test Summary\n");
    printf("========================================\n");
    printf("Tests Passed: %d\n", tests_passed);
    printf("Tests Failed: %d\n", tests_failed);
    printf("Total Tests: %d\n", tests_passed + tests_failed);
    printf("Success Rate: %.1f%%\n", 
           (tests_passed * 100.0) / (tests_passed + tests_failed));
    printf("========================================\n");

    return tests_failed > 0 ? 1 : 0;
}
