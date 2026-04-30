#ifndef MODELFILE_H
#define MODELFILE_H

/**
 * @file modelfile.h
 * @brief Modelfile DSL parser for allama
 * 
 * This module provides functionality for parsing and validating Modelfile DSL
 * for custom model creation, following aerospace-level security standards.
 * 
 * Aerospace-Level Security Features:
 * - Input validation and sanitization
 * - Path traversal prevention
 * - Resource limit enforcement
 * - Audit logging for all operations
 * - ACSL annotations for formal verification
 * - Thread-safe operations
 * - Comprehensive error handling
 */

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Modelfile directive types
 */
typedef enum {
    MODELFILE_DIRECTIVE_FROM = 0,
    MODELFILE_DIRECTIVE_PARAMETER,
    MODELFILE_DIRECTIVE_LICENSE,
    MODELFILE_DIRECTIVE_TEMPLATE,
    MODELFILE_DIRECTIVE_ADAPTER,
    MODELFILE_DIRECTIVE_QUANTIZE,
    MODELFILE_DIRECTIVE_SECURITY,
    MODELFILE_DIRECTIVE_RESOURCE,
    MODELFILE_DIRECTIVE_METADATA,
    MODELFILE_DIRECTIVE_MESSAGE,
    MODELFILE_DIRECTIVE_SYSTEM,
    MODELFILE_DIRECTIVE_UNKNOWN
} modelfile_directive_type_t;

/**
 * @brief Modelfile parsing result codes
 */
typedef enum {
    MODELFILE_SUCCESS = 0,
    MODELFILE_ERROR_INVALID_SYNTAX = -1,
    MODELFILE_ERROR_INVALID_DIRECTIVE = -2,
    MODELFILE_ERROR_INVALID_VALUE = -3,
    MODELFILE_ERROR_IO = -4,
    MODELFILE_ERROR_MEMORY = -5,
    MODELFILE_ERROR_VALIDATION = -6,
    MODELFILE_ERROR_SECURITY = -7,
    MODELFILE_ERROR_RESOURCE = -8,
    MODELFILE_ERROR_PARSE = -9,
    MODELFILE_ERROR_NOT_FOUND = -10
} modelfile_result_t;

/**
 * @brief Security policy structure
 */
typedef struct {
    bool audit_enabled;
    bool rate_limit_enabled;
    uint32_t rate_limit_requests_per_minute;
    uint32_t rate_limit_tokens_per_minute;
    bool network_isolation_enabled;
    char *allowed_hosts;
    bool file_sandbox_enabled;
    char *allowed_directories;
    uint64_t max_file_size;
    bool gpu_isolation_enabled;
    uint64_t max_gpu_memory;
    bool anomaly_detection_enabled;
    char *audit_log_path;
} modelfile_security_policy_t;

/**
 * @brief Resource constraints structure
 */
typedef struct {
    uint64_t max_memory;
    uint32_t max_cpu_cores;
    uint64_t max_gpu_memory;
    uint64_t max_disk_space;
    uint32_t max_concurrent_requests;
} modelfile_resource_constraints_t;

/**
 * @brief Modelfile directive structure
 */
typedef struct modelfile_directive {
    modelfile_directive_type_t type;
    char *name;
    char *value;
    size_t line_number;
    size_t column_number;
    struct modelfile_directive *next;
} modelfile_directive_t;

/**
 * @brief Modelfile structure
 */
typedef struct modelfile {
    char *from;
    char *license;
    char *template;
    char *system;
    char *quantize;
    modelfile_security_policy_t security;
    modelfile_resource_constraints_t resources;
    modelfile_directive_t *directives;
    modelfile_directive_t *parameters;
    modelfile_directive_t *adapters;
    modelfile_directive_t *messages;
    modelfile_directive_t *metadata;
    size_t directive_count;
    bool validated;
} modelfile_t;

/**
 * @brief Modelfile parser context
 */
typedef struct modelfile_parser_context modelfile_parser_context_t;

/**
 * @brief Parse error structure
 */
typedef struct {
    size_t line_number;
    size_t column_number;
    modelfile_result_t error_code;
    char *error_message;
    char *suggested_fix;
} modelfile_parse_error_t;

/**
 * @brief Initialize the Modelfile parser
 * 
 * @param ctx Output parser context
 * @return modelfile_result_t Result code
 * 
 * @post On success, parser context is initialized and ready for use
 * @post On failure, ctx is set to NULL
 * 
 * @threadsafe Yes (uses internal mutex)
 */
modelfile_result_t modelfile_parser_init(
    modelfile_parser_context_t **ctx
) /*@ ensures \result == MODELFILE_SUCCESS ==> \result != NULL */;

/**
 * @brief Shutdown the Modelfile parser
 * 
 * @param ctx Parser context
 * @return modelfile_result_t Result code
 * 
 * @post Parser context is freed and all resources released
 * 
 * @threadsafe Yes (uses internal mutex)
 */
modelfile_result_t modelfile_parser_shutdown(
    modelfile_parser_context_t *ctx
);

/**
 * @brief Parse a Modelfile from string
 * 
 * @param ctx Parser context
 * @param content Modelfile content
 * @param modelfile Output parsed Modelfile
 * @return modelfile_result_t Result code
 * 
 * @post On success, modelfile contains parsed directives
 * @post On failure, modelfile is set to NULL
 * 
 * @threadsafe Yes (uses internal mutex)
 */
modelfile_result_t modelfile_parse_string(
    modelfile_parser_context_t *ctx,
    const char *content,
    modelfile_t **modelfile
);

/**
 * @brief Parse a Modelfile from file
 * 
 * @param ctx Parser context
 * @param file_path Path to Modelfile
 * @param modelfile Output parsed Modelfile
 * @return modelfile_result_t Result code
 * 
 * @post On success, modelfile contains parsed directives
 * @post On failure, modelfile is set to NULL
 * 
 * @threadsafe Yes (uses internal mutex)
 */
modelfile_result_t modelfile_parse_file(
    modelfile_parser_context_t *ctx,
    const char *file_path,
    modelfile_t **modelfile
);

/**
 * @brief Validate a parsed Modelfile
 * 
 * @param ctx Parser context
 * @param modelfile Modelfile to validate
 * @param error Output parse error (if validation fails)
 * @return modelfile_result_t Result code
 * 
 * @post On success, modelfile is marked as validated
 * @post On failure, error contains validation details
 * 
 * @threadsafe Yes (uses internal mutex)
 */
modelfile_result_t modelfile_validate(
    modelfile_parser_context_t *ctx,
    modelfile_t *modelfile,
    modelfile_parse_error_t **error
);

/**
 * @brief Free a Modelfile structure
 * 
 * @param modelfile Modelfile to free
 */
void modelfile_free(modelfile_t *modelfile);

/**
 * @brief Free a parse error structure
 * 
 * @param error Parse error to free
 */
void modelfile_parse_error_free(modelfile_parse_error_t *error);

/**
 * @brief Get directive value by name
 * 
 * @param modelfile Modelfile to search
 * @param name Directive name
 * @param value Output directive value
 * @return modelfile_result_t Result code
 * 
 * @post On success, value contains the directive value
 * @post Caller is responsible for freeing value
 * 
 * @threadsafe Yes (read-only operation)
 */
modelfile_result_t modelfile_get_directive(
    const modelfile_t *modelfile,
    const char *name,
    char **value
);

/**
 * @brief Get parameter value by name
 * 
 * @param modelfile Modelfile to search
 * @param name Parameter name
 * @param value Output parameter value
 * @return modelfile_result_t Result code
 * 
 * @post On success, value contains the parameter value
 * @post Caller is responsible for freeing value
 * 
 * @threadsafe Yes (read-only operation)
 */
modelfile_result_t modelfile_get_parameter(
    const modelfile_t *modelfile,
    const char *name,
    char **value
);

/**
 * @brief Convert result code to string
 * 
 * @param result Result code
 * @return const char* String representation
 */
const char *modelfile_result_to_string(modelfile_result_t result);

/**
 * @brief Convert directive type to string
 * 
 * @param type Directive type
 * @return const char* String representation
 */
const char *modelfile_directive_type_to_string(modelfile_directive_type_t type);

/**
 * @brief Get Modelfile version
 * 
 * @return const char* Version string
 */
const char *modelfile_get_version(void);

#ifdef __cplusplus
}
#endif

#endif /* MODELFILE_H */
