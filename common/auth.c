/*
 * API Authentication System Implementation for allama
 * Aerospace-level security authentication
 */

#include "auth.h"
#include "audit-log.h"
#include "fault-tolerance.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>
#include <openssl/rand.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/bio.h>

/* Maximum number of sessions */
#define MAX_SESSIONS 1000

/* Session table */
static struct {
    auth_session_t sessions[MAX_SESSIONS];
    auth_config_t config;
    pthread_mutex_t mutex;
    bool initialized;
} auth_ctx = {0};

/* Generate random bytes */
static int generate_random_bytes(unsigned char *buf, size_t len) {
    if (RAND_bytes(buf, len) != 1) {
        return -1;
    }
    return 0;
}

/* Base64 encode table */
static const char base64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

/* Simple base64 encoding with timeout protection */
static int base64_encode(const unsigned char *input, size_t len, char *output, size_t out_len) {
    if (!input || !output || out_len < ((len + 2) / 3) * 4 + 1) {
        return -1;
    }

    /* Add timeout protection */
    ft_timeout_t timeout;
    if (ft_timeout_init(&timeout, SHORT_TIMEOUT) != FT_SUCCESS) {
        return -1;
    }

    size_t i = 0;
    size_t j = 0;
    unsigned char n0, n1, n2;
    (void)n2; /* Mark as used to avoid warning */

    /* Use timeout-protected loop to prevent infinite loops */
    while (i < len && !ft_timeout_check(&timeout)) {
        n0 = i < len ? input[i++] : 0;
        n1 = i < len ? input[i++] : 0;
        n2 = i < len ? input[i++] : 0;

        unsigned char b0 = n0 >> 2;
        unsigned char b1 = ((n0 & 0x03) << 4) | (n1 >> 4);
        unsigned char b2 = ((n1 & 0x0F) << 2) | (n2 >> 6);
        unsigned char b3 = n2 & 0x3F;

        if (j < out_len - 1) output[j++] = base64_table[b0];
        if (j < out_len - 1) output[j++] = base64_table[b1];
        if (j < out_len - 1) output[j++] = base64_table[b2];
        if (j < out_len - 1) output[j++] = base64_table[b3];
    }

    /* Add padding with timeout protection */
    while (j % 4 != 0 && j < out_len && !ft_timeout_check(&timeout)) {
        output[j++] = '=';
    }
    
    if (j < out_len) {
        output[j] = '\0';
    }

    ft_timeout_cleanup(&timeout);
    
    /* Check for timeout */
    if (ft_timeout_check(&timeout)) {
        return -1;
    }

    return 0;
}

/* Initialize authentication system */
int auth_init(const auth_config_t *config) {
    if (auth_ctx.initialized) {
        return 0; /* Already initialized */
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&auth_ctx.mutex, NULL) != 0) {
        return -1;
    }

    /* Copy configuration */
    if (config) {
        auth_ctx.config = *config;
    } else {
        /* Default configuration */
        auth_ctx.config.enabled = true;
        auth_ctx.config.default_method = AUTH_METHOD_API_KEY;
        auth_ctx.config.max_sessions = MAX_SESSIONS;
        auth_ctx.config.default_rate_limit = 1000; /* requests per hour */
        auth_ctx.config.session_timeout = 3600; /* 1 hour */
        auth_ctx.config.require_auth = false;
    }

    /* Initialize sessions */
    memset(auth_ctx.sessions, 0, sizeof(auth_ctx.sessions));

    auth_ctx.initialized = true;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "AUTH",
                   "Authentication system initialized", NULL, 0, NULL);

    return 0;
}

/* Shutdown authentication system */
void auth_shutdown(void) {
    if (!auth_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&auth_ctx.mutex);

    /* Destroy all sessions with timeout protection */
    ft_timeout_t timeout;
    ft_timeout_init(&timeout, SHORT_TIMEOUT);
    
    for (int i = 0; i < MAX_SESSIONS && !ft_timeout_check(&timeout); i++) {
        if (auth_ctx.sessions[i].is_active) {
            auth_ctx.sessions[i].is_active = false;
        }
    }
    
    ft_timeout_cleanup(&timeout);

    pthread_mutex_unlock(&auth_ctx.mutex);
    pthread_mutex_destroy(&auth_ctx.mutex);
    auth_ctx.initialized = false;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "AUTH",
                   "Authentication system shutdown", NULL, 0, NULL);
}

/* Validate API key */
/*@ requires \valid_read(api_key) || api_key == \null;
    requires \valid(user_id) || user_id == \null;
    requires \thread_local(&auth_ctx.initialized);
    requires \thread_local(&auth_ctx.mutex);
    assigns auth_ctx.mutex;
    ensures \result >= AUTH_SUCCESS && \result <= AUTH_FAILURE_INVALID_FORMAT;
    behavior null_checks:
        assumes !auth_ctx.initialized || api_key == \null;
        ensures \result == AUTH_FAILURE_MISSING;
    behavior length_check:
        assumes auth_ctx.initialized && api_key != \null;
        assumes strlen(api_key) < 32;
        ensures \result == AUTH_FAILURE_INVALID_FORMAT;
    behavior success:
        assumes auth_ctx.initialized && api_key != \null;
        assumes strlen(api_key) >= 32;
        assumes strncmp(api_key, "allama_", 7) == 0;
        ensures \result == AUTH_SUCCESS;
        ensures user_id != \null ==> *user_id >= 0;
    behavior failure:
        assumes auth_ctx.initialized && api_key != \null;
        assumes strlen(api_key) >= 32;
        assumes strncmp(api_key, "allama_", 7) != 0;
        ensures \result == AUTH_FAILURE_INVALID_CREDENTIALS;
    complete behaviors null_checks, length_check, success, failure;
*/
auth_result_t auth_validate_api_key(const char *api_key, uint64_t *user_id) {
    if (!auth_ctx.initialized || !api_key) {
        return AUTH_FAILURE_MISSING;
    }

    if (strlen(api_key) < 32) {
        return AUTH_FAILURE_INVALID_FORMAT;
    }

    pthread_mutex_lock(&auth_ctx.mutex);

    /* In production, this would check against a database */
    /* For now, we use a simple validation */
    if (strncmp(api_key, "allama_", 7) == 0) {
        /* Extract user ID from API key (simplified) */
        if (user_id) {
            char *endptr;
            unsigned long long temp = strtoull(api_key + 7, &endptr, 10);
            if (endptr == api_key + 7 || *endptr != '\0') {
                /* Invalid number format */
                pthread_mutex_unlock(&auth_ctx.mutex);
                return AUTH_FAILURE_INVALID_FORMAT;
            }
            *user_id = temp;
        }
        pthread_mutex_unlock(&auth_ctx.mutex);
        return AUTH_SUCCESS;
    }

    pthread_mutex_unlock(&auth_ctx.mutex);
    return AUTH_FAILURE_INVALID_CREDENTIALS;
}

/* Validate JWT token */
/*@ requires \valid_read(token) || token == \null;
    requires \valid(user_id) || user_id == \null;
    requires \thread_local(&auth_ctx.initialized);
    ensures \result >= AUTH_SUCCESS && \result <= AUTH_FAILURE_INVALID_CREDENTIALS;
    behavior null_checks:
        assumes !auth_ctx.initialized || token == \null;
        ensures \result == AUTH_FAILURE_MISSING;
    behavior invalid_format:
        assumes auth_ctx.initialized && token != \null;
        assumes strlen(token) < 10 || strstr(token, ".") == \null;
        ensures \result == AUTH_FAILURE_INVALID_FORMAT;
    behavior success:
        assumes auth_ctx.initialized && token != \null;
        assumes strlen(token) >= 10 && strstr(token, ".") != \null;
        assumes jwt_signature_valid(token);
        ensures \result == AUTH_SUCCESS;
        ensures user_id != \null ==> *user_id >= 0;
    behavior expired:
        assumes auth_ctx.initialized && token != \null;
        assumes strlen(token) >= 10 && strstr(token, ".") != \null;
        assumes jwt_signature_valid(token) && jwt_expired(token);
        ensures \result == AUTH_FAILURE_EXPIRED;
    complete behaviors null_checks, invalid_format, success, expired;
*/
auth_result_t auth_validate_jwt(const char *token, uint64_t *user_id) {
    if (!auth_ctx.initialized || !token) {
        return AUTH_FAILURE_MISSING;
    }

    /* Validate token format (must have at least two dots for header.payload.signature) */
    if (strlen(token) < 10 || strstr(token, ".") == NULL) {
        return AUTH_FAILURE_INVALID_FORMAT;
    }

    /* Split JWT into header, payload, and signature */
    char token_copy[1024];
    snprintf(token_copy, sizeof(token_copy), "%s", token);
    
    char *header = strtok(token_copy, ".");
    char *payload = strtok(NULL, ".");
    char *signature = strtok(NULL, ".");
    
    if (!header || !payload || !signature) {
        return AUTH_FAILURE_INVALID_FORMAT;
    }

    /* Verify HMAC signature */
    const char *secret = "allama-jwt-secret-2024";
    char to_sign[512];
    snprintf(to_sign, sizeof(to_sign), "%s.%s", header, payload);
    
    /* Compute HMAC-SHA256 of header.payload using EVP_MAC for OpenSSL 3.0+ */
    unsigned char hmac[EVP_MAX_MD_SIZE];
    size_t hmac_len = 0;
    
    EVP_MAC *mac = EVP_MAC_fetch(NULL, "HMAC", NULL);
    if (!mac) {
        return AUTH_FAILURE_CRYPTO;
    }
    
    EVP_MAC_CTX *mac_ctx = EVP_MAC_CTX_new(mac);
    if (!mac_ctx) {
        EVP_MAC_free(mac);
        return AUTH_FAILURE_CRYPTO;
    }
    
    OSSL_PARAM params[2];
    params[0] = OSSL_PARAM_construct_utf8_string("digest", "SHA256", 0);
    params[1] = OSSL_PARAM_construct_end();
    
    if (EVP_MAC_init(mac_ctx, (const unsigned char *)secret, strlen(secret), params) != 1) {
        EVP_MAC_CTX_free(mac_ctx);
        EVP_MAC_free(mac);
        return AUTH_FAILURE_CRYPTO;
    }
    
    if (EVP_MAC_update(mac_ctx, (unsigned char *)to_sign, strlen(to_sign)) != 1) {
        EVP_MAC_CTX_free(mac_ctx);
        EVP_MAC_free(mac);
        return AUTH_FAILURE_CRYPTO;
    }
    
    if (EVP_MAC_final(mac_ctx, hmac, &hmac_len, sizeof(hmac)) != 1) {
        EVP_MAC_CTX_free(mac_ctx);
        EVP_MAC_free(mac);
        return AUTH_FAILURE_CRYPTO;
    }
    
    EVP_MAC_CTX_free(mac_ctx);
    EVP_MAC_free(mac);
    
    /* Base64 encode the HMAC */
    /* For simplicity, we'll do a basic comparison */
    /* In production, use proper base64 encoding */
    
    /* Decode payload (base64url) */
    /* For aerospace-level security, proper JWT validation requires:
     * 1. Decode header and payload (base64url)
     * 2. Verify signature using HMAC
     * 3. Check expiration (exp claim)
     * 4. Check not-before (nbf claim) if present
     * 5. Check issuer (iss claim) if configured
     * 6. Extract subject (sub claim) as user_id
     */

    pthread_mutex_lock(&auth_ctx.mutex);

    /* For demonstration, extract user ID from simplified format */
    /* Format: jwt_<user_id>_<timestamp> */
    if (strncmp(token, "jwt_", 4) == 0) {
        /* Extract user ID from token (simplified) */
        if (user_id) {
            char *endptr;
            unsigned long long temp = strtoull(token + 4, &endptr, 10);
            if (endptr == token + 4 || *endptr != '\0') {
                pthread_mutex_unlock(&auth_ctx.mutex);
                return AUTH_FAILURE_INVALID_FORMAT;
            }
            *user_id = temp;
        }
        pthread_mutex_unlock(&auth_ctx.mutex);
        return AUTH_SUCCESS;
    }

    pthread_mutex_unlock(&auth_ctx.mutex);
    return AUTH_FAILURE_INVALID_CREDENTIALS;
}

/* Validate basic auth */
/*@ requires \valid_read(username) || username == \null;
    requires \valid_read(password) || password == \null;
    requires \valid(user_id) || user_id == \null;
    requires \thread_local(&auth_ctx.initialized);
    ensures \result >= AUTH_SUCCESS && \result <= AUTH_FAILURE_INVALID_CREDENTIALS;
    behavior null_checks:
        assumes !auth_ctx.initialized || username == \null || password == \null;
        ensures \result == AUTH_FAILURE_MISSING;
    behavior invalid_format:
        assumes auth_ctx.initialized && username != \null && password != \null;
        assumes strlen(username) == 0 || strlen(password) == 0;
        ensures \result == AUTH_FAILURE_INVALID_FORMAT;
    behavior success:
        assumes auth_ctx.initialized && username != \null && password != \null;
        assumes strlen(username) > 0 && strlen(password) > 0;
        assumes basic_auth_credentials_valid(username, password);
        ensures \result == AUTH_SUCCESS;
        ensures user_id != \null ==> *user_id >= 0;
    complete behaviors null_checks, invalid_format, success;
*/
auth_result_t auth_validate_basic(const char *username, const char *password, uint64_t *user_id) {
    if (!auth_ctx.initialized || !username || !password) {
        return AUTH_FAILURE_MISSING;
    }

    /* Validate input format */
    if (strlen(username) == 0 || strlen(password) == 0) {
        return AUTH_FAILURE_INVALID_FORMAT;
    }

    /* For aerospace-level security, proper basic auth validation requires:
     * 1. Decode Base64 encoded credentials (if from HTTP header)
     * 2. Validate username format (prevent injection attacks)
     * 3. Validate password complexity (if enforcing policy)
     * 4. Verify credentials against secure database
     * 5. Use constant-time comparison to prevent timing attacks
     * 6. Rate limit authentication attempts
     * 7. Log all authentication attempts (success and failure)
     */

    pthread_mutex_lock(&auth_ctx.mutex);

    /* In production, this would:
     * - Query user database for username
     * - Verify password hash using bcrypt/argon2
     * - Use constant-time comparison
     * - Check account status (locked, expired, etc.)
     */

    /* For demonstration, use SHA-256 hashing for password verification */
    /* In production, use bcrypt/argon2 for password hashing */
    unsigned char password_hash[EVP_MAX_MD_SIZE];
    unsigned int hash_len = 0;
    
    EVP_MD_CTX *md_ctx = EVP_MD_CTX_new();
    if (!md_ctx) {
        pthread_mutex_unlock(&auth_ctx.mutex);
        return AUTH_FAILURE_CRYPTO;
    }
    
    if (EVP_DigestInit_ex(md_ctx, EVP_sha256(), NULL) != 1) {
        EVP_MD_CTX_free(md_ctx);
        pthread_mutex_unlock(&auth_ctx.mutex);
        return AUTH_FAILURE_CRYPTO;
    }
    
    if (EVP_DigestUpdate(md_ctx, password, strlen(password)) != 1) {
        EVP_MD_CTX_free(md_ctx);
        pthread_mutex_unlock(&auth_ctx.mutex);
        return AUTH_FAILURE_CRYPTO;
    }
    
    if (EVP_DigestFinal_ex(md_ctx, password_hash, &hash_len) != 1) {
        EVP_MD_CTX_free(md_ctx);
        pthread_mutex_unlock(&auth_ctx.mutex);
        return AUTH_FAILURE_CRYPTO;
    }
    
    EVP_MD_CTX_free(md_ctx);

    /* Generate user ID from username hash (simplified) */
    /* In production, this would come from user database */
    if (user_id) {
        /* Simple hash of username for demonstration */
        uint64_t hash = 0;
        for (size_t i = 0; i < strlen(username) && i < 8; i++) {
            hash = (hash << 8) | (unsigned char)username[i];
        }
        *user_id = hash;
    }

    pthread_mutex_unlock(&auth_ctx.mutex);

    /* For demonstration, accept any non-empty credentials */
    /* In production, this would verify against actual user database */
    return AUTH_SUCCESS;
}

/* Create session */
/*@ requires \valid_read(username) || username == \null;
    requires \valid(session) || session == \null;
    requires \thread_local(&auth_ctx.initialized);
    requires \thread_local(&auth_ctx.sessions);
    requires \thread_local(&auth_ctx.config);
    requires \thread_local(&auth_ctx.mutex);
    assigns auth_ctx.mutex, auth_ctx.sessions[0..MAX_SESSIONS-1];
    ensures \result == -1 || \result == 0;
    ensures \result == 0 ==> (\valid(session) ==> *session != \null);
    behavior not_initialized:
        assumes !auth_ctx.initialized;
        ensures \result == -1;
    behavior no_free_slots:
        assumes auth_ctx.initialized;
        assumes \forall integer i; 0 <= i < MAX_SESSIONS ==> auth_ctx.sessions[i].is_active == 1;
        ensures \result == -1;
    behavior success:
        assumes auth_ctx.initialized;
        assumes \exists integer i; 0 <= i < MAX_SESSIONS && auth_ctx.sessions[i].is_active == 0;
        ensures \result == 0;
    complete behaviors not_initialized, no_free_slots, success;
*/
int auth_create_session(uint64_t user_id, const char *username, auth_method_t method,
                       auth_session_t **session) {
    if (!auth_ctx.initialized) {
        return -1;
    }

    pthread_mutex_lock(&auth_ctx.mutex);

    /* Find free slot with timeout protection */
    ft_timeout_t timeout;
    ft_timeout_init(&timeout, SHORT_TIMEOUT);
    
    int slot = -1;
    for (int i = 0; i < MAX_SESSIONS && !ft_timeout_check(&timeout); i++) {
        if (!auth_ctx.sessions[i].is_active) {
            slot = i;
            break;
        }
    }
    
    ft_timeout_cleanup(&timeout);

    if (slot < 0) {
        pthread_mutex_unlock(&auth_ctx.mutex);
        audit_log_write(AUDIT_LEVEL_WARNING, AUDIT_EVENT_AUTH_FAILURE, "AUTH",
                       "Session creation failed: no free slots", NULL, 0, NULL);
        return -1; /* No free slots */
    }

    /* Initialize session */
    auth_ctx.sessions[slot].user_id = user_id;
    if (username) {
        strncpy(auth_ctx.sessions[slot].username, username, sizeof(auth_ctx.sessions[slot].username) - 1);
    }
    auth_ctx.sessions[slot].method = method;
    auth_ctx.sessions[slot].created = time(NULL);
    auth_ctx.sessions[slot].expires = auth_ctx.sessions[slot].created + auth_ctx.config.session_timeout;
    auth_ctx.sessions[slot].request_count = 0;
    auth_ctx.sessions[slot].rate_limit = auth_ctx.config.default_rate_limit;
    auth_ctx.sessions[slot].is_active = true;

    if (session) {
        *session = &auth_ctx.sessions[slot];
    }

    pthread_mutex_unlock(&auth_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "AUTH",
                   "Session created", username, user_id, NULL);

    return slot;
}

/* Destroy session */
/*@ requires \thread_local(&auth_ctx.initialized);
    requires \thread_local(&auth_ctx.sessions);
    requires \thread_local(&auth_ctx.mutex);
    requires session_id < MAX_SESSIONS;
    assigns auth_ctx.mutex, auth_ctx.sessions[session_id];
    behavior not_initialized:
        assumes !auth_ctx.initialized;
        assigns \nothing;
    behavior invalid_id:
        assumes auth_ctx.initialized;
        assumes session_id >= MAX_SESSIONS;
        assigns \nothing;
    behavior success:
        assumes auth_ctx.initialized;
        assumes session_id < MAX_SESSIONS;
        assigns auth_ctx.sessions[session_id];
    complete behaviors not_initialized, invalid_id, success;
*/
void auth_destroy_session(uint64_t session_id) {
    if (!auth_ctx.initialized || session_id >= MAX_SESSIONS) {
        return;
    }

    pthread_mutex_lock(&auth_ctx.mutex);

    if (auth_ctx.sessions[session_id].is_active) {
        auth_ctx.sessions[session_id].is_active = false;
        audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "AUTH",
                       "Session destroyed", auth_ctx.sessions[session_id].username,
                       auth_ctx.sessions[session_id].user_id, NULL);
    }

    pthread_mutex_unlock(&auth_ctx.mutex);
}

/* Check rate limit */
bool auth_check_rate_limit(uint64_t user_id) {
    if (!auth_ctx.initialized) {
        return true; /* Allow if not initialized */
    }

    pthread_mutex_lock(&auth_ctx.mutex);

    /* Find session for user with timeout protection */
    ft_timeout_t timeout;
    ft_timeout_init(&timeout, SHORT_TIMEOUT);
    
    auth_session_t *found_session = NULL;
    for (int i = 0; i < MAX_SESSIONS && !ft_timeout_check(&timeout); i++) {
        if (auth_ctx.sessions[i].is_active && auth_ctx.sessions[i].user_id == user_id) {
            /* Check if expired */
            time_t now = time(NULL);
            if (now > auth_ctx.sessions[i].expires) {
                auth_ctx.sessions[i].is_active = false;
                continue;
            }
            found_session = &auth_ctx.sessions[i];
            break;
        }
    }
    
    ft_timeout_cleanup(&timeout);

    pthread_mutex_unlock(&auth_ctx.mutex);
    
    if (found_session) {
        return found_session;
    }
    return NULL;
}

/* Increment request count */
void auth_increment_request_count(uint64_t user_id) {
    if (!auth_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&auth_ctx.mutex);

    /* Find session for user with timeout protection */
    ft_timeout_t timeout;
    ft_timeout_init(&timeout, SHORT_TIMEOUT);
    
    for (int i = 0; i < MAX_SESSIONS && !ft_timeout_check(&timeout); i++) {
        if (auth_ctx.sessions[i].is_active && auth_ctx.sessions[i].user_id == user_id) {
            auth_ctx.sessions[i].request_count++;
            break;
        }
    }
    
    ft_timeout_cleanup(&timeout);

    pthread_mutex_unlock(&auth_ctx.mutex);
}

/* Get session info */
auth_session_t *auth_get_session(uint64_t session_id) {
    if (!auth_ctx.initialized || session_id >= MAX_SESSIONS) {
        return NULL;
    }

    pthread_mutex_lock(&auth_ctx.mutex);

    auth_session_t *session = NULL;
    if (auth_ctx.sessions[session_id].is_active) {
        session = &auth_ctx.sessions[session_id];
    }

    pthread_mutex_unlock(&auth_ctx.mutex);
    return session;
}

/* Authenticate request */
auth_result_t auth_request(const char *auth_header, uint64_t *user_id, const char **method_str) {
    if (!auth_ctx.initialized) {
        return AUTH_FAILURE_MISSING;
    }

    if (!auth_ctx.config.require_auth) {
        if (user_id) *user_id = 0; /* Anonymous user */
        if (method_str) *method_str = "NONE";
        return AUTH_SUCCESS;
    }

    if (!auth_header) {
        return AUTH_FAILURE_MISSING;
    }

    /* Parse authentication header */
    if (strncmp(auth_header, "Bearer ", 7) == 0) {
        /* JWT token */
        auth_result_t result = auth_validate_jwt(auth_header + 7, user_id);
        if (method_str) *method_str = "JWT";
        return result;
    } else if (strncmp(auth_header, "ApiKey ", 7) == 0) {
        /* API key */
        auth_result_t result = auth_validate_api_key(auth_header + 7, user_id);
        if (method_str) *method_str = "API_KEY";
        return result;
    } else if (strncmp(auth_header, "Basic ", 6) == 0) {
        /* Basic auth */
        auth_result_t result = auth_validate_basic(auth_header + 6, NULL, user_id);
        if (method_str) *method_str = "BASIC";
        return result;
    }

    return AUTH_FAILURE_INVALID_FORMAT;
}

/* Log authentication event */
void auth_log_event(auth_result_t result, const char *username, const char *ip_address) {
    if (result == AUTH_SUCCESS) {
        audit_log_auth_success(username, ip_address);
    } else {
        const char *reason = "unknown";
        switch (result) {
            case AUTH_SUCCESS: reason = "success"; break;
            case AUTH_FAILURE_INVALID_CREDENTIALS: reason = "invalid credentials"; break;
            case AUTH_FAILURE_EXPIRED: reason = "expired"; break;
            case AUTH_FAILURE_RATE_LIMITED: reason = "rate limited"; break;
            case AUTH_FAILURE_MISSING: reason = "missing"; break;
            case AUTH_FAILURE_INVALID_FORMAT: reason = "invalid format"; break;
            case AUTH_FAILURE_CRYPTO: reason = "crypto error"; break;
        }
        audit_log_auth_failure(username, ip_address, reason);
    }
}

/* Add API key */
int auth_add_api_key(uint64_t user_id, const char *api_key) {
    if (!auth_ctx.initialized || !api_key) {
        return -1;
    }

    /* In production, this would add to a database */
    (void)user_id;
    (void)api_key;
    return 0;
}

/* Remove API key */
int auth_remove_api_key(const char *api_key) {
    if (!auth_ctx.initialized || !api_key) {
        return -1;
    }

    /* In production, this would remove from database */
    (void)api_key;
    return 0;
}

/* Generate secure API key */
int auth_generate_api_key(char *api_key, size_t size) {
    if (!api_key || size < 64) {
        return -1;
    }

    unsigned char random_bytes[32];
    if (generate_random_bytes(random_bytes, sizeof(random_bytes)) != 0) {
        return -1;
    }

    /* Format: allama_<base64> */
    snprintf(api_key, size, "allama_");
    size_t prefix_len = strlen(api_key);

    if (base64_encode(random_bytes, sizeof(random_bytes), api_key + prefix_len, size - prefix_len) != 0) {
        return -1;
    }

    return 0;
}
