#![allow(non_camel_case_types)]
// Aerospace-Level FFI Bindings for llama.cpp
// Safe Rust wrappers around llama.cpp C API

use anyhow::Result;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_void};
use std::ptr;

// Re-export key types from llama.h
pub type llama_token = i32;
pub type llama_pos = i32;
pub type llama_seq_id = i32;

// Model and context opaque pointers
#[repr(C)]
pub struct llama_model {
    _private: [u8; 0],
}

// Thread-safe wrapper for raw model pointer
pub struct ModelPtr(*mut llama_model);

unsafe impl Send for ModelPtr {}
unsafe impl Sync for ModelPtr {}
impl std::fmt::Debug for ModelPtr {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "ModelPtr({:p})", self.0)
    }
}

impl ModelPtr {
    pub fn new(ptr: *mut llama_model) -> Self {
        Self(ptr)
    }
    
    pub fn as_ptr(&self) -> *mut llama_model {
        self.0
    }
}

#[repr(C)]
pub struct llama_context {
    _private: [u8; 0],
}

// Thread-safe wrapper for raw context pointer
pub struct ContextPtr(*mut llama_context);

unsafe impl Send for ContextPtr {}
unsafe impl Sync for ContextPtr {}
impl std::fmt::Debug for ContextPtr {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "ContextPtr({:p})", self.0)
    }
}

impl ContextPtr {
    pub fn new(ptr: *mut llama_context) -> Self {
        Self(ptr)
    }
    
    pub fn as_ptr(&self) -> *mut llama_context {
        self.0
    }
}

#[repr(C)]
pub struct llama_vocab {
    _private: [u8; 0],
}

#[repr(C)]
pub struct llama_sampler {
    _private: [u8; 0],
}

unsafe impl Send for llama_sampler {}
unsafe impl Sync for llama_sampler {}

// Sampler chain parameters
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct llama_sampler_chain_params {
    pub no_perf: bool,
}

// Batch structure
#[repr(C)]
pub struct llama_batch {
    pub n_tokens: i32,
    pub token: *mut llama_token,
    pub embd: *mut f32,
    pub pos: *mut llama_pos,
    pub n_seq_id: *mut i32,
    pub seq_id: *mut *mut llama_seq_id,
    pub logits: *mut i8,
}

// Model parameters
#[repr(C)]
pub struct llama_model_params {
    pub n_gpu_layers: i32,
    pub main_gpu: i32,
    pub split_mode: i32,
    pub tensor_split: *const f32,
    pub tensor_buft_overrides: *const (),
    pub kv_overrides: *const (),
    pub vocab_only: bool,
    pub use_mmap: bool,
    pub use_direct_io: bool,
    pub use_mlock: bool,
    pub check_tensors: bool,
    pub use_extra_bufts: bool,
    pub no_host: bool,
    pub no_alloc: bool,
}

// Context parameters
#[repr(C)]
pub struct llama_context_params {
    pub n_ctx: u32,
    pub n_batch: u32,
    pub n_ubatch: u32,
    pub n_seq_max: u32,
    pub n_threads: i32,
    pub n_threads_batch: i32,
    pub rope_scaling_type: i32,
    pub pooling_type: i32,
    pub attention_type: i32,
    pub flash_attn_type: i32,
    pub rope_freq_base: f32,
    pub rope_freq_scale: f32,
    pub yarn_ext_factor: f32,
    pub yarn_attn_factor: f32,
    pub yarn_beta_fast: f32,
    pub yarn_beta_slow: f32,
    pub yarn_orig_ctx: u32,
    pub cb_eval: *const (),
    pub cb_eval_user_data: *mut c_void,
    pub type_k: i32,
    pub type_v: i32,
    pub abort_callback: *const (),
    pub abort_callback_data: *mut c_void,
    pub embeddings: bool,
    pub offload_kqv: bool,
    pub no_perf: bool,
    pub op_offload: bool,
    pub swa_full: bool,
    pub kv_unified: bool,
    pub samplers: *const (),
}

// Token data
#[repr(C)]
pub struct llama_token_data {
    pub id: llama_token,
    pub logit: f32,
    pub p: f32,
}

#[repr(C)]
pub struct llama_token_data_array {
    pub data: *mut llama_token_data,
    pub size: usize,
    pub selected: i64,
    pub sorted: bool,
}

// Link to llama.cpp library (conditionally linked via build.rs)
#[link(name = "llama", kind = "dylib")]
extern "C" {
    // Backend initialization (ggml_backend_load_all removed in modern llama.cpp)
    pub fn llama_backend_init();
    pub fn llama_backend_free();

    // Model loading
    pub fn llama_model_default_params() -> llama_model_params;
    pub fn llama_model_load_from_file(
        path_model: *const c_char,
        params: llama_model_params,
    ) -> *mut llama_model;
    pub fn llama_model_free(model: *mut llama_model);
    pub fn llama_model_size(model: *const llama_model) -> u64;
    pub fn llama_model_n_params(model: *const llama_model) -> u64;
    pub fn llama_model_n_ctx_train(model: *const llama_model) -> u32;
    pub fn llama_model_n_embd(model: *const llama_model) -> i32;
    pub fn llama_model_n_layer(model: *const llama_model) -> i32;
    pub fn llama_model_n_head(model: *const llama_model) -> i32;
    pub fn llama_model_get_vocab(model: *const llama_model) -> *const llama_vocab;
    pub fn llama_vocab_n_tokens(vocab: *const llama_vocab) -> i32;
    pub fn llama_model_meta_val_str(model: *const llama_model, key: *const c_char, buf: *mut c_char, buf_size: i32) -> i32;
    
    // Token functions (use vocab, not model)
    pub fn llama_vocab_eos(vocab: *const llama_vocab) -> llama_token;
    pub fn llama_vocab_bos(vocab: *const llama_vocab) -> llama_token;

    // Context initialization
    pub fn llama_context_default_params() -> llama_context_params;
    pub fn llama_init_from_model(
        model: *const llama_model,
        params: llama_context_params,
    ) -> *mut llama_context;
    pub fn llama_free(ctx: *mut llama_context);
    pub fn llama_get_model(ctx: *const llama_context) -> *const llama_model;
    pub fn llama_n_ctx(ctx: *const llama_context) -> u32;
    pub fn llama_n_batch(ctx: *const llama_context) -> u32;

    // Tokenization (API change: now takes vocab ptr instead of model ptr)
    pub fn llama_tokenize(
        vocab: *const llama_vocab,
        text: *const c_char,
        text_len: i32,
        tokens: *mut llama_token,
        n_tokens_max: i32,
        add_special: bool,
        parse_special: bool,
    ) -> i32;

    // Batch operations
    pub fn llama_batch_init(
        n_tokens: i32,
        embd: i32,
        n_seq_max: i32,
    ) -> llama_batch;
    pub fn llama_batch_free(batch: llama_batch);
    pub fn llama_batch_get_one(
        tokens: *mut llama_token,
        n_tokens: i32,
    ) -> llama_batch;

    // Decoding (llama_encode removed in modern API; use llama_decode for all)
    pub fn llama_decode(
        ctx: *mut llama_context,
        batch: llama_batch,
    ) -> i32;

    // KV Cache management
    pub fn llama_kv_cache_seq_rm(ctx: *mut llama_context, seq_id: llama_seq_id, p0: llama_pos, p1: llama_pos);
    pub fn llama_kv_cache_seq_cp(ctx: *mut llama_context, seq_id_src: llama_seq_id, seq_id_dst: llama_seq_id, p0: llama_pos, p1: llama_pos);
    pub fn llama_kv_cache_clear(ctx: *mut llama_context);

    // Sampling (modern API)
    pub fn llama_sampler_chain_default_params() -> llama_sampler_chain_params;
    pub fn llama_sampler_chain_init(params: llama_sampler_chain_params) -> *mut llama_sampler;
    pub fn llama_sampler_chain_add(
        chain: *mut llama_sampler,
        smpl: *mut llama_sampler,
    );
    pub fn llama_sampler_free(smpl: *mut llama_sampler);
    pub fn llama_sampler_init_greedy() -> *mut llama_sampler;
    pub fn llama_sampler_init_dist(
        temperature: f32,
    ) -> *mut llama_sampler;
    pub fn llama_sampler_init_top_k(
        k: i32,
        min_keep: i32,
    ) -> *mut llama_sampler;
    pub fn llama_sampler_init_top_p(
        p: f32,
        min_keep: i32,
    ) -> *mut llama_sampler;
    // Modern sampling: sample token using sampler chain
    pub fn llama_sampler_sample(
        smpl: *mut llama_sampler,
        ctx: *mut llama_context,
        idx: i32,
    ) -> llama_token;
    // Get sampled token (after applying sampler chain)
    pub fn llama_get_logits_ith(
        ctx: *mut llama_context,
        i: i32,
    ) -> *const f32;

    // Logits
    pub fn llama_get_logits(
        ctx: *mut llama_context,
    ) -> *const f32;

    // Token to piece (API change: now takes vocab ptr instead of model ptr)
    pub fn llama_token_to_piece(
        vocab: *const llama_vocab,
        token: llama_token,
        buf: *mut c_char,
        length: i32,
        lstrip: i32,
        special: bool,
    ) -> i32;

    // Performance
    pub fn llama_perf_context_print(ctx: *mut llama_context);
}

// Safe wrapper functions
pub fn default_model_params() -> llama_model_params {
    unsafe { llama_model_default_params() }
}

pub fn default_context_params() -> llama_context_params {
    unsafe { llama_context_default_params() }
}

pub fn load_model_from_file(path: &str, params: llama_model_params) -> Result<*mut llama_model> {
    let c_path = CString::new(path)?;
    let model = unsafe { llama_model_load_from_file(c_path.as_ptr(), params) };
    
    if model.is_null() {
        anyhow::bail!("Failed to load model from: {}", path);
    }
    
    Ok(model)
}

pub fn init_context(model: *const llama_model, params: llama_context_params) -> Result<*mut llama_context> {
    let ctx = unsafe { llama_init_from_model(model, params) };
    
    if ctx.is_null() {
        anyhow::bail!("Failed to initialize context");
    }
    
    Ok(ctx)
}

/// Aerospace-level tokenization with comprehensive error handling
/// 
/// # Safety
/// - Validates all pointers before use
/// - Checks buffer sizes and boundaries
/// - Handles all error conditions gracefully
/// 
/// # Arguments
/// * `model` - Non-null pointer to llama_model
/// * `text` - Input text to tokenize (must be valid UTF-8)
/// * `add_special` - Whether to add special tokens (BOS/EOS)
/// 
/// # Returns
/// * `Ok(Vec<llama_token>)` - Successfully tokenized tokens
/// * `Err` - Detailed error information
pub fn tokenize(
    model: *const llama_model,
    text: &str,
    add_special: bool,
) -> Result<Vec<llama_token>> {
    use tracing::{info, error, warn};
    
    // Aerospace-level: Input validation
    if model.is_null() {
        error!("CRITICAL: Model pointer is null in tokenize");
        anyhow::bail!("Model pointer is null - cannot proceed with tokenization");
    }
    
    // Validate text length
    if text.is_empty() {
        warn!("Empty text provided for tokenization");
        return Ok(Vec::new());
    }
    
    if text.len() > i32::MAX as usize {
        error!("Text length {} exceeds maximum i32 value", text.len());
        anyhow::bail!("Text too long: {} bytes (max: {})", text.len(), i32::MAX);
    }
    
    info!("tokenize: model_ptr={:p}, text_len={}, add_special={}", model, text.len(), add_special);

    // Aerospace-level: Safe C string conversion with error handling
    let c_text = CString::new(text).map_err(|e| {
        error!("Failed to convert text to CString: {}", e);
        anyhow::anyhow!("Text contains null bytes: {}", e)
    })?;
    let text_len = text.len() as i32;

    info!("tokenize: calling llama_tokenize to get token count...");

    // Get vocab from model (API change in newer llama.cpp)
    let vocab = unsafe { llama_model_get_vocab(model) };
    if vocab.is_null() {
        error!("Failed to get vocab from model");
        anyhow::bail!("Failed to get vocab from model");
    }
    info!("tokenize: got vocab pointer: {:p}", vocab);

    // First call to get the number of tokens
    // Returns negative value indicating required buffer size
    let n_tokens_result = unsafe {
        llama_tokenize(
            vocab,
            c_text.as_ptr(),
            text_len,
            ptr::null_mut(),
            0,
            add_special,
            true,
        )
    };
    
    info!("tokenize: got n_tokens_result={}", n_tokens_result);
    
    // Aerospace-level: Validate tokenization result
    if n_tokens_result == 0 {
        warn!("Tokenization returned 0 tokens for non-empty text");
        return Ok(Vec::new());
    }
    
    // llama_tokenize returns negative value when buffer is too small
    // The absolute value is the required number of tokens
    let n_tokens = if n_tokens_result < 0 {
        -n_tokens_result
    } else {
        n_tokens_result
    };
    
    if n_tokens <= 0 {
        error!("Tokenization failed with invalid token count: {}", n_tokens);
        anyhow::bail!("Tokenization failed: n_tokens={}", n_tokens);
    }
    
    // Aerospace-level: Sanity check on token count
    if n_tokens > 100000 {
        error!("Suspiciously large token count: {}", n_tokens);
        anyhow::bail!("Token count {} exceeds safety limit (100000)", n_tokens);
    }
    
    // Allocate buffer and tokenize
    let mut tokens = vec![0; n_tokens as usize];
    
    info!("tokenize: calling llama_tokenize to fill {} tokens...", n_tokens);
    
    let result = unsafe {
        llama_tokenize(
            vocab,
            c_text.as_ptr(),
            text_len,
            tokens.as_mut_ptr(),
            n_tokens,
            add_special,
            true,
        )
    };
    
    info!("tokenize: result={}", result);
    
    // Aerospace-level: Validate second tokenization call
    if result < 0 {
        error!("Second tokenization call failed with result={}", result);
        anyhow::bail!("Tokenization failed with result={}", result);
    }
    
    if result != n_tokens {
        error!("Token count mismatch: expected {}, got {}", n_tokens, result);
        anyhow::bail!("Token count mismatch: expected {}, got {}", n_tokens, result);
    }
    
    // Resize to actual number of tokens returned
    tokens.truncate(result as usize);
    
    info!("tokenize: success, returning {} tokens", tokens.len());
    Ok(tokens)
}

/// Aerospace-level token to text conversion with comprehensive error handling
/// 
/// # Safety
/// - Validates all pointers before use
/// - Checks buffer boundaries
/// - Handles invalid tokens gracefully
/// 
/// # Arguments
/// * `model` - Non-null pointer to llama_model
/// * `token` - Token ID to convert
/// 
/// # Returns
/// * `Ok(String)` - Successfully converted text
/// * `Err` - Detailed error information
pub fn token_to_piece(model: *const llama_model, token: llama_token) -> Result<String> {
    use tracing::{error, warn, info};
    
    // Aerospace-level: Input validation
    if model.is_null() {
        error!("CRITICAL: Model pointer is null in token_to_piece");
        anyhow::bail!("Model pointer is null");
    }
    
    // Validate token range (basic sanity check)
    if token < 0 {
        error!("Invalid token ID: {}", token);
        anyhow::bail!("Invalid token ID: {}", token);
    }
    
    // Get vocab from model
    let vocab = unsafe { llama_model_get_vocab(model) };
    if vocab.is_null() {
        error!("Failed to get vocab from model");
        anyhow::bail!("Failed to get vocab from model");
    }
    info!("token_to_piece: got vocab {:p} for token {}", vocab, token);
    
    // Aerospace-level: Use adequate buffer size with safety margin
    let mut buf = [0u8; 256];
    let n = unsafe {
        llama_token_to_piece(
            vocab,  // Use vocab instead of model
            token,
            buf.as_mut_ptr() as *mut c_char,
            buf.len() as i32,
            0,  // lstrip
            false,  // special
        )
    };
    
    // Aerospace-level: Validate conversion result
    if n < 0 {
        error!("Failed to convert token {} to piece: result={}", token, n);
        anyhow::bail!("Failed to convert token {} to piece", token);
    }
    
    if n as usize >= buf.len() {
        error!("Token {} conversion exceeded buffer size: {} >= {}", token, n, buf.len());
        anyhow::bail!("Token conversion buffer overflow");
    }
    
    // Aerospace-level: Safe string conversion with error handling
    let c_str = unsafe { CStr::from_ptr(buf.as_ptr() as *const c_char) };
    let result = c_str.to_string_lossy().to_string();
    
    // Sanity check on result
    if result.len() > 1000 {
        warn!("Suspiciously long token conversion: {} bytes", result.len());
    }
    
    Ok(result)
}

pub fn get_batch_one(tokens: &mut [llama_token]) -> llama_batch {
    unsafe { llama_batch_get_one(tokens.as_mut_ptr(), tokens.len() as i32) }
}

pub fn init_batch(n_tokens: i32, embd: i32, n_seq_max: i32) -> llama_batch {
    unsafe { llama_batch_init(n_tokens, embd, n_seq_max) }
}

pub fn free_batch(batch: llama_batch) {
    unsafe { llama_batch_free(batch) }
}
