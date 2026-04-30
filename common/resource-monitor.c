/*
 * Resource Monitoring System Implementation for allama
 * Aerospace-level resource monitoring
 */

#include "resource-monitor.h"
#include "audit-log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach/vm_statistics.h>

/* Resource monitoring context */
static struct {
    monitor_config_t config;
    resource_limits_t limits;
    bool initialized;
    bool running;
    pthread_t monitor_thread;
    pthread_mutex_t mutex;
} monitor_ctx = {0};

/* Initialize resource monitoring system */
int resource_monitor_init(const monitor_config_t *config) {
    if (monitor_ctx.initialized) {
        return 0; /* Already initialized */
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&monitor_ctx.mutex, NULL) != 0) {
        return -1;
    }

    /* Copy configuration */
    if (config) {
        monitor_ctx.config = *config;
    } else {
        /* Default configuration */
        monitor_ctx.config.update_interval_ms = 1000;
        monitor_ctx.config.enable_alerts = true;
        monitor_ctx.config.alert_callback = NULL;
        memset(&monitor_ctx.config.limits, 0, sizeof(resource_limits_t));
        monitor_ctx.config.limits.max_memory = 16ULL * 1024 * 1024 * 1024; /* 16GB */
        monitor_ctx.config.limits.max_threads = 64;
        monitor_ctx.config.limits.max_cpu_percent = 90.0;
        monitor_ctx.config.limits.max_gpu_memory_percent = 90.0;
    }

    /* Copy limits */
    monitor_ctx.limits = monitor_ctx.config.limits;

    monitor_ctx.initialized = true;
    monitor_ctx.running = false;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "RESOURCE_MONITOR",
                   "Resource monitoring system initialized", NULL, 0, NULL);

    return 0;
}

/* Shutdown resource monitoring system */
void resource_monitor_shutdown(void) {
    if (!monitor_ctx.initialized) {
        return;
    }

    if (monitor_ctx.running) {
        resource_monitor_stop();
    }

    pthread_mutex_lock(&monitor_ctx.mutex);
    pthread_mutex_unlock(&monitor_ctx.mutex);
    pthread_mutex_destroy(&monitor_ctx.mutex);
    monitor_ctx.initialized = false;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "RESOURCE_MONITOR",
                   "Resource monitoring system shutdown", NULL, 0, NULL);
}

/* Get memory statistics (macOS) */
int resource_monitor_get_memory(memory_stats_t *stats) {
    if (!stats) {
        return -1;
    }

    int mib[2];
    int64_t physical_memory;
    size_t length;

    /* Get total physical memory */
    mib[0] = CTL_HW;
    mib[1] = HW_MEMSIZE;
    length = sizeof(int64_t);
    sysctl(mib, 2, &physical_memory, &length, NULL, 0);

    /* Get VM statistics */
    vm_size_t page_size;
    mach_port_t mach_port = mach_host_self();
    vm_statistics64_data_t vm_stats;
    mach_msg_type_number_t count = sizeof(vm_stats) / sizeof(natural_t);

    host_page_size(mach_port, &page_size);
    host_statistics64(mach_port, HOST_VM_INFO, (host_info64_t)&vm_stats, &count);

    /* Calculate memory usage */
    uint64_t free_count = vm_stats.free_count + vm_stats.inactive_count;
    uint64_t used_count = physical_memory / page_size - free_count;

    stats->total = physical_memory;
    stats->free = free_count * page_size;
    stats->used = used_count * page_size;
    stats->cache = vm_stats.inactive_count * page_size;
    stats->buffers = 0;
    stats->swap_total = 0;
    stats->swap_used = 0;

    return 0;
}

/* Get CPU statistics (macOS) */
int resource_monitor_get_cpu(cpu_stats_t *stats) {
    if (!stats) {
        return -1;
    }

    /* Get CPU load averages */
    double loadavg[3];
    if (getloadavg(loadavg, 3) < 0) {
        return -1;
    }

    stats->user_percent = loadavg[0] * 100.0;
    stats->system_percent = 0.0;
    stats->idle_percent = 100.0 - loadavg[0] * 100.0;
    stats->iowait_percent = 0.0;

    /* Get process count */
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    sysctl(mib, 4, NULL, &size, NULL, 0);
    stats->process_count = size / sizeof(struct kinfo_proc);

    /* Get thread count */
    stats->thread_count = stats->process_count;

    return 0;
}

/* Get GPU statistics */
int resource_monitor_get_gpu(gpu_stats_t *stats) {
    if (!stats) {
        return -1;
    }

    /* GPU statistics would require Metal API integration */
    /* For now, return basic info */
    memset(stats, 0, sizeof(gpu_stats_t));
    stats->available = true; /* Assume available on macOS with Metal */
    stats->total_memory = 0;
    stats->used_memory = 0;
    stats->memory_usage_percent = 0.0;
    stats->gpu_utilization_percent = 0.0;
    stats->temperature = 0.0;
    stats->fan_speed = 0;

    return 0;
}

/* Get disk statistics */
int resource_monitor_get_disk(const char *path, disk_stats_t *stats) {
    if (!path || !stats) {
        return -1;
    }

    struct statfs fs;
    if (statfs(path, &fs) != 0) {
        return -1;
    }

    stats->total = fs.f_blocks * fs.f_bsize;
    stats->free = fs.f_bfree * fs.f_bsize;
    stats->used = stats->total - stats->free;
    stats->usage_percent = (double)stats->used / stats->total * 100.0;
    stats->iops = 0;
    stats->throughput_mb_s = 0.0;

    return 0;
}

/* Check resource limits */
bool resource_monitor_check_limits(resource_type_t type, uint64_t value) {
    if (!monitor_ctx.initialized) {
        return true; /* Allow if not initialized */
    }

    pthread_mutex_lock(&monitor_ctx.mutex);

    bool within_limits = true;

    switch (type) {
        case RESOURCE_MEMORY:
            within_limits = (value <= monitor_ctx.limits.max_memory);
            break;
        case RESOURCE_THREADS:
            within_limits = ((uint32_t)value <= monitor_ctx.limits.max_threads);
            break;
        default:
            within_limits = true;
            break;
    }

    pthread_mutex_unlock(&monitor_ctx.mutex);
    return within_limits;
}

/* Set resource limit */
int resource_monitor_set_limit(resource_type_t type, uint64_t limit) {
    if (!monitor_ctx.initialized) {
        return -1;
    }

    pthread_mutex_lock(&monitor_ctx.mutex);

    switch (type) {
        case RESOURCE_MEMORY:
            monitor_ctx.limits.max_memory = limit;
            break;
        case RESOURCE_THREADS:
            monitor_ctx.limits.max_threads = (uint32_t)limit;
            break;
        case RESOURCE_CPU:
            monitor_ctx.limits.max_cpu_percent = (double)limit;
            break;
        case RESOURCE_GPU:
            monitor_ctx.limits.max_gpu_memory_percent = (double)limit;
            break;
        case RESOURCE_DISK:
            monitor_ctx.limits.max_disk_usage = limit;
            break;
        default:
            pthread_mutex_unlock(&monitor_ctx.mutex);
            return -1;
    }

    pthread_mutex_unlock(&monitor_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_RESOURCE_ALLOC, "RESOURCE_MONITOR",
                   "Resource limit set", NULL, 0, NULL);

    return 0;
}

/* Get current resource usage */
double resource_monitor_get_usage(resource_type_t type) {
    if (!monitor_ctx.initialized) {
        return 0.0;
    }

    double usage = 0.0;

    switch (type) {
        case RESOURCE_MEMORY: {
            memory_stats_t mem_stats;
            if (resource_monitor_get_memory(&mem_stats) == 0) {
                usage = (double)mem_stats.used / mem_stats.total * 100.0;
            }
            break;
        }
        case RESOURCE_CPU: {
            cpu_stats_t cpu_stats;
            if (resource_monitor_get_cpu(&cpu_stats) == 0) {
                usage = cpu_stats.user_percent;
            }
            break;
        }
        case RESOURCE_DISK: {
            disk_stats_t disk_stats;
            if (resource_monitor_get_disk(".", &disk_stats) == 0) {
                usage = disk_stats.usage_percent;
            }
            break;
        }
        default:
            usage = 0.0;
            break;
    }

    return usage;
}

/* Monitor thread function */
static void *monitor_thread_func(void *arg) {
    (void)arg;

    while (monitor_ctx.running) {
        resource_monitor_update();
        usleep(monitor_ctx.config.update_interval_ms * 1000);
    }

    return NULL;
}

/* Start monitoring */
int resource_monitor_start(void) {
    if (!monitor_ctx.initialized || monitor_ctx.running) {
        return -1;
    }

    monitor_ctx.running = true;

    if (pthread_create(&monitor_ctx.monitor_thread, NULL, monitor_thread_func, NULL) != 0) {
        monitor_ctx.running = false;
        return -1;
    }

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_RESOURCE_ALLOC, "RESOURCE_MONITOR",
                   "Resource monitoring started", NULL, 0, NULL);

    return 0;
}

/* Stop monitoring */
void resource_monitor_stop(void) {
    if (!monitor_ctx.initialized || !monitor_ctx.running) {
        return;
    }

    monitor_ctx.running = false;
    pthread_join(monitor_ctx.monitor_thread, NULL);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_RESOURCE_ALLOC, "RESOURCE_MONITOR",
                   "Resource monitoring stopped", NULL, 0, NULL);
}

/* Update statistics */
void resource_monitor_update(void) {
    if (!monitor_ctx.initialized) {
        return;
    }

    /* Check memory limits */
    double mem_usage = resource_monitor_get_usage(RESOURCE_MEMORY);
    if (mem_usage > 90.0) {
        resource_monitor_alert(RESOURCE_MEMORY, mem_usage, "High memory usage");
    }

    /* Check CPU limits */
    double cpu_usage = resource_monitor_get_usage(RESOURCE_CPU);
    if (cpu_usage > monitor_ctx.limits.max_cpu_percent) {
        resource_monitor_alert(RESOURCE_CPU, cpu_usage, "High CPU usage");
    }

    /* Check disk limits */
    double disk_usage = resource_monitor_get_usage(RESOURCE_DISK);
    if (disk_usage > 90.0) {
        resource_monitor_alert(RESOURCE_DISK, disk_usage, "High disk usage");
    }
}

/* Generate alert */
void resource_monitor_alert(resource_type_t type, double value, const char *message) {
    if (!monitor_ctx.config.enable_alerts) {
        return;
    }

    /* Call custom callback if set */
    if (monitor_ctx.config.alert_callback) {
        monitor_ctx.config.alert_callback(type, value, message);
    }

    /* Log alert */
    char details[256];
    const char *type_str = "UNKNOWN";
    switch (type) {
        case RESOURCE_MEMORY: type_str = "MEMORY"; break;
        case RESOURCE_CPU: type_str = "CPU"; break;
        case RESOURCE_GPU: type_str = "GPU"; break;
        case RESOURCE_DISK: type_str = "DISK"; break;
        case RESOURCE_THREADS: type_str = "THREADS"; break;
    }
    snprintf(details, sizeof(details), "type=%s value=%.2f message=%s", type_str, value, message);
    audit_log_write(AUDIT_LEVEL_WARNING, AUDIT_EVENT_SECURITY_VIOLATION, "RESOURCE_MONITOR",
                   "Resource alert", details, 0, NULL);
}

/* Get resource statistics summary */
void resource_monitor_get_summary(char *buffer, size_t size) {
    if (!buffer || size == 0) {
        return;
    }

    memory_stats_t mem_stats;
    cpu_stats_t cpu_stats;
    disk_stats_t disk_stats;

    resource_monitor_get_memory(&mem_stats);
    resource_monitor_get_cpu(&cpu_stats);
    resource_monitor_get_disk(".", &disk_stats);

    snprintf(buffer, size,
             "Memory: %.2f GB / %.2f GB (%.1f%%)\n"
             "CPU: %.1f%%\n"
             "Processes: %u\n"
             "Disk: %.2f GB / %.2f GB (%.1f%%)",
             (double)mem_stats.used / (1024 * 1024 * 1024),
             (double)mem_stats.total / (1024 * 1024 * 1024),
             (double)mem_stats.used / mem_stats.total * 100.0,
             cpu_stats.user_percent,
             cpu_stats.process_count,
             (double)disk_stats.used / (1024 * 1024 * 1024),
             (double)disk_stats.total / (1024 * 1024 * 1024),
             disk_stats.usage_percent);
}
