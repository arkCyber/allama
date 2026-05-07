// Inference Service - Separate process for LLM inference
// This service runs independently and provides HTTP endpoints for inference

pub mod server;

pub use server::InferenceService;
