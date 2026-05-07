// Inference Service HTTP Client
// Used by Axum server to communicate with inference service

use anyhow::Result;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::time::Duration;

/// Inference request to send to inference service
#[derive(Debug, Serialize)]
pub struct InferenceRequest {
    pub model: String,
    pub prompt: String,
    pub max_tokens: Option<u32>,
    pub temperature: Option<f32>,
    pub top_p: Option<f32>,
    pub top_k: Option<i32>,
}

/// Inference response from inference service
#[derive(Debug, Deserialize)]
pub struct InferenceResponse {
    pub text: String,
    pub tokens_generated: u32,
    pub prompt_tokens: u32,
    pub duration_ms: u64,
    pub tokens_per_second: f32,
    pub error: Option<String>,
}

/// HTTP client for inference service
pub struct InferenceClient {
    client: Client,
    base_url: String,
}

impl InferenceClient {
    pub fn new(base_url: String) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(300))
            .build()
            .expect("Failed to create HTTP client");
        
        Self { client, base_url }
    }
    
    pub async fn generate(&self, model: &str, prompt: &str, max_tokens: u32, temperature: f32) -> Result<InferenceResponse> {
        let url = format!("{}/inference", self.base_url);
        
        let request = InferenceRequest {
            model: model.to_string(),
            prompt: prompt.to_string(),
            max_tokens: Some(max_tokens),
            temperature: Some(temperature),
            top_p: Some(0.9),
            top_k: Some(40),
        };
        
        let response = self.client
            .post(&url)
            .json(&request)
            .send()
            .await?;
        
        if !response.status().is_success() {
            return Err(anyhow::anyhow!("Inference service returned error: {}", response.status()));
        }
        
        let result: InferenceResponse = response.json().await?;
        
        if let Some(error) = &result.error {
            return Err(anyhow::anyhow!("Inference failed: {}", error));
        }
        
        Ok(result)
    }
    
    pub async fn health_check(&self) -> Result<bool> {
        let url = format!("{}/health", self.base_url);
        
        let response = self.client
            .post(&url)
            .send()
            .await?;
        
        Ok(response.status().is_success())
    }
}
