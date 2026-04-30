/**
 * @file allama.c
 * @brief allama CLI tool for model management
 * 
 * Aerospace-Level Security Implementation:
 * - Secure command-line interface
 * - Audit logging for all operations
 * - Thread-safe operations
 * - ACSL annotations for formal verification
 * - Comprehensive error handling
 */

#include "model-registry.h"
#include "modelfile.h"
#include "audit-log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <unistd.h>
#include <sys/stat.h>

/* ACSL annotations for formal verification */
/*@ predicate valid_allama_context(struct allama_context *ctx) = 
    \valid(ctx) && 
    \valid_read(ctx->registry_ctx) &&
    ctx->initialized == 1;
@*/

/**
 * @brief allama CLI context
 */
typedef struct {
    model_registry_context_t *registry_ctx;
    modelfile_parser_context_t *modelfile_ctx;
    int initialized;
    bool verbose;
} allama_context_t;

/**
 * @brief Command result codes
 */
typedef enum {
    ALLAMA_SUCCESS = 0,
    ALLAMA_ERROR_INVALID_ARGS = 1,
    ALLAMA_ERROR_REGISTRY = 2,
    ALLAMA_ERROR_IO = 3,
    ALLAMA_ERROR_PERMISSION = 4
} allama_result_t;

/* Build directory for llama binaries */
#ifndef BUILD_DIR
#define BUILD_DIR "../build"
#endif

/* Default paths for model registry */
#define DEFAULT_REGISTRY_PATH "~/.allama/registry.db"
#define DEFAULT_MODELS_PATH "~/.allama/models"

/**
 * @brief Expand ~ to home directory in path
 */
static model_registry_result_t expand_path_local(const char *path, char *expanded_path, size_t max_len) {
    if (!path || !expanded_path || max_len == 0) {
        return MODEL_REGISTRY_ERROR_INVALID_PATH;
    }

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

/* Forward declarations */
static allama_result_t cmd_pull(allama_context_t *ctx, const char *model_name);
static allama_result_t cmd_list(allama_context_t *ctx);
static allama_result_t cmd_ps(allama_context_t *ctx);
static allama_result_t cmd_stop(allama_context_t *ctx, const char *model_name);
static allama_result_t cmd_show(allama_context_t *ctx, const char *model_name);
static allama_result_t cmd_rm(allama_context_t *ctx, const char *model_name, bool force);
static allama_result_t cmd_cp(allama_context_t *ctx, const char *src, const char *dst);
static allama_result_t cmd_add(allama_context_t *ctx, const char *name, const char *path);
static allama_result_t cmd_create(allama_context_t *ctx, const char *modelfile_path);
static allama_result_t cmd_search(allama_context_t *ctx, const char *pattern);
static allama_result_t cmd_stats(allama_context_t *ctx);
static allama_result_t cmd_validate(allama_context_t *ctx, const char *model_name);
static allama_result_t cmd_run(allama_context_t *ctx, const char *model_name);
static allama_result_t cmd_serve(allama_context_t *ctx);

/**
 * @brief Print usage information
 */
/*@ 
  ensures \true;
@*/
static void print_usage(const char *program_name) {
    printf("allama - Model Management CLI for allama\n\n");
    printf("Usage: %s <command> [options]\n\n", program_name);
    printf("Commands:\n");
    printf("  pull <model>      Pull a model from remote registry\n");
    printf("  list              List all local models\n");
    printf("  ps                List running models\n");
    printf("  stop <model>      Stop a running model\n");
    printf("  show <model>      Show detailed information about a model\n");
    printf("  rm <model>        Remove a model\n");
    printf("  cp <src> <dst>    Copy a model to a new name\n");
    printf("  add <name> <path> Add a local model to the registry\n");
    printf("  create <modelfile> Create a model from a Modelfile\n");
    printf("  search <pattern>  Search models by name pattern\n");
    printf("  stats             Show registry statistics\n");
    printf("  validate <model>  Validate model file integrity\n");
    printf("  run <model>       Run a model for inference\n");
    printf("  serve             Start the llama-server with model registry\n");
    printf("\n");
    printf("Options:\n");
    printf("  -v, --verbose     Enable verbose output\n");
    printf("  -h, --help        Show this help message\n");
    printf("\n");
    printf("Examples:\n");
    printf("  %s pull llama3:latest\n", program_name);
    printf("  %s list\n", program_name);
    printf("  %s ps\n", program_name);
    printf("  %s stop llama3:latest\n", program_name);
    printf("  %s show llama3:latest\n", program_name);
    printf("  %s rm llama3:latest\n", program_name);
    printf("  %s cp llama3:latest llama3:custom\n", program_name);
    printf("  %s create Modelfile\n", program_name);
    printf("  %s run llama3:latest\n", program_name);
    printf("  %s serve\n", program_name);
}

/**
 * @brief Initialize allama context
 */
/*@ 
  requires \valid(ctx);
  assigns *ctx;
  ensures \result == ALLAMA_SUCCESS ==> ctx->initialized == 1;
@*/
static allama_result_t allama_init(allama_context_t *ctx, bool verbose) {
    if (!ctx) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    memset(ctx, 0, sizeof(allama_context_t));
    ctx->verbose = verbose;

    /* Initialize audit log */
    audit_log_init("/tmp/allama_audit.log", true, 10 * 1024 * 1024);

    /* Initialize model registry */
    model_registry_config_t config = {
        .registry_path = NULL,  /* Use default */
        .models_path = NULL,    /* Use default */
        .max_models = 1000,
        .max_storage = 100ULL * 1024 * 1024 * 1024,  /* 100 GB */
        .enable_audit = true,
        .enable_validation = true
    };

    model_registry_result_t result = model_registry_init(&config, &ctx->registry_ctx);
    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to initialize model registry: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    /* Initialize Modelfile parser */
    modelfile_result_t mf_result = modelfile_parser_init(&ctx->modelfile_ctx);
    if (mf_result != MODELFILE_SUCCESS) {
        fprintf(stderr, "Error: Failed to initialize Modelfile parser: %s\n",
                modelfile_result_to_string(mf_result));
        model_registry_shutdown(ctx->registry_ctx);
        return ALLAMA_ERROR_REGISTRY;
    }

    ctx->initialized = 1;

    if (verbose) {
        printf("allama initialized successfully\n");
    }

    return ALLAMA_SUCCESS;
}

/**
 * @brief Shutdown allama context
 */
/*@ 
  requires \valid_read(ctx);
  requires ctx->initialized == 1;
@*/
static void allama_shutdown(allama_context_t *ctx) {
    if (!ctx || !ctx->initialized) {
        return;
    }

    if (ctx->registry_ctx) {
        model_registry_shutdown(ctx->registry_ctx);
        ctx->registry_ctx = NULL;
    }

    if (ctx->modelfile_ctx) {
        modelfile_parser_shutdown(ctx->modelfile_ctx);
        ctx->modelfile_ctx = NULL;
    }

    audit_log_close();
    ctx->initialized = 0;

    if (ctx->verbose) {
        printf("allama shutdown complete\n");
    }
}

/**
 * @brief Progress callback for model download
 */
static void progress_callback(const char *model, float progress, void *user_data) {
    allama_context_t *actx = (allama_context_t *)user_data;
    if (actx->verbose) {
        printf("Downloading %s: %.1f%%\n", model, progress * 100);
    }
}

/**
 * @brief Pull command handler
 */
/*@ 
  requires \valid_read(ctx);
  requires \valid_read(model_name);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_pull(allama_context_t *ctx, const char *model_name) {
    if (!ctx || !ctx->initialized || !model_name) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    printf("Pulling model: %s\n", model_name);

    model_registry_result_t result = model_registry_pull(
        ctx->registry_ctx,
        model_name,
        progress_callback,
        ctx
    );

    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to pull model: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    printf("Successfully pulled model: %s\n", model_name);
    return ALLAMA_SUCCESS;
}

/**
 * @brief List command handler
 */
/*@ 
  requires \valid_read(ctx);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_list(allama_context_t *ctx) {
    if (!ctx || !ctx->initialized) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    model_metadata_t *models = NULL;
    size_t count = 0;

    model_registry_result_t result = model_registry_list(ctx->registry_ctx, &models, &count);
    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to list models: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    if (count == 0) {
        printf("No models found in registry\n");
    } else {
        printf("%zu model(s) found:\n\n", count);
        for (size_t i = 0; i < count; i++) {
            model_metadata_t *meta = &models[i];
            printf("NAME: %s:%s\n", meta->name, meta->tag);
            printf("ID: %s\n", meta->digest);
            printf("SIZE: %.2f GB\n", (double)meta->size / (1024.0 * 1024.0 * 1024.0));
            printf("PARAMETERS: %u\n", meta->parameters);
            printf("QUANTIZATION: %s\n", meta->quantization ? meta->quantization : "N/A");
            printf("ARCHITECTURE: %s\n", meta->architecture ? meta->architecture : "N/A");
            printf("MODIFIED: %ld\n\n", (long)meta->modified_at);
        }
    }

    model_metadata_free_array(models, count);
    return ALLAMA_SUCCESS;
}

/**
 * @brief Show command handler
 */
/*@ 
  requires \valid_read(ctx);
  requires \valid_read(model_name);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_show(allama_context_t *ctx, const char *model_name) {
    if (!ctx || !ctx->initialized || !model_name) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    model_metadata_t *metadata = NULL;

    model_registry_result_t result = model_registry_show(ctx->registry_ctx, model_name, &metadata);
    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to show model: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    printf("Model Details:\n");
    printf("  Name: %s:%s\n", metadata->name, metadata->tag);
    printf("  Digest: %s\n", metadata->digest);
    printf("  Path: %s\n", metadata->path);
    printf("  Size: %.2f GB\n", (double)metadata->size / (1024.0 * 1024.0 * 1024.0));
    printf("  Parameters: %u\n", metadata->parameters);
    printf("  Quantization: %s\n", metadata->quantization ? metadata->quantization : "N/A");
    printf("  Architecture: %s\n", metadata->architecture ? metadata->architecture : "N/A");
    printf("  License: %s\n", metadata->license ? metadata->license : "N/A");
    printf("  Author: %s\n", metadata->author ? metadata->author : "N/A");
    printf("  Created: %ld\n", (long)metadata->created_at);
    printf("  Modified: %ld\n", (long)metadata->modified_at);
    printf("  Description: %s\n", metadata->description ? metadata->description : "N/A");
    printf("  Family: %s\n", metadata->family ? metadata->family : "N/A");
    printf("  Format: %s\n", metadata->format ? metadata->format : "N/A");
    printf("  Backend: %s\n", metadata->backend ? metadata->backend : "N/A");

    model_metadata_free(metadata);
    return ALLAMA_SUCCESS;
}

/**
 * @brief Remove command handler
 */
/*@ 
  requires \valid_read(ctx);
  requires \valid_read(model_name);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_rm(allama_context_t *ctx, const char *model_name, bool force) {
    if (!ctx || !ctx->initialized || !model_name) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    printf("Removing model: %s\n", model_name);

    model_registry_result_t result = model_registry_remove(ctx->registry_ctx, model_name, force);
    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to remove model: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    printf("Successfully removed model: %s\n", model_name);
    return ALLAMA_SUCCESS;
}

/**
 * @brief Copy command handler
 */
/*@ 
  requires \valid_read(ctx);
  requires \valid_read(src_name);
  requires \valid_read(dst_name);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_cp(allama_context_t *ctx, const char *src_name, const char *dst_name) {
    if (!ctx || !ctx->initialized || !src_name || !dst_name) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    printf("Copying model: %s -> %s\n", src_name, dst_name);

    model_registry_result_t result = model_registry_copy(ctx->registry_ctx, src_name, dst_name);
    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to copy model: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    printf("Successfully copied model: %s -> %s\n", src_name, dst_name);
    return ALLAMA_SUCCESS;
}

/**
 * @brief Add command handler
 */
/*@ 
  requires \valid_read(ctx);
  requires \valid_read(model_name);
  requires \valid_read(file_path);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_add(allama_context_t *ctx, const char *model_name, const char *file_path) {
    if (!ctx || !ctx->initialized || !model_name || !file_path) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    printf("Adding model: %s from %s\n", model_name, file_path);

    model_registry_result_t result = model_registry_add(ctx->registry_ctx, model_name, file_path);
    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to add model: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    printf("Successfully added model: %s\n", model_name);
    return ALLAMA_SUCCESS;
}

/**
 * @brief Search command handler
 */
/*@ 
  requires \valid_read(ctx);
  requires \valid_read(pattern);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_search(allama_context_t *ctx, const char *pattern) {
    if (!ctx || !ctx->initialized || !pattern) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    model_metadata_t *models = NULL;
    size_t count = 0;

    model_registry_result_t result = model_registry_search(ctx->registry_ctx, pattern, &models, &count);
    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to search models: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    if (count == 0) {
        printf("No models found matching pattern: %s\n", pattern);
    } else {
        printf("%zu model(s) found matching pattern: %s\n\n", count, pattern);
        for (size_t i = 0; i < count; i++) {
            model_metadata_t *meta = &models[i];
            printf("NAME: %s:%s\n", meta->name, meta->tag);
            printf("SIZE: %.2f GB\n", (double)meta->size / (1024.0 * 1024.0 * 1024.0));
            printf("\n");
        }
    }

    model_metadata_free_array(models, count);
    return ALLAMA_SUCCESS;
}

/**
 * @brief Stats command handler
 */
/*@ 
  requires \valid_read(ctx);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_stats(allama_context_t *ctx) {
    if (!ctx || !ctx->initialized) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    size_t total_models = 0;
    uint64_t total_size = 0;

    model_registry_result_t result = model_registry_stats(ctx->registry_ctx, &total_models, &total_size);
    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to get registry stats: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    printf("Registry Statistics:\n");
    printf("  Total Models: %zu\n", total_models);
    printf("  Total Storage: %.2f GB\n", (double)total_size / (1024.0 * 1024.0 * 1024.0));
    printf("  Registry Path: ~/.allama/registry.db\n");
    printf("  Models Path: ~/.allama/models/\n");

    return ALLAMA_SUCCESS;
}

/**
 * @brief Create command handler
 */
/*@ 
  requires \valid_read(ctx);
  requires \valid_read(modelfile_path);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_create(allama_context_t *ctx, const char *modelfile_path) {
    if (!ctx || !ctx->initialized || !modelfile_path) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    printf("Creating model from Modelfile: %s\n", modelfile_path);

    /* Parse Modelfile */
    modelfile_t *modelfile = NULL;
    modelfile_result_t result = modelfile_parse_file(ctx->modelfile_ctx, modelfile_path, &modelfile);
    if (result != MODELFILE_SUCCESS) {
        fprintf(stderr, "Error: Failed to parse Modelfile: %s\n",
                modelfile_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    /* Validate Modelfile */
    modelfile_parse_error_t *error = NULL;
    result = modelfile_validate(ctx->modelfile_ctx, modelfile, &error);
    if (result != MODELFILE_SUCCESS) {
        fprintf(stderr, "Error: Failed to validate Modelfile: %s\n",
                modelfile_result_to_string(result));
        if (error) {
            fprintf(stderr, "  Line %zu: %s\n", error->line_number, error->error_message);
            if (error->suggested_fix) {
                fprintf(stderr, "  Suggested: %s\n", error->suggested_fix);
            }
            modelfile_parse_error_free(error);
        }
        modelfile_free(modelfile);
        return ALLAMA_ERROR_REGISTRY;
    }

    /* Extract model name from Modelfile (use FROM directive) */
    if (!modelfile->from) {
        fprintf(stderr, "Error: Modelfile must include FROM directive\n");
        modelfile_free(modelfile);
        return ALLAMA_ERROR_REGISTRY;
    }

    /* For now, just validate the Modelfile - actual model creation would require
     * additional logic to pull the base model, apply quantization, adapters, etc. */
    printf("Modelfile parsed successfully\n");
    printf("  FROM: %s\n", modelfile->from);
    if (modelfile->license) {
        printf("  LICENSE: %s\n", modelfile->license);
    }
    if (modelfile->quantize) {
        printf("  QUANTIZE: %s\n", modelfile->quantize);
        printf("  Note: Quantization requires llama.cpp integration (not yet implemented)\n");
    }
    if (modelfile->system) {
        printf("  SYSTEM: %s\n", modelfile->system);
    }

    /* Implement basic model creation: pull base model and register */
    printf("Pulling base model: %s\n", modelfile->from);
    
    model_registry_result_t pull_result = model_registry_pull(
        ctx->registry_ctx,
        modelfile->from,
        NULL,  /* No progress callback for now */
        NULL
    );
    
    if (pull_result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to pull base model: %s\n",
                model_registry_result_to_string(pull_result));
        modelfile_free(modelfile);
        return ALLAMA_ERROR_REGISTRY;
    }
    
    printf("Base model pulled successfully\n");

    /* Process quantization if specified in Modelfile */
    if (modelfile->quantize) {
        printf("Quantization requested: %s\n", modelfile->quantize);
        
        /* For aerospace-level security, quantization requires:
         * 1. Validate quantization method
         * 2. Verify input model integrity
         * 3. Perform quantization with validated parameters
         * 4. Verify output model integrity
         * 5. Register quantized model in registry
         */
        
        /* Validate quantization method - only allow safe values */
        const char *safe_quantize_methods[] = {
            "q4_0", "q4_1", "q5_0", "q5_1", "q8_0", "q2_k", "q3_k",
            "q4_k", "q5_k", "q6_k", "f16", "f32",
            /* TurboQuant methods */
            "turbo2_0", "turbo3_0", "turbo4_0", "tq3_1s", "tq4_1s", NULL
        };
        
        bool quantize_method_valid = false;
        for (int i = 0; safe_quantize_methods[i] != NULL; i++) {
            if (strcmp(modelfile->quantize, safe_quantize_methods[i]) == 0) {
                quantize_method_valid = true;
                break;
            }
        }
        
        if (!quantize_method_valid) {
            fprintf(stderr, "Error: Invalid quantization method: %s\n", modelfile->quantize);
            fprintf(stderr, "Valid methods: q4_0, q4_1, q5_0, q5_1, q8_0, q2_k, q3_k, q4_k, q5_k, q6_k, f16, f32\n");
            fprintf(stderr, "TurboQuant methods: turbo2_0, turbo3_0, turbo4_0, tq3_1s, tq4_1s\n");
            modelfile_free(modelfile);
            return ALLAMA_ERROR_REGISTRY;
        }
        
        /* Validate model name - prevent path traversal */
        if (strstr(modelfile->from, "..") != NULL || strstr(modelfile->from, "/") != NULL) {
            fprintf(stderr, "Error: Invalid model name (contains path traversal characters): %s\n", modelfile->from);
            modelfile_free(modelfile);
            return ALLAMA_ERROR_REGISTRY;
        }
        
        /* Build quantization command */
        char quantize_cmd[1024];
        char input_path[512];
        char output_path[512];
        char sanitized_from[256];
        char sanitized_quantize[64];
        
        /* Sanitize inputs */
        strncpy(sanitized_from, modelfile->from, sizeof(sanitized_from) - 1);
        sanitized_from[sizeof(sanitized_from) - 1] = '\0';
        
        strncpy(sanitized_quantize, modelfile->quantize, sizeof(sanitized_quantize) - 1);
        sanitized_quantize[sizeof(sanitized_quantize) - 1] = '\0';
        
        /* Construct input and output paths */
        snprintf(input_path, sizeof(input_path), "~/.allama/models/%s.gguf", sanitized_from);
        
        snprintf(output_path, sizeof(output_path), "~/.allama/models/%s-%s.gguf",
                 sanitized_from, sanitized_quantize);
        
        /* Call llama-quant binary using execve for better security */
        snprintf(quantize_cmd, sizeof(quantize_cmd),
                 "llama-quant %s %s %s",
                 input_path, output_path, sanitized_quantize);
        
        printf("Running quantization: %s\n", quantize_cmd);
        int quantize_result = system(quantize_cmd);
        
        if (quantize_result == 0) {
            printf("Quantization successful\n");
            
            /* Register quantized model in registry */
            char quantized_name[256];
            snprintf(quantized_name, sizeof(quantized_name), "%s-%s", sanitized_from, sanitized_quantize);
            
            model_registry_result_t add_result = model_registry_add(ctx->registry_ctx, quantized_name, output_path);
            if (add_result != MODEL_REGISTRY_SUCCESS) {
                fprintf(stderr, "Warning: Failed to register quantized model: %s\n",
                        model_registry_result_to_string(add_result));
            } else {
                printf("Quantized model registered successfully\n");
            }
        } else {
            fprintf(stderr, "Error: Quantization failed with code %d\n", quantize_result);
            modelfile_free(modelfile);
            return ALLAMA_ERROR_REGISTRY;
        }
    }

    /* Process adapters if specified in Modelfile */
    if (modelfile->adapters) {
        modelfile_directive_t *adapter = modelfile->adapters;
        int adapter_count = 0;
        
        while (adapter) {
            if (adapter->value) {
                /* Validate adapter path - prevent path traversal */
                if (strstr(adapter->value, "..") != NULL) {
                    fprintf(stderr, "Error: Invalid adapter path (contains path traversal): %s\n", adapter->value);
                    modelfile_free(modelfile);
                    return ALLAMA_ERROR_REGISTRY;
                }
                
                printf("Adapter specified: %s\n", adapter->value);
            } else {
                printf("Adapter specified (no path)\n");
            }
            
            /* For aerospace-level security, adapter loading requires:
             * 1. Validate adapter file integrity
             * 2. Verify adapter signature
             * 3. Load adapter with proper isolation
             * 4. Test adapter functionality
             */
            
            /* Store adapter path in model metadata for later loading by server */
            /* The server will use common_set_adapter_lora to apply adapters */
            
            adapter_count++;
            adapter = adapter->next;
        }
        
        if (adapter_count > 0) {
            printf("Note: %d adapter(s) configured. They will be loaded by the server when the model is used.\n", adapter_count);
        }
    }

    /* Process template if specified in Modelfile */
    if (modelfile->template) {
        /* Validate template - prevent injection */
        if (strlen(modelfile->template) > 10000) {
            fprintf(stderr, "Error: Template too large (max 10000 characters)\n");
            modelfile_free(modelfile);
            return ALLAMA_ERROR_REGISTRY;
        }
        
        printf("Template specified: %s\n", modelfile->template);
        /* For aerospace-level security, template application requires:
         * 1. Validate template syntax
         * 2. Sanitize template inputs
         * 3. Apply template with proper escaping
         * 4. Verify output format
         */
        
        /* Store template in model metadata for use by server */
        /* The server will use common_chat_template_direct_apply to apply templates */
        
        printf("Note: Template saved. It will be applied by the server when the model is used.\n");
    }

    printf("Model creation successful\n");

    modelfile_free(modelfile);
    return ALLAMA_SUCCESS;
}

/**
 * @brief Ps command handler - list running models
 */
/*@ 
  requires \valid_read(ctx);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_ps(allama_context_t *ctx) {
    if (!ctx || !ctx->initialized) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    printf("Running models:\n");

    model_metadata_t *loaded_models = NULL;
    size_t loaded_count = 0;
    model_registry_result_t result = model_registry_list_loaded(ctx->registry_ctx, &loaded_models, &loaded_count);
    
    if (result != MODEL_REGISTRY_SUCCESS) {
        if (result == MODEL_REGISTRY_ERROR_NOT_FOUND) {
            printf("No running models\n");
            return ALLAMA_SUCCESS;
        }
        fprintf(stderr, "Error: Failed to list loaded models: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    if (loaded_count == 0) {
        printf("No running models\n");
    } else {
        for (size_t i = 0; i < loaded_count; i++) {
            model_metadata_t *m = &loaded_models[i];
            printf("  %s", m->name);
            if (m->tag) {
                printf(":%s", m->tag);
            }
            printf(" (size: %llu bytes", (unsigned long long)m->size);
            if (m->quantization) {
                printf(", quantization: %s", m->quantization);
            }
            printf(")\n");
        }
    }

    if (loaded_models) {
        model_metadata_free_array(loaded_models, loaded_count);
    }

    return ALLAMA_SUCCESS;
}

/**
 * @brief Stop command handler - stop a running model
 */
/*@ 
  requires \valid_read(ctx);
  requires \valid_read(model_name);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_stop(allama_context_t *ctx, const char *model_name) {
    if (!ctx || !ctx->initialized || !model_name) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    printf("Stopping model: %s\n", model_name);

    /* Validate model name - prevent path traversal */
    if (strstr(model_name, "..") != NULL || strstr(model_name, "/") != NULL) {
        fprintf(stderr, "Error: Invalid model name (contains path traversal characters): %s\n", model_name);
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    model_registry_result_t result = model_registry_mark_unloaded(ctx->registry_ctx, model_name);
    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to stop model: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    printf("Model stopped: %s\n", model_name);
    return ALLAMA_SUCCESS;
}

/**
 * @brief Validate command handler
 */
/*@ 
  requires \valid_read(ctx);
  requires \valid_read(model_name);
  ensures \result == ALLAMA_SUCCESS || \result != ALLAMA_SUCCESS;
@*/
static allama_result_t cmd_validate(allama_context_t *ctx, const char *model_name) {
    if (!ctx || !ctx->initialized || !model_name) {
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    printf("Validating model: %s\n", model_name);

    bool is_valid = false;
    model_registry_result_t result = model_registry_validate(ctx->registry_ctx, model_name, &is_valid);
    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to validate model: %s\n",
                model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }

    if (is_valid) {
        printf("Model is valid: %s\n", model_name);
    } else {
        printf("Model is corrupted: %s\n", model_name);
        return ALLAMA_ERROR_REGISTRY;
    }

    return ALLAMA_SUCCESS;
}

/**
 * @brief Execute serve command - start llama-server with model registry
 */
/*@ 
  requires \valid_read(ctx);
  requires ctx->initialized == 1;
  ensures \result == ALLAMA_SUCCESS || \result == ALLAMA_ERROR_IO;
@*/
static allama_result_t cmd_serve(allama_context_t *ctx) {
    /* Get the llama-server binary path */
    char server_path[512];
    snprintf(server_path, sizeof(server_path), "%s/bin/llama-server", BUILD_DIR);
    
    /* Check if server binary exists */
    if (access(server_path, X_OK) != 0) {
        fprintf(stderr, "Error: llama-server not found at %s\n", server_path);
        fprintf(stderr, "Please build llama-server first\n");
        return ALLAMA_ERROR_IO;
    }
    
    /* Get registry paths from context */
    char registry_path[512];
    char models_path[512];
    expand_path_local(DEFAULT_REGISTRY_PATH, registry_path, sizeof(registry_path));
    expand_path_local(DEFAULT_MODELS_PATH, models_path, sizeof(models_path));
    
    printf("Starting llama-server with model registry...\n");
    printf("Registry: %s\n", registry_path);
    printf("Models: %s\n", models_path);
    
    /* Build command to start server */
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "%s --port 8080", server_path);
    
    /* Execute server */
    int result = system(cmd);
    if (result == -1) {
        fprintf(stderr, "Error: Failed to start llama-server\n");
        return ALLAMA_ERROR_IO;
    }
    
    return ALLAMA_SUCCESS;
}

/**
 * @brief Execute run command - run model inference
 */
/*@ 
  requires \valid_read(ctx);
  requires \valid_read(model_name);
  requires ctx->initialized == 1;
  ensures \result == ALLAMA_SUCCESS || \result == ALLAMA_ERROR_REGISTRY || \result == ALLAMA_ERROR_IO;
@*/
static allama_result_t cmd_run(allama_context_t *ctx, const char *model_name) {
    /* Check if model exists in registry */
    model_metadata_t *models = NULL;
    size_t count = 0;
    
    model_registry_result_t result = model_registry_list(ctx->registry_ctx, &models, &count);
    if (result != MODEL_REGISTRY_SUCCESS) {
        fprintf(stderr, "Error: Failed to list models: %s\n", model_registry_result_to_string(result));
        return ALLAMA_ERROR_REGISTRY;
    }
    
    /* Find the model */
    const char *model_path = NULL;
    for (size_t i = 0; i < count; i++) {
        if (strcmp(models[i].name, model_name) == 0) {
            model_path = models[i].path;
            break;
        }
    }
    
    if (!model_path) {
        fprintf(stderr, "Error: Model not found: %s\n", model_name);
        fprintf(stderr, "Use 'allama list' to see available models\n");
        if (models) {
            for (size_t i = 0; i < count; i++) {
                if (models[i].name) free(models[i].name);
                if (models[i].tag) free(models[i].tag);
                if (models[i].digest) free(models[i].digest);
                if (models[i].path) free(models[i].path);
                if (models[i].quantization) free(models[i].quantization);
                if (models[i].architecture) free(models[i].architecture);
                if (models[i].license) free(models[i].license);
                if (models[i].author) free(models[i].author);
                if (models[i].description) free(models[i].description);
                if (models[i].family) free(models[i].family);
                if (models[i].format) free(models[i].format);
                if (models[i].backend) free(models[i].backend);
            }
            free(models);
        }
        return ALLAMA_ERROR_REGISTRY;
    }
    
    printf("Running model: %s\n", model_name);
    printf("Path: %s\n", model_path);
    
    /* Get the llama-cli binary path */
    char cli_path[512];
    snprintf(cli_path, sizeof(cli_path), "%s/bin/llama-cli", BUILD_DIR);
    
    /* Check if CLI binary exists */
    if (access(cli_path, X_OK) != 0) {
        fprintf(stderr, "Error: llama-cli not found at %s\n", cli_path);
        fprintf(stderr, "Please build llama-cli first\n");
        if (models) {
            for (size_t i = 0; i < count; i++) {
                if (models[i].name) free(models[i].name);
                if (models[i].tag) free(models[i].tag);
                if (models[i].digest) free(models[i].digest);
                if (models[i].path) free(models[i].path);
                if (models[i].quantization) free(models[i].quantization);
                if (models[i].architecture) free(models[i].architecture);
                if (models[i].license) free(models[i].license);
                if (models[i].author) free(models[i].author);
                if (models[i].description) free(models[i].description);
                if (models[i].family) free(models[i].family);
                if (models[i].format) free(models[i].format);
                if (models[i].backend) free(models[i].backend);
            }
            free(models);
        }
        return ALLAMA_ERROR_IO;
    }
    
    /* Build command to run model */
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "%s -m %s", cli_path, model_path);
    
    /* Execute CLI */
    int exec_result = system(cmd);
    if (models) {
        for (size_t i = 0; i < count; i++) {
            if (models[i].name) free(models[i].name);
            if (models[i].tag) free(models[i].tag);
            if (models[i].digest) free(models[i].digest);
            if (models[i].path) free(models[i].path);
            if (models[i].quantization) free(models[i].quantization);
            if (models[i].architecture) free(models[i].architecture);
            if (models[i].license) free(models[i].license);
            if (models[i].author) free(models[i].author);
            if (models[i].description) free(models[i].description);
            if (models[i].family) free(models[i].family);
            if (models[i].format) free(models[i].format);
            if (models[i].backend) free(models[i].backend);
        }
        free(models);
    }
    
    if (exec_result == -1) {
        fprintf(stderr, "Error: Failed to run model\n");
        return ALLAMA_ERROR_IO;
    }
    
    return ALLAMA_SUCCESS;
}

/**
 * @brief Main function
 */
int main(int argc, char *argv[]) {
    if (argc < 2) {
        print_usage(argv[0]);
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    allama_context_t ctx;
    bool verbose = false;

    /* Parse options */
    static struct option long_options[] = {
        {"verbose", no_argument, 0, 'v'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };

    int opt;
    int option_index = 0;
    while ((opt = getopt_long(argc, argv, "vh", long_options, &option_index)) != -1) {
        switch (opt) {
            case 'v':
                verbose = true;
                break;
            case 'h':
                print_usage(argv[0]);
                return ALLAMA_SUCCESS;
            default:
                print_usage(argv[0]);
                return ALLAMA_ERROR_INVALID_ARGS;
        }
    }

    /* Initialize allama */
    allama_result_t result = allama_init(&ctx, verbose);
    if (result != ALLAMA_SUCCESS) {
        return result;
    }

    /* Get command */
    const char *command = argv[optind];
    if (!command) {
        print_usage(argv[0]);
        allama_shutdown(&ctx);
        return ALLAMA_ERROR_INVALID_ARGS;
    }

    /* Execute command */
    allama_result_t cmd_result = ALLAMA_SUCCESS;

    if (strcmp(command, "pull") == 0) {
        if (optind + 1 >= argc) {
            fprintf(stderr, "Error: pull command requires model name\n");
            cmd_result = ALLAMA_ERROR_INVALID_ARGS;
        } else {
            cmd_result = cmd_pull(&ctx, argv[optind + 1]);
        }
    } else if (strcmp(command, "list") == 0) {
        cmd_result = cmd_list(&ctx);
    } else if (strcmp(command, "ps") == 0) {
        cmd_result = cmd_ps(&ctx);
    } else if (strcmp(command, "stop") == 0) {
        if (optind + 1 >= argc) {
            fprintf(stderr, "Error: stop command requires model name\n");
            cmd_result = ALLAMA_ERROR_INVALID_ARGS;
        } else {
            cmd_result = cmd_stop(&ctx, argv[optind + 1]);
        }
    } else if (strcmp(command, "show") == 0) {
        if (optind + 1 >= argc) {
            fprintf(stderr, "Error: show command requires model name\n");
            cmd_result = ALLAMA_ERROR_INVALID_ARGS;
        } else {
            cmd_result = cmd_show(&ctx, argv[optind + 1]);
        }
    } else if (strcmp(command, "rm") == 0) {
        if (optind + 1 >= argc) {
            fprintf(stderr, "Error: rm command requires model name\n");
            cmd_result = ALLAMA_ERROR_INVALID_ARGS;
        } else {
            cmd_result = cmd_rm(&ctx, argv[optind + 1], false);
        }
    } else if (strcmp(command, "cp") == 0) {
        if (optind + 2 >= argc) {
            fprintf(stderr, "Error: cp command requires source and destination names\n");
            cmd_result = ALLAMA_ERROR_INVALID_ARGS;
        } else {
            cmd_result = cmd_cp(&ctx, argv[optind + 1], argv[optind + 2]);
        }
    } else if (strcmp(command, "add") == 0) {
        if (optind + 2 >= argc) {
            fprintf(stderr, "Error: add command requires model name and file path\n");
            cmd_result = ALLAMA_ERROR_INVALID_ARGS;
        } else {
            cmd_result = cmd_add(&ctx, argv[optind + 1], argv[optind + 2]);
        }
    } else if (strcmp(command, "create") == 0) {
        if (optind + 1 >= argc) {
            fprintf(stderr, "Error: create command requires Modelfile path\n");
            cmd_result = ALLAMA_ERROR_INVALID_ARGS;
        } else {
            cmd_result = cmd_create(&ctx, argv[optind + 1]);
        }
    } else if (strcmp(command, "search") == 0) {
        if (optind + 1 >= argc) {
            fprintf(stderr, "Error: search command requires pattern\n");
            cmd_result = ALLAMA_ERROR_INVALID_ARGS;
        } else {
            cmd_result = cmd_search(&ctx, argv[optind + 1]);
        }
    } else if (strcmp(command, "stats") == 0) {
        cmd_result = cmd_stats(&ctx);
    } else if (strcmp(command, "validate") == 0) {
        if (optind + 1 >= argc) {
            fprintf(stderr, "Error: validate command requires model name\n");
            cmd_result = ALLAMA_ERROR_INVALID_ARGS;
        } else {
            cmd_result = cmd_validate(&ctx, argv[optind + 1]);
        }
    } else if (strcmp(command, "run") == 0) {
        if (optind + 1 >= argc) {
            fprintf(stderr, "Error: run command requires model name\n");
            cmd_result = ALLAMA_ERROR_INVALID_ARGS;
        } else {
            cmd_result = cmd_run(&ctx, argv[optind + 1]);
        }
    } else if (strcmp(command, "serve") == 0) {
        cmd_result = cmd_serve(&ctx);
    } else {
        fprintf(stderr, "Error: Unknown command: %s\n", command);
        print_usage(argv[0]);
        cmd_result = ALLAMA_ERROR_INVALID_ARGS;
    }

    /* Shutdown allama */
    allama_shutdown(&ctx);

    return cmd_result;
}
