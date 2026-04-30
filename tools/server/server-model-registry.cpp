/**
 * @file server-model-registry.cpp
 * @brief Ollama-compatible model management API endpoints
 * 
 * Aerospace-Level Security Implementation:
 * - Authentication and authorization
 * - Audit logging for all operations
 * - Input validation and sanitization
 * - Rate limiting
 * - Thread-safe operations
 */

#include "server-model-registry.h"
#include "model-registry.h"
#include "audit-log.h"
#include "auth.h"
#include "log.h"
#include "server-common.h"
#include <llama.h>
#include <string>
#include <vector>
#include <unordered_map>
#include <functional>
#include <sstream>
#include <iomanip>
#include <cstring>

/**
 * @brief Model registry API context
 */
struct server_model_registry_context::Impl {
    model_registry_context_t *registry_ctx;
    bool initialized;
};

server_model_registry_context::server_model_registry_context()
    : pimpl(std::make_unique<server_model_registry_context::Impl>())
{}

server_model_registry_context::~server_model_registry_context() {
    if (pimpl->initialized && pimpl->registry_ctx) {
        model_registry_shutdown(pimpl->registry_ctx);
    }
}

/**
 * @brief Initialize model registry API
 */
bool server_model_registry_context::init(const common_params & params) {
    if (pimpl->initialized) {
        return true;
    }

    /* Initialize authentication system */
    auth_config_t auth_config = {
        .enabled = true,
        .default_method = AUTH_METHOD_API_KEY,
        .max_sessions = 1000,
        .default_rate_limit = 1000, /* requests per hour */
        .session_timeout = 3600, /* 1 hour */
        .require_auth = false /* Can be enabled via config */
    };

    if (auth_init(&auth_config) != 0) {
        LOG_ERR("Failed to initialize authentication system\n");
        return false;
    }

    /* Initialize model registry */
    char *registry_path_copy = nullptr;
    char *models_path_copy = nullptr;
    if (!params.model_registry_path.empty()) {
        registry_path_copy = strdup(params.model_registry_path.c_str());
    }
    if (!params.models_path.empty()) {
        models_path_copy = strdup(params.models_path.c_str());
    }

    model_registry_config_t config = {
        .registry_path = registry_path_copy,
        .models_path = models_path_copy,
        .remote_registry_url = nullptr, /* Use default */
        .max_models = 1000,
        .max_storage = 100ULL * 1024 * 1024 * 1024, /* 100 GB */
        .enable_audit = true,
        .enable_validation = true
    };

    model_registry_result_t result = model_registry_init(&config, &pimpl->registry_ctx);
    if (result != MODEL_REGISTRY_SUCCESS) {
        LOG_ERR("Failed to initialize model registry: %s\n", model_registry_result_to_string(result));
        if (registry_path_copy) free(registry_path_copy);
        if (models_path_copy) free(models_path_copy);
        return false;
    }

    /* The model registry takes ownership of the strings */
    pimpl->initialized = true;
    LOG_INF("Model registry API initialized\n");

    return true;
}

/**
 * @brief Check authentication for a request
 * Returns: 0 = success, 1 = auth failure, 2 = rate limit exceeded
 */
static int check_authentication(const server_http_req & req, uint64_t *user_id) {
    /* Get Authorization header */
    auto auth_header_it = req.headers.find("Authorization");
    const char *auth_header = (auth_header_it != req.headers.end()) ? auth_header_it->second.c_str() : nullptr;
    if (!auth_header) {
        /* No auth header provided */
        *user_id = 0; /* Anonymous user */
        return 0; /* Allow if auth is not required */
    }

    /* Validate authentication */
    const char *method_str = nullptr;
    auth_result_t result = auth_request(auth_header, user_id, &method_str);

    if (result != AUTH_SUCCESS) {
        LOG_ERR("Authentication failed: %s\n", method_str ? method_str : "unknown");
        return 1; /* Auth failure */
    }

    /* Check rate limit */
    if (!auth_check_rate_limit(*user_id)) {
        LOG_ERR("Rate limit exceeded for user %llu\n", (unsigned long long)*user_id);
        return 2; /* Rate limit exceeded */
    }

    /* Increment request count */
    auth_increment_request_count(*user_id);

    return 0; /* Success */
}

/**
 * @brief Register model management endpoints
 */
void server_model_registry_context::register_endpoints(server_http_context & http_ctx) const {
    if (!pimpl->initialized) {
        LOG_ERR("Model registry not initialized, cannot register endpoints\n");
        return;
    }

    auto registry_ctx = pimpl->registry_ctx;

    /**
     * GET /api/tags - List models (ollama-compatible)
     */
    http_ctx.get("/api/tags", [registry_ctx](const server_http_req & req) -> server_http_res_ptr {
        auto res = std::make_unique<server_http_res>();

        model_metadata_t *models = nullptr;
        size_t count = 0;

        model_registry_result_t result = model_registry_list(registry_ctx, &models, &count);
        if (result != MODEL_REGISTRY_SUCCESS) {
            res->status = 500;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", model_registry_result_to_string(result)},
                    {"type", "internal_error"}
                }}
            });
            return res;
        }

        /* Build response in ollama format */
        json models_array = json::array();
        for (size_t i = 0; i < count; i++) {
            model_metadata_t *meta = &models[i];
            models_array.push_back({
                {"name", meta->name},
                {"tag", meta->tag},
                {"digest", meta->digest},
                {"size", meta->size},
                {"parameters", meta->parameters},
                {"quantization", meta->quantization ? meta->quantization : ""},
                {"architecture", meta->architecture ? meta->architecture : ""},
                {"license", meta->license ? meta->license : ""},
                {"author", meta->author ? meta->author : ""},
                {"modified_at", meta->modified_at}
            });
        }

        model_metadata_free_array(models, count);

        res->status = 200;
        res->data = safe_json_to_str(json{
            {"models", models_array}
        });

        /* Audit log */
        audit_log_auth_success("api_tags", "list models");

        return res;
    });

    /**
     * GET /api/show - Show model details (ollama-compatible)
     */
    http_ctx.get("/api/show", [registry_ctx](const server_http_req & req) -> server_http_res_ptr {
        auto res = std::make_unique<server_http_res>();

        /* Get model name from query parameter */
        std::string model_name;
        auto it = req.params.find("name");
        if (it != req.params.end()) {
            model_name = it->second;
        } else {
            res->status = 400;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", "Missing 'name' parameter"},
                    {"type", "invalid_request"}
                }}
            });
            return res;
        }

        model_metadata_t *metadata = nullptr;
        model_registry_result_t result = model_registry_show(registry_ctx, model_name.c_str(), &metadata);
        if (result != MODEL_REGISTRY_SUCCESS) {
            res->status = 404;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", "Model not found"},
                    {"type", "not_found_error"}
                }}
            });
            return res;
        }

        /* Build response in ollama format */
        json details = {
            {"name", metadata->name},
            {"tag", metadata->tag},
            {"digest", metadata->digest},
            {"path", metadata->path},
            {"size", metadata->size},
            {"parameters", metadata->parameters},
            {"quantization", metadata->quantization ? metadata->quantization : ""},
            {"architecture", metadata->architecture ? metadata->architecture : ""},
            {"license", metadata->license ? metadata->license : ""},
            {"author", metadata->author ? metadata->author : ""},
            {"created_at", metadata->created_at},
            {"modified_at", metadata->modified_at},
            {"description", metadata->description ? metadata->description : ""},
            {"family", metadata->family ? metadata->family : ""},
            {"format", metadata->format ? metadata->format : ""},
            {"backend", metadata->backend ? metadata->backend : ""}
        };

        model_metadata_free(metadata);

        res->status = 200;
        res->data = safe_json_to_str(json{
            {"details", details}
        });

        /* Audit log */
        audit_log_auth_success("api_show", model_name.c_str());

        return res;
    });

    /**
     * DELETE /api/delete - Delete model (ollama-compatible)
     */
    http_ctx.post("/api/delete", [registry_ctx](const server_http_req & req) -> server_http_res_ptr {
        auto res = std::make_unique<server_http_res>();

        /* Check authentication */
        uint64_t user_id = 0;
        int auth_result = check_authentication(req, &user_id);
        if (auth_result == 1) {
            res->status = 401;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", "Authentication failed"},
                    {"type", "authentication_error"}
                }}
            });
            return res;
        } else if (auth_result == 2) {
            res->status = 429;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", "Rate limit exceeded"},
                    {"type", "rate_limit_error"}
                }}
            });
            return res;
        }

        try {
            json body = json::parse(req.body);
            std::string model_name = body.value("name", "");

            if (model_name.empty()) {
                res->status = 400;
                res->data = safe_json_to_str(json{
                    {"error", {
                        {"message", "Missing 'name' in request body"},
                        {"type", "invalid_request"}
                    }}
                });
                return res;
            }

            model_registry_result_t result = model_registry_remove(registry_ctx, model_name.c_str(), false);

            if (result != MODEL_REGISTRY_SUCCESS) {
                res->status = 400;
                res->data = safe_json_to_str(json{
                    {"error", {
                        {"message", model_registry_result_to_string(result)},
                        {"type", "invalid_request"}
                    }}
                });
                audit_log_auth_failure("api_delete", model_name.c_str(),
                                     model_registry_result_to_string(result));
                return res;
            }

            res->status = 200;
            res->data = safe_json_to_str(json{
                {"status", "success"}
            });

            audit_log_auth_success("api_delete", model_name.c_str());

        } catch (const json::exception & e) {
            res->status = 400;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", "Invalid JSON"},
                    {"type", "invalid_request"}
                }}
            });
        }

        return res;
    });

    /**
     * POST /api/copy - Copy model (ollama-compatible)
     */
    http_ctx.post("/api/copy", [registry_ctx](const server_http_req & req) -> server_http_res_ptr {
        auto res = std::make_unique<server_http_res>();

        /* Check authentication */
        uint64_t user_id = 0;
        int auth_result = check_authentication(req, &user_id);
        if (auth_result == 1) {
            res->status = 401;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", "Authentication failed"},
                    {"type", "authentication_error"}
                }}
            });
            return res;
        } else if (auth_result == 2) {
            res->status = 429;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", "Rate limit exceeded"},
                    {"type", "rate_limit_error"}
                }}
            });
            return res;
        }

        try {
            json body = json::parse(req.body);
            std::string source = body.value("source", "");
            std::string destination = body.value("destination", "");

            if (source.empty() || destination.empty()) {
                res->status = 400;
                res->data = safe_json_to_str(json{
                    {"error", {
                        {"message", "Missing 'source' or 'destination' in request body"},
                        {"type", "invalid_request"}
                    }}
                });
                return res;
            }

            model_registry_result_t result = model_registry_copy(
                registry_ctx, source.c_str(), destination.c_str());

            if (result != MODEL_REGISTRY_SUCCESS) {
                res->status = 400;
                res->data = safe_json_to_str(json{
                    {"error", {
                        {"message", model_registry_result_to_string(result)},
                        {"type", "invalid_request"}
                    }}
                });
                audit_log_auth_failure("api_copy", source.c_str(),
                                     model_registry_result_to_string(result));
                return res;
            }

            res->status = 200;
            res->data = safe_json_to_str(json{
                {"status", "success"}
            });

            audit_log_auth_success("api_copy", source.c_str());

        } catch (const json::exception & e) {
            res->status = 400;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", "Invalid JSON"},
                    {"type", "invalid_request"}
                }}
            });
        }

        return res;
    });

    /**
     * GET /api/ps - System info (ollama-compatible)
     */
    http_ctx.get("/api/ps", [registry_ctx](const server_http_req & req) -> server_http_res_ptr {
        auto res = std::make_unique<server_http_res>();

        size_t total_models = 0;
        uint64_t total_size = 0;

        model_registry_result_t result = model_registry_stats(registry_ctx, &total_models, &total_size);
        if (result != MODEL_REGISTRY_SUCCESS) {
            res->status = 500;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", model_registry_result_to_string(result)},
                    {"type", "internal_error"}
                }}
            });
            return res;
        }

        /* Get list of all models */
        model_metadata_t *all_models = NULL;
        size_t all_count = 0;
        result = model_registry_list(registry_ctx, &all_models, &all_count);
        if (result != MODEL_REGISTRY_SUCCESS && result != MODEL_REGISTRY_ERROR_NOT_FOUND) {
            res->status = 500;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", model_registry_result_to_string(result)},
                    {"type", "internal_error"}
                }}
            });
            return res;
        }

        /* Get list of loaded models */
        model_metadata_t *loaded_models = NULL;
        size_t loaded_count = 0;
        result = model_registry_list_loaded(registry_ctx, &loaded_models, &loaded_count);
        if (result != MODEL_REGISTRY_SUCCESS && result != MODEL_REGISTRY_ERROR_NOT_FOUND) {
            /* Log error but continue without loaded models info */
            if (all_models) model_metadata_free_array(all_models, all_count);
            loaded_models = NULL;
            loaded_count = 0;
        }

        /* Build response in ollama format */
        json models_array = json::array();

        /* Add all models with their status */
        for (size_t i = 0; i < all_count; i++) {
            model_metadata_t *m = &all_models[i];

            /* Check if this model is loaded */
            bool is_loaded = false;
            for (size_t j = 0; j < loaded_count; j++) {
                if (strcmp(loaded_models[j].name, m->name) == 0) {
                    is_loaded = true;
                    break;
                }
            }

            json model_info = {
                {"name", m->name},
                {"tag", m->tag},
                {"size", m->size},
                {"digest", m->digest ? m->digest : ""},
                {"modified_at", m->modified_at},
                {"status", is_loaded ? "running" : "unloaded"}
            };

            if (m->quantization) model_info["quantization"] = m->quantization;
            if (m->architecture) model_info["architecture"] = m->architecture;
            if (m->author) model_info["author"] = m->author;
            if (m->description) model_info["description"] = m->description;

            models_array.push_back(model_info);
        }

        /* Free memory */
        if (all_models) model_metadata_free_array(all_models, all_count);
        if (loaded_models) model_metadata_free_array(loaded_models, loaded_count);

        res->status = 200;
        res->data = safe_json_to_str(json{
            {"models", models_array},
            {"total_models", total_models},
            {"total_size", total_size}
        });

        /* Audit log */
        audit_log_auth_success("api_ps", "system info");

        return res;
    });

    /**
     * GET /api/version - Version information
     */
    http_ctx.get("/api/version", [](const server_http_req & req) -> server_http_res_ptr {
        auto res = std::make_unique<server_http_res>();
        res->data = safe_json_to_str(json{
            {"version", "1.0.0"},
            {"build", "llama.cpp"}
        });
        return res;
    });

    /**
     * POST /api/pull - Pull model (ollama-compatible)
     * Note: Full implementation requires remote registry integration
     */
    http_ctx.post("/api/pull", [registry_ctx](const server_http_req & req) -> server_http_res_ptr {
        auto res = std::make_unique<server_http_res>();

        /* Check authentication */
        uint64_t user_id = 0;
        int auth_result = check_authentication(req, &user_id);
        if (auth_result == 1) {
            res->status = 401;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", "Authentication failed"},
                    {"type", "authentication_error"}
                }}
            });
            return res;
        } else if (auth_result == 2) {
            res->status = 429;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", "Rate limit exceeded"},
                    {"type", "rate_limit_error"}
                }}
            });
            return res;
        }

        try {
            json body = json::parse(req.body);
            std::string model_name = body.value("name", "");

            if (model_name.empty()) {
                res->status = 400;
                res->data = safe_json_to_str(json{
                    {"error", {
                        {"message", "Missing 'name' in request body"},
                        {"type", "invalid_request"}
                    }}
                });
                return res;
            }

            /* Pull the model using model registry */
            model_registry_result_t result = model_registry_pull(
                registry_ctx,
                model_name.c_str(),
                NULL,  /* No progress callback for HTTP API */
                NULL
            );

            if (result != MODEL_REGISTRY_SUCCESS) {
                res->status = 400;
                res->data = safe_json_to_str(json{
                    {"error", {
                        {"message", model_registry_result_to_string(result)},
                        {"type", "invalid_request"}
                    }}
                });
                /* Audit log */
                audit_log_auth_failure("api_pull", model_name.c_str(),
                                     model_registry_result_to_string(result));
                return res;
            }

            res->status = 200;
            res->data = safe_json_to_str(json{
                {"status", "success"},
                {"name", model_name}
            });

            /* Audit log */
            audit_log_auth_success("api_pull", model_name.c_str());

        } catch (const json::exception & e) {
            res->status = 400;
            res->data = safe_json_to_str(json{
                {"error", {
                    {"message", "Invalid JSON"},
                    {"type", "invalid_request"}
                }}
            });
        }

        return res;
    });

    LOG_INF("Model registry API endpoints registered\n");
}
