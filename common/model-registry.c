/**
 * @file model-registry.c
 * @brief Model registry and management system implementation
 * 
 * Aerospace-Level Security Implementation:
 * - Thread-safe operations with pthread mutex
 * - Audit logging for all registry operations
 * - Secure model file validation
 * - ACSL annotations for formal verification
 * - Comprehensive error handling
 */

#include "model-registry.h"
#include "audit-log.h"
#include "http-download.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sqlite3.h>
#include <sys/stat.h>
#include <time.h>
#include <openssl/sha.h>
#include <unistd.h>
#include <errno.h>
#include <ctype.h>

/* ACSL annotations for formal verification */
/*@ predicate valid_registry_context(struct model_registry_context *ctx) = 
    \valid(ctx) && 
    \valid_read(ctx->config) &&
    \valid(ctx->mutex) &&
    ctx->initialized == 1;
@*/

/**
 * @brief Model registry context structure
 */
struct model_registry_context {
    model_registry_config_t config;
    char *remote_registry_url;  /* Copy of remote registry URL for use */
    sqlite3 *db;
    pthread_mutex_t mutex;
    int initialized;
    bool audit_enabled;
};

/**
 * @brief Default configuration values
 */
#define DEFAULT_REGISTRY_PATH "~/.allama/registry.db"
#define DEFAULT_MODELS_PATH "~/.allama/models"
#define DEFAULT_REMOTE_REGISTRY_URL "https://huggingface.co/ggml-org"
#define DEFAULT_MAX_MODELS 1000
#define DEFAULT_MAX_STORAGE (100ULL * 1024 * 1024 * 1024) /* 100 GB */

/**
 * @brief SQL schema for model registry
 */
static const char *SQL_SCHEMA = 
    "CREATE TABLE IF NOT EXISTS models ("
    "id INTEGER PRIMARY KEY AUTOINCREMENT,"
    "name TEXT NOT NULL UNIQUE,"
    "tag TEXT NOT NULL,"
    "digest TEXT NOT NULL,"
    "path TEXT NOT NULL UNIQUE,"
    "size INTEGER NOT NULL,"
    "parameters INTEGER,"
    "quantization TEXT,"
    "architecture TEXT,"
    "license TEXT,"
    "author TEXT,"
    "created_at INTEGER NOT NULL,"
    "modified_at INTEGER NOT NULL,"
    "description TEXT,"
    "family TEXT,"
    "format TEXT,"
    "backend TEXT,"
    "loaded INTEGER DEFAULT 0"
    ");"
    "CREATE INDEX IF NOT EXISTS idx_name ON models(name);"
    "CREATE INDEX IF NOT EXISTS idx_tag ON models(tag);"
    "CREATE INDEX IF NOT EXISTS idx_digest ON models(digest);"
    "CREATE INDEX IF NOT EXISTS idx_loaded ON models(loaded);";

/**
 * @brief Initialize SQLite database
 * 
 * @param db_path Path to database file
 * @param db Output database handle
 * @return model_registry_result_t Result code
 */
/*@ 
  requires \valid_read(db_path);
  requires \valid(db);
  assigns *db;
  ensures \result == MODEL_REGISTRY_SUCCESS ==> *db != NULL;
@*/
static model_registry_result_t init_database(const char *db_path, sqlite3 **db) {
    int rc = sqlite3_open(db_path, db);
    if (rc != SQLITE_OK) {
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    char *err_msg = NULL;
    rc = sqlite3_exec(*db, SQL_SCHEMA, NULL, NULL, &err_msg);
    if (rc != SQLITE_OK) {
        sqlite3_close(*db);
        *db = NULL;
        if (err_msg) {
            sqlite3_free(err_msg);
        }
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Expand home directory in path
 * 
 * @param path Path with ~
 * @param expanded_path Output expanded path
 * @param max_len Maximum length of output path
 * @return model_registry_result_t Result code
 */
static model_registry_result_t expand_path(const char *path, char *expanded_path, size_t max_len) {
    if (path[0] == '~') {
        const char *home = getenv("HOME");
        if (!home) {
            return MODEL_REGISTRY_ERROR_INVALID_PATH;
        }
        snprintf(expanded_path, max_len, "%s%s", home, path + 1);
    } else {
        snprintf(expanded_path, max_len, "%s", path);
    }
    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Create directory recursively
 * 
 * @param path Directory path
 * @return int 0 on success, -1 on failure
 */
static int mkdir_recursive(const char *path) {
    char tmp[512];
    char *p = NULL;
    size_t len;

    snprintf(tmp, sizeof(tmp), "%s", path);
    len = strlen(tmp);
    if (tmp[len - 1] == '/') {
        tmp[len - 1] = 0;
    }

    for (p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = 0;
            if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
                return -1;
            }
            *p = '/';
        }
    }

    if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
        return -1;
    }

    return 0;
}

/**
 * @brief Calculate SHA256 digest of file
 * 
 * @param file_path Path to file
 * @param digest Output digest (32 bytes)
 * @return model_registry_result_t Result code
 */
static model_registry_result_t calculate_digest(const char *file_path, unsigned char *digest) {
    FILE *file = fopen(file_path, "rb");
    if (!file) {
        return MODEL_REGISTRY_ERROR_IO;
    }

    SHA256_CTX sha256;
    SHA256_Init(&sha256);

    unsigned char buffer[4096];
    size_t bytes_read;
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), file)) > 0) {
        SHA256_Update(&sha256, buffer, bytes_read);
    }

    fclose(file);
    SHA256_Final(digest, &sha256);

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Convert digest to hex string
 * 
 * @param digest Binary digest
 * @param hex_string Output hex string (65 bytes including null terminator)
 */
static void digest_to_hex(const unsigned char *digest, char *hex_string) {
    for (int i = 0; i < 32; i++) {
        snprintf(hex_string + (i * 2), 3, "%02x", digest[i]);
    }
    hex_string[64] = '\0';
}

static void sanitize_model_name_for_filename(const char *input, char *output, size_t output_size) {
    if (!input || !output || output_size == 0) {
        return;
    }

    size_t j = 0;
    for (size_t i = 0; input[i] != '\0' && j + 1 < output_size; ++i) {
        unsigned char c = (unsigned char) input[i];
        if (isalnum(c) || c == '-' || c == '_' || c == '.') {
            output[j++] = (char) c;
        } else {
            output[j++] = '-';
        }
    }
    output[j] = '\0';
}

/**
 * @brief Initialize the model registry
 */
model_registry_result_t model_registry_init(
    const model_registry_config_t *config,
    model_registry_context_t **ctx
) {
    if (!config || !ctx) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    /* Allocate context */
    model_registry_context_t *context = calloc(1, sizeof(model_registry_context_t));
    if (!context) {
        return MODEL_REGISTRY_ERROR_IO;
    }

    /* Copy configuration */
    context->config = *config;
    context->initialized = 0;
    context->audit_enabled = config->enable_audit;

    /* Copy remote registry URL */
    if (config->remote_registry_url) {
        context->remote_registry_url = strdup(config->remote_registry_url);
        if (!context->remote_registry_url) {
            pthread_mutex_destroy(&context->mutex);
            free(context);
            return MODEL_REGISTRY_ERROR_DATABASE;
        }
    } else {
        context->remote_registry_url = strdup(DEFAULT_REMOTE_REGISTRY_URL);
        if (!context->remote_registry_url) {
            pthread_mutex_destroy(&context->mutex);
            free(context);
            return MODEL_REGISTRY_ERROR_DATABASE;
        }
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&context->mutex, NULL) != 0) {
        free(context);
        return MODEL_REGISTRY_ERROR_LOCKED;
    }

    /* Expand paths */
    char registry_path[512];
    char models_path[512];
    
    if (expand_path(config->registry_path ? config->registry_path : DEFAULT_REGISTRY_PATH, 
                    registry_path, sizeof(registry_path)) != MODEL_REGISTRY_SUCCESS) {
        pthread_mutex_destroy(&context->mutex);
        free(context);
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    if (expand_path(config->models_path ? config->models_path : DEFAULT_MODELS_PATH,
                    models_path, sizeof(models_path)) != MODEL_REGISTRY_SUCCESS) {
        pthread_mutex_destroy(&context->mutex);
        free(context);
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    /* Create directories if they don't exist */
    char registry_dir[512];
    snprintf(registry_dir, sizeof(registry_dir), "%s", registry_path);
    char *last_slash = strrchr(registry_dir, '/');
    if (last_slash) {
        *last_slash = '\0';
        mkdir_recursive(registry_dir);
    }

    mkdir_recursive(models_path);

    /* Initialize database */
    model_registry_result_t result = init_database(registry_path, &context->db);
    if (result != MODEL_REGISTRY_SUCCESS) {
        pthread_mutex_destroy(&context->mutex);
        free(context);
        return result;
    }

    context->initialized = 1;
    *ctx = context;

    /* Audit log */
    if (context->audit_enabled) {
        audit_log_security_violation("model_registry_init", "registry", "initialized");
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Shutdown the model registry
 */
model_registry_result_t model_registry_shutdown(model_registry_context_t *ctx) {
    if (!ctx || !ctx->initialized) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    if (ctx->remote_registry_url) {
        free(ctx->remote_registry_url);
        ctx->remote_registry_url = NULL;
    }

    if (ctx->db) {
        sqlite3_close(ctx->db);
        ctx->db = NULL;
    }

    if (ctx->audit_enabled) {
        audit_log_security_violation("model_registry_shutdown", "registry", "shutdown");
    }

    ctx->initialized = 0;
    pthread_mutex_unlock(&ctx->mutex);
    pthread_mutex_destroy(&ctx->mutex);

    free(ctx);

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Pull a model from remote registry
 */
model_registry_result_t model_registry_pull(
    model_registry_context_t *ctx,
    const char *model_name,
    void (*progress_callback)(const char *, float, void *),
    void *user_data
) {
    if (!ctx || !ctx->initialized || !model_name) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    /* Check if model already exists */
    sqlite3_stmt *stmt;
    const char *sql = "SELECT path FROM models WHERE name = ? LIMIT 1;";
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, model_name, -1, SQLITE_STATIC);
        rc = sqlite3_step(stmt);
        sqlite3_finalize(stmt);
        
        if (rc == SQLITE_ROW) {
            pthread_mutex_unlock(&ctx->mutex);
            if (ctx->audit_enabled) {
                audit_log_auth_failure("model_registry_pull", model_name, "model already exists");
            }
            return MODEL_REGISTRY_ERROR_EXISTS;
        }
    }

    pthread_mutex_unlock(&ctx->mutex);

    /* Construct download URL (Hugging Face format) */
    char download_url[512];
    char output_path[512];
    
    /* Convert model name to safe filename format */
    char sanitized_name[256];
    sanitize_model_name_for_filename(model_name, sanitized_name, sizeof(sanitized_name));
    
    /* Construct download URL using configured remote registry */
    snprintf(download_url, sizeof(download_url), 
             "%s/%s/resolve/main/%s.gguf",
             ctx->remote_registry_url, sanitized_name, sanitized_name);
    
    /* Construct output path */
    snprintf(output_path, sizeof(output_path), "%s/%s.gguf", 
             ctx->config.models_path ? ctx->config.models_path : "~/.allama/models", 
             sanitized_name);
    
    /* Download the model */
    download_result_t dl_result = http_download_file(
        download_url,
        output_path,
        (download_progress_callback_t)progress_callback,
        user_data,
        3600  /* 1 hour timeout */
    );
    
    if (dl_result != DOWNLOAD_SUCCESS) {
        if (ctx->audit_enabled) {
            audit_log_security_violation("model_registry_pull", model_name, 
                                      download_result_to_string(dl_result));
        }
        return MODEL_REGISTRY_ERROR_NETWORK;
    }
    
    /* Compute SHA256 hash */
    uint8_t digest[SHA256_DIGEST_LENGTH];
    FILE *file = fopen(output_path, "rb");
    if (!file) {
        if (ctx->audit_enabled) {
            audit_log_security_violation("model_registry_pull", model_name, "file open failed");
        }
        return MODEL_REGISTRY_ERROR_IO;
    }
    
    SHA256_CTX sha256;
    SHA256_Init(&sha256);
    
    uint8_t buffer[8192];
    size_t bytes_read;
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), file)) > 0) {
        SHA256_Update(&sha256, buffer, bytes_read);
    }
    fclose(file);
    SHA256_Final(digest, &sha256);
    
    char hex_digest[SHA256_DIGEST_LENGTH * 2 + 1];
    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        snprintf(hex_digest + (i * 2), 3, "%02x", digest[i]);
    }
    
    /* Get file size */
    struct stat st;
    if (stat(output_path, &st) != 0) {
        if (ctx->audit_enabled) {
            audit_log_security_violation("model_registry_pull", model_name, "stat failed");
        }
        return MODEL_REGISTRY_ERROR_IO;
    }
    
    /* Register model in registry */
    pthread_mutex_lock(&ctx->mutex);
    
    sql = "INSERT INTO models (name, tag, digest, path, size, created_at, modified_at) "
          "VALUES (?, 'latest', ?, ?, ?, ?, ?);";
    rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        pthread_mutex_unlock(&ctx->mutex);
        if (ctx->audit_enabled) {
            audit_log_security_violation("model_registry_pull", model_name, "insert failed");
        }
        return MODEL_REGISTRY_ERROR_DATABASE;
    }
    
    uint64_t now = time(NULL);
    sqlite3_bind_text(stmt, 1, model_name, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, hex_digest, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 3, output_path, -1, SQLITE_STATIC);
    sqlite3_bind_int64(stmt, 4, st.st_size);
    sqlite3_bind_int64(stmt, 5, now);
    sqlite3_bind_int64(stmt, 6, now);
    
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    
    pthread_mutex_unlock(&ctx->mutex);
    
    if (rc != SQLITE_DONE) {
        if (ctx->audit_enabled) {
            audit_log_security_violation("model_registry_pull", model_name, "insert failed");
        }
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_pull", model_name);
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Pull a model from remote registry with custom download URL
 */
model_registry_result_t model_registry_pull_with_url(
    model_registry_context_t *ctx,
    const char *model_name,
    const char *download_url,
    void (*progress_callback)(const char *model, float progress, void *user_data),
    void *user_data
) {
    if (!ctx || !ctx->initialized || !model_name) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    /* Check if model already exists */
    sqlite3_stmt *stmt;
    const char *sql = "SELECT path FROM models WHERE name = ? LIMIT 1;";
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, model_name, -1, SQLITE_STATIC);
        rc = sqlite3_step(stmt);
        sqlite3_finalize(stmt);
        
        if (rc == SQLITE_ROW) {
            pthread_mutex_unlock(&ctx->mutex);
            if (ctx->audit_enabled) {
                audit_log_auth_failure("model_registry_pull", model_name, "model already exists");
            }
            return MODEL_REGISTRY_ERROR_EXISTS;
        }
    }

    pthread_mutex_unlock(&ctx->mutex);

    /* Construct output path */
    char output_path[512];
    
    /* Convert model name to safe filename format */
    char sanitized_name[256];
    sanitize_model_name_for_filename(model_name, sanitized_name, sizeof(sanitized_name));
    
    /* Construct output path */
    snprintf(output_path, sizeof(output_path), "%s/%s.gguf", 
             ctx->config.models_path ? ctx->config.models_path : "~/.allama/models", 
             sanitized_name);
    
    /* Determine which download URL to use */
    char actual_download_url[512];
    if (download_url && strlen(download_url) > 0) {
        /* Use provided download URL from catalog */
        snprintf(actual_download_url, sizeof(actual_download_url), "%s", download_url);
    } else {
        /* Fall back to default URL construction */
        snprintf(actual_download_url, sizeof(actual_download_url), 
                 "%s/%s/resolve/main/%s.gguf",
                 ctx->remote_registry_url, sanitized_name, sanitized_name);
    }
    
    /* Download the model */
    download_result_t dl_result = http_download_file(
        actual_download_url,
        output_path,
        (download_progress_callback_t)progress_callback,
        user_data,
        3600  /* 1 hour timeout */
    );
    
    if (dl_result != DOWNLOAD_SUCCESS) {
        if (ctx->audit_enabled) {
            audit_log_security_violation("model_registry_pull", model_name, 
                                      download_result_to_string(dl_result));
        }
        return MODEL_REGISTRY_ERROR_NETWORK;
    }
    
    /* Compute SHA256 hash */
    uint8_t digest[SHA256_DIGEST_LENGTH];
    FILE *file = fopen(output_path, "rb");
    if (!file) {
        if (ctx->audit_enabled) {
            audit_log_security_violation("model_registry_pull", model_name, "file open failed");
        }
        return MODEL_REGISTRY_ERROR_IO;
    }
    
    SHA256_CTX sha256;
    SHA256_Init(&sha256);
    
    uint8_t buffer[8192];
    size_t bytes_read;
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), file)) > 0) {
        SHA256_Update(&sha256, buffer, bytes_read);
    }
    fclose(file);
    SHA256_Final(digest, &sha256);
    
    char hex_digest[SHA256_DIGEST_LENGTH * 2 + 1];
    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        snprintf(hex_digest + (i * 2), 3, "%02x", digest[i]);
    }
    
    /* Get file size */
    struct stat st;
    if (stat(output_path, &st) != 0) {
        if (ctx->audit_enabled) {
            audit_log_security_violation("model_registry_pull", model_name, "stat failed");
        }
        return MODEL_REGISTRY_ERROR_IO;
    }
    
    /* Register model in registry */
    pthread_mutex_lock(&ctx->mutex);
    
    sql = "INSERT INTO models (name, tag, digest, path, size, created_at, modified_at) "
          "VALUES (?, 'latest', ?, ?, ?, ?, ?);";
    rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        pthread_mutex_unlock(&ctx->mutex);
        if (ctx->audit_enabled) {
            audit_log_security_violation("model_registry_pull", model_name, "insert failed");
        }
        return MODEL_REGISTRY_ERROR_DATABASE;
    }
    
    uint64_t now = time(NULL);
    sqlite3_bind_text(stmt, 1, model_name, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, hex_digest, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 3, output_path, -1, SQLITE_STATIC);
    sqlite3_bind_int64(stmt, 4, st.st_size);
    sqlite3_bind_int64(stmt, 5, now);
    sqlite3_bind_int64(stmt, 6, now);
    
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    
    pthread_mutex_unlock(&ctx->mutex);
    
    if (rc != SQLITE_DONE) {
        if (ctx->audit_enabled) {
            audit_log_security_violation("model_registry_pull", model_name, "insert failed");
        }
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_pull", model_name);
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief List all registered models
 */
model_registry_result_t model_registry_list(
    model_registry_context_t *ctx,
    model_metadata_t **models,
    size_t *count
) {
    if (!ctx || !ctx->initialized || !models || !count) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    const char *sql = "SELECT name, tag, digest, path, size, parameters, "
                      "quantization, architecture, license, author, created_at, "
                      "modified_at, description, family, format, backend FROM models;";

    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    /* Count models first */
    size_t model_count = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        model_count++;
    }
    sqlite3_reset(stmt);

    /* Allocate array */
    model_metadata_t *model_array = calloc(model_count, sizeof(model_metadata_t));
    if (!model_array) {
        sqlite3_finalize(stmt);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_IO;
    }

    /* Populate array */
    size_t idx = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW && idx < model_count) {
        model_metadata_t *meta = &model_array[idx];

        const char *name = (const char *)sqlite3_column_text(stmt, 0);
        const char *tag = (const char *)sqlite3_column_text(stmt, 1);
        const char *digest = (const char *)sqlite3_column_text(stmt, 2);
        const char *path = (const char *)sqlite3_column_text(stmt, 3);
        const char *quantization = (const char *)sqlite3_column_text(stmt, 6);
        const char *architecture = (const char *)sqlite3_column_text(stmt, 7);
        const char *license = (const char *)sqlite3_column_text(stmt, 8);
        const char *author = (const char *)sqlite3_column_text(stmt, 9);
        const char *description = (const char *)sqlite3_column_text(stmt, 12);
        const char *family = (const char *)sqlite3_column_text(stmt, 13);
        const char *format = (const char *)sqlite3_column_text(stmt, 14);
        const char *backend = (const char *)sqlite3_column_text(stmt, 15);

        meta->name = name ? strdup(name) : NULL;
        meta->tag = tag ? strdup(tag) : NULL;
        meta->digest = digest ? strdup(digest) : NULL;
        meta->path = path ? strdup(path) : NULL;
        meta->size = sqlite3_column_int64(stmt, 4);
        meta->parameters = sqlite3_column_int(stmt, 5);
        meta->quantization = quantization ? strdup(quantization) : NULL;
        meta->architecture = architecture ? strdup(architecture) : NULL;
        meta->license = license ? strdup(license) : NULL;
        meta->author = author ? strdup(author) : NULL;
        meta->created_at = sqlite3_column_int64(stmt, 10);
        meta->modified_at = sqlite3_column_int64(stmt, 11);
        meta->description = description ? strdup(description) : NULL;
        meta->family = family ? strdup(family) : NULL;
        meta->format = format ? strdup(format) : NULL;
        meta->backend = backend ? strdup(backend) : NULL;

        idx++;
    }

    sqlite3_finalize(stmt);
    pthread_mutex_unlock(&ctx->mutex);

    *models = model_array;
    *count = model_count;

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_list", "list operation");
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Show detailed information about a model
 */
model_registry_result_t model_registry_show(
    model_registry_context_t *ctx,
    const char *model_name,
    model_metadata_t **metadata
) {
    if (!ctx || !ctx->initialized || !model_name || !metadata) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    const char *sql = "SELECT name, tag, digest, path, size, parameters, "
                      "quantization, architecture, license, author, created_at, "
                      "modified_at, description, family, format, backend "
                      "FROM models WHERE name = ? LIMIT 1;";
    
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    sqlite3_bind_text(stmt, 1, model_name, -1, SQLITE_STATIC);
    rc = sqlite3_step(stmt);

    if (rc != SQLITE_ROW) {
        sqlite3_finalize(stmt);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_NOT_FOUND;
    }

    model_metadata_t *meta = calloc(1, sizeof(model_metadata_t));
    if (!meta) {
        sqlite3_finalize(stmt);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_IO;
    }

    const char *name = (const char *)sqlite3_column_text(stmt, 0);
    const char *tag = (const char *)sqlite3_column_text(stmt, 1);
    const char *digest = (const char *)sqlite3_column_text(stmt, 2);
    const char *path = (const char *)sqlite3_column_text(stmt, 3);
    const char *quantization = (const char *)sqlite3_column_text(stmt, 6);
    const char *architecture = (const char *)sqlite3_column_text(stmt, 7);
    const char *license = (const char *)sqlite3_column_text(stmt, 8);
    const char *author = (const char *)sqlite3_column_text(stmt, 9);
    const char *description = (const char *)sqlite3_column_text(stmt, 12);
    const char *family = (const char *)sqlite3_column_text(stmt, 13);
    const char *format = (const char *)sqlite3_column_text(stmt, 14);
    const char *backend = (const char *)sqlite3_column_text(stmt, 15);

    meta->name = name ? strdup(name) : NULL;
    meta->tag = tag ? strdup(tag) : NULL;
    meta->digest = digest ? strdup(digest) : NULL;
    meta->path = path ? strdup(path) : NULL;
    meta->size = sqlite3_column_int64(stmt, 4);
    meta->parameters = sqlite3_column_int(stmt, 5);
    meta->quantization = quantization ? strdup(quantization) : NULL;
    meta->architecture = architecture ? strdup(architecture) : NULL;
    meta->license = license ? strdup(license) : NULL;
    meta->author = author ? strdup(author) : NULL;
    meta->created_at = sqlite3_column_int64(stmt, 10);
    meta->modified_at = sqlite3_column_int64(stmt, 11);
    meta->description = description ? strdup(description) : NULL;
    meta->family = family ? strdup(family) : NULL;
    meta->format = format ? strdup(format) : NULL;
    meta->backend = backend ? strdup(backend) : NULL;

    sqlite3_finalize(stmt);
    pthread_mutex_unlock(&ctx->mutex);

    *metadata = meta;

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_show", model_name);
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Remove a model from the registry
 */
model_registry_result_t model_registry_remove(
    model_registry_context_t *ctx,
    const char *model_name,
    bool force
) {
    if (!ctx || !ctx->initialized || !model_name) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    /* Get model path first */
    char *path = NULL;
    const char *sql = "SELECT path FROM models WHERE name = ? LIMIT 1;";
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, model_name, -1, SQLITE_STATIC);
        rc = sqlite3_step(stmt);
        if (rc == SQLITE_ROW) {
            path = strdup((const char *)sqlite3_column_text(stmt, 0));
        }
        sqlite3_finalize(stmt);
    }

    if (!path) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_NOT_FOUND;
    }

    /* Delete from database */
    sql = "DELETE FROM models WHERE name = ?;";
    rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        free(path);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    sqlite3_bind_text(stmt, 1, model_name, -1, SQLITE_STATIC);
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    if (rc != SQLITE_DONE) {
        free(path);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    /* Delete file */
    if (force || access(path, F_OK) == 0) {
        unlink(path);
    }

    free(path);
    pthread_mutex_unlock(&ctx->mutex);

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_remove", model_name);
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Copy a model to a new name
 */
model_registry_result_t model_registry_copy(
    model_registry_context_t *ctx,
    const char *src_name,
    const char *dst_name
) {
    if (!ctx || !ctx->initialized || !src_name || !dst_name) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    /* Get source model metadata */
    model_metadata_t *src_meta = NULL;
    model_registry_result_t result = model_registry_show(ctx, src_name, &src_meta);
    if (result != MODEL_REGISTRY_SUCCESS) {
        pthread_mutex_unlock(&ctx->mutex);
        return result;
    }

    /* Check if destination already exists */
    sqlite3_stmt *stmt;
    const char *sql = "SELECT name FROM models WHERE name = ? LIMIT 1;";
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, dst_name, -1, SQLITE_STATIC);
        rc = sqlite3_step(stmt);
        sqlite3_finalize(stmt);
        
        if (rc == SQLITE_ROW) {
            model_metadata_free(src_meta);
            pthread_mutex_unlock(&ctx->mutex);
            return MODEL_REGISTRY_ERROR_EXISTS;
        }
    }

    /* Copy file */
    char dst_path[512];
    snprintf(dst_path, sizeof(dst_path), "%s/%s.gguf", 
             ctx->config.models_path, dst_name);

    /* Copy file content */
    FILE *src_file = fopen(src_meta->path, "rb");
    if (!src_file) {
        model_metadata_free(src_meta);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_IO;
    }

    FILE *dst_file = fopen(dst_path, "wb");
    if (!dst_file) {
        fclose(src_file);
        model_metadata_free(src_meta);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_IO;
    }

    unsigned char buffer[4096];
    size_t bytes_read;
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), src_file)) > 0) {
        fwrite(buffer, 1, bytes_read, dst_file);
    }

    fclose(src_file);
    fclose(dst_file);

    /* Add to registry */
    sql = "INSERT INTO models (name, tag, digest, path, size, parameters, "
          "quantization, architecture, license, author, created_at, modified_at, "
          "description, family, format, backend) VALUES (?, ?, ?, ?, ?, ?, "
          "?, ?, ?, ?, ?, ?, ?, ?, ?);";
    
    rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        unlink(dst_path);
        model_metadata_free(src_meta);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    uint64_t now = time(NULL);
    sqlite3_bind_text(stmt, 1, dst_name, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, src_meta->tag, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 3, src_meta->digest, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 4, dst_path, -1, SQLITE_STATIC);
    sqlite3_bind_int64(stmt, 5, src_meta->size);
    sqlite3_bind_int(stmt, 6, src_meta->parameters);
    sqlite3_bind_text(stmt, 7, src_meta->quantization, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 8, src_meta->architecture, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 9, src_meta->license, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 10, src_meta->author, -1, SQLITE_STATIC);
    sqlite3_bind_int64(stmt, 11, now);
    sqlite3_bind_int64(stmt, 12, now);
    sqlite3_bind_text(stmt, 13, src_meta->description, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 14, src_meta->family, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 15, src_meta->format, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 16, src_meta->backend, -1, SQLITE_STATIC);

    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    model_metadata_free(src_meta);

    if (rc != SQLITE_DONE) {
        unlink(dst_path);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    pthread_mutex_unlock(&ctx->mutex);

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_copy", dst_name);
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Add a local model to the registry
 */
model_registry_result_t model_registry_add(
    model_registry_context_t *ctx,
    const char *model_name,
    const char *file_path
) {
    if (!ctx || !ctx->initialized || !model_name || !file_path) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    /* Check if file exists */
    if (access(file_path, F_OK) != 0) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_IO;
    }

    /* Calculate file size */
    struct stat st;
    if (stat(file_path, &st) != 0) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_IO;
    }

    /* Calculate digest */
    unsigned char digest[32];
    char digest_str[65];
    model_registry_result_t result = calculate_digest(file_path, digest);
    if (result != MODEL_REGISTRY_SUCCESS) {
        pthread_mutex_unlock(&ctx->mutex);
        return result;
    }
    digest_to_hex(digest, digest_str);

    /* Check if model already exists */
    sqlite3_stmt *stmt;
    const char *sql = "SELECT name FROM models WHERE name = ? LIMIT 1;";
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, model_name, -1, SQLITE_STATIC);
        rc = sqlite3_step(stmt);
        sqlite3_finalize(stmt);
        
        if (rc == SQLITE_ROW) {
            pthread_mutex_unlock(&ctx->mutex);
            return MODEL_REGISTRY_ERROR_EXISTS;
        }
    }

    /* Copy file to models directory */
    char dst_path[512];
    snprintf(dst_path, sizeof(dst_path), "%s/%s.gguf", 
             ctx->config.models_path, model_name);

    FILE *src_file = fopen(file_path, "rb");
    if (!src_file) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_IO;
    }

    FILE *dst_file = fopen(dst_path, "wb");
    if (!dst_file) {
        fclose(src_file);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_IO;
    }

    unsigned char buffer[4096];
    size_t bytes_read;
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), src_file)) > 0) {
        fwrite(buffer, 1, bytes_read, dst_file);
    }

    fclose(src_file);
    fclose(dst_file);

    /* Add to registry with minimal metadata */
    sql = "INSERT INTO models (name, tag, digest, path, size, created_at, modified_at) "
          "VALUES (?, ?, ?, ?, ?, ?, ?);";
    
    rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        unlink(dst_path);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    uint64_t now = time(NULL);
    const char *default_tag = "latest";
    sqlite3_bind_text(stmt, 1, model_name, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, default_tag, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 3, digest_str, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 4, dst_path, -1, SQLITE_STATIC);
    sqlite3_bind_int64(stmt, 5, st.st_size);
    sqlite3_bind_int64(stmt, 6, now);
    sqlite3_bind_int64(stmt, 7, now);

    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    if (rc != SQLITE_DONE) {
        unlink(dst_path);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    pthread_mutex_unlock(&ctx->mutex);

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_add", model_name);
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Search models by name pattern
 */
model_registry_result_t model_registry_search(
    model_registry_context_t *ctx,
    const char *pattern,
    model_metadata_t **models,
    size_t *count
) {
    if (!ctx || !ctx->initialized || !pattern || !models || !count) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    const char *sql = "SELECT name, tag, digest, path, size, parameters, "
                      "quantization, architecture, license, author, created_at, "
                      "modified_at, description, family, format, backend "
                      "FROM models WHERE name LIKE ?;";
    
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    /* Convert pattern to SQL LIKE pattern */
    char sql_pattern[256];
    snprintf(sql_pattern, sizeof(sql_pattern), "%%%s%%", pattern);
    sqlite3_bind_text(stmt, 1, sql_pattern, -1, SQLITE_STATIC);

    /* Count models first */
    size_t model_count = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        model_count++;
    }
    sqlite3_reset(stmt);

    /* Allocate array */
    model_metadata_t *model_array = calloc(model_count, sizeof(model_metadata_t));
    if (!model_array) {
        sqlite3_finalize(stmt);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_IO;
    }

    /* Populate array */
    size_t idx = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW && idx < model_count) {
        model_metadata_t *meta = &model_array[idx];

        const char *name = (const char *)sqlite3_column_text(stmt, 0);
        const char *tag = (const char *)sqlite3_column_text(stmt, 1);
        const char *digest = (const char *)sqlite3_column_text(stmt, 2);
        const char *path = (const char *)sqlite3_column_text(stmt, 3);
        const char *quantization = (const char *)sqlite3_column_text(stmt, 6);
        const char *architecture = (const char *)sqlite3_column_text(stmt, 7);
        const char *license = (const char *)sqlite3_column_text(stmt, 8);
        const char *author = (const char *)sqlite3_column_text(stmt, 9);
        const char *description = (const char *)sqlite3_column_text(stmt, 12);
        const char *family = (const char *)sqlite3_column_text(stmt, 13);
        const char *format = (const char *)sqlite3_column_text(stmt, 14);
        const char *backend = (const char *)sqlite3_column_text(stmt, 15);

        meta->name = name ? strdup(name) : NULL;
        meta->tag = tag ? strdup(tag) : NULL;
        meta->digest = digest ? strdup(digest) : NULL;
        meta->path = path ? strdup(path) : NULL;
        meta->size = sqlite3_column_int64(stmt, 4);
        meta->parameters = sqlite3_column_int(stmt, 5);
        meta->quantization = quantization ? strdup(quantization) : NULL;
        meta->architecture = architecture ? strdup(architecture) : NULL;
        meta->license = license ? strdup(license) : NULL;
        meta->author = author ? strdup(author) : NULL;
        meta->created_at = sqlite3_column_int64(stmt, 10);
        meta->modified_at = sqlite3_column_int64(stmt, 11);
        meta->description = description ? strdup(description) : NULL;
        meta->family = family ? strdup(family) : NULL;
        meta->format = format ? strdup(format) : NULL;
        meta->backend = backend ? strdup(backend) : NULL;

        idx++;
    }

    sqlite3_finalize(stmt);
    pthread_mutex_unlock(&ctx->mutex);

    *models = model_array;
    *count = model_count;

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_search", pattern);
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Get registry statistics
 */
model_registry_result_t model_registry_stats(
    model_registry_context_t *ctx,
    size_t *total_models,
    uint64_t *total_size
) {
    if (!ctx || !ctx->initialized || !total_models || !total_size) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    const char *sql = "SELECT COUNT(*), SUM(size) FROM models;";
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    rc = sqlite3_step(stmt);
    if (rc != SQLITE_ROW) {
        sqlite3_finalize(stmt);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    *total_models = sqlite3_column_int64(stmt, 0);
    *total_size = sqlite3_column_int64(stmt, 1);

    sqlite3_finalize(stmt);
    pthread_mutex_unlock(&ctx->mutex);

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Validate model file integrity
 */
model_registry_result_t model_registry_validate(
    model_registry_context_t *ctx,
    const char *model_name,
    bool *is_valid
) {
    if (!ctx || !ctx->initialized || !model_name || !is_valid) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    /* Get model metadata */
    model_metadata_t *meta = NULL;
    model_registry_result_t result = model_registry_show(ctx, model_name, &meta);
    if (result != MODEL_REGISTRY_SUCCESS) {
        pthread_mutex_unlock(&ctx->mutex);
        return result;
    }

    /* Calculate current digest */
    unsigned char digest[32];
    char digest_str[65];
    result = calculate_digest(meta->path, digest);
    if (result != MODEL_REGISTRY_SUCCESS) {
        model_metadata_free(meta);
        pthread_mutex_unlock(&ctx->mutex);
        return result;
    }
    digest_to_hex(digest, digest_str);

    /* Compare with stored digest */
    *is_valid = (strcmp(digest_str, meta->digest) == 0);

    model_metadata_free(meta);
    pthread_mutex_unlock(&ctx->mutex);

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_validate", model_name);
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Get model file path
 */
model_registry_result_t model_registry_get_path(
    model_registry_context_t *ctx,
    const char *model_name,
    char **path
) {
    if (!ctx || !ctx->initialized || !model_name || !path) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    const char *sql = "SELECT path FROM models WHERE name = ? LIMIT 1;";
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    sqlite3_bind_text(stmt, 1, model_name, -1, SQLITE_STATIC);
    rc = sqlite3_step(stmt);

    if (rc != SQLITE_ROW) {
        sqlite3_finalize(stmt);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_NOT_FOUND;
    }

    *path = strdup((const char *)sqlite3_column_text(stmt, 0));
    sqlite3_finalize(stmt);
    pthread_mutex_unlock(&ctx->mutex);

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Free model metadata
 */
void model_metadata_free(model_metadata_t *metadata) {
    if (!metadata) return;

    if (metadata->name) { free(metadata->name); metadata->name = NULL; }
    if (metadata->tag) { free(metadata->tag); metadata->tag = NULL; }
    if (metadata->digest) { free(metadata->digest); metadata->digest = NULL; }
    if (metadata->path) { free(metadata->path); metadata->path = NULL; }
    if (metadata->quantization) { free(metadata->quantization); metadata->quantization = NULL; }
    if (metadata->architecture) { free(metadata->architecture); metadata->architecture = NULL; }
    if (metadata->license) { free(metadata->license); metadata->license = NULL; }
    if (metadata->author) { free(metadata->author); metadata->author = NULL; }
    if (metadata->description) { free(metadata->description); metadata->description = NULL; }
    if (metadata->family) { free(metadata->family); metadata->family = NULL; }
    if (metadata->format) { free(metadata->format); metadata->format = NULL; }
    if (metadata->backend) { free(metadata->backend); metadata->backend = NULL; }

    free(metadata);
}

/**
 * @brief Free array of model metadata
 */
void model_metadata_free_array(model_metadata_t *models, size_t count) {
    if (!models) return;

    for (size_t i = 0; i < count; i++) {
        free(models[i].name);
        free(models[i].tag);
        free(models[i].digest);
        free(models[i].path);
        free(models[i].quantization);
        free(models[i].architecture);
        free(models[i].license);
        free(models[i].author);
        free(models[i].description);
        free(models[i].family);
        free(models[i].format);
        free(models[i].backend);
    }

    free(models);
}

/**
 * @brief Mark model as loaded
 */
model_registry_result_t model_registry_mark_loaded(
    model_registry_context_t *ctx,
    const char *model_name
) {
    if (!ctx || !ctx->initialized || !model_name) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    const char *sql = "UPDATE models SET loaded = 1, modified_at = ? WHERE name = ?;";
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    uint64_t now = time(NULL);
    sqlite3_bind_int64(stmt, 1, now);
    sqlite3_bind_text(stmt, 2, model_name, -1, SQLITE_STATIC);

    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    pthread_mutex_unlock(&ctx->mutex);

    if (rc != SQLITE_DONE) {
        if (ctx->audit_enabled) {
            audit_log_auth_failure("model_registry_mark_loaded", model_name, "update failed");
        }
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_mark_loaded", model_name);
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Mark model as unloaded
 */
model_registry_result_t model_registry_mark_unloaded(
    model_registry_context_t *ctx,
    const char *model_name
) {
    if (!ctx || !ctx->initialized || !model_name) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    const char *sql = "UPDATE models SET loaded = 0, modified_at = ? WHERE name = ?;";
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    uint64_t now = time(NULL);
    sqlite3_bind_int64(stmt, 1, now);
    sqlite3_bind_text(stmt, 2, model_name, -1, SQLITE_STATIC);

    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    pthread_mutex_unlock(&ctx->mutex);

    if (rc != SQLITE_DONE) {
        if (ctx->audit_enabled) {
            audit_log_auth_failure("model_registry_mark_unloaded", model_name, "update failed");
        }
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_mark_unloaded", model_name);
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Get list of currently loaded models
 */
model_registry_result_t model_registry_list_loaded(
    model_registry_context_t *ctx,
    model_metadata_t **models,
    size_t *count
) {
    if (!ctx || !ctx->initialized || !models || !count) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

    pthread_mutex_lock(&ctx->mutex);

    const char *sql = "SELECT name, tag, digest, path, size, parameters, quantization, "
                     "architecture, license, author, created_at, modified_at, description, "
                     "family, format, backend FROM models WHERE loaded = 1;";
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(ctx->db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    /* Count loaded models */
    size_t loaded_count = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        loaded_count++;
    }
    sqlite3_reset(stmt);

    if (loaded_count == 0) {
        sqlite3_finalize(stmt);
        pthread_mutex_unlock(&ctx->mutex);
        *models = NULL;
        *count = 0;
        return MODEL_REGISTRY_SUCCESS;
    }

    /* Allocate array */
    model_metadata_t *loaded_models = (model_metadata_t *)calloc(loaded_count, sizeof(model_metadata_t));
    if (!loaded_models) {
        sqlite3_finalize(stmt);
        pthread_mutex_unlock(&ctx->mutex);
        return MODEL_REGISTRY_ERROR_DATABASE;
    }

    /* Fill array */
    size_t idx = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW && idx < loaded_count) {
        model_metadata_t *m = &loaded_models[idx++];
        
        m->name = strdup((const char *)sqlite3_column_text(stmt, 0));
        m->tag = strdup((const char *)sqlite3_column_text(stmt, 1));
        m->digest = strdup((const char *)sqlite3_column_text(stmt, 2));
        m->path = strdup((const char *)sqlite3_column_text(stmt, 3));
        m->size = sqlite3_column_int64(stmt, 4);
        m->parameters = sqlite3_column_int(stmt, 5);
        m->quantization = sqlite3_column_text(stmt, 6) ? strdup((const char *)sqlite3_column_text(stmt, 6)) : NULL;
        m->architecture = sqlite3_column_text(stmt, 7) ? strdup((const char *)sqlite3_column_text(stmt, 7)) : NULL;
        m->license = sqlite3_column_text(stmt, 8) ? strdup((const char *)sqlite3_column_text(stmt, 8)) : NULL;
        m->author = sqlite3_column_text(stmt, 9) ? strdup((const char *)sqlite3_column_text(stmt, 9)) : NULL;
        m->created_at = sqlite3_column_int64(stmt, 10);
        m->modified_at = sqlite3_column_int64(stmt, 11);
        m->description = sqlite3_column_text(stmt, 12) ? strdup((const char *)sqlite3_column_text(stmt, 12)) : NULL;
        m->family = sqlite3_column_text(stmt, 13) ? strdup((const char *)sqlite3_column_text(stmt, 13)) : NULL;
        m->format = sqlite3_column_text(stmt, 14) ? strdup((const char *)sqlite3_column_text(stmt, 14)) : NULL;
        m->backend = sqlite3_column_text(stmt, 15) ? strdup((const char *)sqlite3_column_text(stmt, 15)) : NULL;
    }

    sqlite3_finalize(stmt);
    pthread_mutex_unlock(&ctx->mutex);

    *models = loaded_models;
    *count = loaded_count;

    if (ctx->audit_enabled) {
        audit_log_auth_success("model_registry_list_loaded", "query");
    }

    return MODEL_REGISTRY_SUCCESS;
}

/**
 * @brief Convert result code to string
 */
const char *model_registry_result_to_string(model_registry_result_t result) {
    switch (result) {
        case MODEL_REGISTRY_SUCCESS: return "success";
        case MODEL_REGISTRY_ERROR_INVALID_PATH: return "invalid path";
        case MODEL_REGISTRY_ERROR_DATABASE: return "database error";
        case MODEL_REGISTRY_ERROR_EXISTS: return "already exists";
        case MODEL_REGISTRY_ERROR_NOT_FOUND: return "not found";
        case MODEL_REGISTRY_ERROR_IO: return "IO error";
        case MODEL_REGISTRY_ERROR_PERMISSION: return "permission denied";
        case MODEL_REGISTRY_ERROR_CORRUPTED: return "corrupted";
        case MODEL_REGISTRY_ERROR_NETWORK: return "network error";
        case MODEL_REGISTRY_ERROR_VALIDATION: return "validation error";
        case MODEL_REGISTRY_ERROR_LOCKED: return "locked";
        default: return "unknown error";
    }
}
