// Aerospace-level billing statistics module
// Provides secure, reliable token usage tracking for billing purposes

use anyhow::Result;
use chrono::{DateTime, Utc};
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex as TokioMutex;
use tracing::info;

/// Billing record for each API request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BillingRecord {
    pub id: String,
    pub timestamp: DateTime<Utc>,
    pub user_id: Option<String>,
    pub username: Option<String>,
    pub model_name: String,
    pub prompt_tokens: u64,
    pub completion_tokens: u64,
    pub total_tokens: u64,
    pub prompt_text: String,
    pub completion_text: String,
    pub client_ip: String,
    pub endpoint: String,
    pub duration_ms: u64,
}

/// Billing statistics manager
pub struct BillingManager {
    db_path: PathBuf,
    conn: Arc<TokioMutex<Connection>>,
}

impl BillingManager {
    /// Create a new billing manager
    pub fn new(db_path: PathBuf) -> Result<Self> {
        let conn = Connection::open(&db_path)?;
        
        // Aerospace-level: Enable WAL mode for better concurrency and crash recovery
        conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA foreign_keys=ON;")?;
        
        // Create billing table
        conn.execute(
            "CREATE TABLE IF NOT EXISTS billing_records (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                user_id TEXT,
                username TEXT,
                model_name TEXT NOT NULL,
                prompt_tokens INTEGER NOT NULL,
                completion_tokens INTEGER NOT NULL,
                total_tokens INTEGER NOT NULL,
                prompt_text TEXT NOT NULL,
                completion_text TEXT NOT NULL,
                client_ip TEXT NOT NULL,
                endpoint TEXT NOT NULL,
                duration_ms INTEGER NOT NULL
            )",
            [],
        )?;
        
        // Create indexes for common queries
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_timestamp ON billing_records(timestamp)",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_model ON billing_records(model_name)",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_client ON billing_records(client_ip)",
            [],
        )?;
        
        info!("Billing manager initialized with database: {:?}", db_path);
        
        Ok(Self {
            db_path,
            conn: Arc::new(TokioMutex::new(conn)),
        })
    }
    
    /// Record a billing transaction
    pub async fn record_transaction(&self, record: BillingRecord) -> Result<()> {
        let conn = self.conn.lock().await;
        
        conn.execute(
            "INSERT INTO billing_records (
                id, timestamp, user_id, username, model_name, prompt_tokens, completion_tokens,
                total_tokens, prompt_text, completion_text, client_ip, endpoint, duration_ms
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)",
            params![
                record.id,
                record.timestamp.to_rfc3339(),
                record.user_id,
                record.username,
                record.model_name,
                record.prompt_tokens,
                record.completion_tokens,
                record.total_tokens,
                record.prompt_text,
                record.completion_text,
                record.client_ip,
                record.endpoint,
                record.duration_ms,
            ],
        )?;
        
        info!("Billing record saved: {} (user: {}, model: {}, tokens: {})", 
              record.id, record.username.as_deref().unwrap_or("anonymous"), record.model_name, record.total_tokens);
        
        Ok(())
    }
    
    /// Get billing records for a specific time range
    pub async fn get_records_by_time_range(
        &self,
        start: DateTime<Utc>,
        end: DateTime<Utc>,
    ) -> Result<Vec<BillingRecord>> {
        let conn = self.conn.lock().await;
        
        let mut stmt = conn.prepare(
            "SELECT id, timestamp, user_id, username, model_name, prompt_tokens, completion_tokens,
                    total_tokens, prompt_text, completion_text, client_ip, endpoint, duration_ms
             FROM billing_records
             WHERE timestamp BETWEEN ?1 AND ?2
             ORDER BY timestamp DESC"
        )?;
        
        let records = stmt.query_map(
            params![start.to_rfc3339(), end.to_rfc3339()],
            |row| {
                Ok(BillingRecord {
                    id: row.get(0)?,
                    timestamp: DateTime::parse_from_rfc3339(&row.get::<_, String>(1)?)
                        .unwrap()
                        .with_timezone(&Utc),
                    user_id: row.get(2)?,
                    username: row.get(3)?,
                    model_name: row.get(4)?,
                    prompt_tokens: row.get(5)?,
                    completion_tokens: row.get(6)?,
                    total_tokens: row.get(7)?,
                    prompt_text: row.get(8)?,
                    completion_text: row.get(9)?,
                    client_ip: row.get(10)?,
                    endpoint: row.get(11)?,
                    duration_ms: row.get(12)?,
                })
            },
        )?;
        
        let mut result = Vec::new();
        for record in records {
            result.push(record?);
        }
        
        Ok(result)
    }
    
    /// Get total token usage by model
    pub async fn get_total_tokens_by_model(&self, model_name: &str) -> Result<u64> {
        let conn = self.conn.lock().await;
        
        let total: u64 = conn.query_row(
            "SELECT COALESCE(SUM(total_tokens), 0) FROM billing_records WHERE model_name = ?1",
            params![model_name],
            |row| row.get(0),
        )?;
        
        Ok(total)
    }
    
    /// Get billing statistics summary
    pub async fn get_summary(&self) -> Result<BillingSummary> {
        let conn = self.conn.lock(). await;
        
        let total_records: u64 = conn.query_row(
            "SELECT COUNT(*) FROM billing_records",
            [],
            |row| row.get(0),
        )?;
        
        let total_tokens: u64 = conn.query_row(
            "SELECT COALESCE(SUM(total_tokens), 0) FROM billing_records",
            [],
            |row| row.get(0),
        )?;
        
        let total_prompt_tokens: u64 = conn.query_row(
            "SELECT COALESCE(SUM(prompt_tokens), 0) FROM billing_records",
            [],
            |row| row.get(0),
        )?;
        
        let total_completion_tokens: u64 = conn.query_row(
            "SELECT COALESCE(SUM(completion_tokens), 0) FROM billing_records",
            [],
            |row| row.get(0),
        )?;
        
        let unique_models: u64 = conn.query_row(
            "SELECT COUNT(DISTINCT model_name) FROM billing_records",
            [],
            |row| row.get(0),
        )?;
        
        let unique_clients: u64 = conn.query_row(
            "SELECT COUNT(DISTINCT client_ip) FROM billing_records",
            [],
            |row| row.get(0),
        )?;
        
        Ok(BillingSummary {
            total_records,
            total_tokens,
            total_prompt_tokens,
            total_completion_tokens,
            unique_models,
            unique_clients,
        })
    }
}

/// Billing statistics summary
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BillingSummary {
    pub total_records: u64,
    pub total_tokens: u64,
    pub total_prompt_tokens: u64,
    pub total_completion_tokens: u64,
    pub unique_models: u64,
    pub unique_clients: u64,
}

/// Simple token counter (approximate)
/// In a real implementation, this would use the model's tokenizer
pub fn count_tokens(text: &str) -> u64 {
    // Aerospace-level: Simple approximation (4 characters per token on average)
    // This is a conservative estimate for billing purposes
    let char_count = text.chars().count() as u64;
    (char_count / 4).max(1)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;
    
    #[tokio::test]
    async fn test_billing_manager_creation() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test_billing.db");
        
        let manager = BillingManager::new(db_path).unwrap();
        assert!(manager.db_path.exists());
    }
    
    #[tokio::test]
    async fn test_record_transaction() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test_billing.db");
        
        let manager = BillingManager::new(db_path).unwrap();
        
        let record = BillingRecord {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp: Utc::now(),
            model_name: "llama3".to_string(),
            prompt_tokens: 100,
            completion_tokens: 200,
            total_tokens: 300,
            prompt_text: "Hello".to_string(),
            completion_text: "Hi there!".to_string(),
            client_ip: "127.0.0.1".to_string(),
            endpoint: "/api/generate".to_string(),
            duration_ms: 1000,
        };
        
        manager.record_transaction(record).await.unwrap();
    }
    
    #[test]
    fn test_count_tokens() {
        assert_eq!(count_tokens(""), 1);
        assert_eq!(count_tokens("Hello"), 2);
        assert_eq!(count_tokens("Hello world!"), 3);
    }
}
