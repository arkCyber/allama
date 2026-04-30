/**
 * @file fault-tolerance.c
 * @brief Aerospace-level fault tolerance and error handling framework implementation
 */

#include "fault-tolerance.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <stdatomic.h>

/* Global shutdown flag */
static atomic_bool g_shutdown_requested;

/* Global watchdog for the entire system */
static ft_watchdog_t g_system_watchdog;

/* Signal handler for graceful shutdown */
static void signal_handler(int signum) {
    (void)signum;
    atomic_store(&g_shutdown_requested, true);
}

/**
 * @brief Initialize timeout context
 */
ft_result_t ft_timeout_init(ft_timeout_t *timeout, time_t timeout_seconds) {
    if (!timeout) {
        return FT_ERROR_INVALID_PARAM;
    }
    
    timeout->start_time = time(NULL);
    timeout->timeout_seconds = timeout_seconds;
    timeout->is_active = true;
    
    if (pthread_mutex_init(&timeout->mutex, NULL) != 0) {
        return FT_ERROR_RESOURCE;
    }
    
    return FT_SUCCESS;
}

/**
 * @brief Check if timeout has expired
 */
bool ft_timeout_check(const ft_timeout_t *timeout) {
    if (!timeout || !timeout->is_active || timeout->timeout_seconds == 0) {
        return false;
    }
    
    time_t current = time(NULL);
    return (current - timeout->start_time) >= timeout->timeout_seconds;
}

/**
 * @brief Get remaining time before timeout
 */
time_t ft_timeout_remaining(const ft_timeout_t *timeout) {
    if (!timeout || !timeout->is_active || timeout->timeout_seconds == 0) {
        return 0;
    }
    
    time_t current = time(NULL);
    time_t elapsed = current - timeout->start_time;
    
    if (elapsed >= timeout->timeout_seconds) {
        return 0;
    }
    
    return timeout->timeout_seconds - elapsed;
}

/**
 * @brief Reset timeout
 */
ft_result_t ft_timeout_reset(ft_timeout_t *timeout) {
    if (!timeout) {
        return FT_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&timeout->mutex);
    timeout->start_time = time(NULL);
    pthread_mutex_unlock(&timeout->mutex);
    
    return FT_SUCCESS;
}

/**
 * @brief Cleanup timeout context
 */
ft_result_t ft_timeout_cleanup(ft_timeout_t *timeout) {
    if (!timeout) {
        return FT_ERROR_INVALID_PARAM;
    }
    
    timeout->is_active = false;
    pthread_mutex_destroy(&timeout->mutex);
    
    return FT_SUCCESS;
}

/**
 * @brief Watchdog thread function
 */
static void *watchdog_thread_func(void *arg) {
    ft_watchdog_t *watchdog = (ft_watchdog_t *)arg;
    
    while (watchdog->is_active) {
        pthread_mutex_lock(&watchdog->mutex);
        time_t current = time(NULL);
        time_t elapsed = current - watchdog->last_checkin;
        
        if (elapsed >= watchdog->timeout_seconds) {
            pthread_mutex_unlock(&watchdog->mutex);
            /* Timeout occurred - trigger emergency shutdown */
            atomic_store(&g_shutdown_requested, true);
            break;
        }
        
        pthread_mutex_unlock(&watchdog->mutex);
        
        /* Sleep for 1 second */
        sleep(1);
    }
    
    return NULL;
}

/**
 * @brief Initialize watchdog
 */
ft_result_t ft_watchdog_init(ft_watchdog_t *watchdog, time_t timeout_seconds) {
    if (!watchdog || timeout_seconds == 0) {
        return FT_ERROR_INVALID_PARAM;
    }
    
    watchdog->last_checkin = time(NULL);
    watchdog->timeout_seconds = timeout_seconds;
    watchdog->is_active = false;
    
    if (pthread_mutex_init(&watchdog->mutex, NULL) != 0) {
        return FT_ERROR_RESOURCE;
    }
    
    return FT_SUCCESS;
}

/**
 * @brief Start watchdog thread
 */
ft_result_t ft_watchdog_start(ft_watchdog_t *watchdog, void (*callback)(void)) {
    if (!watchdog) {
        return FT_ERROR_INVALID_PARAM;
    }
    
    (void)callback; /* Unused for now */
    
    pthread_mutex_lock(&watchdog->mutex);
    watchdog->is_active = true;
    watchdog->last_checkin = time(NULL);
    pthread_mutex_unlock(&watchdog->mutex);
    
    if (pthread_create(&watchdog->watchdog_thread, NULL, watchdog_thread_func, watchdog) != 0) {
        watchdog->is_active = false;
        return FT_ERROR_RESOURCE;
    }
    
    return FT_SUCCESS;
}

/**
 * @brief Check in with watchdog
 */
ft_result_t ft_watchdog_checkin(ft_watchdog_t *watchdog) {
    if (!watchdog) {
        return FT_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&watchdog->mutex);
    watchdog->last_checkin = time(NULL);
    pthread_mutex_unlock(&watchdog->mutex);
    
    return FT_SUCCESS;
}

/**
 * @brief Stop watchdog thread
 */
ft_result_t ft_watchdog_stop(ft_watchdog_t *watchdog) {
    if (!watchdog) {
        return FT_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&watchdog->mutex);
    watchdog->is_active = false;
    pthread_mutex_unlock(&watchdog->mutex);
    
    pthread_join(watchdog->watchdog_thread, NULL);
    
    return FT_SUCCESS;
}

/**
 * @brief Cleanup watchdog
 */
ft_result_t ft_watchdog_cleanup(ft_watchdog_t *watchdog) {
    if (!watchdog) {
        return FT_ERROR_INVALID_PARAM;
    }
    
    if (watchdog->is_active) {
        ft_watchdog_stop(watchdog);
    }
    
    pthread_mutex_destroy(&watchdog->mutex);
    
    return FT_SUCCESS;
}

/**
 * @brief Initialize retry configuration
 */
ft_result_t ft_retry_init(ft_retry_config_t *config, int max_attempts, 
                         int initial_delay_ms, int max_delay_ms, 
                         bool exponential_backoff) {
    if (!config || max_attempts <= 0 || initial_delay_ms <= 0) {
        return FT_ERROR_INVALID_PARAM;
    }
    
    config->max_attempts = max_attempts;
    config->current_attempt = 0;
    config->initial_delay_ms = initial_delay_ms;
    config->max_delay_ms = max_delay_ms;
    config->exponential_backoff = exponential_backoff;
    
    return FT_SUCCESS;
}

/**
 * @brief Calculate delay for next retry
 */
int ft_retry_calculate_delay(const ft_retry_config_t *config) {
    if (!config) {
        return 0;
    }
    
    int delay = config->initial_delay_ms;
    
    if (config->exponential_backoff) {
        delay = config->initial_delay_ms * (1 << config->current_attempt);
    } else {
        delay = config->initial_delay_ms * (config->current_attempt + 1);
    }
    
    if (delay > config->max_delay_ms) {
        delay = config->max_delay_ms;
    }
    
    return delay;
}

/**
 * @brief Execute retry logic
 */
ft_result_t ft_retry_execute(ft_retry_config_t *config, 
                            ft_result_t (*operation)(void *), 
                            void *user_data) {
    if (!config || !operation) {
        return FT_ERROR_INVALID_PARAM;
    }
    
    ft_result_t result;
    
    for (config->current_attempt = 0; config->current_attempt < config->max_attempts; config->current_attempt++) {
        /* Check for shutdown request */
        if (atomic_load(&g_shutdown_requested)) {
            return FT_ERROR_CANCELLED;
        }
        
        /* Execute operation */
        result = operation(user_data);
        
        if (result == FT_SUCCESS) {
            return FT_SUCCESS;
        }
        
        /* Don't retry on certain errors */
        if (result == FT_ERROR_INVALID_PARAM || result == FT_ERROR_CANCELLED) {
            return result;
        }
        
        /* Delay before retry (unless it's the last attempt) */
        if (config->current_attempt < config->max_attempts - 1) {
            int delay_ms = ft_retry_calculate_delay(config);
            usleep(delay_ms * 1000);
        }
    }
    
    return result;
}

/**
 * @brief Initialize global fault tolerance framework
 */
ft_result_t ft_global_init(void) {
    atomic_init(&g_shutdown_requested, false);
    
    /* Initialize system watchdog with 5 minute timeout */
    ft_result_t result = ft_watchdog_init(&g_system_watchdog, 300);
    if (result != FT_SUCCESS) {
        return result;
    }
    
    /* Start watchdog */
    result = ft_watchdog_start(&g_system_watchdog, NULL);
    if (result != FT_SUCCESS) {
        ft_watchdog_cleanup(&g_system_watchdog);
        return result;
    }
    
    /* Register signal handlers */
    result = ft_register_signal_handlers();
    if (result != FT_SUCCESS) {
        ft_watchdog_stop(&g_system_watchdog);
        ft_watchdog_cleanup(&g_system_watchdog);
        return result;
    }
    
    return FT_SUCCESS;
}

/**
 * @brief Cleanup global fault tolerance framework
 */
ft_result_t ft_global_cleanup(void) {
    ft_watchdog_stop(&g_system_watchdog);
    ft_watchdog_cleanup(&g_system_watchdog);
    return FT_SUCCESS;
}

/**
 * @brief Register signal handlers for graceful shutdown
 */
ft_result_t ft_register_signal_handlers(void) {
    struct sigaction sa;
    
    sa.sa_handler = signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    
    /* Register handlers for common signals */
    if (sigaction(SIGTERM, &sa, NULL) < 0) {
        return FT_ERROR_RESOURCE;
    }
    
    if (sigaction(SIGINT, &sa, NULL) < 0) {
        return FT_ERROR_RESOURCE;
    }
    
    return FT_SUCCESS;
}

/**
 * @brief Request graceful shutdown
 */
void ft_request_shutdown(void) {
    atomic_store(&g_shutdown_requested, true);
}

/**
 * @brief Check if shutdown was requested
 */
bool ft_is_shutdown_requested(void) {
    return atomic_load(&g_shutdown_requested);
}
