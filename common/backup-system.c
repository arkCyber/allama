/*
 * Backup System Implementation for allama
 * Aerospace-level backup and recovery
 */

#include "backup-system.h"
#include "audit-log.h"
#include "code-sign.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>

/* Maximum number of backups */
#define MAX_BACKUPS 100

/* Backup system context */
static struct {
    backup_config_t config;
    backup_metadata_t backups[MAX_BACKUPS];
    uint64_t total_size;
    uint64_t failed_backups;
    uint64_t backup_counter;
    bool initialized;
    pthread_mutex_t mutex;
} backup_ctx = {0};

/* Calculate file checksum */
static uint32_t calculate_checksum(const char *path) {
    FILE *file = fopen(path, "rb");
    if (!file) {
        return 0;
    }

    uint32_t checksum = 0;
    unsigned char buffer[4096];
    size_t bytes_read;

    while ((bytes_read = fread(buffer, 1, sizeof(buffer), file)) > 0) {
        for (size_t i = 0; i < bytes_read; i++) {
            checksum = (checksum << 8) ^ buffer[i];
            checksum = checksum * 31 + buffer[i];
        }
    }

    fclose(file);
    return checksum;
}

/* Get file size */
static uint64_t get_file_size(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) {
        return 0;
    }
    return st.st_size;
}

/* Initialize backup system */
int backup_system_init(const backup_config_t *config) {
    if (backup_ctx.initialized) {
        return 0; /* Already initialized */
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&backup_ctx.mutex, NULL) != 0) {
        return -1;
    }

    /* Copy configuration */
    if (config) {
        backup_ctx.config = *config;
    } else {
        /* Default configuration */
        strncpy(backup_ctx.config.backup_directory, "./backups", sizeof(backup_ctx.config.backup_directory) - 1);
        backup_ctx.config.max_backups = 10;
        backup_ctx.config.enable_compression = false;
        backup_ctx.config.enable_encryption = false;
        backup_ctx.config.backup_interval_hours = 24;
        backup_ctx.config.auto_backup = false;
    }

    /* Create backup directory if it doesn't exist */
    mkdir(backup_ctx.config.backup_directory, 0755);

    /* Initialize backups */
    memset(backup_ctx.backups, 0, sizeof(backup_ctx.backups));

    backup_ctx.total_size = 0;
    backup_ctx.failed_backups = 0;
    backup_ctx.backup_counter = 0;
    backup_ctx.initialized = true;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "BACKUP_SYSTEM",
                   "Backup system initialized", NULL, 0, NULL);

    return 0;
}

/* Shutdown backup system */
void backup_system_shutdown(void) {
    if (!backup_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&backup_ctx.mutex);
    pthread_mutex_unlock(&backup_ctx.mutex);
    pthread_mutex_destroy(&backup_ctx.mutex);
    backup_ctx.initialized = false;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "BACKUP_SYSTEM",
                   "Backup system shutdown", NULL, 0, NULL);
}

/* Create backup */
static backup_metadata_t *backup_create_internal(const char *source_path, backup_type_t type, const char *backup_name) {
    if (!backup_ctx.initialized || !source_path) {
        return NULL;
    }

    pthread_mutex_lock(&backup_ctx.mutex);

    /* Check if source exists */
    if (access(source_path, R_OK) != 0) {
        pthread_mutex_unlock(&backup_ctx.mutex);
        return NULL;
    }

    /* Find free slot */
    int slot = -1;
    for (int i = 0; i < MAX_BACKUPS; i++) {
        if (backup_ctx.backups[i].backup_id == 0) {
            slot = i;
            break;
        }
    }

    if (slot == -1) {
        pthread_mutex_unlock(&backup_ctx.mutex);
        return NULL; /* No free slots */
    }

    /* Generate backup path */
    char backup_path[512];
    if (backup_name) {
        snprintf(backup_path, sizeof(backup_path), "%s/%s", backup_ctx.config.backup_directory, backup_name);
    } else {
        time_t now = time(NULL);
        snprintf(backup_path, sizeof(backup_path), "%s/backup_%llu_%ld",
                 backup_ctx.config.backup_directory, (unsigned long long)backup_ctx.backup_counter, now);
    }

    /* Copy file */
    char command[1024];
    snprintf(command, sizeof(command), "cp \"%s\" \"%s\"", source_path, backup_path);
    int result = system(command);

    if (result != 0) {
        backup_ctx.failed_backups++;
        pthread_mutex_unlock(&backup_ctx.mutex);
        audit_log_error("BACKUP_SYSTEM", "Backup copy failed", source_path);
        return NULL;
    }

    /* Create metadata */
    backup_ctx.backups[slot].backup_id = ++backup_ctx.backup_counter;
    backup_ctx.backups[slot].type = type;
    backup_ctx.backups[slot].timestamp = time(NULL);
    strncpy(backup_ctx.backups[slot].source_path, source_path, sizeof(backup_ctx.backups[slot].source_path) - 1);
    strncpy(backup_ctx.backups[slot].backup_path, backup_path, sizeof(backup_ctx.backups[slot].backup_path) - 1);
    backup_ctx.backups[slot].size = get_file_size(backup_path);
    backup_ctx.backups[slot].checksum = calculate_checksum(backup_path);
    backup_ctx.backups[slot].status = BACKUP_STATUS_SUCCESS;
    backup_ctx.backups[slot].is_incremental = false;
    backup_ctx.backups[slot].parent_backup_id = 0;

    backup_ctx.total_size += backup_ctx.backups[slot].size;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "BACKUP_SYSTEM",
                   "Backup created", backup_path, 0, NULL);

    pthread_mutex_unlock(&backup_ctx.mutex);
    return &backup_ctx.backups[slot];
}

/* Create backup of model file */
backup_metadata_t *backup_create_model(const char *model_path, const char *backup_name) {
    return backup_create_internal(model_path, BACKUP_TYPE_MODEL, backup_name);
}

/* Create backup of configuration */
backup_metadata_t *backup_create_config(const char *config_path, const char *backup_name) {
    return backup_create_internal(config_path, BACKUP_TYPE_CONFIG, backup_name);
}

/* Create backup of state */
backup_metadata_t *backup_create_state(const char *state_path, const char *backup_name) {
    return backup_create_internal(state_path, BACKUP_TYPE_STATE, backup_name);
}

/* Create full backup */
backup_metadata_t *backup_create_full(const char *source_path, const char *backup_name) {
    return backup_create_internal(source_path, BACKUP_TYPE_FULL, backup_name);
}

/* Restore backup */
int backup_restore(uint64_t backup_id, const char *restore_path) {
    if (!backup_ctx.initialized) {
        return -1;
    }

    pthread_mutex_lock(&backup_ctx.mutex);

    /* Find backup */
    backup_metadata_t *backup = NULL;
    for (int i = 0; i < MAX_BACKUPS; i++) {
        if (backup_ctx.backups[i].backup_id == backup_id) {
            backup = &backup_ctx.backups[i];
            break;
        }
    }

    if (!backup) {
        pthread_mutex_unlock(&backup_ctx.mutex);
        return -1;
    }

    /* Verify backup */
    uint32_t current_checksum = calculate_checksum(backup->backup_path);
    if (current_checksum != backup->checksum) {
        pthread_mutex_unlock(&backup_ctx.mutex);
        audit_log_error("BACKUP_SYSTEM", "Backup verification failed", backup->backup_path);
        return -1;
    }

    /* Copy backup to restore path */
    char command[1024];
    snprintf(command, sizeof(command), "cp \"%s\" \"%s\"", backup->backup_path, restore_path);
    int result = system(command);

    pthread_mutex_unlock(&backup_ctx.mutex);

    if (result == 0) {
        audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "BACKUP_SYSTEM",
                       "Backup restored", restore_path, 0, NULL);
    } else {
        audit_log_error("BACKUP_SYSTEM", "Backup restore failed", restore_path);
    }

    return result == 0 ? 0 : -1;
}

/* Verify backup integrity */
bool backup_verify(uint64_t backup_id) {
    if (!backup_ctx.initialized) {
        return false;
    }

    pthread_mutex_lock(&backup_ctx.mutex);

    /* Find backup */
    backup_metadata_t *backup = NULL;
    for (int i = 0; i < MAX_BACKUPS; i++) {
        if (backup_ctx.backups[i].backup_id == backup_id) {
            backup = &backup_ctx.backups[i];
            break;
        }
    }

    if (!backup) {
        pthread_mutex_unlock(&backup_ctx.mutex);
        return false;
    }

    uint32_t current_checksum = calculate_checksum(backup->backup_path);
    bool valid = (current_checksum == backup->checksum);

    if (!valid) {
        backup->status = BACKUP_STATUS_VERIFICATION_FAILED;
        audit_log_error("BACKUP_SYSTEM", "Backup verification failed", backup->backup_path);
    }

    pthread_mutex_unlock(&backup_ctx.mutex);
    return valid;
}

/* Delete backup */
int backup_delete(uint64_t backup_id) {
    if (!backup_ctx.initialized) {
        return -1;
    }

    pthread_mutex_lock(&backup_ctx.mutex);

    /* Find backup */
    int slot = -1;
    for (int i = 0; i < MAX_BACKUPS; i++) {
        if (backup_ctx.backups[i].backup_id == backup_id) {
            slot = i;
            break;
        }
    }

    if (slot == -1) {
        pthread_mutex_unlock(&backup_ctx.mutex);
        return -1;
    }

    /* Delete file */
    unlink(backup_ctx.backups[slot].backup_path);

    /* Update total size */
    backup_ctx.total_size -= backup_ctx.backups[slot].size;

    /* Clear slot */
    memset(&backup_ctx.backups[slot], 0, sizeof(backup_metadata_t));

    pthread_mutex_unlock(&backup_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "BACKUP_SYSTEM",
                   "Backup deleted", NULL, 0, NULL);

    return 0;
}

/* List backups */
void backup_list(backup_metadata_t *backups, uint32_t max_count, uint32_t *actual_count) {
    if (!backup_ctx.initialized || !backups || !actual_count) {
        return;
    }

    pthread_mutex_lock(&backup_ctx.mutex);

    uint32_t count = 0;
    for (int i = 0; i < MAX_BACKUPS && count < max_count; i++) {
        if (backup_ctx.backups[i].backup_id != 0) {
            backups[count] = backup_ctx.backups[i];
            count++;
        }
    }

    *actual_count = count;
    pthread_mutex_unlock(&backup_ctx.mutex);
}

/* Get backup by ID */
backup_metadata_t *backup_get(uint64_t backup_id) {
    if (!backup_ctx.initialized) {
        return NULL;
    }

    pthread_mutex_lock(&backup_ctx.mutex);

    for (int i = 0; i < MAX_BACKUPS; i++) {
        if (backup_ctx.backups[i].backup_id == backup_id) {
            pthread_mutex_unlock(&backup_ctx.mutex);
            return &backup_ctx.backups[i];
        }
    }

    pthread_mutex_unlock(&backup_ctx.mutex);
    return NULL;
}

/* Get latest backup */
backup_metadata_t *backup_get_latest(backup_type_t type) {
    if (!backup_ctx.initialized) {
        return NULL;
    }

    pthread_mutex_lock(&backup_ctx.mutex);

    backup_metadata_t *latest = NULL;
    time_t latest_time = 0;

    for (int i = 0; i < MAX_BACKUPS; i++) {
        if (backup_ctx.backups[i].backup_id != 0 && 
            (type == BACKUP_TYPE_FULL || backup_ctx.backups[i].type == type)) {
            if (backup_ctx.backups[i].timestamp > latest_time) {
                latest = &backup_ctx.backups[i];
                latest_time = backup_ctx.backups[i].timestamp;
            }
        }
    }

    pthread_mutex_unlock(&backup_ctx.mutex);
    return latest;
}

/* Set backup configuration */
int backup_set_config(const backup_config_t *config) {
    if (!backup_ctx.initialized || !config) {
        return -1;
    }

    pthread_mutex_lock(&backup_ctx.mutex);
    backup_ctx.config = *config;
    pthread_mutex_unlock(&backup_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "BACKUP_SYSTEM",
                   "Backup configuration updated", NULL, 0, NULL);

    return 0;
}

/* Get backup configuration */
backup_config_t backup_get_config(void) {
    backup_config_t config;
    if (backup_ctx.initialized) {
        pthread_mutex_lock(&backup_ctx.mutex);
        config = backup_ctx.config;
        pthread_mutex_unlock(&backup_ctx.mutex);
    } else {
        memset(&config, 0, sizeof(config));
    }
    return config;
}

/* Perform automatic backup if enabled */
int backup_auto_backup(void) {
    if (!backup_ctx.initialized || !backup_ctx.config.auto_backup) {
        return -1;
    }

    /* Check if it's time for auto backup */
    static time_t last_backup = 0;
    time_t now = time(NULL);
    double elapsed = difftime(now, last_backup);

    if (elapsed < backup_ctx.config.backup_interval_hours * 3600) {
        return 0; /* Not time yet */
    }

    /* Perform backup of critical files */
    backup_create_config("CMakeLists.txt", "cmake_backup");
    backup_create_config("README.md", "readme_backup");

    last_backup = now;
    return 0;
}

/* Get backup statistics */
void backup_get_stats(uint64_t *total_backups, uint64_t *total_size, uint64_t *failed_backups) {
    if (!backup_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&backup_ctx.mutex);
    if (total_backups) *total_backups = backup_ctx.backup_counter;
    if (total_size) *total_size = backup_ctx.total_size;
    if (failed_backups) *failed_backups = backup_ctx.failed_backups;
    pthread_mutex_unlock(&backup_ctx.mutex);
}

/* Get backup status string */
const char *backup_status_to_string(backup_status_t status) {
    switch (status) {
        case BACKUP_STATUS_SUCCESS: return "SUCCESS";
        case BACKUP_STATUS_FAILED: return "FAILED";
        case BACKUP_STATUS_IN_PROGRESS: return "IN_PROGRESS";
        case BACKUP_STATUS_VERIFICATION_FAILED: return "VERIFICATION_FAILED";
        default: return "UNKNOWN";
    }
}

/* Get backup type string */
const char *backup_type_to_string(backup_type_t type) {
    switch (type) {
        case BACKUP_TYPE_MODEL: return "MODEL";
        case BACKUP_TYPE_CONFIG: return "CONFIG";
        case BACKUP_TYPE_STATE: return "STATE";
        case BACKUP_TYPE_FULL: return "FULL";
        default: return "UNKNOWN";
    }
}
