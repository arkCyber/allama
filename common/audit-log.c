/*
 * Audit Logging System Implementation for allama
 * Aerospace-level security audit logging
 */

#include "audit-log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>

/* Audit log context */
static struct {
    FILE *log_file;
    char log_path[512];
    bool rotate_enabled;
    size_t max_size;
    size_t current_size;
    pthread_mutex_t mutex;
    bool initialized;
    uint64_t total_entries;
    uint64_t error_count;
    uint64_t security_events;
} audit_ctx = {0};

/* Get current timestamp in milliseconds */
static uint64_t get_timestamp_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

/* Get current timestamp string */
static void get_timestamp_str(char *buffer, size_t size) {
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    strftime(buffer, size, "%Y-%m-%d %H:%M:%S", tm_info);
}

/* Audit level to string */
static const char *level_to_string(audit_level_t level) {
    switch (level) {
        case AUDIT_LEVEL_DEBUG: return "DEBUG";
        case AUDIT_LEVEL_INFO: return "INFO";
        case AUDIT_LEVEL_WARNING: return "WARNING";
        case AUDIT_LEVEL_ERROR: return "ERROR";
        case AUDIT_LEVEL_CRITICAL: return "CRITICAL";
        default: return "UNKNOWN";
    }
}

/* Event type to string */
static const char *event_to_string(audit_event_type_t event) {
    switch (event) {
        case AUDIT_EVENT_MODEL_LOAD: return "MODEL_LOAD";
        case AUDIT_EVENT_MODEL_UNLOAD: return "MODEL_UNLOAD";
        case AUDIT_EVENT_API_REQUEST: return "API_REQUEST";
        case AUDIT_EVENT_API_RESPONSE: return "API_RESPONSE";
        case AUDIT_EVENT_AUTH_SUCCESS: return "AUTH_SUCCESS";
        case AUDIT_EVENT_AUTH_FAILURE: return "AUTH_FAILURE";
        case AUDIT_EVENT_RESOURCE_ALLOC: return "RESOURCE_ALLOC";
        case AUDIT_EVENT_RESOURCE_FREE: return "RESOURCE_FREE";
        case AUDIT_EVENT_SECURITY_VIOLATION: return "SECURITY_VIOLATION";
        case AUDIT_EVENT_ERROR: return "ERROR";
        case AUDIT_EVENT_TURBOQUANT: return "TURBOQUANT";
        default: return "UNKNOWN";
    }
}

/* Initialize audit logging system */
int audit_log_init(const char *log_file, bool rotate, size_t max_size) {
    if (audit_ctx.initialized) {
        return 0; /* Already initialized */
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&audit_ctx.mutex, NULL) != 0) {
        return -1;
    }

    /* Store configuration */
    strncpy(audit_ctx.log_path, log_file, sizeof(audit_ctx.log_path) - 1);
    audit_ctx.log_path[sizeof(audit_ctx.log_path) - 1] = '\0';
    audit_ctx.rotate_enabled = rotate;
    audit_ctx.max_size = max_size;
    audit_ctx.current_size = 0;
    audit_ctx.total_entries = 0;
    audit_ctx.error_count = 0;
    audit_ctx.security_events = 0;

    /* Open log file */
    audit_ctx.log_file = fopen(log_file, "a");
    if (audit_ctx.log_file == NULL) {
        pthread_mutex_destroy(&audit_ctx.mutex);
        return -1;
    }

    /* Get current file size */
    struct stat st;
    if (stat(log_file, &st) == 0) {
        audit_ctx.current_size = st.st_size;
    }

    audit_ctx.initialized = true;

    /* Write initialization message */
    char timestamp[64];
    get_timestamp_str(timestamp, sizeof(timestamp));
    fprintf(audit_ctx.log_file, "[%s] [INFO] [SYSTEM] Audit logging system initialized\n", timestamp);
    fflush(audit_ctx.log_file);

    return 0;
}

/* Close audit logging system */
void audit_log_close(void) {
    if (!audit_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&audit_ctx.mutex);

    if (audit_ctx.log_file != NULL) {
        char timestamp[64];
        get_timestamp_str(timestamp, sizeof(timestamp));
        fprintf(audit_ctx.log_file, "[%s] [INFO] [SYSTEM] Audit logging system closed\n", timestamp);
        fprintf(audit_ctx.log_file, "[%s] [INFO] [SYSTEM] Total entries: %llu, Errors: %llu, Security events: %llu\n",
                timestamp, (unsigned long long)audit_ctx.total_entries, (unsigned long long)audit_ctx.error_count, (unsigned long long)audit_ctx.security_events);
        fflush(audit_ctx.log_file);
        fclose(audit_ctx.log_file);
        audit_ctx.log_file = NULL;
    }

    pthread_mutex_unlock(&audit_ctx.mutex);
    pthread_mutex_destroy(&audit_ctx.mutex);
    audit_ctx.initialized = false;
}

/* Log an audit entry */
void audit_log_write(audit_level_t level, audit_event_type_t event_type,
                    const char *component, const char *message,
                    const char *details, uint64_t user_id,
                    const char *ip_address) {
    if (!audit_ctx.initialized || audit_ctx.log_file == NULL) {
        return;
    }

    pthread_mutex_lock(&audit_ctx.mutex);

    char timestamp[64];
    get_timestamp_str(timestamp, sizeof(timestamp));

    /* Format: [timestamp] [level] [event] [component] message [details] user_id ip_address */
    fprintf(audit_ctx.log_file, "[%s] [%s] [%s] [%s] %s",
            timestamp,
            level_to_string(level),
            event_to_string(event_type),
            component ? component : "SYSTEM",
            message ? message : "");

    if (details) {
        fprintf(audit_ctx.log_file, " [%s]", details);
    }

    fprintf(audit_ctx.log_file, " user_id=%llu", (unsigned long long)user_id);

    if (ip_address) {
        fprintf(audit_ctx.log_file, " ip=%s", ip_address);
    }

    fprintf(audit_ctx.log_file, " pid=%u tid=%u\n", getpid(), (uint32_t)pthread_self());

    fflush(audit_ctx.log_file);

    /* Update statistics */
    audit_ctx.total_entries++;
    if (level >= AUDIT_LEVEL_ERROR) {
        audit_ctx.error_count++;
    }
    if (event_type == AUDIT_EVENT_SECURITY_VIOLATION || event_type == AUDIT_EVENT_AUTH_FAILURE) {
        audit_ctx.security_events++;
    }

    /* Check for rotation */
    if (audit_ctx.rotate_enabled && audit_ctx.max_size > 0) {
        long pos = ftell(audit_ctx.log_file);
        if (pos > 0 && (size_t)pos > audit_ctx.max_size) {
            audit_log_rotate();
        }
    }

    pthread_mutex_unlock(&audit_ctx.mutex);
}

/* Convenience functions */
void audit_log_model_load(const char *model_path, size_t model_size, uint64_t user_id) {
    char details[256];
    snprintf(details, sizeof(details), "path=%s size=%zu", model_path, model_size);
    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_MODEL_LOAD, "MODEL_LOADER",
                   "Model loaded", details, user_id, NULL);
}

void audit_log_model_unload(const char *model_path, uint64_t user_id) {
    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_MODEL_UNLOAD, "MODEL_LOADER",
                   "Model unloaded", model_path, user_id, NULL);
}

void audit_log_api_request(const char *endpoint, const char *method, uint64_t user_id,
                          const char *ip_address) {
    char details[256];
    snprintf(details, sizeof(details), "endpoint=%s method=%s", endpoint, method);
    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_API_REQUEST, "API_SERVER",
                   "API request received", details, user_id, ip_address);
}

void audit_log_api_response(const char *endpoint, int status_code, uint64_t user_id) {
    char details[256];
    snprintf(details, sizeof(details), "endpoint=%s status=%d", endpoint, status_code);
    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_API_RESPONSE, "API_SERVER",
                   "API response sent", details, user_id, NULL);
}

void audit_log_auth_success(const char *username, const char *ip_address) {
    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "AUTH",
                   "Authentication successful", username, 0, ip_address);
}

void audit_log_auth_failure(const char *username, const char *ip_address, const char *reason) {
    audit_log_write(AUDIT_LEVEL_WARNING, AUDIT_EVENT_AUTH_FAILURE, "AUTH",
                   "Authentication failed", reason, 0, ip_address);
}

void audit_log_security_violation(const char *component, const char *violation_type,
                                  const char *details) {
    audit_log_write(AUDIT_LEVEL_CRITICAL, AUDIT_EVENT_SECURITY_VIOLATION, component,
                   "Security violation detected", violation_type, 0, NULL);
}

void audit_log_error(const char *component, const char *error_msg, const char *details) {
    audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_ERROR, component,
                   "Error occurred", error_msg, 0, NULL);
}

void audit_log_turboquant(const char *operation, const char *cache_type, size_t compression_ratio) {
    char details[256];
    snprintf(details, sizeof(details), "operation=%s cache_type=%s ratio=%zu",
             operation, cache_type, compression_ratio);
    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_TURBOQUANT, "TURBOQUANT",
                   "TurboQuant operation", details, 0, NULL);
}

/* Flush audit log to disk */
void audit_log_flush(void) {
    if (!audit_ctx.initialized || audit_ctx.log_file == NULL) {
        return;
    }

    pthread_mutex_lock(&audit_ctx.mutex);
    fflush(audit_ctx.log_file);
    pthread_mutex_unlock(&audit_ctx.mutex);
}

/* Rotate audit log */
void audit_log_rotate(void) {
    if (!audit_ctx.initialized || audit_ctx.log_file == NULL) {
        return;
    }

    pthread_mutex_lock(&audit_ctx.mutex);

    /* Close current log file */
    fclose(audit_ctx.log_file);

    /* Rename current log file */
    char old_path[512];
    char new_path[512];
    time_t now = time(NULL);
    snprintf(old_path, sizeof(old_path), "%s", audit_ctx.log_path);
    snprintf(new_path, sizeof(new_path), "%s.%ld", audit_ctx.log_path, now);
    rename(old_path, new_path);

    /* Open new log file */
    audit_ctx.log_file = fopen(audit_ctx.log_path, "w");
    audit_ctx.current_size = 0;

    char timestamp[64];
    get_timestamp_str(timestamp, sizeof(timestamp));
    fprintf(audit_ctx.log_file, "[%s] [INFO] [SYSTEM] Audit log rotated\n", timestamp);
    fflush(audit_ctx.log_file);

    pthread_mutex_unlock(&audit_ctx.mutex);
}

/* Get audit log statistics */
void audit_log_get_stats(uint64_t *total_entries, uint64_t *error_count,
                         uint64_t *security_events) {
    if (!audit_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&audit_ctx.mutex);
    if (total_entries) *total_entries = audit_ctx.total_entries;
    if (error_count) *error_count = audit_ctx.error_count;
    if (security_events) *security_events = audit_ctx.security_events;
    pthread_mutex_unlock(&audit_ctx.mutex);
}
