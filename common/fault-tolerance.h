/**
 * @file fault-tolerance.h
 * @brief Aerospace-level fault tolerance and error handling framework
 * 
 * This framework provides:
 * - Timeout mechanisms for all blocking operations
 * - Watchdog timers to prevent infinite loops
 * - Graceful degradation on errors
 * - Resource cleanup on failures
 * - Retry mechanisms with exponential backoff
 * - Signal handling for graceful shutdown
 * 
 * Aerospace-Level Requirements:
 * - No infinite loops (all loops must have timeout)
 * - No crashes (all errors must be caught and handled)
 * - Time-bounded operations (all operations must have timeout)
 * - Resource cleanup (all resources must be cleaned up on error)
 * - Graceful degradation (system must continue operating with reduced functionality)
 */

#ifndef FAULT_TOLERANCE_H
#define FAULT_TOLERANCE_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>
#include <pthread.h>
#include <signal.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Default timeout values (in seconds) */
#define DEFAULT_TIMEOUT 30
#define SHORT_TIMEOUT 5
#define MEDIUM_TIMEOUT 15
#define LONG_TIMEOUT 60
#define INFINITE_TIMEOUT 0

/* Retry configuration */
#define MAX_RETRY_ATTEMPTS 3
#define INITIAL_RETRY_DELAY_MS 100
#define MAX_RETRY_DELAY_MS 5000

/* Error codes */
typedef enum {
    FT_SUCCESS = 0,
    FT_ERROR_TIMEOUT = 1,
    FT_ERROR_CANCELLED = 2,
    FT_ERROR_RESOURCE = 3,
    FT_ERROR_INVALID_PARAM = 4,
    FT_ERROR_UNKNOWN = 5
} ft_result_t;

/**
 * @brief Timeout context for time-bounded operations
 */
typedef struct {
    time_t start_time;
    time_t timeout_seconds;
    bool is_active;
    pthread_mutex_t mutex;
} ft_timeout_t;

/**
 * @brief Watchdog context for preventing infinite loops
 */
typedef struct {
    time_t last_checkin;
    time_t timeout_seconds;
    bool is_active;
    pthread_mutex_t mutex;
    pthread_t watchdog_thread;
} ft_watchdog_t;

/**
 * @brief Retry configuration
 */
typedef struct {
    int max_attempts;
    int current_attempt;
    int initial_delay_ms;
    int max_delay_ms;
    bool exponential_backoff;
} ft_retry_config_t;

/**
 * @brief Initialize timeout context
 * 
 * @param timeout Timeout context
 * @param timeout_seconds Timeout in seconds (0 = no timeout)
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_timeout_init(ft_timeout_t *timeout, time_t timeout_seconds);

/**
 * @brief Check if timeout has expired
 * 
 * @param timeout Timeout context
 * @return true if expired, false otherwise
 */
bool ft_timeout_check(const ft_timeout_t *timeout);

/**
 * @brief Get remaining time before timeout
 * 
 * @param timeout Timeout context
 * @return Remaining seconds (0 if expired or no timeout)
 */
time_t ft_timeout_remaining(const ft_timeout_t *timeout);

/**
 * @brief Reset timeout
 * 
 * @param timeout Timeout context
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_timeout_reset(ft_timeout_t *timeout);

/**
 * @brief Cleanup timeout context
 * 
 * @param timeout Timeout context
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_timeout_cleanup(ft_timeout_t *timeout);

/**
 * @brief Initialize watchdog
 * 
 * @param watchdog Watchdog context
 * @param timeout_seconds Timeout in seconds
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_watchdog_init(ft_watchdog_t *watchdog, time_t timeout_seconds);

/**
 * @brief Start watchdog thread
 * 
 * @param watchdog Watchdog context
 * @param callback Function to call on timeout (optional)
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_watchdog_start(ft_watchdog_t *watchdog, void (*callback)(void));

/**
 * @brief Check in with watchdog (reset timer)
 * 
 * @param watchdog Watchdog context
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_watchdog_checkin(ft_watchdog_t *watchdog);

/**
 * @brief Stop watchdog thread
 * 
 * @param watchdog Watchdog context
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_watchdog_stop(ft_watchdog_t *watchdog);

/**
 * @brief Cleanup watchdog
 * 
 * @param watchdog Watchdog context
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_watchdog_cleanup(ft_watchdog_t *watchdog);

/**
 * @brief Initialize retry configuration
 * 
 * @param config Retry configuration
 * @param max_attempts Maximum retry attempts
 * @param initial_delay_ms Initial delay in milliseconds
 * @param max_delay_ms Maximum delay in milliseconds
 * @param exponential_backoff Use exponential backoff
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_retry_init(ft_retry_config_t *config, int max_attempts, 
                         int initial_delay_ms, int max_delay_ms, 
                         bool exponential_backoff);

/**
 * @brief Execute retry logic
 * 
 * @param config Retry configuration
 * @param operation Function to execute
 * @param user_data User data for operation
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_retry_execute(ft_retry_config_t *config, 
                            ft_result_t (*operation)(void *), 
                            void *user_data);

/**
 * @brief Calculate delay for next retry
 * 
 * @param config Retry configuration
 * @return Delay in milliseconds
 */
int ft_retry_calculate_delay(const ft_retry_config_t *config);

/**
 * @brief Safe loop with timeout
 * 
 * This macro ensures loops cannot run infinitely by checking timeout
 * on each iteration. Use this instead of while/for loops for critical
 * operations.
 * 
 * Usage:
 *   FT_TIMEOUT_LOOP(timeout, i, max_iterations) {
 *       // loop body
 *       if (ft_timeout_check(&timeout)) break;
 *   }
 */
#define FT_TIMEOUT_LOOP(timeout, iterator, max_iterations) \
    for (size_t iterator = 0; iterator < (max_iterations) && !ft_timeout_check(&(timeout)); iterator++)

/**
 * @brief Safe while loop with timeout
 * 
 * Usage:
 *   FT_TIMEOUT_WHILE(timeout, condition) {
 *       // loop body
 *       if (ft_timeout_check(&timeout)) break;
 *   }
 */
#define FT_TIMEOUT_WHILE(timeout, condition) \
    while ((condition) && !ft_timeout_check(&(timeout)))

/**
 * @brief Initialize global fault tolerance framework
 * 
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_global_init(void);

/**
 * @brief Cleanup global fault tolerance framework
 * 
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_global_cleanup(void);

/**
 * @brief Register signal handlers for graceful shutdown
 * 
 * @return FT_SUCCESS on success, error code on failure
 */
ft_result_t ft_register_signal_handlers(void);

/**
 * @brief Request graceful shutdown
 */
void ft_request_shutdown(void);

/**
 * @brief Check if shutdown was requested
 * 
 * @return true if shutdown requested, false otherwise
 */
bool ft_is_shutdown_requested(void);

#ifdef __cplusplus
}
#endif

#endif /* FAULT_TOLERANCE_H */
