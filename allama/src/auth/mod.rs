// Aerospace-level authentication and user management module
// Provides secure API key authentication and user management for billing

use anyhow::Result;
use chrono::{DateTime, Utc};
use rand::Rng;
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use sha2::{Sha256, Digest};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex as TokioMutex;
use tracing::{info, warn};

/// User information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub user_id: String,
    pub api_key: String,
    pub api_key_hash: String,
    pub username: String,
    pub email: Option<String>,
    pub created_at: DateTime<Utc>,
    pub is_active: bool,
    pub rate_limit: u32, // requests per minute
    pub monthly_quota: Option<u64>, // monthly token quota
}

/// Authentication manager
pub struct AuthManager {
    db_path: PathBuf,
    conn: Arc<TokioMutex<Connection>>,
}

impl AuthManager {
    /// Create a new authentication manager
    pub fn new(db_path: PathBuf) -> Result<Self> {
        let conn = Connection::open(&db_path)?;
        
        // Aerospace-level: Enable WAL mode for better concurrency and crash recovery
        conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA foreign_keys=ON;")?;
        
        // Create users table
        conn.execute(
            "CREATE TABLE IF NOT EXISTS users (
                user_id TEXT PRIMARY KEY,
                api_key TEXT UNIQUE NOT NULL,
                api_key_hash TEXT UNIQUE NOT NULL,
                username TEXT UNIQUE NOT NULL,
                email TEXT,
                created_at TEXT NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
                rate_limit INTEGER NOT NULL DEFAULT 60,
                monthly_quota INTEGER
            )",
            [],
        )?;
        
        // Create indexes for common queries
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_api_key ON users(api_key)",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_api_key_hash ON users(api_key_hash)",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_username ON users(username)",
            [],
        )?;
        
        info!("Authentication manager initialized with database: {:?}", db_path);
        
        Ok(Self {
            db_path,
            conn: Arc::new(TokioMutex::new(conn)),
        })
    }
    
    /// Generate a secure API key
    pub fn generate_api_key() -> String {
        // Aerospace-level: Generate cryptographically secure API key
        let mut rng = rand::thread_rng();
        let mut key = String::new();
        let chars = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        for _ in 0..32 {
            key.push(chars[rng.gen_range(0..chars.len())] as char);
        }
        format!("allama_{}", key)
    }
    
    /// Hash an API key (SHA-256)
    pub fn hash_api_key(api_key: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(api_key.as_bytes());
        let result = hasher.finalize();
        hex::encode(result)
    }
    
    /// Create a new user
    pub async fn create_user(
        &self,
        username: &str,
        email: Option<String>,
        rate_limit: u32,
        monthly_quota: Option<u64>,
    ) -> Result<User> {
        let user_id = uuid::Uuid::new_v4().to_string();
        let api_key = Self::generate_api_key();
        let api_key_hash = Self::hash_api_key(&api_key);
        let created_at = Utc::now();
        
        let conn = self.conn.lock().await;
        conn.execute(
            "INSERT INTO users (user_id, api_key, api_key_hash, username, email, created_at, is_active, rate_limit, monthly_quota)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
            params![
                user_id,
                api_key,
                api_key_hash,
                username,
                email,
                created_at.to_rfc3339(),
                1, // is_active
                rate_limit,
                monthly_quota,
            ],
        )?;
        
        info!("Created new user: {} (user_id: {})", username, user_id);
        
        Ok(User {
            user_id,
            api_key,
            api_key_hash,
            username: username.to_string(),
            email,
            created_at,
            is_active: true,
            rate_limit,
            monthly_quota,
        })
    }
    
    /// Authenticate a user by API key
    pub async fn authenticate(&self, api_key: &str) -> Result<Option<User>> {
        let api_key_hash = Self::hash_api_key(api_key);
        
        let conn = self.conn.lock().await;
        let mut stmt = conn.prepare(
            "SELECT user_id, api_key, api_key_hash, username, email, created_at, is_active, rate_limit, monthly_quota
             FROM users
             WHERE api_key_hash = ?1 AND is_active = 1"
        )?;
        
        let user = stmt.query_row(
            params![api_key_hash],
            |row| {
                Ok(User {
                    user_id: row.get(0)?,
                    api_key: row.get(1)?,
                    api_key_hash: row.get(2)?,
                    username: row.get(3)?,
                    email: row.get(4)?,
                    created_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(5)?)
                        .unwrap()
                        .with_timezone(&Utc),
                    is_active: row.get::<_, i32>(6)? == 1,
                    rate_limit: row.get(7)?,
                    monthly_quota: row.get(8)?,
                })
            },
        );
        
        match user {
            Ok(u) => {
                info!("Authenticated user: {} (user_id: {})", u.username, u.user_id);
                Ok(Some(u))
            }
            Err(rusqlite::Error::QueryReturnedNoRows) => {
                warn!("Authentication failed: Invalid API key");
                Ok(None)
            }
            Err(e) => Err(e.into()),
        }
    }
    
    /// Get user by user ID
    pub async fn get_user(&self, user_id: &str) -> Result<Option<User>> {
        let conn = self.conn.lock().await;
        let mut stmt = conn.prepare(
            "SELECT user_id, api_key, api_key_hash, username, email, created_at, is_active, rate_limit, monthly_quota
             FROM users
             WHERE user_id = ?1"
        )?;
        
        let user = stmt.query_row(
            params![user_id],
            |row| {
                Ok(User {
                    user_id: row.get(0)?,
                    api_key: row.get(1)?,
                    api_key_hash: row.get(2)?,
                    username: row.get(3)?,
                    email: row.get(4)?,
                    created_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(5)?)
                        .unwrap()
                        .with_timezone(&Utc),
                    is_active: row.get::<_, i32>(6)? == 1,
                    rate_limit: row.get(7)?,
                    monthly_quota: row.get(8)?,
                })
            },
        );
        
        match user {
            Ok(u) => Ok(Some(u)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }
    
    /// List all users
    pub async fn list_users(&self) -> Result<Vec<User>> {
        let conn = self.conn.lock().await;
        let mut stmt = conn.prepare(
            "SELECT user_id, api_key, api_key_hash, username, email, created_at, is_active, rate_limit, monthly_quota
             FROM users"
        )?;
        
        let users = stmt.query_map([], |row| {
            Ok(User {
                user_id: row.get(0)?,
                api_key: row.get(1)?,
                api_key_hash: row.get(2)?,
                username: row.get(3)?,
                email: row.get(4)?,
                created_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(5)?)
                    .unwrap()
                    .with_timezone(&Utc),
                is_active: row.get::<_, i32>(6)? == 1,
                rate_limit: row.get(7)?,
                monthly_quota: row.get(8)?,
            })
        })?;
        
        let mut result = Vec::new();
        for user in users {
            result.push(user?);
        }
        
        Ok(result)
    }
    
    /// Deactivate a user
    pub async fn deactivate_user(&self, user_id: &str) -> Result<()> {
        let conn = self.conn.lock().await;
        conn.execute(
            "UPDATE users SET is_active = 0 WHERE user_id = ?1",
            params![user_id],
        )?;
        
        info!("Deactivated user: {}", user_id);
        Ok(())
    }
    
    /// Update user rate limit
    pub async fn update_rate_limit(&self, user_id: &str, rate_limit: u32) -> Result<()> {
        let conn = self.conn.lock().await;
        conn.execute(
            "UPDATE users SET rate_limit = ?1 WHERE user_id = ?2",
            params![rate_limit, user_id],
        )?;
        
        info!("Updated rate limit for user {}: {}", user_id, rate_limit);
        Ok(())
    }

    /// Create or get default test user
    pub async fn ensure_default_test_user(&self) -> Result<User> {
        let username = "test_user";
        
        // Check if default test user already exists
        let user_exists = {
            let conn = self.conn.lock().await;
            let mut stmt = conn.prepare(
                "SELECT COUNT(*) FROM users WHERE username = ?1"
            )?;
            
            let count: i64 = stmt.query_row(params![username], |row| row.get(0))?;
            count > 0
        };
        
        if user_exists {
            // Get existing user
            let conn = self.conn.lock().await;
            let mut stmt = conn.prepare(
                "SELECT user_id, api_key, api_key_hash, username, email, created_at, is_active, rate_limit, monthly_quota
                 FROM users
                 WHERE username = ?1"
            )?;
            
            let user = stmt.query_row(
                params![username],
                |row| {
                    Ok(User {
                        user_id: row.get(0)?,
                        api_key: row.get(1)?,
                        api_key_hash: row.get(2)?,
                        username: row.get(3)?,
                        email: row.get(4)?,
                        created_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(5)?)
                            .unwrap()
                            .with_timezone(&Utc),
                        is_active: row.get::<_, i32>(6)? == 1,
                        rate_limit: row.get(7)?,
                        monthly_quota: row.get(8)?,
                    })
                },
            )?;
            
            info!("Default test user already exists: {}", user.username);
            Ok(user)
        } else {
            // Create default test user
            let user = self.create_user(
                username,
                Some("test@allama.ai".to_string()),
                60, // 60 requests per minute
                Some(100000), // 100k tokens monthly quota
            ).await?;
            info!("Created default test user with API key: {}", user.api_key);
            Ok(user)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;
    
    #[test]
    fn test_api_key_generation() {
        let api_key = AuthManager::generate_api_key();
        assert!(api_key.starts_with("allama_"));
        assert_eq!(api_key.len(), 38); // "allama_" + 32 chars
    }
    
    #[test]
    fn test_api_key_hash() {
        let api_key = "test_api_key";
        let hash1 = AuthManager::hash_api_key(api_key);
        let hash2 = AuthManager::hash_api_key(api_key);
        assert_eq!(hash1, hash2);
        
        let hash3 = AuthManager::hash_api_key("different_key");
        assert_ne!(hash1, hash3);
    }
    
    #[tokio::test]
    async fn test_create_user() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test_auth.db");
        
        let manager = AuthManager::new(db_path).unwrap();
        let user = manager.create_user("testuser", Some("test@example.com".to_string()), 60, Some(1000000)).await.unwrap();
        
        assert_eq!(user.username, "testuser");
        assert!(user.api_key.starts_with("allama_"));
        assert!(user.is_active);
        assert_eq!(user.rate_limit, 60);
        assert_eq!(user.monthly_quota, Some(1000000));
    }
    
    #[tokio::test]
    async fn test_authenticate() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test_auth.db");
        
        let manager = AuthManager::new(db_path).unwrap();
        let user = manager.create_user("testuser", None, 60, None).await.unwrap();
        
        // Test valid API key
        let authenticated = manager.authenticate(&user.api_key).await.unwrap();
        assert!(authenticated.is_some());
        assert_eq!(authenticated.unwrap().username, "testuser");
        
        // Test invalid API key
        let authenticated = manager.authenticate("invalid_key").await.unwrap();
        assert!(authenticated.is_none());
    }
}
