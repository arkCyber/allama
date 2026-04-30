/*
 * Rate Limiting System for allama
 * Aerospace-level rate limiting
 * 
 * Provides:
 * - Token bucket rate limiting
 * - Sliding window rate limiting
 * - Per-user rate limits
 * - Per-IP rate limits
 * - Global rate limits
 * - Burst handling
 * - Rate limit violation logging
 */

#ifndef RATE_LIMIT_H
#define RATE_LIMIT_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Rate limit algorithms */
typedef enum {
    RATE_LIMIT_TOKEN_BUCKET = 0,
    RATE_LIMIT_SLIDING_WINDOW = 1,
    RATE_LIMIT_FIXED_WINDOW = 2
} rate_limit_algo_t;

/* Rate limit result */
typedef enum {
    RATE_LIMIT_SUCCESS = 0,
    RATE_LIMIT_EXCEEDED = 1,
    RATE_LIMIT_ERROR_INVALID = 2
} rate_limit_result_t;

/* Rate limit configuration */
typedef struct {
    uint32_t rate;          /* requests per second */
    uint32_t burst;         /* maximum burst size */
    rate_limit_algo_t algorithm;
    bool enabled;
} rate_limit_config_t;

/* Rate limit bucket */
typedef struct {
    uint32_t tokens;
    uint32_t capacity;
    uint32_t rate;
    time_t last_update;
} rate_limit_bucket_t;

/* Rate limit context */
typedef struct {
    uint64_t user_id;
    char ip_address[64];
    rate_limit_bucket_t bucket;
    time_t window_start;
    uint32_t request_count;
    bool is_active;
} rate_limit_context_t;

/* Initialize rate limiting system */
int rate_limit_init(const rate_limit_config_t *config);

/* Shutdown rate limiting system */
void rate_limit_shutdown(void);

/* Check rate limit for user */
rate_limit_result_t rate_limit_check_user(uint64_t user_id);

/* Check rate limit for IP */
rate_limit_result_t rate_limit_check_ip(const char *ip_address);

/* Check rate limit globally */
rate_limit_result_t rate_limit_check_global(void);

/* Increment request count */
void rate_limit_increment(uint64_t user_id, const char *ip_address);

/* Reset rate limit for user */
int rate_limit_reset_user(uint64_t user_id);

/* Reset rate limit for IP */
int rate_limit_reset_ip(const char *ip_address);

/* Get rate limit statistics */
void rate_limit_get_stats(uint64_t *total_requests, uint64_t *limited_requests);

/* Set rate limit configuration */
int rate_limit_set_config(const rate_limit_config_t *config);

/* Get rate limit configuration */
rate_limit_config_t rate_limit_get_config(void);

/* Get result string */
const char *rate_limit_result_to_string(rate_limit_result_t result);

/* Create rate limit context */
rate_limit_context_t *rate_limit_create_context(uint64_t user_id, const char *ip_address);

/* Destroy rate limit context */
void rate_limit_destroy_context(rate_limit_context_t *ctx);

/* Check rate limit with context */
rate_limit_result_t rate_limit_check_context(rate_limit_context_t *ctx);

#ifdef __cplusplus
}
#endif

#endif /* RATE_LIMIT_H */
