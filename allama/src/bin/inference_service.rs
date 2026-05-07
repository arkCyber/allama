// Standalone Inference Service Binary
// Using Hyper 1.0 for HTTP server to avoid Axum Handler trait constraints

use anyhow::Result;
use clap::Parser;
use std::path::PathBuf;
use tracing::{info, error};
use tracing_subscriber;

use allama::inference::{InferenceEngine, ModelManager};

use hyper::{Request, Response, StatusCode, Method};
use hyper::body::{Bytes, Incoming};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use http_body_util::{BodyExt, Full};
use hyper_util::rt::TokioIo;
use tokio::net::TcpListener;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::convert::Infallible;
use std::net::SocketAddr;
use tokio::sync::{Mutex, Semaphore, RwLock};
use tokio::time::{timeout, Duration, Instant};
use std::collections::HashMap;
use scopeguard;

#[derive(Parser)]
#[command(name = "allama-inference")]
#[command(about = "Allama Inference Service - Standalone LLM inference server")]
struct Cli {
    #[arg(long, default_value = "127.0.0.1")]
    host: String,
    
    #[arg(long, default_value = "8081")]
    port: u16,
    
    #[arg(long, default_value = "./models")]
    models_dir: String,
    
    #[arg(long, default_value = "3")]
    max_loaded_models: usize,
    
    #[arg(long, default_value = "4096")]
    context_size: u32,
}

#[derive(Debug, Deserialize)]
struct LoadModelRequest {
    model: String,
}

#[derive(Debug, Deserialize)]
struct UnloadModelRequest {
    model: String,
}

#[derive(Debug, Serialize)]
struct LoadModelResponse {
    success: bool,
    message: String,
    model_name: String,
    model_size: Option<u64>,
}

#[derive(Debug, Serialize)]
struct UnloadModelResponse {
    success: bool,
    message: String,
    model_name: String,
}

#[derive(Debug, Deserialize)]
struct InferenceRequest {
    model: String,
    prompt: String,
    max_tokens: Option<u32>,
    temperature: Option<f32>,
    top_p: Option<f32>,
    top_k: Option<i32>,
}

#[derive(Debug, Serialize)]
struct InferenceResponse {
    text: String,
    tokens_generated: u32,
    prompt_tokens: u32,
    duration_ms: u64,
    tokens_per_second: f32,
    error: Option<String>,
}

/// Aerospace-level concurrent service state
#[derive(Clone)]
struct ServiceState {
    model_manager: Arc<ModelManager>,
    inference_engine: Arc<InferenceEngine>,
    // Concurrent control
    global_semaphore: Arc<Semaphore>,
    model_semaphores: Arc<RwLock<HashMap<String, Arc<Semaphore>>>>,
    // Performance monitoring
    active_requests: Arc<Mutex<usize>>,
    total_requests: Arc<Mutex<usize>>,
}

async fn handle_request(
    req: Request<Incoming>,
    state: Arc<ServiceState>,
) -> Result<Response<Full<Bytes>>, Infallible> {
    let path = req.uri().path();
    let method = req.method();
    
    match (method, path) {
        (&Method::POST, "/load-model") => {
            handle_load_model(req, state).await
        },
        (&Method::POST, "/unload-model") => {
            handle_unload_model(req, state).await
        },
        (&Method::POST, "/inference") => {
            handle_inference(req, state).await
        },
        (&Method::POST, "/health") | (&Method::GET, "/health") => {
            Ok(Response::builder()
                .status(StatusCode::OK)
                .header("Content-Type", "application/json")
                .body(Full::new(Bytes::from(r#"{"status":"ok"}"#)))
                .unwrap())
        },
        (&Method::GET, "/stats") => {
            handle_stats(state).await
        },
        _ => {
            Ok(Response::builder()
                .status(StatusCode::NOT_FOUND)
                .body(Full::new(Bytes::from("Not Found")))
                .unwrap())
        }
    }
}

/// Aerospace-level: Statistics endpoint
async fn handle_stats(
    state: Arc<ServiceState>,
) -> Result<Response<Full<Bytes>>, Infallible> {
    let active = *state.active_requests.lock().await;
    let total = *state.total_requests.lock().await;
    let loaded_models = state.model_manager.list_loaded().await;
    let (model_count, total_memory) = state.model_manager.get_memory_usage().await;
    
    let stats = serde_json::json!({
        "active_requests": active,
        "total_requests": total,
        "loaded_models": loaded_models,
        "model_count": model_count,
        "total_memory_bytes": total_memory,
        "total_memory_mb": total_memory / (1024 * 1024),
        "global_semaphore_available": state.global_semaphore.available_permits(),
    });
    
    let json = serde_json::to_string(&stats).unwrap();
    
    Ok(Response::builder()
        .status(StatusCode::OK)
        .header("Content-Type", "application/json")
        .body(Full::new(Bytes::from(json)))
        .unwrap())
}

async fn handle_load_model(
    req: Request<Incoming>,
    state: Arc<ServiceState>,
) -> Result<Response<Full<Bytes>>, Infallible> {
    let body_bytes = match req.collect().await {
        Ok(collected) => collected.to_bytes(),
        Err(e) => {
            error!("Failed to read request body: {}", e);
            return Ok(error_response("Failed to read request body"));
        }
    };
    
    let load_req: LoadModelRequest = match serde_json::from_slice(&body_bytes) {
        Ok(req) => req,
        Err(e) => {
            error!("Failed to parse request: {}", e);
            return Ok(error_response("Invalid JSON request"));
        }
    };
    
    info!("Loading model: {}", load_req.model);
    
    use allama::inference::ffi;
    
    let model_params = ffi::default_model_params();
    let context_params = ffi::default_context_params();
    
    match state.model_manager.load_model(&load_req.model, Some(model_params), Some(context_params)).await {
        Ok(handle) => {
            info!("✅ Model loaded successfully: {}", load_req.model);
            let response = LoadModelResponse {
                success: true,
                message: format!("Model '{}' loaded successfully", load_req.model),
                model_name: load_req.model,
                model_size: Some(handle.info.size_bytes),
            };
            let json = serde_json::to_string(&response).unwrap();
            Ok(Response::builder()
                .status(StatusCode::OK)
                .header("Content-Type", "application/json")
                .body(Full::new(Bytes::from(json)))
                .unwrap())
        },
        Err(e) => {
            error!("❌ Failed to load model: {}", e);
            let response = LoadModelResponse {
                success: false,
                message: format!("Failed to load model: {}", e),
                model_name: load_req.model,
                model_size: None,
            };
            let json = serde_json::to_string(&response).unwrap();
            Ok(Response::builder()
                .status(StatusCode::INTERNAL_SERVER_ERROR)
                .header("Content-Type", "application/json")
                .body(Full::new(Bytes::from(json)))
                .unwrap())
        }
    }
}

async fn handle_unload_model(
    req: Request<Incoming>,
    state: Arc<ServiceState>,
) -> Result<Response<Full<Bytes>>, Infallible> {
    let body_bytes = match req.collect().await {
        Ok(collected) => collected.to_bytes(),
        Err(e) => {
            error!("Failed to read request body: {}", e);
            return Ok(error_response("Failed to read request body"));
        }
    };
    
    let unload_req: UnloadModelRequest = match serde_json::from_slice(&body_bytes) {
        Ok(req) => req,
        Err(e) => {
            error!("Failed to parse request: {}", e);
            return Ok(error_response("Invalid JSON request"));
        }
    };
    
    info!("Unloading model: {}", unload_req.model);
    
    match state.model_manager.unload_model(&unload_req.model).await {
        Ok(()) => {
            info!("✅ Model unloaded successfully: {}", unload_req.model);
            let response = UnloadModelResponse {
                success: true,
                message: format!("Model '{}' unloaded successfully", unload_req.model),
                model_name: unload_req.model,
            };
            let json = serde_json::to_string(&response).unwrap();
            Ok(Response::builder()
                .status(StatusCode::OK)
                .header("Content-Type", "application/json")
                .body(Full::new(Bytes::from(json)))
                .unwrap())
        },
        Err(e) => {
            error!("❌ Failed to unload model: {}", e);
            let response = UnloadModelResponse {
                success: false,
                message: format!("Failed to unload model: {}", e),
                model_name: unload_req.model,
            };
            let json = serde_json::to_string(&response).unwrap();
            Ok(Response::builder()
                .status(StatusCode::INTERNAL_SERVER_ERROR)
                .header("Content-Type", "application/json")
                .body(Full::new(Bytes::from(json)))
                .unwrap())
        }
    }
}

/// Aerospace-level concurrent inference handler with monitoring
async fn handle_inference(
    req: Request<Incoming>,
    state: Arc<ServiceState>,
) -> Result<Response<Full<Bytes>>, Infallible> {
    let request_start = Instant::now();
    
    // Aerospace-level: Update active requests counter
    {
        let mut active = state.active_requests.lock().await;
        *active += 1;
        info!("📊 Active requests: {}", *active);
    }
    
    // Aerospace-level: Update total requests counter
    {
        let mut total = state.total_requests.lock().await;
        *total += 1;
    }
    
    // Ensure we decrement active requests on exit
    let _guard = scopeguard::guard(state.clone(), |state| {
        tokio::spawn(async move {
            let mut active = state.active_requests.lock().await;
            *active = active.saturating_sub(1);
        });
    });
    
    // Read request body
    let body_bytes = match req.collect().await {
        Ok(collected) => collected.to_bytes(),
        Err(e) => {
            error!("Failed to read request body: {}", e);
            return Ok(error_response("Failed to read request body"));
        }
    };
    
    // Parse JSON request
    let inference_req: InferenceRequest = match serde_json::from_slice(&body_bytes) {
        Ok(req) => req,
        Err(e) => {
            error!("Failed to parse request: {}", e);
            return Ok(error_response("Invalid JSON request"));
        }
    };
    
    info!("🔄 Inference request: model={}, prompt_len={}", 
          inference_req.model, inference_req.prompt.len());
    
    // Aerospace-level: Acquire global semaphore (limit total concurrent requests)
    let _global_permit = match state.global_semaphore.acquire().await {
        Ok(permit) => {
            info!("✓ Global semaphore acquired");
            permit
        },
        Err(e) => {
            error!("Failed to acquire global semaphore: {}", e);
            return Ok(error_response("Server overloaded, please try again later"));
        }
    };
    
    // Aerospace-level: Acquire model-specific semaphore
    let model_semaphore = {
        let mut semaphores = state.model_semaphores.write().await;
        semaphores.entry(inference_req.model.clone())
            .or_insert_with(|| Arc::new(Semaphore::new(3))) // Max 3 concurrent per model
            .clone()
    };
    
    let _model_permit = match model_semaphore.acquire().await {
        Ok(permit) => {
            info!("✓ Model semaphore acquired for: {}", inference_req.model);
            permit
        },
        Err(e) => {
            error!("Failed to acquire model semaphore: {}", e);
            return Ok(error_response("Model busy, please try again later"));
        }
    };
    
    use allama::inference::engine::GenerationParams;
    
    let params = GenerationParams {
        max_tokens: inference_req.max_tokens.unwrap_or(512),
        temperature: inference_req.temperature.unwrap_or(0.7),
        top_p: inference_req.top_p.unwrap_or(0.9),
        top_k: inference_req.top_k,
        repeat_penalty: 1.0,
        repeat_last_n: 64,
        stop_sequences: vec![],
        presence_penalty: 0.0,
        frequency_penalty: 0.0,
    };
    
    // Aerospace-level: Perform inference with timeout
    let inference_timeout = Duration::from_secs(300); // 5 minutes
    let inference_result = timeout(
        inference_timeout,
        state.inference_engine.generate(&inference_req.model, &inference_req.prompt, params)
    ).await;
    
    match inference_result {
        Ok(Ok(result)) => {
            let request_duration = request_start.elapsed();
            info!("✅ Inference successful: {} tokens in {:?}", 
                  result.tokens_generated, request_duration);
            info!("   Tokens/sec: {:.2}, Total time: {}ms", 
                  result.tokens_per_second, result.duration_ms);
            
            let response = InferenceResponse {
                text: result.text,
                tokens_generated: result.tokens_generated,
                prompt_tokens: result.prompt_tokens,
                duration_ms: result.duration_ms,
                tokens_per_second: result.tokens_per_second,
                error: None,
            };
            
            let json = serde_json::to_string(&response).unwrap();
            
            Ok(Response::builder()
                .status(StatusCode::OK)
                .header("Content-Type", "application/json")
                .body(Full::new(Bytes::from(json)))
                .unwrap())
        },
        Ok(Err(e)) => {
            error!("❌ Inference failed: {}", e);
            
            let response = InferenceResponse {
                text: String::new(),
                tokens_generated: 0,
                prompt_tokens: 0,
                duration_ms: 0,
                tokens_per_second: 0.0,
                error: Some(e.to_string()),
            };
            
            let json = serde_json::to_string(&response).unwrap();
            
            Ok(Response::builder()
                .status(StatusCode::INTERNAL_SERVER_ERROR)
                .header("Content-Type", "application/json")
                .body(Full::new(Bytes::from(json)))
                .unwrap())
        },
        Err(_timeout) => {
            error!("❌ Inference timeout after {}s", inference_timeout.as_secs());
            
            let response = InferenceResponse {
                text: String::new(),
                tokens_generated: 0,
                prompt_tokens: 0,
                duration_ms: 0,
                tokens_per_second: 0.0,
                error: Some("Request timeout".to_string()),
            };
            
            let json = serde_json::to_string(&response).unwrap();
            
            Ok(Response::builder()
                .status(StatusCode::REQUEST_TIMEOUT)
                .header("Content-Type", "application/json")
                .body(Full::new(Bytes::from(json)))
                .unwrap())
        }
    }
}

fn error_response(message: &str) -> Response<Full<Bytes>> {
    let response = InferenceResponse {
        text: String::new(),
        tokens_generated: 0,
        prompt_tokens: 0,
        duration_ms: 0,
        tokens_per_second: 0.0,
        error: Some(message.to_string()),
    };
    
    let json = serde_json::to_string(&response).unwrap();
    
    Response::builder()
        .status(StatusCode::BAD_REQUEST)
        .header("Content-Type", "application/json")
        .body(Full::new(Bytes::from(json)))
        .unwrap()
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_target(false)
        .with_thread_ids(false)
        .with_file(false)
        .init();
    
    let cli = Cli::parse();
    
    info!("==========================================");
    info!("Starting Allama Inference Service (Hyper)");
    info!("==========================================");
    info!("Host: {}", cli.host);
    info!("Port: {}", cli.port);
    info!("Models directory: {}", cli.models_dir);
    info!("Max loaded models: {}", cli.max_loaded_models);
    info!("Context size: {}", cli.context_size);
    info!("==========================================");
    
    // Initialize llama.cpp backend
    info!("Initializing llama.cpp backend...");
    allama::inference::init_backend()?;
    info!("Backend initialized successfully");
    
    let models_path = PathBuf::from(&cli.models_dir);
    let model_manager = ModelManager::new(cli.max_loaded_models, models_path)?;
    let inference_engine = InferenceEngine::new(Arc::new(model_manager.clone()), cli.context_size);
    
    // Aerospace-level: Initialize concurrent control
    let max_concurrent_requests = 10; // Global limit
    info!("Concurrent configuration:");
    info!("  Max concurrent requests: {}", max_concurrent_requests);
    info!("  Max concurrent per model: 3");
    
    let state = Arc::new(ServiceState {
        model_manager: Arc::new(model_manager),
        inference_engine: Arc::new(inference_engine),
        global_semaphore: Arc::new(Semaphore::new(max_concurrent_requests)),
        model_semaphores: Arc::new(RwLock::new(HashMap::new())),
        active_requests: Arc::new(Mutex::new(0)),
        total_requests: Arc::new(Mutex::new(0)),
    });
    
    let addr: SocketAddr = format!("{}:{}", cli.host, cli.port).parse()?;
    let listener = TcpListener::bind(addr).await?;
    
    info!("🚀 Inference service listening on {}", addr);
    
    loop {
        let (stream, _) = listener.accept().await?;
        let io = TokioIo::new(stream);
        let state = state.clone();
        
        // Handle connection in the current task
        // Note: spawn_blocking causes segfault with FFI pointers across threads
        // Connection-level concurrency is handled by the semaphore mechanism instead
        if let Err(err) = http1::Builder::new()
            .serve_connection(io, service_fn(move |req| {
                handle_request(req, state.clone())
            }))
            .await
        {
            error!("Error serving connection: {:?}", err);
        }
    }
}
