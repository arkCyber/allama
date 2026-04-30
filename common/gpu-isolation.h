/*
 * GPU Isolation System for allama
 * Aerospace-level GPU resource isolation
 * 
 * Provides:
 * - GPU memory partitioning
 * - GPU compute isolation
 * - Multi-tenant GPU support
 * - GPU resource quotas
 * - GPU access control
 * - GPU error containment
 */

#ifndef GPU_ISOLATION_H
#define GPU_ISOLATION_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* GPU isolation configuration */
typedef struct {
    bool enabled;
    uint32_t max_memory_per_tenant;
    uint32_t max_compute_units_per_tenant;
    uint32_t max_concurrent_kernels;
    bool enable_error_containment;
    bool enable_memory_encryption;
} gpu_isolation_config_t;

/* GPU tenant context */
typedef struct {
    uint64_t tenant_id;
    uint32_t memory_quota;
    uint32_t memory_used;
    uint32_t compute_units_quota;
    uint32_t compute_units_used;
    uint32_t active_kernels;
    bool is_active;
} gpu_tenant_t;

/* GPU isolation result */
typedef enum {
    GPU_ISOLATION_SUCCESS = 0,
    GPU_ISOLATION_ERROR_DISABLED = 1,
    GPU_ISOLATION_ERROR_QUOTA_EXCEEDED = 2,
    GPU_ISOLATION_ERROR_INVALID = 3,
    GPU_ISOLATION_ERROR_NOT_AVAILABLE = 4
} gpu_isolation_result_t;

/* Initialize GPU isolation system */
int gpu_isolation_init(const gpu_isolation_config_t *config);

/* Shutdown GPU isolation system */
void gpu_isolation_shutdown(void);

/* Create tenant context */
int gpu_isolation_create_tenant(uint64_t tenant_id, uint32_t memory_quota, uint32_t compute_quota);

/* Destroy tenant context */
void gpu_isolation_destroy_tenant(uint64_t tenant_id);

/* Allocate GPU memory for tenant */
gpu_isolation_result_t gpu_isolation_allocate_memory(uint64_t tenant_id, size_t size);

/* Free GPU memory for tenant */
void gpu_isolation_free_memory(uint64_t tenant_id, size_t size);

/* Check GPU memory quota */
gpu_isolation_result_t gpu_isolation_check_memory_quota(uint64_t tenant_id, size_t size);

/* Allocate compute units for tenant */
gpu_isolation_result_t gpu_isolation_allocate_compute(uint64_t tenant_id, uint32_t units);

/* Free compute units for tenant */
void gpu_isolation_free_compute(uint64_t tenant_id, uint32_t units);

/* Check compute quota */
gpu_isolation_result_t gpu_isolation_check_compute_quota(uint64_t tenant_id, uint32_t units);

/* Get tenant statistics */
gpu_tenant_t *gpu_isolation_get_tenant(uint64_t tenant_id);

/* Get GPU isolation configuration */
gpu_isolation_config_t gpu_isolation_get_config(void);

/* Set GPU isolation configuration */
int gpu_isolation_set_config(const gpu_isolation_config_t *config);

/* Check if GPU isolation is enabled */
bool gpu_isolation_is_enabled(void);

/* Get result string */
const char *gpu_isolation_result_to_string(gpu_isolation_result_t result);

/* Get total GPU memory usage */
void gpu_isolation_get_total_usage(uint32_t *memory_used, uint32_t *compute_used);

#ifdef __cplusplus
}
#endif

#endif /* GPU_ISOLATION_H */
