/*
 * Rate Limiting System Implementation for allama
 * Aerospace-level rate limiting
 */

#include "rate-limit.h"
#include "audit-log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <time.h>

/* Maximum number of rate limit contexts */
#define MAX_RATE_LIMIT_CONTEXTS 1000

/* Rate limiting context */
static struct {
    rate_limit_config_t config;
    rate_limit_context_t contexts[MAX_RATE_LIMIT_CONTEXTS];
    uint64_t total_requests;
    uint64_t limited_requests;
    bool initialized;
    pthread_mutex_t mutex;
} rate_limit_ctx = {0};

/* Update token bucket */
static void update_bucket(rate_limit_bucket_t *bucket, time_t now) {
    if (now <= bucket->last_update) {
        return;
    }

    double elapsed = difftime(now, bucket->last_update);
    uint32_t new_tokens = (uint32_t)(elapsed * bucket->rate);

    bucket->tokens = bucket->tokens + new_tokens;
    if (bucket->tokens > bucket->capacity) {
        bucket->tokens = bucket->capacity;
    }

    bucket->last_update = now;
}

/* Initialize rate limiting system */
int rate_limit_init(const rate_limit_config_t *config) {
    if (rate_limit_ctx.initialized) {
        return 0; /* Already initialized */
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&rate_limit_ctx.mutex, NULL) != 0) {
        return -1;
    }

    /* Copy configuration */
    if (config) {
        rate_limit_ctx.config = *config;
    } else {
        /* Default configuration */
        rate_limit_ctx.config.rate = 100; /* 100 requests per second */
        rate_limit_ctx.config.burst = 200; /* Max burst size */
        rate_limit_ctx.config.algorithm = RATE_LIMIT_TOKEN_BUCKET;
        rate_limit_ctx.config.enabled = true;
    }

    /* Initialize contexts */
    memset(rate_limit_ctx.contexts, 0, sizeof(rate_limit_ctx.contexts));

    rate_limit_ctx.total_requests = 0;
    rate_limit_ctx.limited_requests = 0;
    rate_limit_ctx.initialized = true;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "RATE_LIMIT",
                   "Rate limiting system initialized", NULL, 0, NULL);

    return 0;
}

/* Shutdown rate limiting system */
void rate_limit_shutdown(void) {
    if (!rate_limit_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);
    pthread_mutex_unlock(&rate_limit_ctx.mutex);
    pthread_mutex_destroy(&rate_limit_ctx.mutex);
    rate_limit_ctx.initialized = false;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "RATE_LIMIT",
                   "Rate limiting system shutdown", NULL, 0, NULL);
}

/* Find or create context for user */
static rate_limit_context_t *get_user_context(uint64_t user_id) {
    for (int i = 0; i < MAX_RATE_LIMIT_CONTEXTS; i++) {
        if (rate_limit_ctx.contexts[i].is_active && rate_limit_ctx.contexts[i].user_id == user_id) {
            return &rate_limit_ctx.contexts[i];
        }
    }

    /* Find free slot */
    for (int i = 0; i < MAX_RATE_LIMIT_CONTEXTS; i++) {
        if (!rate_limit_ctx.contexts[i].is_active) {
            rate_limit_ctx.contexts[i].user_id = user_id;
            rate_limit_ctx.contexts[i].bucket.capacity = rate_limit_ctx.config.burst;
            rate_limit_ctx.contexts[i].bucket.tokens = rate_limit_ctx.config.burst;
            rate_limit_ctx.contexts[i].bucket.rate = rate_limit_ctx.config.rate;
            rate_limit_ctx.contexts[i].bucket.last_update = time(NULL);
            rate_limit_ctx.contexts[i].window_start = time(NULL);
            rate_limit_ctx.contexts[i].request_count = 0;
            rate_limit_ctx.contexts[i].is_active = true;
            return &rate_limit_ctx.contexts[i];
        }
    }

    return NULL; /* No free slots */
}

/* Find or create context for IP */
static rate_limit_context_t *get_ip_context(const char *ip_address) {
    for (int i = 0; i < MAX_RATE_LIMIT_CONTEXTS; i++) {
        if (rate_limit_ctx.contexts[i].is_active && 
            strcmp(rate_limit_ctx.contexts[i].ip_address, ip_address) == 0) {
            return &rate_limit_ctx.contexts[i];
        }
    }

    /* Find free slot */
    for (int i = 0; i < MAX_RATE_LIMIT_CONTEXTS; i++) {
        if (!rate_limit_ctx.contexts[i].is_active) {
            strncpy(rate_limit_ctx.contexts[i].ip_address, ip_address, 
                   sizeof(rate_limit_ctx.contexts[i].ip_address) - 1);
            rate_limit_ctx.contexts[i].bucket.capacity = rate_limit_ctx.config.burst;
            rate_limit_ctx.contexts[i].bucket.tokens = rate_limit_ctx.config.burst;
            rate_limit_ctx.contexts[i].bucket.rate = rate_limit_ctx.config.rate;
            rate_limit_ctx.contexts[i].bucket.last_update = time(NULL);
            rate_limit_ctx.contexts[i].window_start = time(NULL);
            rate_limit_ctx.contexts[i].request_count = 0;
            rate_limit_ctx.contexts[i].is_active = true;
            return &rate_limit_ctx.contexts[i];
        }
    }

    return NULL; /* No free slots */
}

/* Check rate limit for user */
rate_limit_result_t rate_limit_check_user(uint64_t user_id) {
    if (!rate_limit_ctx.initialized || !rate_limit_ctx.config.enabled) {
        return RATE_LIMIT_SUCCESS;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);

    rate_limit_context_t *ctx = get_user_context(user_id);
    if (!ctx) {
        pthread_mutex_unlock(&rate_limit_ctx.mutex);
        return RATE_LIMIT_ERROR_INVALID;
    }

    time_t now = time(NULL);
    update_bucket(&ctx->bucket, now);

    if (ctx->bucket.tokens > 0) {
        ctx->bucket.tokens--;
        pthread_mutex_unlock(&rate_limit_ctx.mutex);
        return RATE_LIMIT_SUCCESS;
    }

    pthread_mutex_unlock(&rate_limit_ctx.mutex);
    rate_limit_ctx.limited_requests++;
    audit_log_write(AUDIT_LEVEL_WARNING, AUDIT_EVENT_AUTH_FAILURE, "RATE_LIMIT",
                   "Rate limit exceeded", NULL, user_id, NULL);
    return RATE_LIMIT_EXCEEDED;
}

/* Check rate limit for IP */
rate_limit_result_t rate_limit_check_ip(const char *ip_address) {
    if (!rate_limit_ctx.initialized || !rate_limit_ctx.config.enabled || !ip_address) {
        return RATE_LIMIT_SUCCESS;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);

    rate_limit_context_t *ctx = get_ip_context(ip_address);
    if (!ctx) {
        pthread_mutex_unlock(&rate_limit_ctx.mutex);
        return RATE_LIMIT_ERROR_INVALID;
    }

    time_t now = time(NULL);
    update_bucket(&ctx->bucket, now);

    if (ctx->bucket.tokens > 0) {
        ctx->bucket.tokens--;
        pthread_mutex_unlock(&rate_limit_ctx.mutex);
        return RATE_LIMIT_SUCCESS;
    }

    pthread_mutex_unlock(&rate_limit_ctx.mutex);
    rate_limit_ctx.limited_requests++;
    audit_log_write(AUDIT_LEVEL_WARNING, AUDIT_EVENT_AUTH_FAILURE, "RATE_LIMIT",
                   "Rate limit exceeded", ip_address, 0, NULL);
    return RATE_LIMIT_EXCEEDED;
}

/* Check rate limit globally */
rate_limit_result_t rate_limit_check_global(void) {
    if (!rate_limit_ctx.initialized || !rate_limit_ctx.config.enabled) {
        return RATE_LIMIT_SUCCESS;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);

    time_t now = time(NULL);

    /* Simple global rate limit using sliding window */
    static time_t global_window_start = 0;
    static uint32_t global_request_count = 0;

    if (global_window_start == 0) {
        global_window_start = now;
    }

    double elapsed = difftime(now, global_window_start);
    if (elapsed >= 1.0) {
        global_request_count = 0;
        global_window_start = now;
    }

    if (global_request_count < rate_limit_ctx.config.rate) {
        global_request_count++;
        pthread_mutex_unlock(&rate_limit_ctx.mutex);
        return RATE_LIMIT_SUCCESS;
    }

    pthread_mutex_unlock(&rate_limit_ctx.mutex);
    rate_limit_ctx.limited_requests++;
    audit_log_write(AUDIT_LEVEL_WARNING, AUDIT_EVENT_AUTH_FAILURE, "RATE_LIMIT",
                   "Global rate limit exceeded", NULL, 0, NULL);
    return RATE_LIMIT_EXCEEDED;
}

/* Increment request count */
void rate_limit_increment(uint64_t user_id, const char *ip_address) {
    if (!rate_limit_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);
    rate_limit_ctx.total_requests++;
    pthread_mutex_unlock(&rate_limit_ctx.mutex);
}

/* Reset rate limit for user */
int rate_limit_reset_user(uint64_t user_id) {
    if (!rate_limit_ctx.initialized) {
        return -1;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);

    for (int i = 0; i < MAX_RATE_LIMIT_CONTEXTS; i++) {
        if (rate_limit_ctx.contexts[i].is_active && rate_limit_ctx.contexts[i].user_id == user_id) {
            rate_limit_ctx.contexts[i].bucket.tokens = rate_limit_ctx.config.burst;
            rate_limit_ctx.contexts[i].request_count = 0;
            pthread_mutex_unlock(&rate_limit_ctx.mutex);
            return 0;
        }
    }

    pthread_mutex_unlock(&rate_limit_ctx.mutex);
    return -1;
}

/* Reset rate limit for IP */
int rate_limit_reset_ip(const char *ip_address) {
    if (!rate_limit_ctx.initialized || !ip_address) {
        return -1;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);

    for (int i = 0; i < MAX_RATE_LIMIT_CONTEXTS; i++) {
        if (rate_limit_ctx.contexts[i].is_active && 
            strcmp(rate_limit_ctx.contexts[i].ip_address, ip_address) == 0) {
            rate_limit_ctx.contexts[i].bucket.tokens = rate_limit_ctx.config.burst;
            rate_limit_ctx.contexts[i].request_count = 0;
            pthread_mutex_unlock(&rate_limit_ctx.mutex);
            return 0;
        }
    }

    pthread_mutex_unlock(&rate_limit_ctx.mutex);
    return -1;
}

/* Get rate limit statistics */
void rate_limit_get_stats(uint64_t *total_requests, uint64_t *limited_requests) {
    if (!rate_limit_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);
    if (total_requests) *total_requests = rate_limit_ctx.total_requests;
    if (limited_requests) *limited_requests = rate_limit_ctx.limited_requests;
    pthread_mutex_unlock(&rate_limit_ctx.mutex);
}

/* Set rate limit configuration */
int rate_limit_set_config(const rate_limit_config_t *config) {
    if (!rate_limit_ctx.initialized || !config) {
        return -1;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);
    rate_limit_ctx.config = *config;
    pthread_mutex_unlock(&rate_limit_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "RATE_LIMIT",
                   "Rate limit configuration updated", NULL, 0, NULL);

    return 0;
}

/* Get rate limit configuration */
rate_limit_config_t rate_limit_get_config(void) {
    rate_limit_config_t config;
    if (rate_limit_ctx.initialized) {
        pthread_mutex_lock(&rate_limit_ctx.mutex);
        config = rate_limit_ctx.config;
        pthread_mutex_unlock(&rate_limit_ctx.mutex);
    } else {
        memset(&config, 0, sizeof(config));
    }
    return config;
}

/* Get result string */
const char *rate_limit_result_to_string(rate_limit_result_t result) {
    switch (result) {
        case RATE_LIMIT_SUCCESS: return "SUCCESS";
        case RATE_LIMIT_EXCEEDED: return "EXCEEDED";
        case RATE_LIMIT_ERROR_INVALID: return "INVALID";
        default: return "UNKNOWN";
    }
}

/* Create rate limit context */
rate_limit_context_t *rate_limit_create_context(uint64_t user_id, const char *ip_address) {
    if (!rate_limit_ctx.initialized) {
        return NULL;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);

    rate_limit_context_t *ctx = get_user_context(user_id);
    if (ctx && ip_address) {
        strncpy(ctx->ip_address, ip_address, sizeof(ctx->ip_address) - 1);
    }

    pthread_mutex_unlock(&rate_limit_ctx.mutex);
    return ctx;
}

/* Destroy rate limit context */
void rate_limit_destroy_context(rate_limit_context_t *ctx) {
    if (!ctx || !rate_limit_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);
    ctx->is_active = false;
    pthread_mutex_unlock(&rate_limit_ctx.mutex);
}

/* Check rate limit with context */
rate_limit_result_t rate_limit_check_context(rate_limit_context_t *ctx) {
    if (!ctx || !rate_limit_ctx.initialized) {
        return RATE_LIMIT_ERROR_INVALID;
    }

    if (!rate_limit_ctx.config.enabled) {
        return RATE_LIMIT_SUCCESS;
    }

    pthread_mutex_lock(&rate_limit_ctx.mutex);

    time_t now = time(NULL);
    update_bucket(&ctx->bucket, now);

    if (ctx->bucket.tokens > 0) {
        ctx->bucket.tokens--;
        pthread_mutex_unlock(&rate_limit_ctx.mutex);
        return RATE_LIMIT_SUCCESS;
    }

    pthread_mutex_unlock(&rate_limit_ctx.mutex);
    rate_limit_ctx.limited_requests++;
    return RATE_LIMIT_EXCEEDED;
}
