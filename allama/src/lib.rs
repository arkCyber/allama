pub mod platform;
pub mod installer;
pub mod gpu;
pub mod service;
pub mod auth;
pub mod billing;
pub mod fault;
pub mod model;
pub mod moe;
pub mod network;
pub mod metrics;
pub mod logging;
pub mod audit;
pub mod anomaly;
pub mod security;
pub mod server;
pub mod update;

#[cfg(feature = "inference")]
pub mod inference;

// Disabled: Using standalone binary src/bin/inference_service.rs instead
// #[cfg(feature = "inference")]
// pub mod inference_service;

