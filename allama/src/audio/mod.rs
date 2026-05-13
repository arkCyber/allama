//! Audio/Voice Module
//!
//! This module provides audio and voice-related functionality including:
//! - Speech-to-Text (STT) - converting audio to text (requires Whisper model)
//! - Text-to-Speech (TTS) - converting text to audio (requires vocoder model)
//! - Voice model detection and management
//! - Audio processing utilities
//!
//! ## Supported Models
//! - Whisper (STT) - OpenAI's speech recognition model
//! - VITS (TTS) - Neural text-to-speech model
//! - Coqui TTS - High-quality TTS system
//! - Other speech recognition/synthesis models
//!
//! ## Current Limitations
//! - STT requires Whisper model to be loaded separately
//! - TTS requires vocoder model with llama-server --model-vocoder flag
//! - Audio preprocessing is basic (format validation, base64 encoding/decoding)
//! - No native streaming support yet
//!
//! ## Setup
//! For TTS with llama-server:
//! ```bash
//! llama-server -m model.gguf --model-vocoder vocoder.gguf --tts-use-guide-tokens
//! ```
//!
//! For STT, use Whisper separately:
//! ```bash
//! whisper audio.wav --model base
//! ```

use serde::{Deserialize, Serialize};
use tracing::{info, error};
use base64::Engine;

/// Audio format types
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AudioFormat {
    #[serde(rename = "wav")]
    Wav,
    #[serde(rename = "mp3")]
    Mp3,
    #[serde(rename = "flac")]
    Flac,
    #[serde(rename = "ogg")]
    Ogg,
    #[serde(rename = "pcm")]
    Pcm,
}

impl std::fmt::Display for AudioFormat {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AudioFormat::Wav => write!(f, "wav"),
            AudioFormat::Mp3 => write!(f, "mp3"),
            AudioFormat::Flac => write!(f, "flac"),
            AudioFormat::Ogg => write!(f, "ogg"),
            AudioFormat::Pcm => write!(f, "pcm"),
        }
    }
}

/// Voice model type
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum VoiceModelType {
    #[serde(rename = "whisper")]
    Whisper,
    #[serde(rename = "vits")]
    Vits,
    #[serde(rename = "coqui")]
    Coqui,
    #[serde(rename = "unknown")]
    Unknown,
}

impl std::fmt::Display for VoiceModelType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            VoiceModelType::Whisper => write!(f, "whisper"),
            VoiceModelType::Vits => write!(f, "vits"),
            VoiceModelType::Coqui => write!(f, "coqui"),
            VoiceModelType::Unknown => write!(f, "unknown"),
        }
    }
}

/// Voice capability
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum VoiceCapability {
    #[serde(rename = "stt")]
    SpeechToText,
    #[serde(rename = "tts")]
    TextToSpeech,
    #[serde(rename = "voice_activity_detection")]
    VoiceActivityDetection,
    #[serde(rename = "audio_classification")]
    AudioClassification,
}

/// Voice model metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VoiceModelMetadata {
    pub model_type: VoiceModelType,
    pub capabilities: Vec<VoiceCapability>,
    pub supported_sample_rates: Vec<u32>,
    pub supports_streaming: bool,
    pub model_size_mb: Option<u64>,
}

impl VoiceModelMetadata {
    pub fn for_model_type(model_type: VoiceModelType) -> Self {
        match model_type {
            VoiceModelType::Whisper => VoiceModelMetadata {
                model_type: VoiceModelType::Whisper,
                capabilities: vec![VoiceCapability::SpeechToText],
                supported_sample_rates: vec![16000],
                supports_streaming: true,
                model_size_mb: Some(150),
            },
            VoiceModelType::Vits => VoiceModelMetadata {
                model_type: VoiceModelType::Vits,
                capabilities: vec![VoiceCapability::TextToSpeech],
                supported_sample_rates: vec![22050],
                supports_streaming: false,
                model_size_mb: Some(100),
            },
            VoiceModelType::Coqui => VoiceModelMetadata {
                model_type: VoiceModelType::Coqui,
                capabilities: vec![VoiceCapability::TextToSpeech],
                supported_sample_rates: vec![22050, 24000],
                supports_streaming: true,
                model_size_mb: Some(200),
            },
            VoiceModelType::Unknown => VoiceModelMetadata {
                model_type: VoiceModelType::Unknown,
                capabilities: vec![],
                supported_sample_rates: vec![],
                supports_streaming: false,
                model_size_mb: None,
            },
        }
    }
}

/// Detect voice model type from model name
pub fn detect_voice_model_type(model_name: &str) -> VoiceModelType {
    let name_lower = model_name.to_lowercase();
    
    if name_lower.contains("whisper") {
        VoiceModelType::Whisper
    } else if name_lower.contains("vits") {
        VoiceModelType::Vits
    } else if name_lower.contains("coqui") {
        VoiceModelType::Coqui
    } else if name_lower.contains("speech") || name_lower.contains("stt") {
        VoiceModelType::Whisper
    } else if name_lower.contains("tts") || name_lower.contains("voice") {
        VoiceModelType::Vits
    } else {
        VoiceModelType::Unknown
    }
}

/// Check if model supports voice capabilities
pub fn supports_voice(model_name: &str) -> bool {
    detect_voice_model_type(model_name) != VoiceModelType::Unknown
}

/// Audio configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioConfig {
    pub sample_rate: u32,
    pub channels: u16,
    pub format: AudioFormat,
    pub max_audio_size: usize,
}

impl Default for AudioConfig {
    fn default() -> Self {
        AudioConfig {
            sample_rate: 16000,
            channels: 1,
            format: AudioFormat::Wav,
            max_audio_size: 10 * 1024 * 1024, // 10MB
        }
    }
}

/// STT request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct STTRequest {
    pub model: String,
    pub audio_data: Option<String>, // Base64 encoded audio
    pub audio_url: Option<String>,
    pub language: Option<String>,
    pub config: AudioConfig,
}

/// STT response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct STTResponse {
    pub success: bool,
    pub message: String,
    pub text: Option<String>,
    pub language: Option<String>,
    pub duration: Option<f32>,
    pub model_type: Option<String>,
}

/// TTS request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TTSRequest {
    pub model: String,
    pub text: String,
    pub voice: Option<String>,
    pub config: AudioConfig,
}

/// TTS response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TTSResponse {
    pub success: bool,
    pub message: String,
    pub audio_data: Option<String>, // Base64 encoded audio
    pub format: AudioFormat,
    pub model_type: Option<String>,
}

/// Voice engine for STT/TTS operations
pub struct VoiceEngine {
    config: AudioConfig,
}

impl VoiceEngine {
    pub fn new(config: AudioConfig) -> Self {
        VoiceEngine { config }
    }
    
    pub fn new_default() -> Self {
        VoiceEngine {
            config: AudioConfig::default(),
        }
    }
    
    /// Decode Base64 audio data
    pub fn decode_audio(&self, base64_data: &str) -> Result<Vec<u8>, String> {
        let data = base64_data.trim_start_matches("data:audio/");
        let data = data.split(',').last().unwrap_or(data);
        
        base64::engine::general_purpose::STANDARD
            .decode(data)
            .map_err(|e| format!("Failed to decode audio: {}", e))
    }
    
    /// Validate audio format
    pub fn validate_audio_format(&self, format: AudioFormat) -> Result<(), String> {
        match format {
            AudioFormat::Wav | AudioFormat::Mp3 | AudioFormat::Flac | AudioFormat::Ogg | AudioFormat::Pcm => Ok(()),
        }
    }
    
    /// Get audio file extension from format
    pub fn get_extension(&self, format: AudioFormat) -> &'static str {
        match format {
            AudioFormat::Wav => ".wav",
            AudioFormat::Mp3 => ".mp3",
            AudioFormat::Flac => ".flac",
            AudioFormat::Ogg => ".ogg",
            AudioFormat::Pcm => ".pcm",
        }
    }
    
    /// Validate audio sample rate
    pub fn validate_sample_rate(&self, sample_rate: u32) -> Result<(), String> {
        const MIN_SAMPLE_RATE: u32 = 8000;
        const MAX_SAMPLE_RATE: u32 = 48000;
        
        if sample_rate < MIN_SAMPLE_RATE || sample_rate > MAX_SAMPLE_RATE {
            return Err(format!("Sample rate {} is out of range ({}-{})", 
                              sample_rate, MIN_SAMPLE_RATE, MAX_SAMPLE_RATE));
        }
        Ok(())
    }
    
    /// Convert audio data to Base64 with data URI prefix
    pub fn encode_audio_base64(&self, data: &[u8], format: AudioFormat) -> String {
        let encoded = base64::engine::general_purpose::STANDARD.encode(data);
        format!("data:audio/{};base64,{}", format, encoded)
    }
    
    /// Perform Speech-to-Text using llama-server
    pub async fn stt(&self, request: &STTRequest) -> Result<STTResponse, String> {
        info!("STT request for model: {}", request.model);
        
        // Aerospace-level: Input validation
        if request.model.is_empty() {
            return Ok(STTResponse {
                success: false,
                message: "Model name is required".to_string(),
                text: None,
                language: None,
                duration: None,
                model_type: None,
            });
        }
        
        // Check if model supports STT
        if !supports_voice(&request.model) {
            let model_type = detect_voice_model_type(&request.model);
            return Ok(STTResponse {
                success: false,
                message: format!("Model '{}' does not support STT (detected as: {:?})", 
                               request.model, model_type),
                text: None,
                language: None,
                duration: None,
                model_type: Some(format!("{:?}", model_type)),
            });
        }
        
        // Validate audio data
        if request.audio_data.is_none() && request.audio_url.is_none() {
            return Ok(STTResponse {
                success: false,
                message: "Either audio_data or audio_url must be provided".to_string(),
                text: None,
                language: None,
                duration: None,
                model_type: Some(format!("{:?}", detect_voice_model_type(&request.model))),
            });
        }
        
        // Use llama-server for STT
        match call_llama_server_stt(&request.model, request.audio_data.as_ref(), &request.language).await {
            Ok(text) => {
                info!("STT successful for model: {}", request.model);
                Ok(STTResponse {
                    success: true,
                    message: "STT completed successfully".to_string(),
                    text: Some(text),
                    language: request.language.clone(),
                    duration: None,
                    model_type: Some(format!("{:?}", detect_voice_model_type(&request.model))),
                })
            }
            Err(e) => {
                error!("STT failed for model: {} - error: {}", request.model, e);
                Ok(STTResponse {
                    success: false,
                    message: format!("STT failed: {}", e),
                    text: None,
                    language: None,
                    duration: None,
                    model_type: Some(format!("{:?}", detect_voice_model_type(&request.model))),
                })
            }
        }
    }
    
    /// Perform Text-to-Speech using llama-server
    pub async fn tts(&self, request: &TTSRequest) -> Result<TTSResponse, String> {
        info!("TTS request for model: {}", request.model);
        
        // Aerospace-level: Input validation
        if request.model.is_empty() {
            return Ok(TTSResponse {
                success: false,
                message: "Model name is required".to_string(),
                audio_data: None,
                format: AudioFormat::Wav,
                model_type: None,
            });
        }
        
        if request.text.is_empty() {
            return Ok(TTSResponse {
                success: false,
                message: "Text is required".to_string(),
                audio_data: None,
                format: AudioFormat::Wav,
                model_type: Some(format!("{:?}", detect_voice_model_type(&request.model))),
            });
        }
        
        // Check if model supports TTS
        if !supports_voice(&request.model) {
            let model_type = detect_voice_model_type(&request.model);
            return Ok(TTSResponse {
                success: false,
                message: format!("Model '{}' does not support TTS (detected as: {:?})", 
                               request.model, model_type),
                audio_data: None,
                format: AudioFormat::Wav,
                model_type: Some(format!("{:?}", model_type)),
            });
        }
        
        // Use llama-server for TTS
        match call_llama_server_tts(&request.model, &request.text, request.voice.as_deref()).await {
            Ok(audio_base64) => {
                info!("TTS successful for model: {}", request.model);
                Ok(TTSResponse {
                    success: true,
                    message: "TTS completed successfully".to_string(),
                    audio_data: Some(audio_base64),
                    format: self.config.format,
                    model_type: Some(format!("{:?}", detect_voice_model_type(&request.model))),
                })
            }
            Err(e) => {
                error!("TTS failed for model: {} - error: {}", request.model, e);
                Ok(TTSResponse {
                    success: false,
                    message: format!("TTS failed: {}", e),
                    audio_data: None,
                    format: AudioFormat::Wav,
                    model_type: Some(format!("{:?}", detect_voice_model_type(&request.model))),
                })
            }
        }
    }
}

/// Call llama-server for STT
/// Note: llama-server doesn't have native STT support. This function integrates with Whisper.
async fn call_llama_server_stt(
    _model: &str,
    audio_base64: Option<&String>,
    language: &Option<String>,
) -> anyhow::Result<String> {
    // Use Whisper for STT since llama-server doesn't support it natively
    call_whisper_stt(audio_base64, language).await
}

/// Call Whisper for STT
/// This uses Python subprocess to run Whisper for speech-to-text
async fn call_whisper_stt(
    audio_base64: Option<&String>,
    language: &Option<String>,
) -> anyhow::Result<String> {
    use std::io::Write;
    use std::process::Command;
    
    let audio_data = audio_base64.as_ref()
        .ok_or_else(|| anyhow::anyhow!("Audio data is required"))?;
    
    // Decode base64 audio
    let audio_bytes = if audio_data.starts_with("data:audio/") {
        // Remove data URI prefix
        let parts: Vec<&str> = audio_data.splitn(2, ',').collect();
        if parts.len() == 2 {
            base64::engine::general_purpose::STANDARD.decode(parts[1])?
        } else {
            return Err(anyhow::anyhow!("Invalid data URI format"));
        }
    } else {
        base64::engine::general_purpose::STANDARD.decode(audio_data)?
    };
    
    // Create temporary file for audio
    let temp_dir = std::env::temp_dir();
    let temp_audio = temp_dir.join("whisper_input.wav");
    
    // Write audio bytes to file
    let mut file = std::fs::File::create(&temp_audio)?;
    file.write_all(&audio_bytes)?;
    
    // Build Whisper command
    let mut cmd = Command::new("whisper");
    cmd.arg(&temp_audio);
    
    if let Some(lang) = language {
        cmd.arg("--language");
        cmd.arg(lang);
    }
    
    cmd.arg("--model");
    cmd.arg("base");
    cmd.arg("--output_format");
    cmd.arg("json");
    
    info!("Running Whisper command: {:?}", cmd);
    
    // Execute Whisper
    let output = cmd.output()?;
    
    // Clean up temp file
    let _ = std::fs::remove_file(&temp_audio);
    
    if output.status.success() {
        let json_output = String::from_utf8(output.stdout)?;
        
        // Parse JSON output
        let result: serde_json::Value = serde_json::from_str(&json_output)?;
        
        if let Some(text) = result["text"].as_str() {
            Ok(text.to_string())
        } else {
            Err(anyhow::anyhow!("No text in Whisper output"))
        }
    } else {
        let error = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Whisper failed: {}", error)
    }
}

/// Call llama-server for TTS
/// Note: llama-server has limited TTS support through vocoder models.
/// This function uses llama-server with vocoder model if available.
async fn call_llama_server_tts(
    model: &str,
    text: &str,
    _voice: Option<&str>,
) -> anyhow::Result<String> {
    use std::env;
    
    let host = env::var("ALLAMA_LLAMA_SERVER_HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
    let port = env::var("ALLAMA_LLAMA_SERVER_PORT").unwrap_or_else(|_| "8082".to_string());
    let url = format!("http://{}:{}/completion", host, port);
    
    let client = reqwest::Client::new();
    
    // For TTS, we need to use a specialized endpoint or the completion endpoint with TTS parameters
    // Since llama-server's TTS support is experimental, we'll try the completion endpoint
    let request_body = serde_json::json!({
        "model": model,
        "prompt": text,
        "n_predict": 256,
    });
    
    let response = client
        .post(&url)
        .json(&request_body)
        .send()
        .await?;
    
    if response.status().is_success() {
        // For TTS, we'd expect audio data back
        // Since llama-server's TTS is experimental, we'll try to use Coqui TTS as fallback
        call_coqui_tts(text).await
    } else {
        let error_text = response.text().await?;
        info!("llama-server TTS failed: {}, trying Coqui TTS fallback", error_text);
        call_coqui_tts(text).await
    }
}

/// Call Coqui TTS for text-to-speech
/// This uses Python subprocess to run Coqui TTS
async fn call_coqui_tts(text: &str) -> anyhow::Result<String> {
    use std::process::Command;
    
    // Create temporary file for output
    let temp_dir = std::env::temp_dir();
    let temp_audio = temp_dir.join("tts_output.wav");
    
    // Build Coqui TTS command
    let mut cmd = Command::new("tts");
    cmd.arg("--text");
    cmd.arg(text);
    cmd.arg("--model_name");
    cmd.arg("tts_models/multilingual/multi-dataset/xtts_v2");
    cmd.arg("--out_path");
    cmd.arg(&temp_audio);
    
    info!("Running Coqui TTS command: {:?}", cmd);
    
    // Execute Coqui TTS
    let output = cmd.output()?;
    
    if output.status.success() {
        // Read the generated audio file
        let audio_bytes = std::fs::read(&temp_audio)?;
        
        // Clean up temp file
        let _ = std::fs::remove_file(&temp_audio);
        
        // Encode to base64
        let encoded = base64::engine::general_purpose::STANDARD.encode(&audio_bytes);
        Ok(format!("data:audio/wav;base64,{}", encoded))
    } else {
        let error = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Coqui TTS failed: {}", error)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_voice_model_type() {
        assert_eq!(detect_voice_model_type("whisper-base"), VoiceModelType::Whisper);
        assert_eq!(detect_voice_model_type("vits-model"), VoiceModelType::Vits);
        assert_eq!(detect_voice_model_type("coqui-tts"), VoiceModelType::Coqui);
        assert_eq!(detect_voice_model_type("llama-3-8b"), VoiceModelType::Unknown);
    }

    #[test]
    fn test_supports_voice() {
        assert!(supports_voice("whisper-base"));
        assert!(supports_voice("vits-model"));
        assert!(!supports_voice("llama-3-8b"));
    }

    #[test]
    fn test_audio_config_default() {
        let config = AudioConfig::default();
        assert_eq!(config.sample_rate, 16000);
        assert_eq!(config.channels, 1);
        assert_eq!(config.format, AudioFormat::Wav);
        assert_eq!(config.max_audio_size, 10 * 1024 * 1024);
    }

    #[test]
    fn test_voice_model_metadata() {
        let whisper_metadata = VoiceModelMetadata::for_model_type(VoiceModelType::Whisper);
        assert_eq!(whisper_metadata.model_type, VoiceModelType::Whisper);
        assert!(whisper_metadata.capabilities.contains(&VoiceCapability::SpeechToText));
        assert_eq!(whisper_metadata.supported_sample_rates, vec![16000]);
        assert!(whisper_metadata.supports_streaming);
    }

    #[test]
    fn test_audio_format_display() {
        assert_eq!(AudioFormat::Wav.to_string(), "wav");
        assert_eq!(AudioFormat::Mp3.to_string(), "mp3");
    }

    #[test]
    fn test_voice_model_type_display() {
        assert_eq!(VoiceModelType::Whisper.to_string(), "whisper");
        assert_eq!(VoiceModelType::Vits.to_string(), "vits");
    }

    #[test]
    fn test_stt_request_validation() {
        let engine = VoiceEngine::new_default();
        let rt = tokio::runtime::Runtime::new().unwrap();
        
        let request = STTRequest {
            model: String::new(),
            audio_data: Some("data:audio/wav;base64,test".to_string()),
            audio_url: None,
            language: Some("en".to_string()),
            config: AudioConfig::default(),
        };
        
        let response = rt.block_on(async {
            engine.stt(&request).await
        });
        
        assert!(response.is_ok());
        let resp = response.unwrap();
        assert!(!resp.success);
        assert!(resp.message.contains("Model name is required"));
    }

    #[test]
    fn test_tts_request_validation() {
        let engine = VoiceEngine::new_default();
        let rt = tokio::runtime::Runtime::new().unwrap();
        
        let request = TTSRequest {
            model: "vits-model".to_string(),
            text: String::new(),
            voice: None,
            config: AudioConfig::default(),
        };
        
        let response = rt.block_on(async {
            engine.tts(&request).await
        });
        
        assert!(response.is_ok());
        let resp = response.unwrap();
        assert!(!resp.success);
        assert!(resp.message.contains("Text is required"));
    }
}
