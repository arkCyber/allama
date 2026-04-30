/*
 * File Sandbox System Implementation for allama
 * Aerospace-level file access control
 */

#include "file-sandbox.h"
#include "audit-log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <limits.h>
#include <sys/stat.h>
#include <unistd.h>
#include <libgen.h>

/* File sandbox context */
static struct {
    sandbox_config_t config;
    bool initialized;
    pthread_mutex_t mutex;
} sandbox_ctx = {0};

/* Check if path contains directory traversal */
static bool contains_traversal(const char *path) {
    return strstr(path, "..") != NULL;
}

/* Check if path is absolute */
static bool is_absolute_path(const char *path) {
    return path[0] == '/';
}

/* Resolve path (remove symlinks, get real path) */
static int resolve_path(const char *path, char *resolved, size_t size) {
    char *real_path = realpath(path, NULL);
    if (!real_path) {
        return -1;
    }

    strncpy(resolved, real_path, size - 1);
    resolved[size - 1] = '\0';
    free(real_path);

    return 0;
}

/* Check if path is within allowed directory */
static bool is_within_allowed(const char *path) {
    if (sandbox_ctx.config.num_allowed_directories == 0) {
        return true; /* No restrictions if no directories specified */
    }

    char resolved[PATH_MAX];
    if (resolve_path(path, resolved, sizeof(resolved)) != 0) {
        return false;
    }

    for (int i = 0; i < sandbox_ctx.config.num_allowed_directories; i++) {
        const char *allowed_dir = sandbox_ctx.config.allowed_directories[i];
        if (strncmp(resolved, allowed_dir, strlen(allowed_dir)) == 0) {
            return true;
        }
    }

    return false;
}

/* Initialize file sandbox */
int file_sandbox_init(const sandbox_config_t *config) {
    if (sandbox_ctx.initialized) {
        return 0; /* Already initialized */
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&sandbox_ctx.mutex, NULL) != 0) {
        return -1;
    }

    /* Copy configuration */
    if (config) {
        sandbox_ctx.config = *config;
    } else {
        /* Default configuration */
        sandbox_ctx.config.enabled = true;
        sandbox_ctx.config.allow_symlinks = false;
        sandbox_ctx.config.allow_absolute_paths = true;
        sandbox_ctx.config.allow_parent_directory = false;
        sandbox_ctx.config.max_file_size = 1ULL * 1024 * 1024 * 1024; /* 1GB */
        sandbox_ctx.config.num_allowed_directories = 0;
    }

    sandbox_ctx.initialized = true;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "FILE_SANDBOX",
                   "File sandbox initialized", NULL, 0, NULL);

    return 0;
}

/* Shutdown file sandbox */
void file_sandbox_shutdown(void) {
    if (!sandbox_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&sandbox_ctx.mutex);
    pthread_mutex_unlock(&sandbox_ctx.mutex);
    pthread_mutex_destroy(&sandbox_ctx.mutex);
    sandbox_ctx.initialized = false;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "FILE_SANDBOX",
                   "File sandbox shutdown", NULL, 0, NULL);
}

/* Validate and sanitize a file path */
sandbox_result_t file_sandbox_validate_path(const char *path, char *sanitized, size_t size) {
    if (!sandbox_ctx.initialized) {
        return SANDBOX_ERROR_DISABLED;
    }

    if (!path) {
        return SANDBOX_ERROR_PATH_INVALID;
    }

    pthread_mutex_lock(&sandbox_ctx.mutex);

    if (!sandbox_ctx.config.enabled) {
        pthread_mutex_unlock(&sandbox_ctx.mutex);
        return SANDBOX_SUCCESS;
    }

    /* Check for directory traversal */
    if (!sandbox_ctx.config.allow_parent_directory && contains_traversal(path)) {
        pthread_mutex_unlock(&sandbox_ctx.mutex);
        audit_log_security_violation("FILE_SANDBOX", "directory_traversal", path);
        return SANDBOX_ERROR_TRAVERSAL;
    }

    /* Check for absolute paths */
    if (!sandbox_ctx.config.allow_absolute_paths && is_absolute_path(path)) {
        pthread_mutex_unlock(&sandbox_ctx.mutex);
        return SANDBOX_ERROR_PATH_INVALID;
    }

    /* Check if within allowed directories */
    if (!is_within_allowed(path)) {
        pthread_mutex_unlock(&sandbox_ctx.mutex);
        audit_log_security_violation("FILE_SANDBOX", "path_not_allowed", path);
        return SANDBOX_ERROR_PATH_NOT_ALLOWED;
    }

    /* Sanitize path */
    if (sanitized && size > 0) {
        strncpy(sanitized, path, size - 1);
        sanitized[size - 1] = '\0';
    }

    pthread_mutex_unlock(&sandbox_ctx.mutex);
    return SANDBOX_SUCCESS;
}

/* Check if path is allowed */
sandbox_result_t file_sandbox_check_allowed(const char *path) {
    return file_sandbox_validate_path(path, NULL, 0);
}

/* Add allowed directory */
int file_sandbox_add_allowed_directory(const char *directory) {
    if (!sandbox_ctx.initialized || !directory) {
        return -1;
    }

    pthread_mutex_lock(&sandbox_ctx.mutex);

    if (sandbox_ctx.config.num_allowed_directories >= 16) {
        pthread_mutex_unlock(&sandbox_ctx.mutex);
        return -1;
    }

    strncpy(sandbox_ctx.config.allowed_directories[sandbox_ctx.config.num_allowed_directories],
            directory, sizeof(sandbox_ctx.config.allowed_directories[0]) - 1);
    sandbox_ctx.config.allowed_directories[sandbox_ctx.config.num_allowed_directories][sizeof(sandbox_ctx.config.allowed_directories[0]) - 1] = '\0';
    sandbox_ctx.config.num_allowed_directories++;

    pthread_mutex_unlock(&sandbox_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "FILE_SANDBOX",
                   "Allowed directory added", directory, 0, NULL);

    return 0;
}

/* Remove allowed directory */
int file_sandbox_remove_allowed_directory(const char *directory) {
    if (!sandbox_ctx.initialized || !directory) {
        return -1;
    }

    pthread_mutex_lock(&sandbox_ctx.mutex);

    for (int i = 0; i < sandbox_ctx.config.num_allowed_directories; i++) {
        if (strcmp(sandbox_ctx.config.allowed_directories[i], directory) == 0) {
            /* Shift remaining directories */
            for (int j = i; j < sandbox_ctx.config.num_allowed_directories - 1; j++) {
                strcpy(sandbox_ctx.config.allowed_directories[j],
                       sandbox_ctx.config.allowed_directories[j + 1]);
            }
            sandbox_ctx.config.num_allowed_directories--;
            pthread_mutex_unlock(&sandbox_ctx.mutex);
            audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "FILE_SANDBOX",
                           "Allowed directory removed", directory, 0, NULL);
            return 0;
        }
    }

    pthread_mutex_unlock(&sandbox_ctx.mutex);
    return -1;
}

/* Check file size against limit */
sandbox_result_t file_sandbox_check_file_size(const char *path) {
    if (!sandbox_ctx.initialized || !path) {
        return SANDBOX_ERROR_PATH_INVALID;
    }

    struct stat st;
    if (stat(path, &st) != 0) {
        return SANDBOX_ERROR_PATH_INVALID;
    }

    if ((size_t)st.st_size > sandbox_ctx.config.max_file_size) {
        audit_log_security_violation("FILE_SANDBOX", "file_too_large", path);
        return SANDBOX_ERROR_TOO_LARGE;
    }

    return SANDBOX_SUCCESS;
}

/* Safe file open (with sandbox validation) */
FILE *file_sandbox_fopen(const char *path, const char *mode) {
    if (!path || !mode) {
        return NULL;
    }

    /* Validate path */
    sandbox_result_t result = file_sandbox_validate_path(path, NULL, 0);
    if (result != SANDBOX_SUCCESS) {
        return NULL;
    }

    /* Check file size for write mode */
    if (strchr(mode, 'w') || strchr(mode, 'a')) {
        result = file_sandbox_check_file_size(path);
        if (result != SANDBOX_SUCCESS && result != SANDBOX_ERROR_PATH_INVALID) {
            return NULL;
        }
    }

    return fopen(path, mode);
}

/* Safe file read */
sandbox_result_t file_sandbox_read(const char *path, void *buffer, size_t size, size_t *bytes_read) {
    if (!path || !buffer || !bytes_read) {
        return SANDBOX_ERROR_PATH_INVALID;
    }

    FILE *file = file_sandbox_fopen(path, "rb");
    if (!file) {
        return SANDBOX_ERROR_PATH_INVALID;
    }

    *bytes_read = fread(buffer, 1, size, file);
    fclose(file);

    return SANDBOX_SUCCESS;
}

/* Safe file write */
sandbox_result_t file_sandbox_write(const char *path, const void *buffer, size_t size) {
    if (!path || !buffer) {
        return SANDBOX_ERROR_PATH_INVALID;
    }

    FILE *file = file_sandbox_fopen(path, "wb");
    if (!file) {
        return SANDBOX_ERROR_PATH_INVALID;
    }

    size_t written = fwrite(buffer, 1, size, file);
    fclose(file);

    if (written != size) {
        return SANDBOX_ERROR_PERMISSION;
    }

    return SANDBOX_SUCCESS;
}

/* Check if sandbox is enabled */
bool file_sandbox_is_enabled(void) {
    if (!sandbox_ctx.initialized) {
        return false;
    }

    pthread_mutex_lock(&sandbox_ctx.mutex);
    bool enabled = sandbox_ctx.config.enabled;
    pthread_mutex_unlock(&sandbox_ctx.mutex);

    return enabled;
}

/* Get sandbox configuration */
sandbox_config_t file_sandbox_get_config(void) {
    sandbox_config_t config;
    if (sandbox_ctx.initialized) {
        pthread_mutex_lock(&sandbox_ctx.mutex);
        config = sandbox_ctx.config;
        pthread_mutex_unlock(&sandbox_ctx.mutex);
    } else {
        memset(&config, 0, sizeof(config));
    }
    return config;
}

/* Set sandbox configuration */
int file_sandbox_set_config(const sandbox_config_t *config) {
    if (!sandbox_ctx.initialized || !config) {
        return -1;
    }

    pthread_mutex_lock(&sandbox_ctx.mutex);
    sandbox_ctx.config = *config;
    pthread_mutex_unlock(&sandbox_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "FILE_SANDBOX",
                   "Sandbox configuration updated", NULL, 0, NULL);

    return 0;
}

/* Get result string */
const char *file_sandbox_result_to_string(sandbox_result_t result) {
    switch (result) {
        case SANDBOX_SUCCESS: return "SUCCESS";
        case SANDBOX_ERROR_DISABLED: return "DISABLED";
        case SANDBOX_ERROR_PATH_INVALID: return "PATH_INVALID";
        case SANDBOX_ERROR_PATH_NOT_ALLOWED: return "PATH_NOT_ALLOWED";
        case SANDBOX_ERROR_TRAVERSAL: return "TRAVERSAL";
        case SANDBOX_ERROR_SYMLINK: return "SYMLINK";
        case SANDBOX_ERROR_TOO_LARGE: return "TOO_LARGE";
        case SANDBOX_ERROR_PERMISSION: return "PERMISSION";
        default: return "UNKNOWN";
    }
}
