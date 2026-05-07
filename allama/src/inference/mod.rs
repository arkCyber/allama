// Aerospace-Level Llama.cpp Inference Integration
// FFI bindings and safe Rust wrappers for llama.cpp

pub mod ffi;
pub mod engine;
pub mod model;
pub mod sampler;

pub use engine::InferenceEngine;
pub use model::ModelManager;

use anyhow::Result;

/// Initialize llama.cpp backend (call once at startup)
pub fn init_backend() -> Result<()> {
    #[cfg(feature = "inference")]
    unsafe {
        // Load dynamic backends first
        // Note: ggml_backend_load_all() may not be available in all builds
        // ffi::ggml_backend_load_all();
        // Initialize llama backend
        ffi::llama_backend_init();
    }
    Ok(())
}

/// Free llama.cpp backend (call once at shutdown)
pub fn free_backend() {
    #[cfg(feature = "inference")]
    unsafe {
        ffi::llama_backend_free();
    }
}

/// Result of a generation operation
#[derive(Debug, Clone)]
pub struct GenerationResult {
    pub text: String,
    pub tokens_generated: u32,
    pub prompt_tokens: u32,
    pub duration_ms: u64,
    pub tokens_per_second: f32,
    pub stop_reason: StopReason,
}

#[derive(Debug, Clone)]
pub enum StopReason {
    Eos,
    Length,
    StopSequence,
}

/// Generation parameters
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct GenerationParams {
    pub max_tokens: u32,
    pub temperature: f32,
    pub top_p: f32,
    pub top_k: Option<i32>,
    pub repeat_penalty: f32,
    pub repeat_last_n: i32,
    pub stop_sequences: Vec<String>,
    pub presence_penalty: f32,
    pub frequency_penalty: f32,
}

impl Default for GenerationParams {
    fn default() -> Self {
        Self {
            max_tokens: 512,
            temperature: 0.7,
            top_p: 0.9,
            top_k: Some(40),
            repeat_penalty: 1.0,
            repeat_last_n: 64,
            stop_sequences: vec![],
            presence_penalty: 0.0,
            frequency_penalty: 0.0,
        }
    }
}

/// Unified inference engine - always exists
pub struct UnifiedInferenceEngine {
    enabled: bool,
    #[cfg(feature = "inference")]
    real: Option<InferenceEngine>,
}

impl UnifiedInferenceEngine {
    #[cfg(feature = "inference")]
    pub fn new_real(engine: InferenceEngine) -> Self {
        Self { enabled: true, real: Some(engine) }
    }
    
    #[cfg(not(feature = "inference"))]
    pub fn new() -> Self {
        Self { enabled: false }
    }
    
    pub fn is_enabled(&self) -> bool {
        self.enabled
    }
    
    #[cfg(feature = "inference")]
    pub fn get_real(&self) -> Option<&InferenceEngine> {
        self.real.as_ref()
    }
    
    pub async fn generate(&self, model: &str, prompt: &str, params: GenerationParams) -> Result<GenerationResult> {
        if !self.enabled {
            return Ok(GenerationResult {
                text: "Inference feature not enabled. Please rebuild with --features inference".to_string(),
                tokens_generated: 0,
                prompt_tokens: 0,
                duration_ms: 0,
                tokens_per_second: 0.0,
                stop_reason: StopReason::Eos,
            });
        }
        
        #[cfg(feature = "inference")]
        {
            if let Some(engine) = &self.real {
                let engine_params = engine::GenerationParams {
                    max_tokens: params.max_tokens,
                    temperature: params.temperature,
                    top_p: params.top_p,
                    top_k: params.top_k,
                    repeat_penalty: params.repeat_penalty,
                    repeat_last_n: params.repeat_last_n,
                    stop_sequences: params.stop_sequences,
                    presence_penalty: params.presence_penalty,
                    frequency_penalty: params.frequency_penalty,
                };
                
                let result = engine.generate(model, prompt, engine_params).await?;
                return Ok(GenerationResult {
                    text: result.text,
                    tokens_generated: result.tokens_generated,
                    prompt_tokens: result.prompt_tokens,
                    duration_ms: result.duration_ms,
                    tokens_per_second: result.tokens_per_second,
                    stop_reason: StopReason::Eos,
                });
            }
        }
        
        #[cfg(not(feature = "inference"))]
        {
            // This should never be reached since enabled=false in non-inference builds
        }
        
        Ok(GenerationResult {
            text: "Inference not available".to_string(),
            tokens_generated: 0,
            prompt_tokens: 0,
            duration_ms: 0,
            tokens_per_second: 0.0,
            stop_reason: StopReason::Eos,
        })
    }
    
    pub async fn get_loaded_models(&self) -> Vec<String> {
        if !self.enabled {
            return vec![];
        }
        
        #[cfg(feature = "inference")]
        {
            if let Some(engine) = &self.real {
                return engine.get_loaded_models().await;
            }
        }
        
        #[cfg(not(feature = "inference"))]
        {
            // This should never be reached since enabled=false in non-inference builds
        }
        
        vec![]
    }
}

#[cfg(not(feature = "inference"))]
impl Clone for UnifiedInferenceEngine {
    fn clone(&self) -> Self {
        Self { enabled: self.enabled }
    }
}
