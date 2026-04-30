/*
 * Resource Monitoring System for allama
 * Aerospace-level resource monitoring
 * 
 * Provides:
 * - Memory usage monitoring
 * - CPU usage monitoring
 * - GPU usage monitoring
 * - Disk usage monitoring
 * - Thread count monitoring
 * - Resource limit enforcement
 * - Alert generation
 */

#ifndef RESOURCE_MONITOR_H
#define RESOURCE_MONITOR_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Resource types */
typedef enum {
    RESOURCE_MEMORY = 0,
    RESOURCE_CPU = 1,
    RESOURCE_GPU = 2,
    RESOURCE_DISK = 3,
    RESOURCE_THREADS = 4
} resource_type_t;

/* Resource statistics */
typedef struct {
    uint64_t total;
    uint64_t used;
    uint64_t available;
    double usage_percent;
} resource_stats_t;

/* Memory statistics */
typedef struct {
    uint64_t total;
    uint64_t used;
    uint64_t free;
    uint64_t cache;
    uint64_t buffers;
    uint64_t swap_total;
    uint64_t swap_used;
} memory_stats_t;

/* CPU statistics */
typedef struct {
    double user_percent;
    double system_percent;
    double idle_percent;
    double iowait_percent;
    uint32_t process_count;
    uint32_t thread_count;
} cpu_stats_t;

/* GPU statistics */
typedef struct {
    uint64_t total_memory;
    uint64_t used_memory;
    double memory_usage_percent;
    double gpu_utilization_percent;
    double temperature;
    uint32_t fan_speed;
    bool available;
} gpu_stats_t;

/* Disk statistics */
typedef struct {
    uint64_t total;
    uint64_t used;
    uint64_t free;
    double usage_percent;
    uint64_t iops;
    double throughput_mb_s;
} disk_stats_t;

/* Resource limits */
typedef struct {
    uint64_t max_memory;
    uint32_t max_threads;
    double max_cpu_percent;
    double max_gpu_memory_percent;
    uint64_t max_disk_usage;
} resource_limits_t;

/* Alert callback */
typedef void (*resource_alert_callback_t)(resource_type_t type, double value, const char *message);

/* Monitor configuration */
typedef struct {
    uint32_t update_interval_ms;
    bool enable_alerts;
    resource_alert_callback_t alert_callback;
    resource_limits_t limits;
} monitor_config_t;

/* Initialize resource monitoring system */
int resource_monitor_init(const monitor_config_t *config);

/* Shutdown resource monitoring system */
void resource_monitor_shutdown(void);

/* Get memory statistics */
int resource_monitor_get_memory(memory_stats_t *stats);

/* Get CPU statistics */
int resource_monitor_get_cpu(cpu_stats_t *stats);

/* Get GPU statistics */
int resource_monitor_get_gpu(gpu_stats_t *stats);

/* Get disk statistics */
int resource_monitor_get_disk(const char *path, disk_stats_t *stats);

/* Check resource limits */
bool resource_monitor_check_limits(resource_type_t type, uint64_t value);

/* Set resource limit */
int resource_monitor_set_limit(resource_type_t type, uint64_t limit);

/* Get current resource usage */
double resource_monitor_get_usage(resource_type_t type);

/* Start monitoring */
int resource_monitor_start(void);

/* Stop monitoring */
void resource_monitor_stop(void);

/* Update statistics (called automatically) */
void resource_monitor_update(void);

/* Generate alert */
void resource_monitor_alert(resource_type_t type, double value, const char *message);

/* Get resource statistics summary */
void resource_monitor_get_summary(char *buffer, size_t size);

#ifdef __cplusplus
}
#endif

#endif /* RESOURCE_MONITOR_H */
