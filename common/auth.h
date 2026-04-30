/*
 * API Authentication System for allama
 * Aerospace-level security authentication
 * 
 * Provides:
 * - API key authentication
 * - JWT token validation
 * - Rate limiting per user
 * - Session management
 * - Authentication logging
 */

#ifndef AUTH_H
#define AUTH_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Authentication methods */
typedef enum {
    AUTH_METHOD_NONE = 0,
    AUTH_METHOD_API_KEY = 1,
    AUTH_METHOD_JWT = 2,
    AUTH_METHOD_BASIC = 3
} auth_method_t;

/* Authentication result */
typedef enum {
    AUTH_SUCCESS = 0,
    AUTH_FAILURE_INVALID_CREDENTIALS = 1,
    AUTH_FAILURE_EXPIRED = 2,
    AUTH_FAILURE_RATE_LIMITED = 3,
    AUTH_FAILURE_MISSING = 4,
    AUTH_FAILURE_INVALID_FORMAT = 5,
    AUTH_FAILURE_CRYPTO = 6
} auth_result_t;

/* User session */
typedef struct {
    uint64_t user_id;
    char username[128];
    char api_key[256];
    auth_method_t method;
    time_t created;
    time_t expires;
    uint32_t request_count;
    uint32_t rate_limit;
    bool is_active;
} auth_session_t;

/* Authentication context */
typedef struct {
    bool enabled;
    auth_method_t default_method;
    uint32_t max_sessions;
    uint32_t default_rate_limit;
    time_t session_timeout;
    bool require_auth;
} auth_config_t;

/* Initialize authentication system */
int auth_init(const auth_config_t *config);

/* Shutdown authentication system */
void auth_shutdown(void);

/* Validate API key */
auth_result_t auth_validate_api_key(const char *api_key, uint64_t *user_id);

/* Validate JWT token */
auth_result_t auth_validate_jwt(const char *token, uint64_t *user_id);

/* Validate basic auth */
auth_result_t auth_validate_basic(const char *username, const char *password, uint64_t *user_id);

/* Create session */
int auth_create_session(uint64_t user_id, const char *username, auth_method_t method,
                       auth_session_t **session);

/* Destroy session */
void auth_destroy_session(uint64_t session_id);

/* Check rate limit */
bool auth_check_rate_limit(uint64_t user_id);

/* Increment request count */
void auth_increment_request_count(uint64_t user_id);

/* Get session info */
auth_session_t *auth_get_session(uint64_t session_id);

/* Authenticate request */
auth_result_t auth_request(const char *auth_header, uint64_t *user_id, const char **method_str);

/* Log authentication event */
void auth_log_event(auth_result_t result, const char *username, const char *ip_address);

/* Add API key */
int auth_add_api_key(uint64_t user_id, const char *api_key);

/* Remove API key */
int auth_remove_api_key(const char *api_key);

/* Generate secure API key */
int auth_generate_api_key(char *api_key, size_t size);

#ifdef __cplusplus
}
#endif

#endif /* AUTH_H */
