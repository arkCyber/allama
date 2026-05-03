use anyhow::{Context, Result};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use std::path::Path;
use tracing::{info, warn};
use rand::RngCore;

type HmacSha256 = Hmac<Sha256>;

pub struct CodeSigner;

impl CodeSigner {
    /// Sign a file using HMAC-SHA256 (aerospace-level security)
    pub fn sign_file(file_path: &Path, secret_key: &[u8]) -> Result<String> {
        let file_content = std::fs::read(file_path)
            .context("Failed to read file for signing")?;
        
        let mut mac = HmacSha256::new_from_slice(secret_key)
            .context("Invalid key length")?;
        mac.update(&file_content);
        
        let signature = mac.finalize().into_bytes();
        let signature_hex = hex::encode(signature);
        
        info!("File signed successfully: {}", file_path.display());
        Ok(signature_hex)
    }
    
    /// Verify a file signature using HMAC-SHA256
    pub fn verify_file(file_path: &Path, signature: &str, secret_key: &[u8]) -> Result<bool> {
        let file_content = std::fs::read(file_path)
            .context("Failed to read file for verification")?;
        
        let mut mac = HmacSha256::new_from_slice(secret_key)
            .context("Invalid key length")?;
        mac.update(&file_content);
        
        let expected_signature = mac.finalize().into_bytes();
        let expected_signature_hex = hex::encode(expected_signature);
        
        let is_valid = signature == expected_signature_hex;
        
        if is_valid {
            info!("File signature verified: {}", file_path.display());
        } else {
            warn!("File signature verification failed: {}", file_path.display());
        }
        
        Ok(is_valid)
    }
    
    /// Generate a secure random key for signing
    pub fn generate_secret_key() -> Result<Vec<u8>> {
        let mut key = vec![0u8; 32]; // 256-bit key
        rand::rngs::OsRng.fill_bytes(&mut key);
        Ok(key)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;
    
    #[test]
    fn test_sign_and_verify() {
        let secret_key = CodeSigner::generate_secret_key().unwrap();
        
        let mut temp_file = NamedTempFile::new().unwrap();
        temp_file.write_all(b"test content").unwrap();
        
        let signature = CodeSigner::sign_file(temp_file.path(), &secret_key).unwrap();
        let is_valid = CodeSigner::verify_file(temp_file.path(), &signature, &secret_key).unwrap();
        
        assert!(is_valid);
    }
    
    #[test]
    fn test_verify_tampered_file() {
        let secret_key = CodeSigner::generate_secret_key().unwrap();
        
        let mut temp_file = NamedTempFile::new().unwrap();
        temp_file.write_all(b"original content").unwrap();
        
        let signature = CodeSigner::sign_file(temp_file.path(), &secret_key).unwrap();
        
        // Tamper with the file
        temp_file.write_all(b"tampered content").unwrap();
        
        let is_valid = CodeSigner::verify_file(temp_file.path(), &signature, &secret_key).unwrap();
        
        assert!(!is_valid);
    }
}
