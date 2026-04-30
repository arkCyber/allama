/*
 * GPU Isolation System Implementation for allama
 * Aerospace-level GPU resource isolation
 */

#include "gpu-isolation.h"
#include "audit-log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

/* Maximum number of GPU tenants */
#define MAX_GPU_TENANTS 100

/* GPU isolation context */
static struct {
    gpu_isolation_config_t config;
    gpu_tenant_t tenants[MAX_GPU_TENANTS];
    uint32_t total_memory_used;
    uint32_t total_compute_used;
    bool initialized;
    pthread_mutex_t mutex;
} gpu_isolation_ctx = {0};

/* Initialize GPU isolation system */
int gpu_isolation_init(const gpu_isolation_config_t *config) {
    if (gpu_isolation_ctx.initialized) {
        return 0; /* Already initialized */
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&gpu_isolation_ctx.mutex, NULL) != 0) {
        return -1;
    }

    /* Copy configuration */
    if (config) {
        gpu_isolation_ctx.config = *config;
    } else {
        /* Default configuration */
        gpu_isolation_ctx.config.enabled = true;
        gpu_isolation_ctx.config.max_memory_per_tenant = 2ULL * 1024 * 1024 * 1024; /* 2GB */
        gpu_isolation_ctx.config.max_compute_units_per_tenant = 100;
        gpu_isolation_ctx.config.max_concurrent_kernels = 10;
        gpu_isolation_ctx.config.enable_error_containment = true;
        gpu_isolation_ctx.config.enable_memory_encryption = false;
    }

    /* Initialize tenants */
    memset(gpu_isolation_ctx.tenants, 0, sizeof(gpu_isolation_ctx.tenants));

    gpu_isolation_ctx.total_memory_used = 0;
    gpu_isolation_ctx.total_compute_used = 0;
    gpu_isolation_ctx.initialized = true;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "GPU_ISOLATION",
                   "GPU isolation system initialized", NULL, 0, NULL);

    return 0;
}

/* Shutdown GPU isolation system */
void gpu_isolation_shutdown(void) {
    if (!gpu_isolation_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);

    /* Destroy all tenants */
    for (int i = 0; i < MAX_GPU_TENANTS; i++) {
        if (gpu_isolation_ctx.tenants[i].is_active) {
            gpu_isolation_ctx.tenants[i].is_active = false;
        }
    }

    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
    pthread_mutex_destroy(&gpu_isolation_ctx.mutex);
    gpu_isolation_ctx.initialized = false;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "GPU_ISOLATION",
                   "GPU isolation system shutdown", NULL, 0, NULL);
}

/* Find tenant by ID */
static gpu_tenant_t *find_tenant(uint64_t tenant_id) {
    for (int i = 0; i < MAX_GPU_TENANTS; i++) {
        if (gpu_isolation_ctx.tenants[i].is_active && gpu_isolation_ctx.tenants[i].tenant_id == tenant_id) {
            return &gpu_isolation_ctx.tenants[i];
        }
    }
    return NULL;
}

/* Create tenant context */
int gpu_isolation_create_tenant(uint64_t tenant_id, uint32_t memory_quota, uint32_t compute_quota) {
    if (!gpu_isolation_ctx.initialized) {
        return -1;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);

    /* Check if tenant already exists */
    if (find_tenant(tenant_id) != NULL) {
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
        return -1;
    }

    /* Find free slot */
    int slot = -1;
    for (int i = 0; i < MAX_GPU_TENANTS; i++) {
        if (!gpu_isolation_ctx.tenants[i].is_active) {
            slot = i;
            break;
        }
    }

    if (slot == -1) {
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
        return -1; /* No free slots */
    }

    /* Initialize tenant */
    gpu_isolation_ctx.tenants[slot].tenant_id = tenant_id;
    gpu_isolation_ctx.tenants[slot].memory_quota = memory_quota ? memory_quota : gpu_isolation_ctx.config.max_memory_per_tenant;
    gpu_isolation_ctx.tenants[slot].memory_used = 0;
    gpu_isolation_ctx.tenants[slot].compute_units_quota = compute_quota ? compute_quota : gpu_isolation_ctx.config.max_compute_units_per_tenant;
    gpu_isolation_ctx.tenants[slot].compute_units_used = 0;
    gpu_isolation_ctx.tenants[slot].active_kernels = 0;
    gpu_isolation_ctx.tenants[slot].is_active = true;

    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_RESOURCE_ALLOC, "GPU_ISOLATION",
                   "GPU tenant created", NULL, tenant_id, NULL);

    return 0;
}

/* Destroy tenant context */
void gpu_isolation_destroy_tenant(uint64_t tenant_id) {
    if (!gpu_isolation_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);

    gpu_tenant_t *tenant = find_tenant(tenant_id);
    if (tenant) {
        gpu_isolation_ctx.total_memory_used -= tenant->memory_used;
        gpu_isolation_ctx.total_compute_used -= tenant->compute_units_used;
        tenant->is_active = false;

        audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_RESOURCE_FREE, "GPU_ISOLATION",
                       "GPU tenant destroyed", NULL, tenant_id, NULL);
    }

    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
}

/* Allocate GPU memory for tenant */
gpu_isolation_result_t gpu_isolation_allocate_memory(uint64_t tenant_id, size_t size) {
    if (!gpu_isolation_ctx.initialized) {
        return GPU_ISOLATION_ERROR_DISABLED;
    }

    if (!gpu_isolation_ctx.config.enabled) {
        return GPU_ISOLATION_SUCCESS; /* Bypass if disabled */
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);

    gpu_tenant_t *tenant = find_tenant(tenant_id);
    if (!tenant) {
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
        return GPU_ISOLATION_ERROR_INVALID;
    }

    /* Check quota */
    if (tenant->memory_used + size > tenant->memory_quota) {
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
        audit_log_write(AUDIT_LEVEL_WARNING, AUDIT_EVENT_SECURITY_VIOLATION, "GPU_ISOLATION",
                       "GPU memory quota exceeded", NULL, tenant_id, NULL);
        return GPU_ISOLATION_ERROR_QUOTA_EXCEEDED;
    }

    tenant->memory_used += size;
    gpu_isolation_ctx.total_memory_used += size;

    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);

    return GPU_ISOLATION_SUCCESS;
}

/* Free GPU memory for tenant */
void gpu_isolation_free_memory(uint64_t tenant_id, size_t size) {
    if (!gpu_isolation_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);

    gpu_tenant_t *tenant = find_tenant(tenant_id);
    if (tenant) {
        if (tenant->memory_used >= size) {
            tenant->memory_used -= size;
            gpu_isolation_ctx.total_memory_used -= size;
        }
    }

    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
}

/* Check GPU memory quota */
gpu_isolation_result_t gpu_isolation_check_memory_quota(uint64_t tenant_id, size_t size) {
    if (!gpu_isolation_ctx.initialized) {
        return GPU_ISOLATION_ERROR_DISABLED;
    }

    if (!gpu_isolation_ctx.config.enabled) {
        return GPU_ISOLATION_SUCCESS;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);

    gpu_tenant_t *tenant = find_tenant(tenant_id);
    if (!tenant) {
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
        return GPU_ISOLATION_ERROR_INVALID;
    }

    if (tenant->memory_used + size > tenant->memory_quota) {
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
        return GPU_ISOLATION_ERROR_QUOTA_EXCEEDED;
    }

    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
    return GPU_ISOLATION_SUCCESS;
}

/* Allocate compute units for tenant */
gpu_isolation_result_t gpu_isolation_allocate_compute(uint64_t tenant_id, uint32_t units) {
    if (!gpu_isolation_ctx.initialized) {
        return GPU_ISOLATION_ERROR_DISABLED;
    }

    if (!gpu_isolation_ctx.config.enabled) {
        return GPU_ISOLATION_SUCCESS;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);

    gpu_tenant_t *tenant = find_tenant(tenant_id);
    if (!tenant) {
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
        return GPU_ISOLATION_ERROR_INVALID;
    }

    /* Check quota */
    if (tenant->compute_units_used + units > tenant->compute_units_quota) {
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
        audit_log_write(AUDIT_LEVEL_WARNING, AUDIT_EVENT_SECURITY_VIOLATION, "GPU_ISOLATION",
                       "GPU compute quota exceeded", NULL, tenant_id, NULL);
        return GPU_ISOLATION_ERROR_QUOTA_EXCEEDED;
    }

    /* Check concurrent kernels limit */
    if (tenant->active_kernels >= gpu_isolation_ctx.config.max_concurrent_kernels) {
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
        return GPU_ISOLATION_ERROR_QUOTA_EXCEEDED;
    }

    tenant->compute_units_used += units;
    tenant->active_kernels++;
    gpu_isolation_ctx.total_compute_used += units;

    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);

    return GPU_ISOLATION_SUCCESS;
}

/* Free compute units for tenant */
void gpu_isolation_free_compute(uint64_t tenant_id, uint32_t units) {
    if (!gpu_isolation_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);

    gpu_tenant_t *tenant = find_tenant(tenant_id);
    if (tenant) {
        if (tenant->compute_units_used >= units) {
            tenant->compute_units_used -= units;
            gpu_isolation_ctx.total_compute_used -= units;
        }
        if (tenant->active_kernels > 0) {
            tenant->active_kernels--;
        }
    }

    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
}

/* Check compute quota */
gpu_isolation_result_t gpu_isolation_check_compute_quota(uint64_t tenant_id, uint32_t units) {
    if (!gpu_isolation_ctx.initialized) {
        return GPU_ISOLATION_ERROR_DISABLED;
    }

    if (!gpu_isolation_ctx.config.enabled) {
        return GPU_ISOLATION_SUCCESS;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);

    gpu_tenant_t *tenant = find_tenant(tenant_id);
    if (!tenant) {
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
        return GPU_ISOLATION_ERROR_INVALID;
    }

    if (tenant->compute_units_used + units > tenant->compute_units_quota) {
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
        return GPU_ISOLATION_ERROR_QUOTA_EXCEEDED;
    }

    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
    return GPU_ISOLATION_SUCCESS;
}

/* Get tenant statistics */
gpu_tenant_t *gpu_isolation_get_tenant(uint64_t tenant_id) {
    if (!gpu_isolation_ctx.initialized) {
        return NULL;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);
    gpu_tenant_t *tenant = find_tenant(tenant_id);
    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);

    return tenant;
}

/* Get GPU isolation configuration */
gpu_isolation_config_t gpu_isolation_get_config(void) {
    gpu_isolation_config_t config;
    if (gpu_isolation_ctx.initialized) {
        pthread_mutex_lock(&gpu_isolation_ctx.mutex);
        config = gpu_isolation_ctx.config;
        pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
    } else {
        memset(&config, 0, sizeof(config));
    }
    return config;
}

/* Set GPU isolation configuration */
int gpu_isolation_set_config(const gpu_isolation_config_t *config) {
    if (!gpu_isolation_ctx.initialized || !config) {
        return -1;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);
    gpu_isolation_ctx.config = *config;
    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "GPU_ISOLATION",
                   "GPU isolation configuration updated", NULL, 0, NULL);

    return 0;
}

/* Check if GPU isolation is enabled */
bool gpu_isolation_is_enabled(void) {
    if (!gpu_isolation_ctx.initialized) {
        return false;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);
    bool enabled = gpu_isolation_ctx.config.enabled;
    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);

    return enabled;
}

/* Get result string */
const char *gpu_isolation_result_to_string(gpu_isolation_result_t result) {
    switch (result) {
        case GPU_ISOLATION_SUCCESS: return "SUCCESS";
        case GPU_ISOLATION_ERROR_DISABLED: return "DISABLED";
        case GPU_ISOLATION_ERROR_QUOTA_EXCEEDED: return "QUOTA_EXCEEDED";
        case GPU_ISOLATION_ERROR_INVALID: return "INVALID";
        case GPU_ISOLATION_ERROR_NOT_AVAILABLE: return "NOT_AVAILABLE";
        default: return "UNKNOWN";
    }
}

/* Get total GPU memory usage */
void gpu_isolation_get_total_usage(uint32_t *memory_used, uint32_t *compute_used) {
    if (!gpu_isolation_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&gpu_isolation_ctx.mutex);
    if (memory_used) *memory_used = gpu_isolation_ctx.total_memory_used;
    if (compute_used) *compute_used = gpu_isolation_ctx.total_compute_used;
    pthread_mutex_unlock(&gpu_isolation_ctx.mutex);
}
