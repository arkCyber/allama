// Aerospace-Level Model Manager
// Thread-safe model loading, caching, and lifecycle management

use anyhow::Result;
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn, error};

use super::ffi::{llama_model, llama_model_params, llama_context, llama_context_params};

/// Model information
#[derive(Debug, Clone)]
pub struct ModelInfo {
    pub path: PathBuf,
    pub size_bytes: u64,
    pub n_params: u64,
    pub n_ctx_train: u32,
    pub n_embd: i32,
    pub n_layer: i32,
    pub loaded_at: chrono::DateTime<chrono::Utc>,
}

/// Model handle with context
#[derive(Debug)]
pub struct ModelHandle {
    pub model: super::ffi::ModelPtr,
    pub context: super::ffi::ContextPtr,
    pub info: ModelInfo,
}

unsafe impl Send for ModelHandle {}
unsafe impl Sync for ModelHandle {}

impl ModelHandle {
    pub fn new(
        model: *mut llama_model,
        context: *mut llama_context,
        info: ModelInfo,
    ) -> Self {
        Self {
            model: super::ffi::ModelPtr::new(model),
            context: super::ffi::ContextPtr::new(context),
            info,
        }
    }
}

impl Drop for ModelHandle {
    fn drop(&mut self) {
        info!("Dropping model handle: {:?}", self.info.path);
        
        let ctx_ptr = self.context.as_ptr();
        if !ctx_ptr.is_null() {
            unsafe {
                super::ffi::llama_free(ctx_ptr);
            }
        }
        
        let model_ptr = self.model.as_ptr();
        if !model_ptr.is_null() {
            unsafe {
                super::ffi::llama_model_free(model_ptr);
            }
        }
    }
}

/// Model manager (aerospace-level thread-safe)
#[derive(Debug, Clone)]
pub struct ModelManager {
    models: Arc<RwLock<HashMap<String, Arc<ModelHandle>>>>,
    max_loaded_models: usize,
    models_dir: PathBuf,
}

impl ModelManager {
    pub fn new(max_loaded_models: usize, models_dir: PathBuf) -> Result<Self> {
        info!("Initializing model manager with max {} models", max_loaded_models);
        
        Ok(Self {
            models: Arc::new(RwLock::new(HashMap::new())),
            max_loaded_models,
            models_dir,
        })
    }
    
    /// Load a model from file
    pub async fn load_model(
        &self,
        model_name: &str,
        model_params: Option<llama_model_params>,
        context_params: Option<llama_context_params>,
    ) -> Result<Arc<ModelHandle>> {
        // Check if already loaded
        {
            let models = self.models.read().await;
            if let Some(handle) = models.get(model_name) {
                info!("Model '{}' already loaded", model_name);
                return Ok(handle.clone());
            }
        }
        
        // Check capacity
        {
            let models = self.models.read().await;
            if models.len() >= self.max_loaded_models {
                warn!("Model capacity reached ({}), consider unloading unused models", self.max_loaded_models);
            }
        }
        
        // Resolve model path
        let model_path = self.resolve_model_path(model_name)?;
        
        if !model_path.exists() {
            error!("Model file not found: {:?}", model_path);
            anyhow::bail!("Model file not found: {:?}", model_path);
        }
        
        // Aerospace-level: Log model loading attempt
        info!("Loading model '{}' from: {:?}", model_name, model_path);
        
        // Use default params if not provided
        let m_params = model_params.unwrap_or_else(|| {
            unsafe { super::ffi::default_model_params() }
        });
        
        let c_params = context_params.unwrap_or_else(|| {
            unsafe { super::ffi::default_context_params() }
        });
        
        // Load model (FFI call - must be on main thread for thread safety)
        let path_str = model_path.to_str()
            .ok_or_else(|| anyhow::anyhow!("Invalid UTF-8 in model path: {:?}", model_path))?;
        let c_path = std::ffi::CString::new(path_str)?;
        
        let model = unsafe {
            super::ffi::llama_model_load_from_file(c_path.as_ptr(), m_params)
        };
        
        if model.is_null() {
            error!("Failed to load model '{}' from: {:?}", model_name, model_path);
            anyhow::bail!("Failed to load model from: {:?}", model_path);
        }
        
        info!("Model '{}' loaded successfully", model_name);
        
        // Get model info
        let size_bytes = unsafe { super::ffi::llama_model_size(model) };
        let n_params = unsafe { super::ffi::llama_model_n_params(model) };
        let n_ctx_train = unsafe { super::ffi::llama_model_n_ctx_train(model) };
        let n_embd = unsafe { super::ffi::llama_model_n_embd(model) };
        let n_layer = unsafe { super::ffi::llama_model_n_layer(model) };
        
        info!("Model '{}' loaded successfully", model_name);
        
        // Aerospace-level: Log model information
        info!("Model '{}' info: size={}MB, params={}, ctx_train={}, embd={}, layers={}", 
              model_name, size_bytes / (1024 * 1024), n_params, n_ctx_train, n_embd, n_layer);
        
        let info = ModelInfo {
            path: model_path.clone(),
            size_bytes,
            n_params,
            n_ctx_train,
            n_embd,
            n_layer,
            loaded_at: chrono::Utc::now(),
        };
        
        info!("Model loaded: {} params, {} bytes, {} layers", n_params, size_bytes, n_layer);
        
        // Initialize context (FFI call - must be on main thread for thread safety)
        let context = unsafe { super::ffi::init_context(model, c_params) }?;
        
        let handle = Arc::new(ModelHandle::new(model, context, info));
        
        // Store in cache
        {
            let mut models = self.models.write().await;
            models.insert(model_name.to_string(), handle.clone());
        }
        
        info!("Model '{}' loaded and cached", model_name);
        Ok(handle)
    }
    
    /// Unload a model
    pub async fn unload_model(&self, model_name: &str) -> Result<()> {
        let mut models = self.models.write().await;
        
        if models.remove(model_name).is_some() {
            info!("Model '{}' unloaded", model_name);
            Ok(())
        } else {
            warn!("Model '{}' not found for unloading", model_name);
            Ok(())
        }
    }
    
    /// Get a loaded model handle
    pub async fn get_model(&self, model_name: &str) -> Option<Arc<ModelHandle>> {
        let models = self.models.read().await;
        let handle = models.get(model_name).cloned();
        if let Some(ref h) = handle {
            info!("get_model: returning handle with Arc count: {}", Arc::strong_count(h));
        }
        handle
    }
    
    /// List all loaded models
    pub async fn list_loaded(&self) -> Vec<String> {
        let models = self.models.read().await;
        models.keys().cloned().collect()
    }
    
    /// Get model info
    pub async fn get_model_info(&self, model_name: &str) -> Option<ModelInfo> {
        let models = self.models.read().await;
        models.get(model_name).map(|h| h.info.clone())
    }
    
    /// Resolve model path (supports relative paths and model names)
    pub fn resolve_model_path(&self, model_name: &str) -> Result<PathBuf> {
        let path = PathBuf::from(model_name);
        
        if path.is_absolute() {
            return Ok(path);
        }
        
        // Check if it's a relative path
        if path.exists() {
            return Ok(path);
        }
        
        // Check in models directory
        let models_dir_path = self.models_dir.join(model_name);
        if models_dir_path.exists() {
            return Ok(models_dir_path);
        }
        
        // Try with .gguf extension
        let gguf_path = self.models_dir.join(format!("{}.gguf", model_name));
        if gguf_path.exists() {
            return Ok(gguf_path);
        }
        
        // Try as relative path from current directory
        if path.exists() {
            return Ok(path);
        }
        
        anyhow::bail!("Model not found: {}", model_name)
    }
    
    /// Get memory usage statistics
    pub async fn get_memory_usage(&self) -> (usize, u64) {
        let models = self.models.read().await;
        let count = models.len();
        let total_bytes: u64 = models.values()
            .map(|h| h.info.size_bytes)
            .sum();
        (count, total_bytes)
    }
    
    /// Unload all models
    pub async fn unload_all(&self) {
        let mut models = self.models.write().await;
        let count = models.len();
        models.clear();
        info!("Unloaded {} models", count);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    
    #[test]
    fn test_model_manager_creation() {
        let temp_dir = TempDir::new().unwrap();
        let manager = ModelManager::new(3, temp_dir.path().to_path_buf()).unwrap();
        assert_eq!(manager.max_loaded_models, 3);
    }
    
    #[tokio::test]
    async fn test_model_list_empty() {
        let temp_dir = TempDir::new().unwrap();
        let manager = ModelManager::new(3, temp_dir.path().to_path_buf()).unwrap();
        let loaded = manager.list_loaded().await;
        assert!(loaded.is_empty());
    }
    
    #[tokio::test]
    async fn test_memory_usage() {
        let temp_dir = TempDir::new().unwrap();
        let manager = ModelManager::new(3, temp_dir.path().to_path_buf()).unwrap();
        let (count, bytes) = manager.get_memory_usage().await;
        assert_eq!(count, 0);
        assert_eq!(bytes, 0);
    }
}
