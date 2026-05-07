// Inference Service HTTP Server
// Runs as a separate process to avoid type system conflicts with Axum handlers

use anyhow::Result;
use axum::{
    extract::{State, Json},
    http::StatusCode,
    response::IntoResponse,
    routing::post,
    Router,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::net::TcpListener;
use tracing::{info, error};

#[cfg(feature = "inference")]
use crate::inference::{InferenceEngine, ModelManager};
#[cfg(feature = "inference")]
use crate::inference::engine::GenerationParams;

/// Inference request from HTTP client
#[derive(Debug, Deserialize)]
pub struct InferenceRequest {
    pub model: String,
    pub prompt: String,
    pub max_tokens: Option<u32>,
    pub temperature: Option<f32>,
    pub top_p: Option<f32>,
    pub top_k: Option<i32>,
}

/// Inference response to HTTP client
#[derive(Debug, Serialize)]
pub struct InferenceResponse {
    pub text: String,
    pub tokens_generated: u32,
    pub prompt_tokens: u32,
    pub duration_ms: u64,
    pub tokens_per_second: f32,
    pub error: Option<String>,
}

/// POST /health - Health check endpoint
async fn health_handler() -> impl IntoResponse {
    Json(serde_json::json!({ "status": "ok" }))
}

#[cfg(feature = "inference")]
/// Inference service state
#[derive(Clone)]
pub struct InferenceServiceState {
    pub model_manager: Arc<ModelManager>,
    pub inference_engine: Arc<InferenceEngine>,
}

#[cfg(feature = "inference")]
/// Inference service
pub struct InferenceService {
    state: InferenceServiceState,
}

#[cfg(feature = "inference")]
impl InferenceService {
    pub fn new(model_manager: ModelManager, inference_engine: InferenceEngine) -> Self {
        Self {
            state: InferenceServiceState {
                model_manager: Arc::new(model_manager),
                inference_engine: Arc::new(inference_engine),
            },
        }
    }

    pub async fn start(&self, host: &str, port: u16) -> Result<()> {
        let state = self.state.clone();

        let app = Router::new()
            .route("/inference", post(inference_handler))
            .route("/health", post(health_handler))
            .with_state(state);

        let addr = format!("{}:{}", host, port);
        let listener = TcpListener::bind(&addr).await?;

        info!("Inference service listening on {}", addr);
        axum::serve(listener, app).await?;

        Ok(())
    }
}

#[cfg(feature = "inference")]
/// POST /inference - Handle inference requests
async fn inference_handler(
    State(state): State<InferenceServiceState>,
    Json(req): Json<InferenceRequest>,
) -> impl IntoResponse {
    info!("Inference request: model={}, prompt_len={}", req.model, req.prompt.len());

    let params = GenerationParams {
        max_tokens: req.max_tokens.unwrap_or(512),
        temperature: req.temperature.unwrap_or(0.7),
        top_p: req.top_p.unwrap_or(0.9),
        top_k: req.top_k,
        repeat_penalty: 1.0,
        repeat_last_n: 64,
        stop_sequences: vec![],
        presence_penalty: 0.0,
        frequency_penalty: 0.0,
    };

    match state.inference_engine.generate(&req.model, &req.prompt, params).await {
        Ok(result) => {
            info!("Inference successful: {} tokens generated", result.tokens_generated);
            (StatusCode::OK, Json(InferenceResponse {
                text: result.text,
                tokens_generated: result.tokens_generated,
                prompt_tokens: result.prompt_tokens,
                duration_ms: result.duration_ms,
                tokens_per_second: result.tokens_per_second,
                error: None,
            })).into_response()
        },
        Err(e) => {
            error!("Inference failed: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(InferenceResponse {
                    text: String::new(),
                    tokens_generated: 0,
                    prompt_tokens: 0,
                    duration_ms: 0,
                    tokens_per_second: 0.0,
                    error: Some(e.to_string()),
                })
            ).into_response()
        }
    }
}

#[cfg(not(feature = "inference"))]
/// Inference service (stub for non-inference builds)
pub struct InferenceService;

#[cfg(not(feature = "inference"))]
impl InferenceService {
    pub async fn start(&self, _host: &str, _port: u16) -> Result<()> {
        error!("Inference service requires the 'inference' feature. Build with: cargo build --release --features inference --bin allama-inference");
        anyhow::bail!("Inference feature not enabled");
    }
}
