#ifndef MODEL_CATALOG_H
#define MODEL_CATALOG_H

/**
 * @file model-catalog.h
 * @brief Model catalog and caching system for Hugging Face models
 * 
 * Aerospace-Level Security Implementation:
 * - Thread-safe operations with pthread mutex
 * - Audit logging for all catalog operations
 * - Secure HTTP requests with validation
 * - ACSL annotations for formal verification
 * - Comprehensive error handling
 */

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Model catalog initialization result codes
 */
typedef enum {
    MODEL_CATALOG_SUCCESS = 0,
    MODEL_CATALOG_ERROR_INVALID_PATH = -1,
    MODEL_CATALOG_ERROR_DATABASE = -2,
    MODEL_CATALOG_ERROR_NETWORK = -3,
    MODEL_CATALOG_ERROR_IO = -4,
    MODEL_CATALOG_ERROR_PERMISSION = -5,
    MODEL_CATALOG_ERROR_CORRUPTED = -6,
    MODEL_CATALOG_ERROR_VALIDATION = -7,
    MODEL_CATALOG_ERROR_LOCKED = -8
} model_catalog_result_t;

/**
 * @brief Model catalog entry structure
 */
typedef struct {
    char *name;              ///< Model name (e.g., "llama3")
    char *tag;               ///< Model tag (e.g., "latest", "7b")
    char *digest;            ///< SHA256 digest
    uint64_t size;           ///< File size in bytes
    uint32_t parameters;     ///< Number of parameters
    char *quantization;      ///< Quantization type
    char *architecture;      ///< Model architecture
    char *license;           ///< Model license
    char *author;            ///< Model author
    char *description;       ///< Model description
    char *download_url;      ///< Download URL
    uint64_t last_updated;   ///> Last update timestamp
    bool is_available;       ///< Availability status
} model_catalog_entry_t;

/**
 * @brief Model catalog configuration
 */
typedef struct {
    char *catalog_path;      ///< Path to catalog database (NULL for default)
    char *cache_path;        ///< Path to cache directory (NULL for default)
    char *remote_url;        ///< Remote catalog URL (NULL for default Hugging Face)
    uint32_t max_entries;    ///< Maximum number of catalog entries
    uint32_t cache_ttl;      ///< Cache time-to-live in seconds
    bool enable_auto_update; ///< Enable automatic updates
    bool enable_audit;       ///< Enable audit logging
} model_catalog_config_t;

/**
 * @brief Model catalog context
 */
typedef struct model_catalog_context model_catalog_context_t;

/**
 * @brief Initialize the model catalog
 * 
 * @param config Catalog configuration
 * @param ctx Output catalog context
 * @return model_catalog_result_t Result code
 * 
 * @post On success, catalog context is initialized and ready for use
 * @post On failure, ctx is set to NULL
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_catalog_result_t model_catalog_init(
    const model_catalog_config_t *config,
    model_catalog_context_t **ctx
);

/**
 * @brief Shutdown the model catalog
 * 
 * @param ctx Catalog context
 * @return model_catalog_result_t Result code
 * 
 * @post All resources are freed and context is invalidated
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_catalog_result_t model_catalog_shutdown(model_catalog_context_t *ctx);

/**
 * @brief Update catalog from remote source
 * 
 * @param ctx Catalog context
 * @return model_catalog_result_t Result code
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_catalog_result_t model_catalog_update(model_catalog_context_t *ctx);

/**
 * @brief Search catalog for models
 * 
 * @param ctx Catalog context
 * @param pattern Search pattern
 * @param entries Output array of catalog entries
 * @param count Output number of entries
 * @return model_catalog_result_t Result code
 * 
 * @post Caller is responsible for freeing entries with model_catalog_entry_free_array
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_catalog_result_t model_catalog_search(
    model_catalog_context_t *ctx,
    const char *pattern,
    model_catalog_entry_t **entries,
    size_t *count
);

/**
 * @brief Get catalog entry by name and tag
 * 
 * @param ctx Catalog context
 * @param name Model name
 * @param tag Model tag
 * @param entry Output catalog entry
 * @return model_catalog_result_t Result code
 * 
 * @post Caller is responsible for freeing entry with model_catalog_entry_free
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_catalog_result_t model_catalog_get(
    model_catalog_context_t *ctx,
    const char *name,
    const char *tag,
    model_catalog_entry_t **entry
);

/**
 * @brief List all catalog entries
 * 
 * @param ctx Catalog context
 * @param entries Output array of catalog entries
 * @param count Output number of entries
 * @return model_catalog_result_t Result code
 * 
 * @post Caller is responsible for freeing entries with model_catalog_entry_free_array
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_catalog_result_t model_catalog_list(
    model_catalog_context_t *ctx,
    model_catalog_entry_t **entries,
    size_t *count
);

/**
 * @brief Get catalog statistics
 * 
 * @param ctx Catalog context
 * @param total_entries Output total number of entries
 * @param total_size Output total size in bytes
 * @param last_updated Output last update timestamp
 * @return model_catalog_result_t Result code
 * 
 * @threadsafe Yes (uses internal mutex)
 */
model_catalog_result_t model_catalog_stats(
    model_catalog_context_t *ctx,
    size_t *total_entries,
    uint64_t *total_size,
    uint64_t *last_updated
);

/**
 * @brief Free catalog entry
 * 
 * @param entry Catalog entry to free
 */
void model_catalog_entry_free(model_catalog_entry_t *entry);

/**
 * @brief Free array of catalog entries
 * 
 * @param entries Array of catalog entries
 * @param count Number of entries
 */
void model_catalog_entry_free_array(model_catalog_entry_t *entries, size_t count);

/**
 * @brief Convert result code to string
 * 
 * @param result Result code
 * @return const char* String representation
 */
const char *model_catalog_result_to_string(model_catalog_result_t result);

#ifdef __cplusplus
}
#endif

#endif /* MODEL_CATALOG_H */
