use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::Digest;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::PathBuf;
use tracing::{info, error};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AuditEventType {
    Installation,
    Uninstallation,
    Update,
    ServiceStart,
    ServiceStop,
    ConfigurationChange,
    SecurityViolation,
    FileAccess,
    NetworkRequest,
    CodeSigning,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditLogEntry {
    pub timestamp: DateTime<Utc>,
    pub event_type: AuditEventType,
    pub user: String,
    pub process_id: u32,
    pub details: String,
    pub severity: AuditSeverity,
    pub integrity_hash: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AuditSeverity {
    Info,
    Warning,
    Error,
    Critical,
}

pub struct AuditLogger {
    log_file: PathBuf,
    buffer: Vec<AuditLogEntry>,
    max_buffer_size: usize,
}

impl AuditLogger {
    pub fn new(log_dir: PathBuf) -> Result<Self> {
        std::fs::create_dir_all(&log_dir)?;
        
        let log_file = log_dir.join(format!("allama-audit-{}.log", Utc::now().format("%Y%m%d")));
        
        Ok(Self {
            log_file,
            buffer: Vec::new(),
            max_buffer_size: 1000,
        })
    }
    
    pub fn log_event(&mut self, event_type: AuditEventType, details: String, severity: AuditSeverity) -> Result<()> {
        let entry = AuditLogEntry {
            timestamp: Utc::now(),
            event_type: event_type.clone(),
            user: std::env::var("USER").unwrap_or_else(|_| "unknown".to_string()),
            process_id: std::process::id(),
            details: details.clone(),
            severity: severity.clone(),
            integrity_hash: self.calculate_integrity_hash(&event_type, &details, &severity),
        };
        
        self.buffer.push(entry);
        
        // Flush buffer if it reaches max size
        if self.buffer.len() >= self.max_buffer_size {
            self.flush()?;
        }
        
        // Critical events are flushed immediately
        if matches!(severity, AuditSeverity::Critical) {
            self.flush()?;
        }
        
        Ok(())
    }
    
    fn calculate_integrity_hash(&self, event_type: &AuditEventType, details: &str, severity: &AuditSeverity) -> String {
        let serialized = format!("{:?}{}{:?}", event_type, details, severity);
        let hash = sha2::Sha256::digest(serialized.as_bytes());
        hex::encode(hash)
    }
    
    pub fn flush(&mut self) -> Result<()> {
        if self.buffer.is_empty() {
            return Ok(());
        }
        
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.log_file)
            .context("Failed to open audit log file")?;
        
        for entry in self.buffer.drain(..) {
            let serialized = serde_json::to_string(&entry)
                .context("Failed to serialize audit entry")?;
            
            writeln!(file, "{}", serialized)
                .context("Failed to write to audit log file")?;
        }
        
        file.flush()
            .context("Failed to flush audit log file")?;
        
        info!("Audit log flushed to: {}", self.log_file.display());
        Ok(())
    }
    
    pub fn verify_log_integrity(&self) -> Result<bool> {
        if !self.log_file.exists() {
            return Ok(true); // Empty log is valid
        }
        
        let content = std::fs::read_to_string(&self.log_file)
            .context("Failed to read audit log file")?;
        
        for line in content.lines() {
            if line.is_empty() {
                continue;
            }
            
            let entry: AuditLogEntry = serde_json::from_str(line)
                .context("Failed to parse audit log entry")?;
            
            let calculated_hash = self.calculate_integrity_hash(&entry.event_type, &entry.details, &entry.severity);
            
            if calculated_hash != entry.integrity_hash {
                error!("Audit log integrity violation detected");
                return Ok(false);
            }
        }
        
        info!("Audit log integrity verified");
        Ok(true)
    }
}

impl Drop for AuditLogger {
    fn drop(&mut self) {
        if let Err(e) = self.flush() {
            error!("Failed to flush audit log on drop: {}", e);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    
    #[test]
    fn test_audit_logging() {
        let temp_dir = TempDir::new().unwrap();
        let mut logger = AuditLogger::new(temp_dir.path().to_path_buf()).unwrap();
        
        logger.log_event(
            AuditEventType::Installation,
            "Test installation".to_string(),
            AuditSeverity::Info,
        ).unwrap();
        
        logger.flush().unwrap();
        
        assert!(logger.verify_log_integrity().unwrap());
    }
    
    #[test]
    fn test_integrity_hash() {
        let temp_dir = TempDir::new().unwrap();
        let mut logger = AuditLogger::new(temp_dir.path().to_path_buf()).unwrap();
        
        logger.log_event(
            AuditEventType::SecurityViolation,
            "Test violation".to_string(),
            AuditSeverity::Critical,
        ).unwrap();
        
        // Critical events flush immediately
        assert!(logger.buffer.is_empty());
    }
}
