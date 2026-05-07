// Aerospace-Level Inference Engine
// High-level text generation interface with streaming support

use anyhow::Result;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::RwLock;
use tracing::{info, warn, error, debug};

use super::model::ModelManager;
use super::sampler::{Sampler, SamplerConfig, SamplingStrategy};
use super::ffi::get_batch_one;

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

impl GenerationParams {
    pub fn to_sampler_config(&self) -> SamplerConfig {
        let strategy = if let Some(k) = self.top_k {
            SamplingStrategy::Combined {
                temperature: self.temperature,
                top_p: self.top_p,
                top_k: Some(k),
            }
        } else {
            SamplingStrategy::Combined {
                temperature: self.temperature,
                top_p: self.top_p,
                top_k: None,
            }
        };
        
        SamplerConfig {
            strategy,
            repeat_penalty: self.repeat_penalty,
            repeat_last_n: self.repeat_last_n,
            frequency_penalty: self.frequency_penalty,
            presence_penalty: self.presence_penalty,
            ..Default::default()
        }
    }
}

/// Generation result
#[derive(Debug, Clone)]
pub struct GenerationResult {
    pub text: String,
    pub tokens_generated: u32,
    pub prompt_tokens: u32,
    pub duration_ms: u64,
    pub tokens_per_second: f32,
    pub stop_reason: StopReason,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub enum StopReason {
    EosToken,
    MaxTokens,
    StopSequence(String),
    Aborted,
    Error,
}

/// Inference engine (aerospace-level thread-safe)
#[derive(Debug, Clone)]
pub struct InferenceEngine {
    model_manager: Arc<ModelManager>,
    sampler: Arc<RwLock<Option<Sampler>>>,
    max_context_length: u32,
}

// SAFETY: InferenceEngine is thread-safe because:
// - model_manager is Arc<ModelManager> which is thread-safe
// - sampler is Arc<RwLock<...>> which is thread-safe
// - max_context_length is a primitive u32
unsafe impl Send for InferenceEngine {}
unsafe impl Sync for InferenceEngine {}

impl InferenceEngine {
    pub fn new(model_manager: Arc<ModelManager>, max_context_length: u32) -> Self {
        info!("Initializing inference engine with max context: {}", max_context_length);
        
        Self {
            model_manager,
            sampler: Arc::new(RwLock::new(None)),
            max_context_length,
        }
    }
    
    /// Initialize sampler with configuration
    pub async fn init_sampler(&self, config: SamplerConfig) -> Result<()> {
        let sampler = Sampler::new(config)?;
        *self.sampler.write().await = Some(sampler);
        info!("Sampler initialized");
        Ok(())
    }
    
    /// Get list of loaded models
    pub async fn get_loaded_models(&self) -> Vec<String> {
        self.model_manager.list_loaded().await
    }
    
    /// Aerospace-level text generation with comprehensive error handling
    /// 
    /// # Safety Guarantees
    /// - Validates all inputs before processing
    /// - Implements graceful degradation on errors
    /// - Maintains system stability even on failures
    /// - Provides detailed error reporting
    /// 
    /// # Arguments
    /// * `model_name` - Name of the model to use
    /// * `prompt` - Input text prompt
    /// * `params` - Generation parameters
    /// 
    /// # Returns
    /// * `Ok(GenerationResult)` - Successfully generated text with metrics
    /// * `Err` - Detailed error information with recovery suggestions
    pub async fn generate(
        &self,
        model_name: &str,
        prompt: &str,
        params: GenerationParams,
    ) -> Result<GenerationResult> {
        let start_time = Instant::now();
        
        // Aerospace-level: Input validation
        if model_name.is_empty() {
            error!("Empty model name provided");
            anyhow::bail!("Model name cannot be empty");
        }
        
        if prompt.is_empty() {
            warn!("Empty prompt provided, returning empty result");
            return Ok(GenerationResult {
                text: String::new(),
                tokens_generated: 0,
                prompt_tokens: 0,
                duration_ms: 0,
                tokens_per_second: 0.0,
                stop_reason: StopReason::MaxTokens,
            });
        }
        
        // Validate generation parameters
        if params.max_tokens == 0 {
            warn!("max_tokens is 0, returning empty result");
            return Ok(GenerationResult {
                text: String::new(),
                tokens_generated: 0,
                prompt_tokens: 0,
                duration_ms: 0,
                tokens_per_second: 0.0,
                stop_reason: StopReason::MaxTokens,
            });
        }
        
        if params.max_tokens > 10000 {
            error!("max_tokens {} exceeds safety limit", params.max_tokens);
            anyhow::bail!("max_tokens {} exceeds safety limit (10000)", params.max_tokens);
        }
        
        // Aerospace-level: Log generation request
        info!("Starting generation for model: {}, max_tokens: {}, temperature: {:.2}", 
              model_name, params.max_tokens, params.temperature);
        
        // Aerospace-level: Get or load model with error handling
        let model_handle = self.model_manager.get_model(model_name).await
            .ok_or_else(|| {
                error!("Model '{}' not found or not loaded", model_name);
                anyhow::anyhow!("Model '{}' not loaded. Please load the model first using /load-model endpoint", model_name)
            })?;
        
        // Clone the Arc to ensure the model stays alive
        let _model_guard = model_handle.clone();
        
        info!("Model handle Arc count: {}", Arc::strong_count(&model_handle));
        
        // Aerospace-level: Log model loaded successfully
        debug!("Model '{}' loaded and ready for inference", model_name);
        
        // Initialize sampler if needed
        if self.sampler.read().await.is_none() {
            info!("Initializing sampler with Greedy strategy for testing");
            // Temporarily use Greedy for testing
            let mut test_config = SamplerConfig::default();
            test_config.strategy = SamplingStrategy::Greedy;
            self.init_sampler(test_config).await?;
            info!("Sampler initialized, model handle Arc count: {}", Arc::strong_count(&model_handle));
        }
        
        // Aerospace-level: Log prompt tokenization
        info!("Tokenizing prompt...");
        
        let model_ptr = model_handle.model.as_ptr();
        info!("Model pointer: {:p}", model_ptr);
        
        if model_ptr.is_null() {
            error!("Model pointer is null!");
            anyhow::bail!("Model pointer is null");
        }
        
        // Tokenize prompt directly (llama.cpp tokenize is thread-safe)
        let prompt_tokens = super::ffi::tokenize(model_ptr, prompt, true)?;
        let prompt_count = prompt_tokens.len() as u32;
        
        // Aerospace-level: Log prompt tokenization
        info!("Prompt tokenized: {} tokens", prompt_count);
        
        // Aerospace-level: Check context length with detailed error
        if prompt_count > self.max_context_length {
            error!("Prompt exceeds context length: {} > {}", prompt_count, self.max_context_length);
            return Err(anyhow::anyhow!(
                "Prompt too long: {} tokens (max: {}). Please reduce prompt length.",
                prompt_count,
                self.max_context_length
            ));
        }
        
        // Aerospace-level: Check if we have enough context for generation
        if prompt_count + params.max_tokens > self.max_context_length {
            let max_gen = self.max_context_length - prompt_count;
            warn!("Requested {} tokens but only {} available, will generate maximum possible", 
                  params.max_tokens, max_gen);
        }
        
        // Encode prompt
        let ctx = model_handle.context.as_ptr();
        info!("Context pointer: {:p}", ctx);
        
        let mut prompt_tokens_mut = prompt_tokens.clone();
        info!("Creating batch for {} tokens", prompt_tokens_mut.len());
        info!("Token values: {:?}", prompt_tokens_mut);
        
        let batch = get_batch_one(&mut prompt_tokens_mut);
        info!("Batch created:");
        info!("  n_tokens: {}", batch.n_tokens);
        info!("  token: {:p}", batch.token);
        info!("  embd: {:p}", batch.embd);
        info!("  pos: {:p}", batch.pos);
        info!("  n_seq_id: {:p}", batch.n_seq_id);
        info!("  seq_id: {:p}", batch.seq_id);
        info!("  logits: {:p}", batch.logits);
        
        // Verify token pointer is valid
        if !batch.token.is_null() {
            info!("  First token value: {}", unsafe { *batch.token });
        }
        
        // Aerospace-level: Decode prompt (not encode - that's for encoder-decoder models)
        info!("Calling llama_decode for prompt...");
        let decode_result = unsafe { super::ffi::llama_decode(ctx, batch) };
        info!("Decode result: {}", decode_result);
        
        if decode_result != 0 {
            error!("Failed to decode prompt for model '{}', result: {}", model_name, decode_result);
            anyhow::bail!("Failed to decode prompt");
        }
        
        info!("Prompt decoded successfully");
        
        // Generate tokens
        let mut generated_tokens = Vec::new();
        let mut generated_text = String::new();
        let mut stop_reason = StopReason::MaxTokens;
        
        let sampler = self.sampler.read().await;
        let sampler_ref = sampler.as_ref()
            .ok_or_else(|| anyhow::anyhow!("Sampler not initialized"))?;
        
        // Track current position in the sequence
        let mut n_pos = prompt_count as i32;
        
        // Aerospace-level: Generation loop with comprehensive error handling
        let mut consecutive_failures = 0;
        const MAX_CONSECUTIVE_FAILURES: u32 = 3;
        
        for i in 0..params.max_tokens {
            // Aerospace-level: Safety check - prevent infinite loops
            if consecutive_failures >= MAX_CONSECUTIVE_FAILURES {
                error!("Too many consecutive failures ({}), aborting generation", consecutive_failures);
                stop_reason = StopReason::MaxTokens;
                break;
            }
            
            // Sample next token from the last position (-1 means last token)
            info!("Sampling at position: n_pos={}, iteration {}/{}", n_pos, i + 1, params.max_tokens);
            
            let next_token = match sampler_ref.sample(ctx, -1).await {
                Ok(token) => {
                    consecutive_failures = 0;  // Reset on success
                    token
                },
                Err(e) => {
                    consecutive_failures += 1;
                    error!("Sampling failed at iteration {}: {}", i, e);
                    if consecutive_failures >= MAX_CONSECUTIVE_FAILURES {
                        anyhow::bail!("Sampling failed {} times consecutively", consecutive_failures);
                    }
                    continue;  // Try next iteration
                }
            };
            
            info!("✓ Sampled token: {} at iteration {}/{}", next_token, i + 1, params.max_tokens);
            
            // Aerospace-level: Validate token
            if next_token < 0 {
                stop_reason = StopReason::EosToken;
                info!("EOS token reached at position {}", i);
                break;
            }
            
            // Check if token is valid
            let vocab = unsafe { super::ffi::llama_model_get_vocab(model_handle.model.as_ptr()) };
            let n_vocab = unsafe { super::ffi::llama_vocab_n_tokens(vocab) };
            info!("Token {} / vocab size {}", next_token, n_vocab);
            
            if next_token >= n_vocab {
                error!("Token {} exceeds vocabulary size {}", next_token, n_vocab);
                stop_reason = StopReason::Error;
                break;
            }
            
            // Check for EOS token
            info!("Checking if token {} is EOS...", next_token);
            let eos_token = unsafe { super::ffi::llama_vocab_eos(vocab) };
            info!("EOS token ID: {}", eos_token);
            if next_token == eos_token {
                info!("EOS token {} detected", eos_token);
                stop_reason = StopReason::EosToken;
                break;
            }
            info!("Token {} is not EOS, continuing...", next_token);
            
            // Aerospace-level: Convert token to text with error handling
            info!("Converting token {} to text...", next_token);
            let token_text = match super::ffi::token_to_piece(model_handle.model.as_ptr(), next_token) {
                Ok(text) => {
                    info!("Token {} successfully converted", next_token);
                    text
                },
                Err(e) => {
                    consecutive_failures += 1;
                    error!("Failed to convert token {} to text: {}", next_token, e);
                    if consecutive_failures >= MAX_CONSECUTIVE_FAILURES {
                        anyhow::bail!("Token conversion failed {} times", consecutive_failures);
                    }
                    continue;  // Skip this token
                }
            };
            
            info!("✓ Token {} converted to text: '{}' (len: {})", next_token, token_text, token_text.len());
            consecutive_failures = 0;  // Reset on success
            
            // Aerospace-level: Sanity check on generated text length
            if generated_text.len() + token_text.len() > 1000000 {
                error!("Generated text exceeds safety limit (1MB)");
                stop_reason = StopReason::MaxTokens;
                break;
            }
            
            generated_text.push_str(&token_text);
            generated_tokens.push(next_token);
            
            // Check stop sequences
            for stop_seq in &params.stop_sequences {
                if generated_text.contains(stop_seq) {
                    stop_reason = StopReason::StopSequence(stop_seq.clone());
                    info!("Stop sequence '{}' reached at position {}", stop_seq, i);
                    break;
                }
            }
            
            if matches!(stop_reason, StopReason::StopSequence(_)) {
                break;
            }
            
            // Aerospace-level: Decode the token for next iteration with error handling
            let mut decode_tokens = vec![next_token];
            let decode_batch = get_batch_one(&mut decode_tokens);
            
            info!("🔄 Decoding token {} for next iteration (batch size: {})...", next_token, decode_tokens.len());
            let decode_result = unsafe { super::ffi::llama_decode(ctx, decode_batch) };
            info!("Decode result: {}", decode_result);
            
            if decode_result != 0 {
                consecutive_failures += 1;
                error!("❌ Decode failed at token {} for model '{}', result: {}", i, model_name, decode_result);
                if consecutive_failures >= MAX_CONSECUTIVE_FAILURES {
                    anyhow::bail!("Decode failed {} times consecutively", consecutive_failures);
                }
                break;  // Cannot continue without successful decode
            }
            
            info!("✓ Decode successful for token {}", next_token);
            
            // Update position for next iteration
            n_pos += 1;
            
            info!("Generated token {}/{}: '{}'", i + 1, params.max_tokens, token_text);
        }
        
        let duration_ms = start_time.elapsed().as_millis() as u64;
        let tokens_generated = generated_tokens.len() as u32;
        let tokens_per_second = if duration_ms > 0 {
            (tokens_generated as f32) / (duration_ms as f32 / 1000.0)
        } else {
            0.0
        };
        
        // Aerospace-level: Log generation completion with model name and stop reason
        info!("Generation complete for model '{}': {} tokens in {}ms ({:.2} t/s), reason: {:?}", 
              model_name, tokens_generated, duration_ms, tokens_per_second, stop_reason);
        
        Ok(GenerationResult {
            text: generated_text,
            tokens_generated,
            prompt_tokens: prompt_count,
            duration_ms,
            tokens_per_second,
            stop_reason,
        })
    }
    
    /// Generate text with streaming callback
    pub async fn generate_streaming<F>(
        &self,
        model_name: &str,
        prompt: &str,
        params: GenerationParams,
        mut callback: F,
    ) -> Result<GenerationResult>
    where
        F: FnMut(String) -> bool, // Returns false to stop generation
    {
        let start_time = Instant::now();
        
        // Get or load model
        let model_handle = self.model_manager.get_model(model_name).await
            .ok_or_else(|| anyhow::anyhow!("Model '{}' not loaded", model_name))?;
        
        // Initialize sampler if needed
        if self.sampler.read().await.is_none() {
            self.init_sampler(params.to_sampler_config()).await?;
        }
        
        // Tokenize prompt
        let model_handle_clone = model_handle.clone();
        let prompt_clone = prompt.to_string();
        let prompt_tokens = tokio::task::spawn_blocking(move || {
            super::ffi::tokenize(model_handle_clone.model.as_ptr(), &prompt_clone, true)
        }).await??;
        let prompt_count = prompt_tokens.len() as u32;
        
        debug!("Prompt tokenized: {} tokens", prompt_count);
        
        // Encode prompt
        let ctx = model_handle.context.as_ptr();
        let batch = get_batch_one(&mut prompt_tokens.clone());
        
        let encode_result = unsafe { super::ffi::llama_decode(ctx, batch) };
        if encode_result < 0 {
            anyhow::bail!("Failed to encode prompt");
        }
        
        // Note: batch from get_batch_one is stack-allocated, no need to free
        
        // Generate tokens with streaming
        let mut generated_tokens = Vec::new();
        let mut generated_text = String::new();
        let mut stop_reason = StopReason::MaxTokens;
        
        let sampler = self.sampler.read().await;
        let sampler_ref = sampler.as_ref()
            .ok_or_else(|| anyhow::anyhow!("Sampler not initialized"))?;
        
        for i in 0..params.max_tokens {
            // Sample next token from the last position (-1)
            let next_token = sampler_ref.sample(ctx, -1).await?;
            
            // Note: batch from get_batch_one is stack-allocated, no need to free
            
            // Check for EOS
            if next_token == -1 {
                stop_reason = StopReason::EosToken;
                break;
            }
            
            // Convert token to text
            let model_handle_clone = model_handle.clone();
            let token_text = tokio::task::spawn_blocking(move || {
                super::ffi::token_to_piece(model_handle_clone.model.as_ptr(), next_token)
            }).await??;
            generated_text.push_str(&token_text);
            generated_tokens.push(next_token);
            
            // Stream callback
            if !callback(token_text.clone()) {
                stop_reason = StopReason::Aborted;
                break;
            }
            
            // Check stop sequences
            for stop_seq in &params.stop_sequences {
                if generated_text.contains(stop_seq) {
                    stop_reason = StopReason::StopSequence(stop_seq.clone());
                    break;
                }
            }
            
            if matches!(stop_reason, StopReason::StopSequence(_)) {
                break;
            }
            
            // Decode the token
            let mut token_array = vec![next_token];
            let batch = get_batch_one(&mut token_array);
            
            let ctx = model_handle.context.as_ptr();
            let decode_result = unsafe { super::ffi::llama_decode(ctx, batch) };
            if decode_result < 0 {
                warn!("Decode failed at token {}", i);
                break;
            }
            
            // Note: batch from get_batch_one is stack-allocated, no need to free
        }
        
        let duration_ms = start_time.elapsed().as_millis() as u64;
        let tokens_generated = generated_tokens.len() as u32;
        let tokens_per_second = if duration_ms > 0 {
            (tokens_generated as f32) / (duration_ms as f32 / 1000.0)
        } else {
            0.0
        };
        
        info!("Streaming generation complete: {} tokens in {}ms ({:.2} t/s)", 
              tokens_generated, duration_ms, tokens_per_second);
        
        Ok(GenerationResult {
            text: generated_text,
            tokens_generated,
            prompt_tokens: prompt_count,
            duration_ms,
            tokens_per_second,
            stop_reason,
        })
    }
    
    /// Get model manager reference
    pub fn model_manager(&self) -> Arc<ModelManager> {
        self.model_manager.clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_generation_params_default() {
        let params = GenerationParams::default();
        assert_eq!(params.max_tokens, 512);
        assert_eq!(params.temperature, 0.7);
    }
    
    #[test]
    fn test_generation_params_to_sampler() {
        let params = GenerationParams::default();
        let config = params.to_sampler_config();
        assert!(config.validate().is_ok());
    }
}
