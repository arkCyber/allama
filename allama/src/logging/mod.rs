use anyhow::Result;
use tracing_appender::rolling;
use tracing_subscriber::{fmt, layer::SubscriberExt, util::SubscriberInitExt};

pub fn setup_logging() -> Result<()> {
    let log_dir = get_log_dir()?;
    std::fs::create_dir_all(&log_dir)?;
    
    let file_appender = rolling::daily(&log_dir, "allama");
    let (non_blocking, _guard) = tracing_appender::non_blocking(file_appender);
    
    tracing_subscriber::registry()
        .with(
            fmt::layer()
                .with_writer(std::io::stdout)
                .with_ansi(true)
                .with_target(false)
        )
        .with(
            fmt::layer()
                .with_writer(non_blocking)
                .with_ansi(false)
                .with_target(true)
        )
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info"))
        )
        .init();
    
    Ok(())
}

fn get_log_dir() -> Result<std::path::PathBuf> {
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
