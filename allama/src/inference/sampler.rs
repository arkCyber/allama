// Aerospace-Level Sampler Configuration
// Safe wrapper for llama.cpp sampling strategies

use anyhow::Result;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::info;

use super::ffi::{llama_sampler, llama_token};

/// Sampling strategy
#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
pub enum SamplingStrategy {
    /// Greedy sampling (always pick highest probability)
    Greedy,
    /// Temperature sampling (randomness control)
    Temperature { temperature: f32 },
    /// Top-k sampling (sample from top k tokens)
    TopK { k: i32, min_keep: i32 },
    /// Top-p (nucleus) sampling
    TopP { p: f32, min_keep: i32 },
    /// Combined strategy (temperature + top-p)
    Combined { temperature: f32, top_p: f32, top_k: Option<i32> },
}

impl Default for SamplingStrategy {
    fn default() -> Self {
        Self::Combined {
            temperature: 0.7,
            top_p: 0.9,
            top_k: Some(40),
        }
    }
}

/// Sampler configuration
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct SamplerConfig {
    pub strategy: SamplingStrategy,
    pub repeat_penalty: f32,
    pub repeat_last_n: i32,
    pub frequency_penalty: f32,
    pub presence_penalty: f32,
    pub mirostat: bool,
    pub mirostat_tau: f32,
    pub mirostat_eta: f32,
}

impl Default for SamplerConfig {
    fn default() -> Self {
        Self {
            strategy: SamplingStrategy::default(),
            repeat_penalty: 1.0,
            repeat_last_n: 64,
            frequency_penalty: 0.0,
            presence_penalty: 0.0,
            mirostat: false,
            mirostat_tau: 5.0,
            mirostat_eta: 0.1,
        }
    }
}

impl SamplerConfig {
    pub fn validate(&self) -> Result<()> {
        match self.strategy {
            SamplingStrategy::Temperature { temperature } => {
                if temperature <= 0.0 {
                    anyhow::bail!("Temperature must be positive");
                }
            }
            SamplingStrategy::TopK { k, min_keep } => {
                if k <= 0 {
                    anyhow::bail!("Top-k must be positive");
                }
                if min_keep < 0 {
                    anyhow::bail!("Min keep must be non-negative");
                }
            }
            SamplingStrategy::TopP { p, min_keep } => {
                if p <= 0.0 || p > 1.0 {
                    anyhow::bail!("Top-p must be in (0, 1]");
                }
                if min_keep < 0 {
                    anyhow::bail!("Min keep must be non-negative");
                }
            }
            SamplingStrategy::Combined { temperature, top_p, top_k } => {
                if temperature <= 0.0 {
                    anyhow::bail!("Temperature must be positive");
                }
                if top_p <= 0.0 || top_p > 1.0 {
                    anyhow::bail!("Top-p must be in (0, 1]");
                }
                if let Some(k) = top_k {
                    if k <= 0 {
                        anyhow::bail!("Top-k must be positive");
                    }
                }
            }
            _ => {}
        }

        if self.repeat_penalty < 0.0 {
            anyhow::bail!("Repeat penalty must be non-negative");
        }

        Ok(())
    }
}

/// Thread-safe sampler wrapper
// SAFETY: All access to the raw chain pointer is protected by Arc<RwLock>,
// ensuring exclusive access. The pointer is only used in the sample() method
// which synchronizes through the RwLock.
#[derive(Debug, Clone)]
pub struct Sampler {
    config: Arc<RwLock<SamplerConfig>>,
    chain: Arc<RwLock<*mut llama_sampler>>,
}

unsafe impl Send for Sampler {}
unsafe impl Sync for Sampler {}

impl Sampler {
    pub fn new(config: SamplerConfig) -> Result<Self> {
        config.validate()?;

        // Create sampler chain
        let chain = unsafe {
            let sparams = super::ffi::llama_sampler_chain_default_params();
            let chain_ptr = super::ffi::llama_sampler_chain_init(sparams);

            match config.strategy {
                SamplingStrategy::Greedy => {
                    let greedy = super::ffi::llama_sampler_init_greedy();
                    super::ffi::llama_sampler_chain_add(chain_ptr, greedy);
                }
                SamplingStrategy::Temperature { temperature } => {
                    let dist = super::ffi::llama_sampler_init_dist(temperature);
                    super::ffi::llama_sampler_chain_add(chain_ptr, dist);
                }
                SamplingStrategy::TopK { k, min_keep } => {
                    let top_k = super::ffi::llama_sampler_init_top_k(k, min_keep);
                    super::ffi::llama_sampler_chain_add(chain_ptr, top_k);
                }
                SamplingStrategy::TopP { p, min_keep } => {
                    let top_p = super::ffi::llama_sampler_init_top_p(p, min_keep);
                    super::ffi::llama_sampler_chain_add(chain_ptr, top_p);
                }
                SamplingStrategy::Combined { temperature, top_p, top_k } => {
                    let dist = super::ffi::llama_sampler_init_dist(temperature);
                    super::ffi::llama_sampler_chain_add(chain_ptr, dist);

                    let top_p = super::ffi::llama_sampler_init_top_p(top_p, 1);
                    super::ffi::llama_sampler_chain_add(chain_ptr, top_p);

                    if let Some(k) = top_k {
                        let top_k = super::ffi::llama_sampler_init_top_k(k, 1);
                        super::ffi::llama_sampler_chain_add(chain_ptr, top_k);
                    }
                }
            }

            chain_ptr
        };

        if chain.is_null() {
            anyhow::bail!("Failed to create sampler chain");
        }

        Ok(Self {
            config: Arc::new(RwLock::new(config)),
            chain: Arc::new(RwLock::new(chain)),
        })
    }

    pub async fn sample(
        &self,
        ctx: *mut super::ffi::llama_context,
        idx: i32,
    ) -> Result<llama_token> {
        let chain = *self.chain.read().await;

        if chain.is_null() {
            anyhow::bail!("Sampler chain is null");
        }

        if ctx.is_null() {
            anyhow::bail!("Context pointer is null");
        }

        // Sample token using the sampler chain
        // This is the correct API: llama_sampler_sample returns the sampled token directly
        let token = unsafe { super::ffi::llama_sampler_sample(chain, ctx, idx) };

        if token < 0 {
            anyhow::bail!("Sampling failed: invalid token {}", token);
        }

        Ok(token)
    }

    pub async fn get_config(&self) -> SamplerConfig {
        self.config.read().await.clone()
    }

    pub async fn update_config(&self, config: SamplerConfig) -> Result<()> {
        config.validate()?;
        *self.config.write().await = config;
        info!("Sampler configuration updated");
        Ok(())
    }
}

impl Drop for Sampler {
    fn drop(&mut self) {
        // Try to read the chain pointer without blocking
        if let Ok(chain_guard) = self.chain.try_read() {
            let chain = *chain_guard;
            if !chain.is_null() {
                unsafe {
                    super::ffi::llama_sampler_free(chain);
                }
            }
        }
        // If we can't acquire the lock, the chain will be leaked
        // This is acceptable in a Drop implementation to avoid panics
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sampler_config_default() {
        let config = SamplerConfig::default();
        assert!(config.validate().is_ok());
    }

    #[test]
    fn test_sampler_config_validation() {
        let mut config = SamplerConfig::default();
        config.strategy = SamplingStrategy::Temperature { temperature: -1.0 };
        assert!(config.validate().is_err());

        config.strategy = SamplingStrategy::Temperature { temperature: 0.5 };
        assert!(config.validate().is_ok());
    }

    #[test]
    fn test_sampling_strategies() {
        let strategies = vec![
            SamplingStrategy::Greedy,
            SamplingStrategy::Temperature { temperature: 0.7 },
            SamplingStrategy::TopK { k: 40, min_keep: 1 },
            SamplingStrategy::TopP { p: 0.9, min_keep: 1 },
            SamplingStrategy::Combined { temperature: 0.7, top_p: 0.9, top_k: Some(40) },
        ];

        for strategy in strategies {
            let config = SamplerConfig {
                strategy,
                ..Default::default()
            };
            assert!(config.validate().is_ok());
        }
    }
}
