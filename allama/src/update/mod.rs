use anyhow::Result;
use serde::{Deserialize, Serialize};
use reqwest::Client;
use std::path::PathBuf;
use crate::platform::Platform;

#[derive(Debug, Serialize, Deserialize)]
pub struct ReleaseInfo {
    pub version: String,
    pub download_url: String,
    pub release_notes: String,
    pub published_at: String,
}

pub struct Updater {
    force: bool,
    current_version: String,
    client: Client,
}

impl Updater {
    pub fn new(force: bool) -> Result<Self> {
        let current_version = env!("CARGO_PKG_VERSION").to_string();
        let client = Client::new();
        
        Ok(Self {
            force,
            current_version,
            client,
        })
    }
    
    pub async fn update(&self) -> Result<()> {
        let latest_release = self.fetch_latest_release().await?;
        
        if !self.force && self.is_up_to_date(&latest_release)? {
            println!("Already up to date: v{}", self.current_version);
            return Ok(());
        }
        
        println!("New version available: v{}", latest_release.version);
        println!("Release notes: {}", latest_release.release_notes);
        
        // Download update
        let download_path = self.download_update(&latest_release).await?;
        
        // Install update
        self.install_update(&download_path).await?;
        
        println!("Update completed successfully!");
        
        Ok(())
    }
    
    async fn fetch_latest_release(&self) -> Result<ReleaseInfo> {
        let url = "https://api.github.com/repos/arkCyber/allama/releases/latest";
        let response = self.client
            .get(url)
            .header("User-Agent", "allama-installer")
            .send()
            .await?
            .json::<serde_json::Value>()
            .await?;
        
        let version = response["tag_name"]
            .as_str()
            .unwrap_or("unknown")
            .trim_start_matches('v')
            .to_string();
        
        let download_url = response["assets"][0]["browser_download_url"]
            .as_str()
            .unwrap_or("")
            .to_string();
        
        let release_notes = response["body"]
            .as_str()
            .unwrap_or("")
            .to_string();
        
        let published_at = response["published_at"]
            .as_str()
            .unwrap_or("")
            .to_string();
        
        Ok(ReleaseInfo {
            version,
            download_url,
            release_notes,
            published_at,
        })
    }
    
    fn is_up_to_date(&self, latest: &ReleaseInfo) -> Result<bool> {
        let current = semver::Version::parse(&self.current_version)?;
        let latest_semver = semver::Version::parse(&latest.version)?;
        Ok(current >= latest_semver)
    }
    
    async fn download_update(&self, release: &ReleaseInfo) -> Result<PathBuf> {
        let platform = get_platform_name();
        let download_url = format!(
            "{}/allama-{}-{}.tar.gz",
            release.download_url.trim_end_matches('/'),
            platform,
            release.version
        );
        
        println!("Downloading from: {}", download_url);
        
        let response = self.client
            .get(&download_url)
            .send()
            .await?;
        
        let temp_dir = std::env::temp_dir();
        let download_path = temp_dir.join(format!("allama-{}.tar.gz", release.version));
        
        let mut file = std::fs::File::create(&download_path)?;
        let content = response.bytes().await?;
        std::io::copy(&mut content.as_ref(), &mut file)?;
        
        Ok(download_path)
    }
    
    async fn install_update(&self, download_path: &PathBuf) -> Result<()> {
        let temp_dir = std::env::temp_dir();
        let extract_dir = temp_dir.join("allama-update");
        
        // Create extract directory
        std::fs::create_dir_all(&extract_dir)?;
        
        // Extract archive
        extract_archive(download_path, &extract_dir)?;
        
        // Stop service
        let _ = crate::service::ServiceManager::stop_service();
        
        // Install files
        let install_dir = crate::platform::CurrentPlatform::get_install_dir()?;
        
        // Backup current installation
        let backup_dir = install_dir.with_extension(".backup");
        if install_dir.exists() {
            std::fs::rename(&install_dir, &backup_dir)?;
        }
        
        // Copy new files
        copy_directory(&extract_dir, &install_dir)?;
        
        // Start service
        let _ = crate::service::ServiceManager::start_service();
        
        // Clean up
        std::fs::remove_file(download_path)?;
        std::fs::remove_dir_all(&extract_dir)?;
        
        Ok(())
    }
}

fn get_platform_name() -> &'static str {
    #[cfg(windows)]
    {
        return "windows-x86_64";
    }
    
    #[cfg(target_os = "macos")]
    {
        #[cfg(target_arch = "x86_64")]
        {
            return "macos-x86_64";
        }
        #[cfg(not(target_arch = "x86_64"))]
        {
            return "macos-aarch64";
        }
    }
    
    #[cfg(target_os = "linux")]
    {
        #[cfg(target_arch = "x86_64")]
        {
            return "linux-x86_64";
        }
        #[cfg(not(target_arch = "x86_64"))]
        {
            return "linux-aarch64";
        }
    }
    
    #[cfg(not(any(windows, target_os = "macos", target_os = "linux")))]
    {
        "unknown"
    }
}

fn extract_archive(archive_path: &PathBuf, extract_dir: &PathBuf) -> Result<()> {
    let file = std::fs::File::open(archive_path)?;
    let decoder = flate2::read::GzDecoder::new(file);
    let mut archive = tar::Archive::new(decoder);
    
    archive.unpack(extract_dir)?;
    
    Ok(())
}

fn copy_directory(source: &PathBuf, destination: &PathBuf) -> Result<()> {
    if destination.exists() {
        std::fs::remove_dir_all(destination)?;
    }
    
    fs_extra::dir::copy(source, destination, &fs_extra::dir::CopyOptions::new())?;
    
    Ok(())
}
