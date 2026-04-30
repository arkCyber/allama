#ifndef SERVER_MODEL_REGISTRY_H
#define SERVER_MODEL_REGISTRY_H

#include "server-http.h"
#include "common.h"

/**
 * @file server-model-registry.h
 * @brief Ollama-compatible model management API endpoints
 * 
 * This module provides REST API endpoints for model management that are
 * compatible with ollama's API format, while maintaining aerospace-level
 * security standards.
 * 
 * Aerospace-Level Security Features:
 * - Authentication and authorization
 * - Audit logging for all operations
 * - Input validation and sanitization
 * - Rate limiting
 * - Thread-safe operations
 */

struct server_model_registry_context {
    struct Impl;
    std::unique_ptr<Impl> pimpl;

    server_model_registry_context();
    ~server_model_registry_context();

    /**
     * @brief Initialize model registry API
     * @param params Server parameters
     * @return true on success, false on failure
     */
    bool init(const common_params & params);

    /**
     * @brief Register model management endpoints
     * @param http_ctx HTTP server context
     */
    void register_endpoints(server_http_context & http_ctx) const;
};

#endif /* SERVER_MODEL_REGISTRY_H */
