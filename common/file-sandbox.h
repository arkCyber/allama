/*
 * File Sandbox System for allama
 * Aerospace-level file access control
 * 
 * Provides:
 * - Path validation and sanitization
 * - Allowed directory whitelist
 * - File operation restrictions
 * - Symbolic link protection
 * - Directory traversal prevention
 * - File size limits
 * - Permission checking
 */

#ifndef FILE_SANDBOX_H
#define FILE_SANDBOX_H

#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Sandbox configuration */
typedef struct {
    bool enabled;
    bool allow_symlinks;
    bool allow_absolute_paths;
    bool allow_parent_directory;
    size_t max_file_size;
    char allowed_directories[16][512];
    int num_allowed_directories;
} sandbox_config_t;

/* Sandbox result */
typedef enum {
    SANDBOX_SUCCESS = 0,
    SANDBOX_ERROR_DISABLED = 1,
    SANDBOX_ERROR_PATH_INVALID = 2,
    SANDBOX_ERROR_PATH_NOT_ALLOWED = 3,
    SANDBOX_ERROR_TRAVERSAL = 4,
    SANDBOX_ERROR_SYMLINK = 5,
    SANDBOX_ERROR_TOO_LARGE = 6,
    SANDBOX_ERROR_PERMISSION = 7
} sandbox_result_t;

/* Initialize file sandbox */
int file_sandbox_init(const sandbox_config_t *config);

/* Shutdown file sandbox */
void file_sandbox_shutdown(void);

/* Validate and sanitize a file path */
sandbox_result_t file_sandbox_validate_path(const char *path, char *sanitized, size_t size);

/* Check if path is allowed */
sandbox_result_t file_sandbox_check_allowed(const char *path);

/* Add allowed directory */
int file_sandbox_add_allowed_directory(const char *directory);

/* Remove allowed directory */
int file_sandbox_remove_allowed_directory(const char *directory);

/* Check file size against limit */
sandbox_result_t file_sandbox_check_file_size(const char *path);

/* Safe file open (with sandbox validation) */
FILE *file_sandbox_fopen(const char *path, const char *mode);

/* Safe file read */
sandbox_result_t file_sandbox_read(const char *path, void *buffer, size_t size, size_t *bytes_read);

/* Safe file write */
sandbox_result_t file_sandbox_write(const char *path, const void *buffer, size_t size);

/* Check if sandbox is enabled */
bool file_sandbox_is_enabled(void);

/* Get sandbox configuration */
sandbox_config_t file_sandbox_get_config(void);

/* Set sandbox configuration */
int file_sandbox_set_config(const sandbox_config_t *config);

/* Get result string */
const char *file_sandbox_result_to_string(sandbox_result_t result);

#ifdef __cplusplus
}
#endif

#endif /* FILE_SANDBOX_H */
