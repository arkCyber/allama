use anyhow::Result;
use clap::{Parser, Subcommand};
use tracing::{info, error, warn};

mod platform;
mod installer;
mod gpu;
mod service;
mod update;
mod logging;
mod security;
mod audit;
mod fault;
mod anomaly;
mod model;
mod server;
mod billing;
mod auth;

use installer::Installer;
use logging::setup_logging;
use fault::{FaultTolerance, GracefulDegradation};
use audit::{AuditLogger, AuditEventType, AuditSeverity};
use anomaly::ResourceMonitor;
use model::ModelManager;
use server::start_server;
use billing::BillingManager;
use auth::AuthManager;

/// Get default host from OLLAMA_HOST environment variable or use localhost
fn get_default_host() -> String {
    std::env::var("OLLAMA_HOST").unwrap_or_else(|_| "127.0.0.1".to_string())
}

/// Get default parallel number from OLLAMA_NUM_PARALLEL environment variable
fn get_default_parallel() -> u16 {
    std::env::var("OLLAMA_NUM_PARALLEL")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(1)
}

/// Get default max loaded models from OLLAMA_MAX_LOADED_MODELS environment variable
fn get_default_max_loaded_models() -> u16 {
    std::env::var("OLLAMA_MAX_LOADED_MODELS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(3)
}

/// Get default max queue from OLLAMA_MAX_QUEUE environment variable
fn get_default_max_queue() -> u16 {
    std::env::var("OLLAMA_MAX_QUEUE")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(512)
}

#[derive(Parser)]
#[command(name = "allama")]
#[command(about = "Aerospace-Level Security Enhanced LLM Inference Engine", long_about = None)]
#[command(version = env!("CARGO_PKG_VERSION"))]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Install allama (Ollama-aligned one-click installation)
    Install {
        /// Custom installation directory (optional, uses platform default)
        #[arg(short, long)]
        dir: Option<String>,
    },
    /// Uninstall allama
    Uninstall,
    /// Start allama service
    Start,
    /// Stop allama service
    Stop,
    /// Check allama status
    Status,
    /// Update allama to latest version
    Update,
    /// Show version information
    Version,
    /// List models (Ollama-aligned: allama list or allama ls)
    #[command(alias = "ls")]
    List,
    /// Download a model (Ollama-aligned: allama pull <model>)
    Pull {
        /// Model name to download
        model: String,
    },
    /// Run a model (Ollama-aligned: allama run <model>)
    Run {
        /// Model name to run
        model: String,
        /// Prompt to send to the model
        #[arg(short, long)]
        prompt: Option<String>,
        /// Generate embeddings instead of text
        #[arg(long)]
        embeddings: bool,
    },
    /// Show model information (Ollama-aligned: allama show <model>)
    Show {
        /// Model name
        model: String,
    },
    /// Remove a model (Ollama-aligned: allama rm <model>)
    Rm {
        /// Model name to remove
        model: String,
    },
    /// List running models (Ollama-aligned: allama ps)
    Ps,
    /// Create a custom model (Ollama-aligned: allama create <model>)
    Create {
        /// Model name
        model: String,
        /// Modelfile path
        #[arg(short, long)]
        from: Option<String>,
    },
    /// Copy a model (Ollama-aligned: allama cp <source> <dest>)
    Cp {
        /// Source model
        source: String,
        /// Destination model
        destination: String,
    },
    /// Start the allama server (Ollama-aligned: allama serve)
    Serve {
        /// Host to bind to (OLLAMA_HOST environment variable supported)
        #[arg(long, default_value_t = get_default_host())]
        host: String,
        /// Port to bind to
        #[arg(short, long, default_value = "11434")]
        port: u16,
        /// Number of parallel requests (OLLAMA_NUM_PARALLEL environment variable supported)
        #[arg(long, default_value_t = get_default_parallel())]
        parallel: u16,
        /// Maximum number of models to load (OLLAMA_MAX_LOADED_MODELS environment variable supported)
        #[arg(short = 'm', long, default_value_t = get_default_max_loaded_models())]
        max_loaded_models: u16,
        /// Maximum queue size (OLLAMA_MAX_QUEUE environment variable supported)
        #[arg(short = 'q', long, default_value_t = get_default_max_queue())]
        max_queue: u16,
    },
    /// Launch integrations (Ollama-aligned: allama launch)
    Launch {
        /// Integration name (opencode, claude, codex, vscode, droid)
        #[arg(short, long)]
        integration: Option<String>,
        /// Model to use
        #[arg(short, long)]
        model: Option<String>,
        /// Show configuration
        #[arg(short, long)]
        config: bool,
    },
    /// Sign in to Ollama Cloud (Ollama-aligned: allama signin)
    Signin,
    /// Sign out of Ollama Cloud (Ollama-aligned: allama signout)
    Signout,
    /// Push a model to registry (Ollama-aligned: allama push <model>)
    Push {
        /// Model name to push
        model: String,
        /// Insecure connection
        #[arg(long)]
        insecure: bool,
    },
    /// Stop a running model (Ollama-aligned: allama stop <model>)
    StopModel {
        /// Model name to stop
        model: String,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    
    // Setup logging
    setup_logging()?;
    
    info!("Allama v{}", env!("CARGO_PKG_VERSION"));
    
    // Initialize aerospace-level features (always enabled for safety)
    let ft = FaultTolerance::init_global();
    let ft_arc = std::sync::Arc::new(ft.clone());
    let mut audit_logger = AuditLogger::new(get_audit_log_dir()?)?;
    let resource_monitor = ResourceMonitor::new();
    let graceful_degradation = GracefulDegradation::new();
    
    // Aerospace-level: Verify audit log integrity on startup
    if let Ok(is_valid) = audit_logger.verify_log_integrity() {
        if !is_valid {
            warn!("Audit log integrity check failed - potential tampering detected");
            graceful_degradation.enter_degraded_mode();
        }
    }
    
    // Aerospace-level: Monitor system resources
    let gd_clone = graceful_degradation.clone();
    tokio::spawn(async move {
        let monitor = ResourceMonitor::new();
        loop {
            if let Err(e) = monitor.monitor_resources().await {
                error!("Resource monitoring error: {}", e);
                gd_clone.enter_degraded_mode();
            }
            tokio::time::sleep(tokio::time::Duration::from_secs(30)).await;
        }
    });
    
    // Log operation start
    log_operation_start(&cli.command, &mut audit_logger)?;
    
    // Setup signal handlers for graceful shutdown
    #[cfg(unix)]
    {
        tokio::spawn(async move {
            if let Err(e) = fault::signal_handler::setup_signal_handlers(ft_arc).await {
                error!("Signal handler error: {}", e);
            }
        });
    }
    
    #[cfg(windows)]
    {
        tokio::spawn(async move {
            if let Err(e) = fault::signal_handler::setup_signal_handlers(ft_arc).await {
                error!("Signal handler error: {}", e);
            }
        });
    }
    
    // Enable resource monitoring
    let monitor = resource_monitor.clone();
    tokio::spawn(async move {
        loop {
            if let Err(e) = monitor.monitor_resources().await {
                warn!("Resource monitoring error: {}", e);
            }
            tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
        }
    });
    
    // Execute command
    match cli.command {
        Commands::Install { dir } => {
            info!("Starting installation...");
            let mut installer = Installer::new(dir)?;
            installer.install().await?;
            print_install_success_message();
        }
        Commands::Uninstall => {
            info!("Starting uninstallation...");
            let mut installer = Installer::new(None)?;
            installer.uninstall().await?;
            println!("✅ Allama uninstalled successfully");
        }
        Commands::Start => {
            info!("Starting allama service...");
            service::ServiceManager::start_service()?;
            println!("✅ Allama service started");
        }
        Commands::Stop => {
            info!("Stopping allama service...");
            service::ServiceManager::stop_service()?;
            println!("✅ Allama service stopped");
        }
        Commands::Status => {
            let status = service::ServiceManager::get_status()?;
            println!("Status: {}", status);
            
            // Print resource statistics
            println!("\nResource Statistics:");
            if let Ok(cpu_stats) = resource_monitor.get_stats("cpu_usage") {
                println!("  CPU: {:.1}% avg", cpu_stats.avg);
            }
            if let Ok(mem_stats) = resource_monitor.get_stats("memory_usage_mb") {
                println!("  Memory: {:.1} MB avg", mem_stats.avg);
            }
        }
        Commands::Update => {
            info!("Checking for updates...");
            let updater = update::Updater::new(false)?;
            updater.update().await?;
            println!("✅ Allama updated successfully");
        }
        Commands::Version => {
            println!("allama {}", env!("CARGO_PKG_VERSION"));
        }
        Commands::List => {
            info!("Listing models...");
            let model_manager = ModelManager::new()?;
            let models = model_manager.list_models()?;
            
            if models.is_empty() {
                println!("No models installed. Use 'allama pull <model>' to download a model.");
            } else {
                println!("Installed models:");
                for model in models {
                    println!("  {} ({}) - {} MB", model.name, model.tag, model.size / 1024 / 1024);
                }
            }
        }
        Commands::Pull { model } => {
            info!("Pulling model: {}", model);
            let model_manager = ModelManager::new()?;
            model_manager.pull_model(&model).await?;
        }
        Commands::Run { model, prompt, embeddings } => {
            info!("Running model: {}", model);
            let model_manager = ModelManager::new()?;
            
            // Check if model exists
            let models = model_manager.list_models()?;
            if !models.iter().any(|m| m.name == model) {
                println!("Model '{}' not found. Pulling it first...", model);
                model_manager.pull_model(&model).await?;
            }
            
            // Handle multiline input if prompt starts with """
            let final_prompt = if let Some(ref p) = prompt {
                if p.trim().starts_with("\"\"\"") {
                    // Multiline input mode
                    println!("Multiline input mode (type \"\"\" on a line by itself to finish):");
                    let mut lines = Vec::new();
                    let stdin = std::io::stdin();
                    loop {
                        let mut line = String::new();
                        stdin.read_line(&mut line)?;
                        if line.trim() == "\"\"\"" {
                            break;
                        }
                        lines.push(line);
                    }
                    Some(lines.join(""))
                } else {
                    Some(p.clone())
                }
            } else {
                None
            };
            
            if embeddings {
                println!("Generating embeddings with model '{}'", model);
                if let Some(ref p) = final_prompt {
                    println!("Input: {}", p);
                } else {
                    println!("Reading input from stdin...");
                }
                println!("Embeddings generation requires llama.cpp integration");
                println!("This feature will be implemented in the next phase");
                println!("For now, use the llama.cpp CLI directly:");
                if let Some(ref p) = final_prompt {
                    println!("  llama-cli -m ~/.allama/models/{}/{}.gguf --embedding \"{}\"", model, model, p);
                } else {
                    println!("  echo \"your text\" | llama-cli -m ~/.allama/models/{}/{}.gguf --embedding", model, model);
                }
            } else if let Some(ref p) = final_prompt {
                println!("Running model '{}' with prompt: {}", model, p);
                println!("Model execution requires llama.cpp integration");
                println!("This feature will be implemented in the next phase");
                println!("For now, use the llama.cpp CLI directly:");
                println!("  llama-cli -m ~/.allama/models/{}/{}.gguf \"{}\"", model, model, p);
            } else {
                println!("Running model '{}' in interactive mode", model);
                println!("Model execution requires llama.cpp integration");
                println!("This feature will be implemented in the next phase");
                println!("For now, use the llama.cpp CLI directly:");
                println!("  llama-cli -m ~/.allama/models/{}/{}.gguf", model, model);
            }
        }
        Commands::Show { model } => {
            info!("Showing model: {}", model);
            let model_manager = ModelManager::new()?;
            model_manager.show_model(&model)?;
        }
        Commands::Rm { model } => {
            info!("Removing model: {}", model);
            let model_manager = ModelManager::new()?;
            model_manager.remove_model(&model)?;
        }
        Commands::Ps => {
            info!("Listing running models...");
            let model_manager = ModelManager::new()?;
            let running_models = model_manager.list_running_models()?;
            
            if running_models.is_empty() {
                println!("No models currently running.");
            } else {
                println!("Running models:");
                for model in running_models {
                    println!("  {} - PID: {}, Memory: {} MB, CPU: {:.1}%", 
                             model.name, model.pid, model.memory_mb, model.cpu_percent);
                }
            }
        }
        Commands::Create { model, from } => {
            info!("Creating custom model: {}", model);
            let model_manager = ModelManager::new()?;
            
            if let Some(modelfile) = from {
                model_manager.create_model(&model, &modelfile)?;
            } else {
                println!("Creating model '{}' from default template", model);
                println!("Custom model creation will be implemented in the next phase");
            }
        }
        Commands::Cp { source, destination } => {
            info!("Copying model: {} -> {}", source, destination);
            let model_manager = ModelManager::new()?;
            model_manager.copy_model(&source, &destination)?;
        }
        Commands::Push { model, insecure } => {
            info!("Pushing model: {}", model);
            println!("Pushing model '{}' to registry", model);
            if insecure {
                println!("Warning: Using insecure connection");
            }
            println!("Model push to registry will be implemented in the next phase");
            println!("For now, use the API endpoint:");
            println!("  curl -X POST http://localhost:11434/api/push -d '{{\"model\":\"{}\"}}'", model);
        }
        Commands::Serve { host, port, parallel, max_loaded_models, max_queue } => {
            info!("Starting allama server on {}:{} with {} parallel workers, max {} models, queue size {}", host, port, parallel, max_loaded_models, max_queue);
            println!("Starting allama server on {}:{} with {} parallel workers", host, port, parallel);
            println!("Maximum loaded models: {}", max_loaded_models);
            println!("Maximum queue size: {}", max_queue);
            println!("Aerospace-level HTTP server with model hot-swapping");
            println!("API endpoints:");
            println!("  GET  /api/tags - List models");
            println!("  POST /api/generate - Generate text");
            println!("  POST /api/chat - Chat with model");
            println!("  GET  /api/tags/:model - Get model info");
            println!();
            
            let model_manager = ModelManager::new()?;
            let audit_logger_for_server = AuditLogger::new(get_audit_log_dir()?)?;
            
            // Aerospace-level: Initialize billing manager for token usage tracking
            let billing_db_dir = get_data_dir()?.join("billing");
            std::fs::create_dir_all(&billing_db_dir)?;
            let billing_db_path = billing_db_dir.join("billing.db");
            let billing_manager = BillingManager::new(billing_db_path)?;
            info!("Billing manager initialized for token usage tracking");
            
            // Aerospace-level: Initialize authentication manager for user identification
            let auth_db_dir = get_data_dir()?.join("auth");
            std::fs::create_dir_all(&auth_db_dir)?;
            let auth_db_path = auth_db_dir.join("auth.db");
            let auth_manager = AuthManager::new(auth_db_path)?;
            info!("Authentication manager initialized for user identification");
            
            // Aerospace-level: Create default test user for remote testing
            let default_user = auth_manager.ensure_default_test_user().await?;
            info!("Default test user available: {} (API Key: {})", default_user.username, default_user.api_key);
            println!("==========================================");
            println!("Default Test User Created");
            println!("==========================================");
            println!("Username: {}", default_user.username);
            println!("API Key: {}", default_user.api_key);
            println!("Rate Limit: {} requests/minute", default_user.rate_limit);
            println!("Monthly Quota: {} tokens", default_user.monthly_quota.unwrap_or(0));
            println!("==========================================");
            println!();
            
            // Start the HTTP server
            if let Err(e) = start_server(&host, port, parallel, max_loaded_models, max_queue, model_manager, audit_logger_for_server, Some(billing_manager), Some(auth_manager)).await {
                error!("Failed to start server: {}", e);
                anyhow::bail!("Failed to start server: {}", e);
            }
        }
        Commands::Launch { integration, model, config } => {
            info!("Launching integration");
            println!("Launch integrations (Ollama-aligned)");
            if let Some(int_name) = integration {
                println!("Integration: {}", int_name);
            }
            if let Some(model_name) = model {
                println!("Model: {}", model_name);
            }
            if config {
                println!("Configuration mode enabled");
            }
            println!("Supported integrations:");
            println!("  - opencode: Open-source coding assistant");
            println!("  - claude: Anthropic's agentic coding tool");
            println!("  - codex: OpenAI's coding assistant");
            println!("  - vscode: Microsoft's IDE with built-in AI chat");
            println!("  - droid: Factory's AI coding agent");
            println!();
            println!("Integration launch will be implemented in the next phase");
        }
        Commands::Signin => {
            info!("Signing in to Ollama Cloud");
            println!("Sign in to Ollama Cloud");
            println!("Cloud authentication will be implemented in the next phase");
            println!("For now, use Ollama CLI directly:");
            println!("  ollama signin");
        }
        Commands::Signout => {
            info!("Signing out of Ollama Cloud");
            println!("Sign out of Ollama Cloud");
            println!("Cloud authentication will be implemented in the next phase");
            println!("For now, use Ollama CLI directly:");
            println!("  ollama signout");
        }
        Commands::StopModel { model } => {
            info!("Stopping running model: {}", model);
            let model_manager = ModelManager::new()?;
            model_manager.stop_model(&model)?;
        }
    }
    
    // Cleanup
    ft.cleanup();
    audit_logger.flush()?;
    
    Ok(())
}

fn log_operation_start(command: &Commands, audit_logger: &mut AuditLogger) -> Result<()> {
    let (event_type, details) = match command {
        Commands::Install { .. } => (AuditEventType::Installation, "Installation started".to_string()),
        Commands::Uninstall => (AuditEventType::Uninstallation, "Uninstallation started".to_string()),
        Commands::Start => (AuditEventType::ServiceStart, "Service start requested".to_string()),
        Commands::Stop => (AuditEventType::ServiceStop, "Service stop requested".to_string()),
        Commands::Update => (AuditEventType::Update, "Update started".to_string()),
        Commands::Version => (AuditEventType::ConfigurationChange, "Version check".to_string()),
        Commands::Status => (AuditEventType::ConfigurationChange, "Status check".to_string()),
        Commands::List => (AuditEventType::ConfigurationChange, "Model list requested".to_string()),
        Commands::Pull { model } => (AuditEventType::ConfigurationChange, format!("Model pull: {}", model)),
        Commands::Run { model, embeddings, .. } => {
            let details = if *embeddings {
                format!("Model embeddings: {}", model)
            } else {
                format!("Model run: {}", model)
            };
            (AuditEventType::ConfigurationChange, details)
        },
        Commands::Show { model } => (AuditEventType::ConfigurationChange, format!("Model show: {}", model)),
        Commands::Rm { model } => (AuditEventType::ConfigurationChange, format!("Model remove: {}", model)),
        Commands::Ps => (AuditEventType::ConfigurationChange, "Running models list requested".to_string()),
        Commands::Create { model, .. } => (AuditEventType::ConfigurationChange, format!("Model create: {}", model)),
        Commands::Cp { source, destination } => (AuditEventType::ConfigurationChange, format!("Model copy: {} -> {}", source, destination)),
        Commands::Push { model, insecure } => (AuditEventType::ConfigurationChange, format!("Model push: {} (insecure: {})", model, insecure)),
        Commands::Serve { host, port, parallel, max_loaded_models, max_queue } => (AuditEventType::ServiceStart, format!("Server start: {}:{} with {} parallel workers, max {} models, queue size {}", host, port, parallel, max_loaded_models, max_queue)),
        Commands::Launch { integration, .. } => (AuditEventType::ConfigurationChange, format!("Integration launch: {:?}", integration)),
        Commands::Signin => (AuditEventType::ConfigurationChange, "Sign in requested".to_string()),
        Commands::Signout => (AuditEventType::ConfigurationChange, "Sign out requested".to_string()),
        Commands::StopModel { model } => (AuditEventType::ConfigurationChange, format!("Stop model: {}", model)),
    };
    
    audit_logger.log_event(event_type, details, AuditSeverity::Info)?;
    Ok(())
}

fn print_install_success_message() {
    println!("✅ Allama installed successfully!");
    println!();
    println!("Quick Start:");
    println!("  allama run llama3");
    println!("  allama serve");
    println!();
    println!("For more information:");
    println!("  allama --help");
    println!("  https://github.com/arkCyber/allama");
}

fn get_audit_log_dir() -> Result<std::path::PathBuf> {
    #[cfg(windows)]
    {
        let appdata = std::env::var("LOCALAPPDATA")?;
        Ok(std::path::PathBuf::from(appdata).join("allama").join("logs"))
    }
    
    #[cfg(target_os = "macos")]
    {
        let home = std::env::var("HOME")?;
        Ok(std::path::PathBuf::from(home).join("Library").join("Logs").join("allama"))
    }
    
    #[cfg(target_os = "linux")]
    {
        Ok(std::path::PathBuf::from("/var/log/allama"))
    }
}

fn get_data_dir() -> Result<std::path::PathBuf> {
    #[cfg(windows)]
    {
        let appdata = std::env::var("LOCALAPPDATA")?;
        Ok(std::path::PathBuf::from(appdata).join("allama").join("data"))
    }
    
    #[cfg(target_os = "macos")]
    {
        let home = std::env::var("HOME")?;
        Ok(std::path::PathBuf::from(home).join(".allama").join("data"))
    }
    
    #[cfg(target_os = "linux")]
    {
        Ok(std::path::PathBuf::from("/var/lib/allama"))
    }
}
