use anyhow::Result;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tracing::{info, warn, error};

/// Aerospace-level fault tolerance framework
#[derive(Debug, Clone)]
pub struct FaultTolerance {
    shutdown_requested: Arc<AtomicBool>,
    #[allow(dead_code)]
    watchdog_timeout: Duration,
}

impl FaultTolerance {
    pub fn new(watchdog_timeout_ms: u64) -> Self {
        Self {
            shutdown_requested: Arc::new(AtomicBool::new(false)),
            watchdog_timeout: Duration::from_millis(watchdog_timeout_ms),
        }
    }
    
    /// Initialize global fault tolerance
    pub fn init_global() -> Self {
        let ft = Self::new(5000); // 5 second default timeout
        info!("Global fault tolerance initialized");
        ft
    }
    
    /// Check if shutdown has been requested
    #[allow(dead_code)]
    pub fn is_shutdown_requested(&self) -> bool {
        self.shutdown_requested.load(Ordering::SeqCst)
    }
    
    /// Request graceful shutdown
    pub fn request_shutdown(&self) {
        self.shutdown_requested.store(true, Ordering::SeqCst);
        warn!("Shutdown requested");
    }
    
    /// Cleanup and shutdown
    pub fn cleanup(&self) {
        info!("Fault tolerance cleanup initiated");
        self.shutdown_requested.store(true, Ordering::SeqCst);
    }
}

/// Timeout protection for operations
pub struct TimeoutProtection {
    deadline: Instant,
    timeout: Duration,
}

impl TimeoutProtection {
    pub fn new(timeout: Duration) -> Self {
        Self {
            deadline: Instant::now() + timeout,
            timeout,
        }
    }
    
    /// Check if timeout has been exceeded
    pub fn is_expired(&self) -> bool {
        Instant::now() > self.deadline
    }
    
    /// Get remaining time
    #[allow(dead_code)]
    pub fn remaining(&self) -> Duration {
        let now = Instant::now();
        if now < self.deadline {
            self.deadline - now
        } else {
            Duration::ZERO
        }
    }
    
    /// Check with automatic error if expired
    pub fn check(&self) -> Result<()> {
        if self.is_expired() {
            error!("Operation timeout after {:?}", self.timeout);
            anyhow::bail!("Operation timeout after {:?}", self.timeout);
        }
        Ok(())
    }
}

/// Retry mechanism with exponential backoff
#[allow(dead_code)]
pub struct RetryPolicy {
    max_attempts: u32,
    base_delay_ms: u64,
    max_delay_ms: u64,
}

impl RetryPolicy {
    #[allow(dead_code)]
    pub fn new(max_attempts: u32, base_delay_ms: u64, max_delay_ms: u64) -> Self {
        Self {
            max_attempts,
            base_delay_ms,
            max_delay_ms,
        }
    }
    
    #[allow(dead_code)]
    pub fn exponential_backoff() -> Self {
        Self::new(5, 100, 10000) // 5 attempts, 100ms base, 10s max
    }
    
    /// Execute operation with retry logic
    #[allow(dead_code)]
    pub async fn execute<F, Fut, T, E>(&self, operation: F) -> Result<T>
    where
        F: Fn() -> Fut,
        Fut: std::future::Future<Output = Result<T, E>>,
        E: std::error::Error + Send + Sync + 'static,
    {
        let mut last_error = None;
        
        for attempt in 0..self.max_attempts {
            match operation().await {
                Ok(result) => {
                    if attempt > 0 {
                        info!("Operation succeeded on attempt {}", attempt + 1);
                    }
                    return Ok(result);
                }
                Err(e) => {
                    last_error = Some(e);
                    
                    if attempt < self.max_attempts - 1 {
                        let delay = self.calculate_delay(attempt);
                        warn!("Operation failed on attempt {}, retrying after {:?}ms", attempt + 1, delay);
                        tokio::time::sleep(Duration::from_millis(delay)).await;
                    }
                }
            }
        }
        
        Err(last_error.unwrap().into())
    }
    
    #[allow(dead_code)]
    fn calculate_delay(&self, attempt: u32) -> u64 {
        let delay = self.base_delay_ms * 2_u64.pow(attempt);
        delay.min(self.max_delay_ms)
    }
}

/// Graceful degradation handler
#[derive(Debug, Clone)]
pub struct GracefulDegradation {
    degraded_mode: Arc<AtomicBool>,
    #[allow(dead_code)]
    fallback_available: Arc<AtomicBool>,
}

impl GracefulDegradation {
    pub fn new() -> Self {
        Self {
            degraded_mode: Arc::new(AtomicBool::new(false)),
            fallback_available: Arc::new(AtomicBool::new(true)),
        }
    }
    
    /// Check if running in degraded mode
    pub fn is_degraded(&self) -> bool {
        self.degraded_mode.load(Ordering::SeqCst)
    }
    
    /// Enter degraded mode
    pub fn enter_degraded_mode(&self) {
        self.degraded_mode.store(true, Ordering::SeqCst);
        warn!("Entering degraded mode");
    }
    
    /// Exit degraded mode
    #[allow(dead_code)]
    pub fn exit_degraded_mode(&self) {
        self.degraded_mode.store(false, Ordering::SeqCst);
        info!("Exiting degraded mode");
    }
    
    /// Check if fallback is available
    #[allow(dead_code)]
    pub fn has_fallback(&self) -> bool {
        self.fallback_available.load(Ordering::SeqCst)
    }
    
    /// Set fallback availability
    #[allow(dead_code)]
    pub fn set_fallback_available(&self, available: bool) {
        self.fallback_available.store(available, Ordering::SeqCst);
    }
}

/// Signal handling for graceful shutdown
#[cfg(unix)]
pub mod signal_handler {
    use super::*;
    use tokio::signal;
    
    pub async fn setup_signal_handlers(ft: Arc<FaultTolerance>) -> Result<()> {
        let mut sigterm = signal::unix::signal(signal::unix::SignalKind::terminate())?;
        
        tokio::select! {
            _ = signal::ctrl_c() => {
                warn!("Received SIGINT");
                ft.request_shutdown();
            }
            _ = sigterm.recv() => {
                warn!("Received SIGTERM");
                ft.request_shutdown();
            }
        }
        
        Ok(())
    }
}

#[cfg(windows)]
pub mod signal_handler {
    use super::*;
    use tokio::signal::windows;
    
    pub async fn setup_signal_handlers(ft: Arc<FaultTolerance>) -> Result<()> {
        tokio::select! {
            _ = tokio::signal::ctrl_c() => {
                warn!("Received Ctrl+C");
                ft.request_shutdown();
            }
            _ = windows::ctrl_break()?.recv() => {
                warn!("Received Ctrl+Break");
                ft.request_shutdown();
            }
        }
        
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_timeout_protection() {
        let timeout = TimeoutProtection::new(Duration::from_millis(100));
        assert!(!timeout.is_expired());
        
        std::thread::sleep(Duration::from_millis(150));
        assert!(timeout.is_expired());
    }
    
    #[test]
    fn test_retry_policy_delay_calculation() {
        let policy = RetryPolicy::new(5, 100, 1000);
        
        assert_eq!(policy.calculate_delay(0), 100);
        assert_eq!(policy.calculate_delay(1), 200);
        assert_eq!(policy.calculate_delay(2), 400);
        assert_eq!(policy.calculate_delay(3), 800); // Capped at 1000
        assert_eq!(policy.calculate_delay(4), 1000); // Capped at 1000
    }
    
    #[test]
    fn test_graceful_degradation() {
        let gd = GracefulDegradation::new();
        
        assert!(!gd.is_degraded());
        gd.enter_degraded_mode();
        assert!(gd.is_degraded());
        gd.exit_degraded_mode();
        assert!(!gd.is_degraded());
    }
}
