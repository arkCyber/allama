#ifndef MODEL_REGISTRY_H
#define MODEL_REGISTRY_H

/**
 * @file model-registry.h
 * @brief Model registry and management system for allama
 * 
 * This module provides functionality for managing LLM models including:
 * - Local model registry (SQLite-based metadata storage)
 * - Model pull/push operations
 * - Model listing and search
 * - Model metadata management
 * - Model versioning with tags
 * 
 * Aerospace-Level Security Features:
 * - Audit logging for all registry operations
 * - Thread-safe operations with mutex protection
 * - Secure model file validation
 * - ACSL annotations for formal verification
 */

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Model registry initialization result codes
 */
typedef enum {
    MODEL_REGISTRY_SUCCESS = 0,
    MODEL_REGISTRY_ERROR_INVALID_PATH = -1,
    MODEL_REGISTRY_ERROR_DATABASE = -2,
    MODEL_REGISTRY_ERROR_EXISTS = -3,
    MODEL_REGISTRY_ERROR_NOT_FOUND = -4,
    MODEL_REGISTRY_ERROR_IO = -5,
    MODEL_REGISTRY_ERROR_PERMISSION = -6,
    MODEL_REGISTRY_ERROR_CORRUPTED = -7,
    MODEL_REGISTRY_ERROR_NETWORK = -8,
    MODEL_REGISTRY_ERROR_VALIDATION = -9,
    MODEL_REGISTRY_ERROR_LOCKED = -10,
    MODEL_REGISTRY_ERROR_INVALID_ARGS = -11
} model_registry_result_t;

/**
 * @brief Model metadata structure
 */
typedef struct {
    char *name;              ///< Model name (e.g., "llama3:latest")
    char *tag;               ///< Model tag (e.g., "latest", "7b")
    char *digest;            ///< SHA256 digest of model file
    char *path;              ///< Local file path
    uint64_t size;           ///< File size in bytes
    uint32_t parameters;     ///< Number of parameters
    char *quantization;      ///< Quantization type (e.g., "Q4_K_M")
    char *architecture;      ///< Model architecture (e.g., "llama")
    char *license;           ///< Model license
    char *author;            ///< Model author
    uint64_t created_at;     ///< Creation timestamp (Unix epoch)
    uint64_t modified_at;    ///< Modification timestamp (Unix epoch)
    char *description;       ///< Model description
    char *family;            ///< Model family
    char *format;            ///< Model format (e.g., "gguf")
    char *backend;           ///< Preferred backend
} model_metadata_t;

/**
 * @brief Model registry configuration
 */
typedef struct {
    char *registry_path;     ///< Path to registry database (NULL for default)
    char *models_path;       ///< Path to models directory (NULL for default)
    char *remote_registry_url; ///< Remote registry base URL (NULL for default Hugging Face)
    uint32_t max_models;     ///< Maximum number of models
    uint64_t max_storage;    ///< Maximum storage in bytes
    bool enable_audit;       ///< Enable audit logging
    bool enable_validation;  ///< Enable model validation
} model_registry_config_t;

/**
 * @brief Model registry context
 */
typedef struct model_registry_context model_registry_context_t;

/**
 * @brief Initialize the model registry
 * 
 * @param config Registry configuration
 * @param ctx Output registry context
 * @return model_registry_result_t Result code
 * 
 * @post On success, registry context is initialized and ready for use
 * @post On failure, ctx is set to NULL
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_init(
    const model_registry_config_t *config,
    model_registry_context_t **ctx
) /*@ ensures \result == MODEL_REGISTRY_SUCCESS ==> \result != NULL */;

/**
 * @brief Shutdown the model registry
 * 
 * @param ctx Registry context
 * @return model_registry_result_t Result code
 * 
 * @post Registry context is freed and all resources released
 * 
 * @threadsafe Yes (uses internal mutex) */
model_registry_result_t model_registry_shutdown(
    model_registry_context_t *ctx
);

/**
 * @brief Pull a model from remote registry
 * 
 * @param ctx Registry context
 * @param model_name Model name (e.g., "llama3:latest")
 * @param progress_callback Optional progress callback
 * @param user_data User data for callback
 * @return model_registry_result_t Result code
 * 
 * @post On success, model is downloaded and registered
 * @post On failure, no changes to registry
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_pull(
    model_registry_context_t *ctx,
    const char *model_name,
    void (*progress_callback)(const char *model, float progress, void *user_data),
    void *user_data
);

/**
 * @brief Pull a model from remote registry with custom download URL
 * 
 * @param ctx Registry context
 * @param model_name Model name (e.g., "llama3:latest")
 * @param download_url Custom download URL (optional, can be NULL)
 * @param progress_callback Optional progress callback
 * @param user_data User data for callback
 * @return model_registry_result_t Result code
 * 
 * @post On success, model is downloaded and registered
 * @post On failure, no changes to registry
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_pull_with_url(
    model_registry_context_t *ctx,
    const char *model_name,
    const char *download_url,
    void (*progress_callback)(const char *model, float progress, void *user_data),
    void *user_data
);

/**
 * @brief List all registered models
 * 
 * @param ctx Registry context
 * @param models Output array of model metadata
 * @param count Output number of models
 * @return model_registry_result_t Result code
 * 
 * @post On success, models array contains all registered models
 * @post Caller is responsible for freeing models array
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_list(
    model_registry_context_t *ctx,
    model_metadata_t **models,
    size_t *count
);

/**
 * @brief Show detailed information about a model
 * 
 * @param ctx Registry context
 * @param model_name Model name
 * @param metadata Output model metadata
 * @return model_registry_result_t Result code
 * 
 * @post On success, metadata contains model details
 * @post Caller is responsible for freeing metadata
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_show(
    model_registry_context_t *ctx,
    const char *model_name,
    model_metadata_t **metadata
);

/**
 * @brief Remove a model from the registry
 * 
 * @param ctx Registry context
 * @param model_name Model name
 * @param force Force removal even if model is in use
 * @return model_registry_result_t Result code
 * 
 * @post On success, model is removed from registry and disk
 * @post On failure, no changes to registry
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_remove(
    model_registry_context_t *ctx,
    const char *model_name,
    bool force
);

/**
 * @brief Copy a model to a new name
 * 
 * @param ctx Registry context
 * @param src_name Source model name
 * @param dst_name Destination model name
 * @return model_registry_result_t Result code
 * 
 * @post On success, model is copied with new name
 * @post On failure, no changes to registry
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_copy(
    model_registry_context_t *ctx,
    const char *src_name,
    const char *dst_name
);

/**
 * @brief Add a local model to the registry
 * 
 * @param ctx Registry context
 * @param model_name Model name
 * @param file_path Path to model file
 * @return model_registry_result_t Result code
 * 
 * @post On success, model is registered
 * @post On failure, no changes to registry
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_add(
    model_registry_context_t *ctx,
    const char *model_name,
    const char *file_path
);

/**
 * @brief Search models by name pattern
 * 
 * @param ctx Registry context
 * @param pattern Search pattern (supports wildcards)
 * @param models Output array of matching models
 * @param count Output number of matches
 * @return model_registry_result_t Result code
 * 
 * @post On success, models array contains matching models
 * @post Caller is responsible for freeing models array
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_search(
    model_registry_context_t *ctx,
    const char *pattern,
    model_metadata_t **models,
    size_t *count
);

/**
 * @brief Mark model as loaded
 * 
 * @param ctx Registry context
 * @param model_name Model name
 * @return model_registry_result_t Result code
 * 
 * @post On success, model load status is updated
 * @post On failure, no changes to registry
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_mark_loaded(
    model_registry_context_t *ctx,
    const char *model_name
);

/**
 * @brief Mark model as unloaded
 * 
 * @param ctx Registry context
 * @param model_name Model name
 * @return model_registry_result_t Result code
 * 
 * @post On success, model load status is updated
 * @post On failure, no changes to registry
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_mark_unloaded(
    model_registry_context_t *ctx,
    const char *model_name
);

/**
 * @brief Get list of currently loaded models
 * 
 * @param ctx Registry context
 * @param models Output array of loaded models
 * @param count Output number of loaded models
 * @return model_registry_result_t Result code
 * 
 * @post On success, models array contains loaded models
 * @post Caller is responsible for freeing models array
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_list_loaded(
    model_registry_context_t *ctx,
    model_metadata_t **models,
    size_t *count
);

/**
 * @brief Get registry statistics
 * 
 * @param ctx Registry context
 * @param total_models Output total number of models
 * @param total_size Output total storage used
 * @return model_registry_result_t Result code
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_stats(
    model_registry_context_t *ctx,
    size_t *total_models,
    uint64_t *total_size
);

/**
 * @brief Validate model file integrity
 * 
 * @param ctx Registry context
 * @param model_name Model name
 * @param is_valid Output validation result
 * @return model_registry_result_t Result code
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_validate(
    model_registry_context_t *ctx,
    const char *model_name,
    bool *is_valid
);

/**
 * @brief Get model file path
 * 
 * @param ctx Registry context
 * @param model_name Model name
 * @param path Output file path
 * @return model_registry_result_t Result code
 * 
 * @post On success, path contains full path to model file
 * @post Caller is responsible for freeing path
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_get_path(
    model_registry_context_t *ctx,
    const char *model_name,
    char **path
);

/**
 * @brief Free model metadata
 * 
 * @param metadata Model metadata to free
 */
void model_metadata_free(model_metadata_t *metadata);

/**
 * @brief Free array of model metadata
 * 
 * @param models Array of model metadata
 * @param count Number of models
 */
void model_metadata_free_array(model_metadata_t *models, size_t count);

/**
 * @brief Add a tag to a model
 * 
 * @param ctx Registry context
 * @param model_name Model name
 * @param tag Tag to add
 * @return model_registry_result_t Result code
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_add_tag(
    model_registry_context_t *ctx,
    const char *model_name,
    const char *tag
);

/**
 * @brief Remove a tag from a model
 * 
 * @param ctx Registry context
 * @param model_name Model name
 * @param tag Tag to remove
 * @return model_registry_result_t Result code
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_remove_tag(
    model_registry_context_t *ctx,
    const char *model_name,
    const char *tag
);

/**
 * @brief List all tags for a model
 * 
 * @param ctx Registry context
 * @param model_name Model name
 * @param tags Output array of tags
 * @param count Output number of tags
 * @return model_registry_result_t Result code
 * 
 * @post On success, tags array contains all tags for the model
 * @post Caller is responsible for freeing tags array
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_registry_result_t model_registry_list_tags(
    model_registry_context_t *ctx,
    const char *model_name,
    char ***tags,
    size_t *count
);

/**
 * @brief Free array of tags
 * 
 * @param tags Array of tags
 * @param count Number of tags
 */
void model_registry_free_tags(char **tags, size_t count);

/**
 * @brief Convert result code to string
 * 
 * @param result Result code
 * @return const char* String representation
 */
const char *model_registry_result_to_string(model_registry_result_t result);

#ifdef __cplusplus
}
#endif

#endif /* MODEL_REGISTRY_H */
