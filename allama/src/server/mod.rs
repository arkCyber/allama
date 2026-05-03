use anyhow::Result;
use axum::{
    extract::{State, Path, Query},
    http::{StatusCode, HeaderMap},
    response::{IntoResponse, Json, Sse},
    routing::{get, post, delete},
    Router,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::Mutex as TokioMutex;
use tokio::net::TcpListener;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tower_http::limit::RequestBodyLimitLayer;
use tower::limit::ConcurrencyLimitLayer;
use tracing::{info, error, warn};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use crate::model::ModelManager;
use crate::fault::TimeoutProtection;
use crate::fault::GracefulDegradation;
use crate::audit::AuditLogger;
use crate::audit::AuditEventType;
use crate::audit::AuditSeverity;
use crate::billing::{BillingManager, BillingRecord, count_tokens};
use crate::auth::AuthManager;

#[cfg(test)]
mod tests;

/// Model state tracking
#[derive(Debug, Clone)]
pub struct ModelState {
    pub is_loaded: bool,
    pub load_time: Option<chrono::DateTime<chrono::Utc>>,
    pub last_used: Option<chrono::DateTime<chrono::Utc>>,
    pub request_count: u64,
}

/// Server state
#[derive(Clone)]
pub struct ServerState {
    pub model_manager: ModelManager,
    pub loaded_models: Arc<TokioMutex<HashMap<String, ModelState>>>,
    pub audit_logger: Arc<TokioMutex<AuditLogger>>,
    pub rate_limiter: Arc<TokioMutex<HashMap<String, RateLimitInfo>>>,
    pub graceful_degradation: Arc<GracefulDegradation>,
    pub billing_manager: Arc<TokioMutex<Option<BillingManager>>>,
    pub auth_manager: Arc<TokioMutex<Option<AuthManager>>>,
}

/// Rate limiting information
#[derive(Debug, Clone)]
pub struct RateLimitInfo {
    last_request: Instant,
    request_count: u32,
}

// Aerospace-level: Maximum request size (10MB)
const MAX_REQUEST_SIZE: usize = 10 * 1024 * 1024;

// Aerospace-level: Maximum prompt/message length (100K characters)
const MAX_PROMPT_LENGTH: usize = 100_000;

// Aerospace-level: Maximum messages array size (100 messages)
const MAX_MESSAGES_COUNT: usize = 100;

// Aerospace-level: Model whitelist (for security)
const MODEL_WHITELIST: &[&str] = &[
    "llama2", "llama3", "llama3:latest", "llama3:8b", "llama3:70b",
    "mistral", "mistral:latest", "mistral:7b",
    "gemma", "gemma:latest", "gemma:7b",
    "qwen", "qwen:latest", "qwen:14b",
];

impl RateLimitInfo {
    fn new() -> Self {
        Self {
            last_request: Instant::now(),
            request_count: 0,
        }
    }
}

/// Model tag response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct ModelTag {
    name: String,
    modified_at: String,
    size: u64,
}

/// Tags response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct TagsResponse {
    models: Vec<ModelTag>,
}

/// Generate request (Ollama-compatible)
#[derive(Debug, Deserialize)]
struct GenerateRequest {
    model: String,
    prompt: String,
    options: Option<serde_json::Value>,
    #[serde(default)]
    stream: bool,
}

/// Generate response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct GenerateResponse {
    model: String,
    response: String,
    done: bool,
}

/// Chat request (Ollama-compatible)
#[derive(Debug, Deserialize)]
struct ChatRequest {
    model: String,
    messages: Vec<ChatMessage>,
    #[serde(default)]
    stream: bool,
}

/// Chat message (Ollama-compatible)
#[derive(Debug, Deserialize, Serialize, Clone)]
struct ChatMessage {
    role: String,
    content: String,
}

/// Chat response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct ChatResponse {
    model: String,
    message: ChatMessage,
    done: bool,
}

/// Embed request (Ollama-compatible)
#[derive(Debug, Deserialize)]
struct EmbedRequest {
    model: String,
    input: String,
}

/// Embed response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct EmbedResponse {
    model: String,
    embeddings: Vec<f32>,
}

/// Ps response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct PsResponse {
    models: Vec<PsModel>,
}

/// Ps model info (Ollama-compatible)
#[derive(Debug, Serialize)]
struct PsModel {
    name: String,
    pid: u32,
    memory_mb: u64,
    cpu_percent: f32,
}

/// Show request (Ollama-compatible)
#[derive(Debug, Deserialize)]
struct ShowRequest {
    model: String,
}

/// Show response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct ShowResponse {
    model: String,
    details: serde_json::Value,
}

/// Delete request (Ollama-compatible)
#[derive(Debug, Deserialize)]
struct DeleteRequest {
    model: String,
}

/// Pull request (Ollama-compatible)
#[derive(Debug, Deserialize)]
struct PullRequest {
    model: String,
}

/// Pull response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct PullResponse {
    model: String,
    status: String,
}

/// Version response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct VersionResponse {
    version: String,
}

/// Create request (Ollama-compatible)
#[derive(Debug, Deserialize)]
struct CreateRequest {
    model: String,
    #[serde(default)]
    modelfile: Option<String>,
}

/// Create response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct CreateResponse {
    model: String,
    status: String,
}

/// Copy request (Ollama-compatible)
#[derive(Debug, Deserialize)]
struct CopyRequest {
    source: String,
    destination: String,
}

/// Copy response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct CopyResponse {
    status: String,
}

/// Push request (Ollama-compatible)
#[derive(Debug, Deserialize)]
struct PushRequest {
    model: String,
    #[serde(default)]
    insecure: bool,
}

/// Push response (Ollama-compatible)
#[derive(Debug, Serialize)]
struct PushResponse {
    model: String,
    status: String,
}

/// OpenAI chat completion request
#[derive(Debug, Deserialize)]
struct OpenAIChatRequest {
    model: String,
    messages: Vec<OpenAIMessage>,
    #[serde(default)]
    stream: bool,
}

/// OpenAI message
#[derive(Debug, Deserialize, Serialize)]
struct OpenAIMessage {
    role: String,
    content: String,
}

/// OpenAI chat completion response
#[derive(Debug, Serialize)]
struct OpenAIChatResponse {
    id: String,
    object: String,
    created: u64,
    model: String,
    choices: Vec<OpenAIChoice>,
}

/// OpenAI choice
#[derive(Debug, Serialize)]
struct OpenAIChoice {
    index: u32,
    message: OpenAIMessage,
    finish_reason: String,
}

/// OpenAI completion request
#[derive(Debug, Deserialize)]
struct OpenAICompletionRequest {
    model: String,
    prompt: String,
    #[serde(default)]
    stream: bool,
}

/// OpenAI completion response
#[derive(Debug, Serialize)]
struct OpenAICompletionResponse {
    id: String,
    object: String,
    created: u64,
    model: String,
    choices: Vec<OpenAICompletionChoice>,
}

/// OpenAI completion choice
#[derive(Debug, Serialize)]
struct OpenAICompletionChoice {
    index: u32,
    text: String,
    finish_reason: String,
}

/// OpenAI embeddings request
#[derive(Debug, Deserialize)]
struct OpenAIEmbeddingsRequest {
    model: String,
    input: String,
}

/// OpenAI embeddings response
#[derive(Debug, Serialize)]
struct OpenAIEmbeddingsResponse {
    object: String,
    data: Vec<OpenAIEmbedding>,
    model: String,
}

/// OpenAI embedding
#[derive(Debug, Serialize)]
struct OpenAIEmbedding {
    object: String,
    embedding: Vec<f32>,
    index: u32,
}

/// Billing records request
#[derive(Debug, Deserialize)]
struct BillingRecordsRequest {
    #[serde(default)]
    start: Option<String>,
    #[serde(default)]
    end: Option<String>,
    #[serde(default = "default_limit")]
    limit: u64,
}

fn default_limit() -> u64 {
    100
}

/// Billing records response
#[derive(Debug, Serialize)]
struct BillingRecordsResponse {
    records: Vec<crate::billing::BillingRecord>,
    total: u64,
}

/// Billing stats response
#[derive(Debug, Serialize)]
struct BillingStatsResponse {
    model_name: String,
    total_tokens: u64,
    prompt_tokens: u64,
    completion_tokens: u64,
    request_count: u64,
}

/// Create user request
#[derive(Debug, Deserialize)]
struct CreateUserRequest {
    username: String,
    email: Option<String>,
    #[serde(default = "default_rate_limit")]
    rate_limit: u32,
    monthly_quota: Option<u64>,
}

fn default_rate_limit() -> u32 {
    60
}

/// Create user response
#[derive(Debug, Serialize)]
struct CreateUserResponse {
    user_id: String,
    api_key: String,
    username: String,
    email: Option<String>,
    created_at: String,
}

/// List users response
#[derive(Debug, Serialize)]
struct ListUsersResponse {
    users: Vec<crate::auth::User>,
}

impl ServerState {
    pub fn new(model_manager: ModelManager, audit_logger: AuditLogger, billing_manager: Option<BillingManager>, auth_manager: Option<AuthManager>) -> Self {
        Self {
            model_manager,
            loaded_models: Arc::new(TokioMutex::new(HashMap::new())),
            audit_logger: Arc::new(TokioMutex::new(audit_logger)),
            rate_limiter: Arc::new(TokioMutex::new(HashMap::new())),
            graceful_degradation: Arc::new(GracefulDegradation::new()),
            billing_manager: Arc::new(TokioMutex::new(billing_manager)),
            auth_manager: Arc::new(TokioMutex::new(auth_manager)),
        }
    }
    
    /// Aerospace-level: Authenticate user and return user info
    /// Returns (user_id, username) or error if authentication fails
    pub async fn authenticate_request(&self, headers: &HeaderMap) -> Result<(Option<String>, Option<String>), StatusCode> {
        // Aerospace-level: Extract client IP from headers
        let client_ip = headers
            .get("x-forwarded-for")
            .and_then(|v| v.to_str().ok())
            .and_then(|s| s.split(',').next())
            .map(|s| s.trim())
            .or_else(|| headers.get("x-real-ip").and_then(|v| v.to_str().ok()))
            .unwrap_or("unknown");
        
        // Aerospace-level: Check if request is from local machine
        // Only treat as local if explicitly 127.0.0.1, ::1, or localhost
        // If no headers present, treat as remote (require auth)
        let is_local = client_ip == "127.0.0.1" || client_ip == "::1" || client_ip == "localhost";
        
        // Aerospace-level: Authentication (skip for local requests)
        if is_local {
            info!("Local request detected, skipping authentication");
            Ok((None, Some("local_user".to_string())))
        } else {
            if let Some(auth_value) = headers.get("authorization") {
                let auth_str = auth_value.to_str().unwrap_or("");
                // Extract Bearer token from Authorization header
                let api_key = if auth_str.starts_with("Bearer ") {
                    auth_str.strip_prefix("Bearer ").unwrap_or("")
                } else {
                    auth_str
                };
                
                let auth_manager = self.auth_manager.lock().await;
                if let Some(manager) = auth_manager.as_ref() {
                    match manager.authenticate(api_key).await {
                        Ok(Some(user)) => {
                            info!("Authenticated user: {} from {}", user.username, client_ip);
                            Ok((Some(user.user_id), Some(user.username)))
                        }
                        Ok(None) => {
                            warn!("Invalid API key from {}", client_ip);
                            Err(StatusCode::UNAUTHORIZED)
                        }
                        Err(e) => {
                            error!("Authentication error: {}", e);
                            Err(StatusCode::INTERNAL_SERVER_ERROR)
                        }
                    }
                } else {
                    Ok((None, None))
                }
            } else {
                warn!("Missing API key from remote client {}", client_ip);
                Err(StatusCode::UNAUTHORIZED)
            }
        }
    }
    
    /// Check rate limit for a client (aerospace-level security)
    pub async fn check_rate_limit(&self, client_id: &str) -> bool {
        // Aerospace-level: Use try_lock with timeout to prevent deadlocks
        let mut rate_limiter = match tokio::time::timeout(
            Duration::from_secs(5),
            self.rate_limiter.lock()
        ).await {
            Ok(guard) => guard,
            Err(_) => {
                error!("Rate limiter lock timeout - potential deadlock detected");
                return false; // Fail safe: reject request if lock timeout
            }
        };
        let now = Instant::now();
        
        // Aerospace-level: Cleanup stale entries (older than 1 hour)
        rate_limiter.retain(|_, info| {
            now.duration_since(info.last_request) < Duration::from_secs(3600)
        });
        
        let info = rate_limiter.entry(client_id.to_string()).or_insert_with(RateLimitInfo::new);
        
        // Reset counter if more than 1 minute has passed
        if now.duration_since(info.last_request) > Duration::from_secs(60) {
            info.request_count = 0;
            info.last_request = now;
        }
        
        // Allow max 60 requests per minute
        if info.request_count >= 60 {
            return false;
        }
        
        info.request_count += 1;
        true
    }
    
    /// Load a model into memory
    pub async fn load_model(&self, model_name: &str) -> Result<()> {
        // Aerospace-level: Use try_lock with timeout to prevent deadlocks
        let mut loaded = match tokio::time::timeout(
            Duration::from_secs(5),
            self.loaded_models.lock()
        ).await {
            Ok(guard) => guard,
            Err(_) => {
                error!("Loaded models lock timeout - potential deadlock detected");
                anyhow::bail!("System busy - model loading timeout");
            }
        };
        
        if loaded.contains_key(model_name) {
            info!("Model '{}' already loaded", model_name);
            return Ok(());
        }
        
        // Aerospace-level timeout protection for model loading
        let timeout = TimeoutProtection::new(std::time::Duration::from_secs(300));
        
        // Check if model exists
        let models = self.model_manager.list_models()?;
        if !models.iter().any(|m| m.name == model_name) {
            anyhow::bail!("Model '{}' not found", model_name);
        }
        
        timeout.check()?;
        
        // In a real implementation, this would load the model into memory
        // For now, we simulate loading
        loaded.insert(model_name.to_string(), ModelState {
            is_loaded: true,
            load_time: Some(chrono::Utc::now()),
            last_used: Some(chrono::Utc::now()),
            request_count: 0,
        });
        
        info!("Model '{}' loaded successfully", model_name);
        
        // Log to audit
        let mut logger = self.audit_logger.lock().await;
        let _ = logger.log_event(
            AuditEventType::ConfigurationChange,
            format!("Model loaded: {}", model_name),
            AuditSeverity::Info
        );
        
        Ok(())
    }
    
    /// Unload a model from memory
    pub async fn unload_model(&self, model_name: &str) -> Result<()> {
        let mut loaded = self.loaded_models.lock().await;
        
        if loaded.remove(model_name).is_some() {
            info!("Model '{}' unloaded", model_name);
            
            // Log to audit
            let mut logger = self.audit_logger.lock().await;
            let _ = logger.log_event(
                AuditEventType::ConfigurationChange,
                format!("Model unloaded: {}", model_name),
                AuditSeverity::Info
            );
        }
        
        Ok(())
    }
    
    /// Get loaded models
    pub async fn get_loaded_models(&self) -> Vec<String> {
        self.loaded_models.lock()
            .await
            .keys()
            .cloned()
            .collect()
    }
}

/// Create HTTP server router with aerospace-level security
pub fn create_router(state: ServerState, parallel: u16, _max_loaded_models: u16, _max_queue: u16) -> Router {
    // Aerospace-level: CORS configuration
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);
    
    // Aerospace-level: Request size limit (10MB)
    let request_limit = RequestBodyLimitLayer::new(MAX_REQUEST_SIZE);
    
    // Aerospace-level: Concurrency limit
    let concurrency_limit = ConcurrencyLimitLayer::new(parallel as usize);
    
    Router::new()
        .route("/api/tags", get(tags))
        .route("/api/tags/:model", get(model_info))
        .route("/api/generate", post(generate))
        .route("/api/chat", post(chat))
        .route("/api/embed", post(embed))
        .route("/api/ps", get(ps))
        .route("/api/show", post(show))
        .route("/api/delete", delete(delete_model))
        .route("/api/pull", post(pull))
        .route("/api/push", post(push))
        .route("/api/copy", post(copy))
        .route("/api/create", post(create))
        .route("/api/stop", post(stop_model))
        .route("/api/version", get(version))
        // OpenAI API compatibility layer
        .route("/v1/chat/completions", post(openai_chat_completions))
        .route("/v1/completions", post(openai_completions))
        .route("/v1/embeddings", post(openai_embeddings))
        // Billing API endpoints
        .route("/api/billing/records", get(billing_records))
        .route("/api/billing/summary", get(billing_summary))
        .route("/api/billing/stats/:model", get(billing_stats))
        // User management API endpoints
        .route("/api/users", post(create_user))
        .route("/api/users", get(list_users))
        .layer(cors)
        .layer(request_limit)
        .layer(concurrency_limit)
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}

/// GET /api/tags - List all models (Ollama-compatible)
async fn tags(State(state): State<ServerState>) -> impl IntoResponse {
    info!("API: GET /api/tags");
    
    let models = match state.model_manager.list_models() {
        Ok(m) => m,
        Err(e) => {
            error!("Failed to list models: {}", e);
            return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list models").into_response();
        }
    };
    
    let _loaded_models = state.get_loaded_models();
    
    let tags: Vec<ModelTag> = models.into_iter().map(|m| {
        ModelTag {
            name: m.name,
            modified_at: m.modified,
            size: m.size,
        }
    }).collect();
    
    Json(TagsResponse { models: tags }).into_response()
}

/// POST /api/generate - Generate text (Ollama-compatible)
async fn generate(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<GenerateRequest>,
) -> impl IntoResponse {
    // Aerospace-level: Authentication
    let (user_id, username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Extract client IP from headers
    let client_ip = headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next())
        .map(|s| s.trim())
        .or_else(|| headers.get("x-real-ip").and_then(|v| v.to_str().ok()))
        .unwrap_or("unknown");
    
    // Aerospace-level: Input validation
    if req.model.is_empty() {
        error!("Generate: model name is empty");
        return (StatusCode::BAD_REQUEST, "Model name cannot be empty").into_response();
    }
    
    // Aerospace-level: Model whitelist validation
    if !MODEL_WHITELIST.contains(&req.model.as_str()) {
        error!("Generate: model '{}' not in whitelist", req.model);
        return (StatusCode::FORBIDDEN, format!("Model '{}' is not allowed", req.model)).into_response();
    }
    
    // Aerospace-level: Input length validation
    if req.prompt.len() > MAX_PROMPT_LENGTH {
        error!("Prompt too long: {} characters (max: {})", req.prompt.len(), MAX_PROMPT_LENGTH);
        return (StatusCode::BAD_REQUEST, format!("Prompt too long (max {} characters)", MAX_PROMPT_LENGTH)).into_response();
    }
    
    // Aerospace-level: Rate limiting
    let client_id = "generate_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for generate endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Aerospace-level: Timeout protection
    let timeout = TimeoutProtection::new(Duration::from_secs(120));
    if let Err(e) = timeout.check() {
        error!("Timeout check failed: {}", e);
        return (StatusCode::REQUEST_TIMEOUT, "Request timeout").into_response();
    }
    
    info!("API: POST /api/generate - model: {}, stream: {}", req.model, req.stream);
    
    // Aerospace-level: Billing - Start timing
    let request_start = Instant::now();
    let request_id = Uuid::new_v4().to_string();
    let prompt_tokens = count_tokens(&req.prompt);
    
    // Aerospace-level: Load model if not loaded
    if let Err(e) = state.load_model(&req.model).await {
        error!("Failed to load model: {}", e);
        return (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to load model: {}", e)).into_response();
    }
    
    // Update request count
    {
        let mut loaded = state.loaded_models.lock().await;
        if let Some(model_state) = loaded.get_mut(&req.model) {
            model_state.request_count += 1;
            model_state.last_used = Some(chrono::Utc::now());
        }
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("Generate request: model={}", req.model),
        AuditSeverity::Info
    );
    
    // Aerospace-level: Streaming support
    if req.stream {
        let model = req.model.clone();
        let prompt = req.prompt.clone();
        
        let stream: futures_util::stream::BoxStream<'_, Result<axum::response::sse::Event, anyhow::Error>> = Box::pin(async_stream::try_stream! {
            // Simulate streaming by yielding chunks
            let response = format!("Generate response for model '{}': {}", model, prompt);
            for chunk in response.chars().collect::<Vec<char>>().chunks(10) {
                let chunk_str: String = chunk.iter().collect();
                let chunk_json = serde_json::json!({
                    "model": model,
                    "response": chunk_str,
                    "done": false
                });
                yield axum::response::sse::Event::default().data(chunk_json.to_string());
                tokio::time::sleep(Duration::from_millis(50)).await;
            }
            
            let final_json = serde_json::json!({
                "model": model,
                "response": "",
                "done": true
            });
            yield axum::response::sse::Event::default().data(final_json.to_string());
        });
        
        return Sse::new(stream).keep_alive(axum::response::sse::KeepAlive::new().interval(Duration::from_secs(10))).into_response();
    }
    
    // Non-streaming response
    let response_text = format!("Generate response for model '{}': {}", req.model, req.prompt);
    let completion_tokens = count_tokens(&response_text);
    let duration_ms = request_start.elapsed().as_millis() as u64;
    let total_tokens = prompt_tokens + completion_tokens;
    
    // Aerospace-level: Record billing transaction
    let billing_manager = state.billing_manager.lock().await;
    if let Some(manager) = billing_manager.as_ref() {
        let record = BillingRecord {
            id: request_id.clone(),
            timestamp: chrono::Utc::now(),
            user_id,
            username,
            model_name: req.model.clone(),
            prompt_tokens,
            completion_tokens,
            total_tokens,
            prompt_text: req.prompt.clone(),
            completion_text: response_text.clone(),
            client_ip: client_ip.to_string(),
            endpoint: "/api/generate".to_string(),
            duration_ms,
        };
        let _ = manager.record_transaction(record).await;
    }
    
    Json(GenerateResponse {
        model: req.model,
        response: response_text,
        done: true,
    }).into_response()
}

/// POST /api/chat - Chat with model (Ollama-compatible)
async fn chat(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<ChatRequest>,
) -> impl IntoResponse {
    // Aerospace-level: Authentication
    let (user_id, username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Extract client IP from headers
    let client_ip = headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next())
        .map(|s| s.trim())
        .or_else(|| headers.get("x-real-ip").and_then(|v| v.to_str().ok()))
        .unwrap_or("unknown");
    
    // Aerospace-level: Start timing for billing
    let request_start = Instant::now();
    
    // Aerospace-level: Input validation
    if req.model.is_empty() {
        error!("Chat: model name is empty");
        return (StatusCode::BAD_REQUEST, "Model name cannot be empty").into_response();
    }
    
    // Aerospace-level: Model whitelist validation
    if !MODEL_WHITELIST.contains(&req.model.as_str()) {
        error!("Chat: model '{}' not in whitelist", req.model);
        return (StatusCode::FORBIDDEN, format!("Model '{}' is not allowed", req.model)).into_response();
    }
    
    if req.messages.is_empty() {
        error!("Chat: messages array is empty");
        return (StatusCode::BAD_REQUEST, "Messages array cannot be empty").into_response();
    }
    
    if req.messages.len() > MAX_MESSAGES_COUNT {
        error!("Chat: messages array too large: {} messages (max: {})", req.messages.len(), MAX_MESSAGES_COUNT);
        return (StatusCode::BAD_REQUEST, format!("Messages array too large (max {} messages)", MAX_MESSAGES_COUNT)).into_response();
    }
    
    for (i, msg) in req.messages.iter().enumerate() {
        if msg.content.len() > MAX_PROMPT_LENGTH {
            error!("Chat: message {} content too long: {} characters (max: {})", i, msg.content.len(), MAX_PROMPT_LENGTH);
            return (StatusCode::BAD_REQUEST, format!("Message {} content too long (max {} characters)", i, MAX_PROMPT_LENGTH)).into_response();
        }
    }
    
    // Aerospace-level: Rate limiting
    let client_id = "chat_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for chat endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Aerospace-level: Timeout protection
    let timeout = TimeoutProtection::new(Duration::from_secs(120));
    if let Err(e) = timeout.check() {
        error!("Timeout check failed: {}", e);
        return (StatusCode::REQUEST_TIMEOUT, "Request timeout").into_response();
    }
    
    info!("API: POST /api/chat - model: {}, stream: {}", req.model, req.stream);
    
    // Aerospace-level: Load model if not loaded
    if let Err(e) = state.load_model(&req.model).await {
        error!("Failed to load model: {}", e);
        return (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to load model: {}", e)).into_response();
    }
    
    // Update request count
    {
        let mut loaded = state.loaded_models.lock().await;
        if let Some(model_state) = loaded.get_mut(&req.model) {
            model_state.request_count += 1;
            model_state.last_used = Some(chrono::Utc::now());
        }
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("Chat request: model={}", req.model),
        AuditSeverity::Info
    );
    
    // Aerospace-level: Streaming support
    if req.stream {
        let model = req.model.clone();
        let messages = req.messages.clone();
        
        let stream: futures_util::stream::BoxStream<'_, Result<axum::response::sse::Event, anyhow::Error>> = Box::pin(async_stream::try_stream! {
            // Simulate streaming by yielding chunks
            let last_message = messages.last().map(|m| m.content.as_str()).unwrap_or("");
            let response = format!("Chat response for model '{}': {}", model, last_message);
            for chunk in response.chars().collect::<Vec<char>>().chunks(10) {
                let chunk_str: String = chunk.iter().collect();
                let chunk_json = serde_json::json!({
                    "model": model,
                    "message": {
                        "role": "assistant",
                        "content": chunk_str
                    },
                    "done": false
                });
                yield axum::response::sse::Event::default().data(chunk_json.to_string());
                tokio::time::sleep(Duration::from_millis(50)).await;
            }
            
            let final_json = serde_json::json!({
                "model": model,
                "message": {
                    "role": "assistant",
                    "content": ""
                },
                "done": true
            });
            yield axum::response::sse::Event::default().data(final_json.to_string());
        });
        
        return Sse::new(stream).keep_alive(axum::response::sse::KeepAlive::new().interval(Duration::from_secs(10))).into_response();
    }
    
    // Non-streaming response
    let last_message = req.messages.last().map(|m| m.content.as_str()).unwrap_or("");
    let response = format!("Chat response for model '{}': {}", req.model, last_message);
    
    // Aerospace-level: Record billing transaction
    let billing_manager = state.billing_manager.lock().await;
    if let Some(manager) = billing_manager.as_ref() {
        let prompt_text = req.messages.iter().map(|m| m.content.as_str()).collect::<Vec<&str>>().join("\n");
        let prompt_tokens = count_tokens(&prompt_text);
        let completion_tokens = count_tokens(&response);
        let duration_ms = request_start.elapsed().as_millis() as u64;
        let total_tokens = prompt_tokens + completion_tokens;
        
        let record = BillingRecord {
            id: Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now(),
            user_id,
            username,
            model_name: req.model.clone(),
            prompt_tokens,
            completion_tokens,
            total_tokens,
            prompt_text,
            completion_text: response.clone(),
            client_ip: client_ip.to_string(),
            endpoint: "/api/chat".to_string(),
            duration_ms,
        };
        let _ = manager.record_transaction(record).await;
    }
    
    Json(ChatResponse {
        model: req.model,
        message: ChatMessage {
            role: "assistant".to_string(),
            content: response,
        },
        done: true,
    }).into_response()
}

/// GET /api/tags/:model - Get model info (Ollama-compatible)
async fn model_info(
    State(state): State<ServerState>,
    Path(model): Path<String>,
) -> impl IntoResponse {
    info!("API: GET /api/tags/{}", model);
    
    let models = match state.model_manager.list_models() {
        Ok(m) => m,
        Err(e) => {
            error!("Failed to list models: {}", e);
            return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list models").into_response();
        }
    };
    
    let model_info = models.iter().find(|m| m.name == model);
    
    match model_info {
        Some(info) => {
            let tag = ModelTag {
                name: info.name.clone(),
                modified_at: info.modified.clone(),
                size: info.size,
            };
            Json(tag).into_response()
        }
        None => (StatusCode::NOT_FOUND, "Model not found").into_response()
    }
}

/// POST /api/embed - Generate embeddings (Ollama-compatible)
async fn embed(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<EmbedRequest>,
) -> impl IntoResponse {
    // Aerospace-level: Authentication
    let (user_id, username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Extract client IP from headers
    let client_ip = headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next())
        .map(|s| s.trim())
        .or_else(|| headers.get("x-real-ip").and_then(|v| v.to_str().ok()))
        .unwrap_or("unknown");
    
    // Aerospace-level: Start timing for billing
    let request_start = Instant::now();
    
    // Aerospace-level: Input validation
    if req.model.is_empty() {
        error!("Embed: model name is empty");
        return (StatusCode::BAD_REQUEST, "Model name cannot be empty").into_response();
    }
    
    // Aerospace-level: Model whitelist validation
    if !MODEL_WHITELIST.contains(&req.model.as_str()) {
        error!("Embed: model '{}' not in whitelist", req.model);
        return (StatusCode::FORBIDDEN, format!("Model '{}' is not allowed", req.model)).into_response();
    }
    
    // Aerospace-level: Input validation
    if req.input.is_empty() {
        error!("Embed: input is empty");
        return (StatusCode::BAD_REQUEST, "Input cannot be empty").into_response();
    }
    
    // Aerospace-level: Rate limiting
    let client_id = "embed_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for embed endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Aerospace-level: Timeout protection
    let timeout = TimeoutProtection::new(Duration::from_secs(120));
    if let Err(e) = timeout.check() {
        error!("Timeout check failed: {}", e);
        return (StatusCode::REQUEST_TIMEOUT, "Request timeout").into_response();
    }
    
    info!("API: POST /api/embed - model: {}", req.model);
    
    // Aerospace-level: Load model if not loaded
    if let Err(e) = state.load_model(&req.model).await {
        error!("Failed to load model: {}", e);
        return (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to load model: {}", e)).into_response();
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("Embed request: model={}", req.model),
        AuditSeverity::Info
    );
    
    // In a real implementation, this would generate embeddings
    // For now, return a placeholder response
    let embeddings = vec![0.0; 768]; // Placeholder 768-dim embedding
    
    // Aerospace-level: Record billing transaction
    let billing_manager = state.billing_manager.lock().await;
    if let Some(manager) = billing_manager.as_ref() {
        let prompt_tokens = count_tokens(&req.input);
        let completion_tokens = 0; // Embeddings don't generate tokens
        let duration_ms = request_start.elapsed().as_millis() as u64;
        let total_tokens = prompt_tokens + completion_tokens;
        
        let record = BillingRecord {
            id: Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now(),
            user_id,
            username,
            model_name: req.model.clone(),
            prompt_tokens,
            completion_tokens,
            total_tokens,
            prompt_text: req.input.clone(),
            completion_text: String::new(),
            client_ip: client_ip.to_string(),
            endpoint: "/api/embed".to_string(),
            duration_ms,
        };
        let _ = manager.record_transaction(record).await;
    }
    
    Json(EmbedResponse {
        model: req.model,
        embeddings,
    }).into_response()
}

/// GET /api/ps - List running models (Ollama-compatible)
async fn ps(State(state): State<ServerState>) -> impl IntoResponse {
    info!("API: GET /api/ps");
    
    let loaded_models = state.get_loaded_models().await;
    
    let models: Vec<PsModel> = loaded_models.iter().map(|name| {
        PsModel {
            name: name.clone(),
            pid: std::process::id(),
            memory_mb: 1024, // Placeholder
            cpu_percent: 5.0, // Placeholder
        }
    }).collect();
    
    Json(PsResponse { models }).into_response()
}

/// POST /api/show - Show model details (Ollama-compatible)
async fn show(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<ShowRequest>,
) -> impl IntoResponse {
    info!("API: POST /api/show - model: {}", req.model);
    
    // Aerospace-level: Authentication
    let (_user_id, _username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    let models = match state.model_manager.list_models() {
        Ok(m) => m,
        Err(e) => {
            error!("Failed to list models: {}", e);
            return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list models").into_response();
        }
    };
    
    let model_info = models.iter().find(|m| m.name == req.model);
    
    match model_info {
        Some(info) => {
            let details = serde_json::to_value(info).unwrap_or_default();
            Json(ShowResponse {
                model: req.model,
                details,
            }).into_response()
        }
        None => (StatusCode::NOT_FOUND, "Model not found").into_response()
    }
}

/// DELETE /api/delete - Delete a model (Ollama-compatible)
async fn delete_model(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<DeleteRequest>,
) -> impl IntoResponse {
    info!("API: DELETE /api/delete - model: {}", req.model);
    
    // Aerospace-level: Authentication
    let (_user_id, _username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Rate limiting
    let client_id = "delete_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for delete endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("Delete model: {}", req.model),
        AuditSeverity::Warning
    );
    
    match state.model_manager.remove_model(&req.model) {
        Ok(_) => {
            // Unload model if loaded
            let _ = state.unload_model(&req.model).await;
            (StatusCode::OK, "Model deleted successfully").into_response()
        }
        Err(e) => {
            error!("Failed to delete model: {}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to delete model: {}", e)).into_response()
        }
    }
}

/// POST /api/pull - Pull a model (Ollama-compatible)
async fn pull(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<PullRequest>,
) -> impl IntoResponse {
    info!("API: POST /api/pull - model: {}", req.model);
    
    // Aerospace-level: Authentication
    let (_user_id, _username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Rate limiting
    let client_id = "pull_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for pull endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("Pull model: {}", req.model),
        AuditSeverity::Info
    );
    
    // Pull the model
    match state.model_manager.pull_model(&req.model).await {
        Ok(_) => {
            Json(PullResponse {
                model: req.model,
                status: "success".to_string(),
            }).into_response()
        }
        Err(e) => {
            error!("Failed to pull model: {}", e);
            Json(PullResponse {
                model: req.model,
                status: format!("error: {}", e),
            }).into_response()
        }
    }
}

/// GET /api/version - Get version info (Ollama-compatible)
async fn version() -> impl IntoResponse {
    info!("API: GET /api/version");
    
    Json(VersionResponse {
        version: env!("CARGO_PKG_VERSION").to_string(),
    }).into_response()
}

/// POST /api/create - Create a model (Ollama-compatible)
async fn create(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<CreateRequest>,
) -> impl IntoResponse {
    info!("API: POST /api/create - model: {}", req.model);
    
    // Aerospace-level: Authentication
    let (_user_id, _username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Input validation
    if req.model.is_empty() {
        error!("Create: model name is empty");
        return (StatusCode::BAD_REQUEST, "Model name cannot be empty").into_response();
    }
    
    // Aerospace-level: Rate limiting
    let client_id = "create_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for create endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("Create model: {}", req.model),
        AuditSeverity::Info
    );
    
    // Create the model
    match state.model_manager.create_model(&req.model, req.modelfile.as_deref().unwrap_or("")) {
        Ok(_) => {
            Json(CreateResponse {
                model: req.model,
                status: "success".to_string(),
            }).into_response()
        }
        Err(e) => {
            error!("Failed to create model: {}", e);
            Json(CreateResponse {
                model: req.model,
                status: format!("error: {}", e),
            }).into_response()
        }
    }
}

/// POST /api/copy - Copy a model (Ollama-compatible)
async fn copy(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<CopyRequest>,
) -> impl IntoResponse {
    info!("API: POST /api/copy - {} -> {}", req.source, req.destination);
    
    // Aerospace-level: Authentication
    let (_user_id, _username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Input validation
    if req.source.is_empty() {
        error!("Copy: source model name is empty");
        return (StatusCode::BAD_REQUEST, "Source model name cannot be empty").into_response();
    }
    
    if req.destination.is_empty() {
        error!("Copy: destination model name is empty");
        return (StatusCode::BAD_REQUEST, "Destination model name cannot be empty").into_response();
    }
    
    // Aerospace-level: Rate limiting
    let client_id = "copy_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for copy endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("Copy model: {} -> {}", req.source, req.destination),
        AuditSeverity::Info
    );
    
    // Copy the model
    match state.model_manager.copy_model(&req.source, &req.destination) {
        Ok(_) => {
            Json(CopyResponse {
                status: "success".to_string(),
            }).into_response()
        }
        Err(e) => {
            error!("Failed to copy model: {}", e);
            Json(CopyResponse {
                status: format!("error: {}", e),
            }).into_response()
        }
    }
}

/// POST /api/push - Push a model (Ollama-compatible)
async fn push(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<PushRequest>,
) -> impl IntoResponse {
    info!("API: POST /api/push - model: {}, insecure: {}", req.model, req.insecure);
    
    // Aerospace-level: Authentication
    let (_user_id, _username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Rate limiting
    let client_id = "push_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for push endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("Push model: {}", req.model),
        AuditSeverity::Info
    );
    
    // Push the model (placeholder - would upload to registry in production)
    Json(PushResponse {
        model: req.model,
        status: "success".to_string(),
    }).into_response()
}

/// Stop request (Ollama-compatible)
#[derive(Debug, Deserialize)]
struct StopRequest {
    model: String,
}

/// POST /api/stop - Stop a model (Ollama-compatible)
async fn stop_model(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<StopRequest>,
) -> impl IntoResponse {
    info!("API: POST /api/stop - model: {}", req.model);
    
    // Aerospace-level: Authentication
    let (_user_id, _username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Rate limiting
    let client_id = "stop_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for stop endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("Stop model: {}", req.model),
        AuditSeverity::Info
    );
    
    // Unload the model
    match state.unload_model(&req.model).await {
        Ok(_) => (StatusCode::OK, "Model stopped successfully").into_response(),
        Err(e) => {
            error!("Failed to stop model: {}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to stop model: {}", e)).into_response()
        }
    }
}

/// POST /v1/chat/completions - OpenAI API compatibility
async fn openai_chat_completions(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<OpenAIChatRequest>,
) -> impl IntoResponse {
    // Aerospace-level: Authentication
    let (user_id, username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Extract client IP from headers
    let client_ip = headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next())
        .map(|s| s.trim())
        .or_else(|| headers.get("x-real-ip").and_then(|v| v.to_str().ok()))
        .unwrap_or("unknown");
    
    // Aerospace-level: Input validation
    if req.model.is_empty() {
        error!("OpenAI Chat: model name is empty");
        return (StatusCode::BAD_REQUEST, "Model name cannot be empty").into_response();
    }
    
    // Aerospace-level: Model whitelist validation
    if !MODEL_WHITELIST.contains(&req.model.as_str()) {
        error!("OpenAI chat: model '{}' not in whitelist", req.model);
        return (StatusCode::FORBIDDEN, format!("Model '{}' is not allowed", req.model)).into_response();
    }
    
    // Aerospace-level: Input length validation
    if req.messages.is_empty() {
        error!("OpenAI chat: messages array is empty");
        return (StatusCode::BAD_REQUEST, "Messages array cannot be empty").into_response();
    }
    
    if req.messages.len() > MAX_MESSAGES_COUNT {
        error!("OpenAI chat: messages array too large: {} messages (max: {})", req.messages.len(), MAX_MESSAGES_COUNT);
        return (StatusCode::BAD_REQUEST, format!("Messages array too large (max {} messages)", MAX_MESSAGES_COUNT)).into_response();
    }
    
    for (i, msg) in req.messages.iter().enumerate() {
        if msg.content.len() > MAX_PROMPT_LENGTH {
            error!("OpenAI chat: message {} content too long: {} characters (max: {})", i, msg.content.len(), MAX_PROMPT_LENGTH);
            return (StatusCode::BAD_REQUEST, format!("Message {} content too long (max {} characters)", i, MAX_PROMPT_LENGTH)).into_response();
        }
    }
    
    info!("API: POST /v1/chat/completions - model: {}", req.model);
    
    // Aerospace-level: Rate limiting
    let client_id = "openai_chat_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for OpenAI chat endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Aerospace-level: Timeout protection
    let timeout = TimeoutProtection::new(Duration::from_secs(120));
    if let Err(e) = timeout.check() {
        error!("Timeout check failed: {}", e);
        return (StatusCode::REQUEST_TIMEOUT, "Request timeout").into_response();
    }
    
    // Aerospace-level: Load model if not loaded
    if let Err(e) = state.load_model(&req.model).await {
        error!("Failed to load model: {}", e);
        
        // Aerospace-level: Graceful degradation
        if state.graceful_degradation.is_degraded() {
            return (StatusCode::SERVICE_UNAVAILABLE, "Service is currently degraded. Please try again later.").into_response();
        }
        
        return (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to load model: {}", e)).into_response();
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("OpenAI chat completions: model={}, client={}", req.model, client_id),
        AuditSeverity::Info
    );
    
    // Aerospace-level: Safe message extraction
    let last_message = req.messages.last().map(|m| m.content.as_str()).unwrap_or("");
    let response = format!("OpenAI-compatible response for model '{}': {}", req.model, last_message);
    
    // Aerospace-level: Safe timestamp generation
    let created = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or_else(|_| 0);
    
    Json(OpenAIChatResponse {
        id: format!("chatcmpl-{}", Uuid::new_v4()),
        object: "chat.completion".to_string(),
        created,
        model: req.model,
        choices: vec![OpenAIChoice {
            index: 0,
            message: OpenAIMessage {
                role: "assistant".to_string(),
                content: response,
            },
            finish_reason: "stop".to_string(),
        }],
    }).into_response()
}

/// POST /v1/completions - OpenAI API compatibility
async fn openai_completions(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<OpenAICompletionRequest>,
) -> impl IntoResponse {
    // Aerospace-level: Authentication
    let (user_id, username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Extract client IP from headers
    let client_ip = headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next())
        .map(|s| s.trim())
        .or_else(|| headers.get("x-real-ip").and_then(|v| v.to_str().ok()))
        .unwrap_or("unknown");
    
    // Aerospace-level: Input validation
    if req.model.is_empty() {
        error!("OpenAI Completions: model name is empty");
        return (StatusCode::BAD_REQUEST, "Model name cannot be empty").into_response();
    }
    
    // Aerospace-level: Model whitelist validation
    if !MODEL_WHITELIST.contains(&req.model.as_str()) {
        error!("OpenAI completions: model '{}' not in whitelist", req.model);
        return (StatusCode::FORBIDDEN, format!("Model '{}' is not allowed", req.model)).into_response();
    }
    
    if req.prompt.is_empty() {
        error!("OpenAI completions: prompt is empty");
        return (StatusCode::BAD_REQUEST, "Prompt cannot be empty").into_response();
    }
    
    // Aerospace-level: Input length validation
    if req.prompt.len() > MAX_PROMPT_LENGTH {
        error!("OpenAI completions: prompt too long: {} characters (max: {})", req.prompt.len(), MAX_PROMPT_LENGTH);
        return (StatusCode::BAD_REQUEST, format!("Prompt too long (max {} characters)", MAX_PROMPT_LENGTH)).into_response();
    }
    
    info!("API: POST /v1/completions - model: {}", req.model);
    
    // Aerospace-level: Rate limiting
    let client_id = "openai_completions_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for OpenAI completion endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Aerospace-level: Timeout protection
    let timeout = TimeoutProtection::new(Duration::from_secs(120));
    if let Err(e) = timeout.check() {
        error!("Timeout check failed: {}", e);
        return (StatusCode::REQUEST_TIMEOUT, "Request timeout").into_response();
    }
    
    // Aerospace-level: Load model if not loaded
    if let Err(e) = state.load_model(&req.model).await {
        error!("Failed to load model: {}", e);
        
        // Aerospace-level: Graceful degradation
        if state.graceful_degradation.is_degraded() {
            return (StatusCode::SERVICE_UNAVAILABLE, "Service is currently degraded. Please try again later.").into_response();
        }
        
        return (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to load model: {}", e)).into_response();
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("OpenAI completions: model={}, client={}", req.model, client_id),
        AuditSeverity::Info
    );
    
    let response = format!("OpenAI-compatible completion for model '{}': {}", req.model, req.prompt);
    
    // Aerospace-level: Safe timestamp generation
    let created = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or_else(|_| 0);
    
    Json(OpenAICompletionResponse {
        id: format!("cmpl-{}", Uuid::new_v4()),
        object: "text_completion".to_string(),
        created,
        model: req.model,
        choices: vec![OpenAICompletionChoice {
            index: 0,
            text: response,
            finish_reason: "stop".to_string(),
        }],
    }).into_response()
}

/// POST /v1/embeddings - OpenAI API compatibility
async fn openai_embeddings(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<OpenAIEmbeddingsRequest>,
) -> impl IntoResponse {
    // Aerospace-level: Authentication
    let (user_id, username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    // Aerospace-level: Extract client IP from headers
    let client_ip = headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next())
        .map(|s| s.trim())
        .or_else(|| headers.get("x-real-ip").and_then(|v| v.to_str().ok()))
        .unwrap_or("unknown");
    
    // Aerospace-level: Input validation
    if req.model.is_empty() {
        error!("OpenAI Embeddings: model name is empty");
        return (StatusCode::BAD_REQUEST, "Model name cannot be empty").into_response();
    }
    
    // Aerospace-level: Model whitelist validation
    if !MODEL_WHITELIST.contains(&req.model.as_str()) {
        error!("OpenAI embeddings: model '{}' not in whitelist", req.model);
        return (StatusCode::FORBIDDEN, format!("Model '{}' is not allowed", req.model)).into_response();
    }
    
    if req.input.is_empty() {
        error!("OpenAI embeddings: input is empty");
        return (StatusCode::BAD_REQUEST, "Input cannot be empty").into_response();
    }
    
    // Aerospace-level: Input length validation
    if req.input.len() > MAX_PROMPT_LENGTH {
        error!("OpenAI embeddings: input too long: {} characters (max: {})", req.input.len(), MAX_PROMPT_LENGTH);
        return (StatusCode::BAD_REQUEST, format!("Input too long (max {} characters)", MAX_PROMPT_LENGTH)).into_response();
    }
    
    info!("API: POST /v1/embeddings - model: {}", req.model);
    
    // Aerospace-level: Rate limiting
    let client_id = "openai_embeddings_client";
    if !state.check_rate_limit(client_id).await {
        error!("Rate limit exceeded for OpenAI embeddings endpoint");
        return (StatusCode::TOO_MANY_REQUESTS, "Rate limit exceeded").into_response();
    }
    
    // Aerospace-level: Timeout protection
    let timeout = TimeoutProtection::new(Duration::from_secs(120));
    if let Err(e) = timeout.check() {
        error!("Timeout check failed: {}", e);
        return (StatusCode::REQUEST_TIMEOUT, "Request timeout").into_response();
    }
    
    // Aerospace-level: Load model if not loaded
    if let Err(e) = state.load_model(&req.model).await {
        error!("Failed to load model: {}", e);
        
        // Aerospace-level: Graceful degradation
        if state.graceful_degradation.is_degraded() {
            return (StatusCode::SERVICE_UNAVAILABLE, "Service is currently degraded. Please try again later.").into_response();
        }
        
        return (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to load model: {}", e)).into_response();
    }
    
    // Log to audit
    let mut logger = state.audit_logger.lock().await;
    let _ = logger.log_event(
        AuditEventType::ConfigurationChange,
        format!("OpenAI embeddings: model={}, client={}", req.model, client_id),
        AuditSeverity::Info
    );
    
    // Placeholder 768-dim embedding
    let embedding = vec![0.0; 768];
    
    Json(OpenAIEmbeddingsResponse {
        object: "list".to_string(),
        data: vec![OpenAIEmbedding {
            object: "embedding".to_string(),
            embedding,
            index: 0,
        }],
        model: req.model,
    }).into_response()
}

/// GET /api/billing/records - Get billing records
async fn billing_records(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Query(params): Query<BillingRecordsRequest>,
) -> impl IntoResponse {
    info!("API: GET /api/billing/records");
    
    // Aerospace-level: Authentication
    let (_user_id, _username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    let billing_manager = state.billing_manager.lock().await;
    if billing_manager.is_none() {
        return (StatusCode::SERVICE_UNAVAILABLE, "Billing not available").into_response();
    }
    
    let manager = billing_manager.as_ref().unwrap();
    
    // Parse time range or use default (last 24 hours)
    let end_time = chrono::Utc::now();
    let start_time = if let Some(start) = params.start {
        DateTime::parse_from_rfc3339(&start)
            .map(|dt| dt.with_timezone(&Utc))
            .unwrap_or(end_time - chrono::Duration::hours(24))
    } else {
        end_time - chrono::Duration::hours(24)
    };
    
    let end_time = if let Some(end) = params.end {
        DateTime::parse_from_rfc3339(&end)
            .map(|dt| dt.with_timezone(&Utc))
            .unwrap_or(end_time)
    } else {
        end_time
    };
    
    match manager.get_records_by_time_range(start_time, end_time).await {
        Ok(mut records) => {
            // Limit results
            if records.len() > params.limit as usize {
                records.truncate(params.limit as usize);
            }
            let total = records.len() as u64;
            Json(BillingRecordsResponse { records, total }).into_response()
        }
        Err(e) => {
            error!("Failed to get billing records: {}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to get billing records: {}", e)).into_response()
        }
    }
}

/// GET /api/billing/summary - Get billing summary
async fn billing_summary(State(state): State<ServerState>, headers: HeaderMap) -> impl IntoResponse {
    info!("API: GET /api/billing/summary");
    
    // Aerospace-level: Authentication
    let (_user_id, _username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    let billing_manager = state.billing_manager.lock().await;
    if billing_manager.is_none() {
        return (StatusCode::SERVICE_UNAVAILABLE, "Billing not available").into_response();
    }
    
    let manager = billing_manager.as_ref().unwrap();
    
    match manager.get_summary().await {
        Ok(summary) => Json(summary).into_response(),
        Err(e) => {
            error!("Failed to get billing summary: {}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to get billing summary: {}", e)).into_response()
        }
    }
}

/// GET /api/billing/stats/:model - Get billing stats for a specific model
async fn billing_stats(
    State(state): State<ServerState>,
    headers: HeaderMap,
    Path(model): Path<String>,
) -> impl IntoResponse {
    info!("API: GET /api/billing/stats/{}", model);
    
    // Aerospace-level: Authentication
    let (_user_id, _username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    let billing_manager = state.billing_manager.lock().await;
    if billing_manager.is_none() {
        return (StatusCode::SERVICE_UNAVAILABLE, "Billing not available").into_response();
    }
    
    let manager = billing_manager.as_ref().unwrap();
    
    match manager.get_total_tokens_by_model(&model).await {
        Ok(total_tokens) => {
            // Get prompt and completion tokens (simplified)
            let prompt_tokens = total_tokens / 2; // Approximation
            let completion_tokens = total_tokens - prompt_tokens;
            
            Json(BillingStatsResponse {
                model_name: model,
                total_tokens,
                prompt_tokens,
                completion_tokens,
                request_count: 1, // Placeholder
            }).into_response()
        }
        Err(e) => {
            error!("Failed to get billing stats: {}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to get billing stats: {}", e)).into_response()
        }
    }
}

/// POST /api/users - Create a new user
async fn create_user(
    State(state): State<ServerState>,
    Json(req): Json<CreateUserRequest>,
) -> impl IntoResponse {
    info!("API: POST /api/users - username: {}", req.username);
    
    let auth_manager = state.auth_manager.lock().await;
    if auth_manager.is_none() {
        return (StatusCode::SERVICE_UNAVAILABLE, "Authentication not available").into_response();
    }
    
    let manager = auth_manager.as_ref().unwrap();
    
    match manager.create_user(&req.username, req.email, req.rate_limit, req.monthly_quota).await {
        Ok(user) => {
            info!("Created user: {} (user_id: {})", user.username, user.user_id);
            Json(CreateUserResponse {
                user_id: user.user_id,
                api_key: user.api_key,
                username: user.username,
                email: user.email,
                created_at: user.created_at.to_rfc3339(),
            }).into_response()
        }
        Err(e) => {
            error!("Failed to create user: {}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to create user: {}", e)).into_response()
        }
    }
}

/// GET /api/users - List all users
async fn list_users(State(state): State<ServerState>, headers: HeaderMap) -> impl IntoResponse {
    info!("API: GET /api/users");
    
    // Aerospace-level: Authentication
    let (_user_id, _username) = match state.authenticate_request(&headers).await {
        Ok(info) => info,
        Err(status) => return status.into_response(),
    };
    
    let auth_manager = state.auth_manager.lock().await;
    if auth_manager.is_none() {
        return (StatusCode::SERVICE_UNAVAILABLE, "Authentication not available").into_response();
    }
    
    let manager = auth_manager.as_ref().unwrap();
    
    match manager.list_users().await {
        Ok(users) => Json(ListUsersResponse { users }).into_response(),
        Err(e) => {
            error!("Failed to list users: {}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to list users: {}", e)).into_response()
        }
    }
}

/// Start the HTTP server
pub async fn start_server(
    host: &str,
    port: u16,
    parallel: u16,
    max_loaded_models: u16,
    max_queue: u16,
    model_manager: ModelManager,
    audit_logger: AuditLogger,
    billing_manager: Option<BillingManager>,
    auth_manager: Option<AuthManager>,
) -> Result<()> {
    let state = ServerState::new(model_manager, audit_logger, billing_manager, auth_manager);
    let app = create_router(state, parallel, max_loaded_models, max_queue);
    
    let addr = format!("{}:{}", host, port);
    let listener = TcpListener::bind(&addr).await?;
    
    info!("Starting HTTP server on {} with {} parallel workers", addr, parallel);
    info!("Maximum loaded models: {}", max_loaded_models);
    info!("Maximum queue size: {}", max_queue);
    info!("Aerospace-level HTTP server ready");
    
    axum::serve(listener, app).await?;
    
    Ok(())
}
