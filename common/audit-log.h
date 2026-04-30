/*
 * Audit Logging System for allama
 * Aerospace-level security audit logging
 * 
 * Provides comprehensive logging for:
 * - Model loading/unloading
 * - API requests/responses
 * - Authentication events
 * - Resource usage
 * - Security events
 * - Errors and exceptions
 */

#ifndef AUDIT_LOG_H
#define AUDIT_LOG_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Audit log levels */
typedef enum {
    AUDIT_LEVEL_DEBUG = 0,
    AUDIT_LEVEL_INFO = 1,
    AUDIT_LEVEL_WARNING = 2,
    AUDIT_LEVEL_ERROR = 3,
    AUDIT_LEVEL_CRITICAL = 4
} audit_level_t;

/* Audit event types */
typedef enum {
    AUDIT_EVENT_MODEL_LOAD = 0,
    AUDIT_EVENT_MODEL_UNLOAD = 1,
    AUDIT_EVENT_API_REQUEST = 2,
    AUDIT_EVENT_API_RESPONSE = 3,
    AUDIT_EVENT_AUTH_SUCCESS = 4,
    AUDIT_EVENT_AUTH_FAILURE = 5,
    AUDIT_EVENT_RESOURCE_ALLOC = 6,
    AUDIT_EVENT_RESOURCE_FREE = 7,
    AUDIT_EVENT_SECURITY_VIOLATION = 8,
    AUDIT_EVENT_ERROR = 9,
    AUDIT_EVENT_TURBOQUANT = 10
} audit_event_type_t;

/* Audit log entry */
typedef struct {
    uint64_t timestamp;
    audit_level_t level;
    audit_event_type_t event_type;
    const char *component;
    const char *message;
    const char *details;
    uint64_t user_id;
    const char *ip_address;
    uint32_t process_id;
    uint32_t thread_id;
} audit_entry_t;

/* Initialize audit logging system */
int audit_log_init(const char *log_file, bool rotate, size_t max_size);

/* Close audit logging system */
void audit_log_close(void);

/* Log an audit entry */
void audit_log_write(audit_level_t level, audit_event_type_t event_type,
                    const char *component, const char *message,
                    const char *details, uint64_t user_id,
                    const char *ip_address);

/* Convenience functions for common events */
void audit_log_model_load(const char *model_path, size_t model_size, uint64_t user_id);
void audit_log_model_unload(const char *model_path, uint64_t user_id);
void audit_log_api_request(const char *endpoint, const char *method, uint64_t user_id,
                          const char *ip_address);
void audit_log_api_response(const char *endpoint, int status_code, uint64_t user_id);
void audit_log_auth_success(const char *username, const char *ip_address);
void audit_log_auth_failure(const char *username, const char *ip_address, const char *reason);
void audit_log_security_violation(const char *component, const char *violation_type,
                                  const char *details);
void audit_log_error(const char *component, const char *error_msg, const char *details);
void audit_log_turboquant(const char *operation, const char *cache_type, size_t compression_ratio);

/* Flush audit log to disk */
void audit_log_flush(void);

/* Rotate audit log (if enabled) */
void audit_log_rotate(void);

/* Get audit log statistics */
void audit_log_get_stats(uint64_t *total_entries, uint64_t *error_count,
                         uint64_t *security_events);

#ifdef __cplusplus
}
#endif

#endif /* AUDIT_LOG_H */
