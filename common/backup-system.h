/*
 * Backup System for allama
 * Aerospace-level backup and recovery
 * 
 * Provides:
 * - Model file backup
 * - Configuration backup
 * - State backup
 * - Incremental backups
 * - Backup verification
 * - Restore functionality
 */

#ifndef BACKUP_SYSTEM_H
#define BACKUP_SYSTEM_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Backup types */
typedef enum {
    BACKUP_TYPE_MODEL = 0,
    BACKUP_TYPE_CONFIG = 1,
    BACKUP_TYPE_STATE = 2,
    BACKUP_TYPE_FULL = 3
} backup_type_t;

/* Backup status */
typedef enum {
    BACKUP_STATUS_SUCCESS = 0,
    BACKUP_STATUS_FAILED = 1,
    BACKUP_STATUS_IN_PROGRESS = 2,
    BACKUP_STATUS_VERIFICATION_FAILED = 3
} backup_status_t;

/* Backup metadata */
typedef struct {
    uint64_t backup_id;
    backup_type_t type;
    time_t timestamp;
    char source_path[512];
    char backup_path[512];
    uint64_t size;
    uint32_t checksum;
    backup_status_t status;
    bool is_incremental;
    uint64_t parent_backup_id;
} backup_metadata_t;

/* Backup configuration */
typedef struct {
    char backup_directory[512];
    uint32_t max_backups;
    bool enable_compression;
    bool enable_encryption;
    uint32_t backup_interval_hours;
    bool auto_backup;
} backup_config_t;

/* Initialize backup system */
int backup_system_init(const backup_config_t *config);

/* Shutdown backup system */
void backup_system_shutdown(void);

/* Create backup of model file */
backup_metadata_t *backup_create_model(const char *model_path, const char *backup_name);

/* Create backup of configuration */
backup_metadata_t *backup_create_config(const char *config_path, const char *backup_name);

/* Create backup of state */
backup_metadata_t *backup_create_state(const char *state_path, const char *backup_name);

/* Create full backup */
backup_metadata_t *backup_create_full(const char *source_path, const char *backup_name);

/* Restore backup */
int backup_restore(uint64_t backup_id, const char *restore_path);

/* Verify backup integrity */
bool backup_verify(uint64_t backup_id);

/* Delete backup */
int backup_delete(uint64_t backup_id);

/* List backups */
void backup_list(backup_metadata_t *backups, uint32_t max_count, uint32_t *actual_count);

/* Get backup by ID */
backup_metadata_t *backup_get(uint64_t backup_id);

/* Get latest backup */
backup_metadata_t *backup_get_latest(backup_type_t type);

/* Set backup configuration */
int backup_set_config(const backup_config_t *config);

/* Get backup configuration */
backup_config_t backup_get_config(void);

/* Perform automatic backup if enabled */
int backup_auto_backup(void);

/* Get backup statistics */
void backup_get_stats(uint64_t *total_backups, uint64_t *total_size, uint64_t *failed_backups);

/* Get backup status string */
const char *backup_status_to_string(backup_status_t status);

/* Get backup type string */
const char *backup_type_to_string(backup_type_t type);

#ifdef __cplusplus
}
#endif

#endif /* BACKUP_SYSTEM_H */
