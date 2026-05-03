use anyhow::{Context, Result};
use std::path::PathBuf;
use tracing::{info, warn};

use crate::platform::Platform;
use crate::gpu::detect_gpu;
use crate::gpu::print_gpu_info;

pub struct Installer {
    install_dir: Option<PathBuf>,
}

impl Installer {
    pub fn new(install_dir: Option<String>) -> Result<Self> {
        let install_dir = install_dir.map(PathBuf::from);
        
        Ok(Self {
            install_dir,
        })
    }
    
    pub async fn install(&mut self) -> Result<()> {
        info!("Starting allama installation...");
        
        // Check admin privileges
        if !crate::platform::CurrentPlatform::is_admin() {
            warn!("Running without admin privileges. Some features may not work.");
            println!("⚠️  Running without admin privileges. Some features may not work.");
        }
        
        // Detect system resources (always enabled for optimal configuration)
        info!("Detecting system resources...");
        let resources = detect_gpu()?;
        print_gpu_info(&resources);
        
        // Get installation directory
        let install_dir = if let Some(dir) = &self.install_dir {
            dir.clone()
        } else {
            crate::platform::CurrentPlatform::get_install_dir()?
        };
        
        info!("Installing to: {}", install_dir.display());
        println!("Installing to: {}", install_dir.display());
        
        // Create installation directory
        std::fs::create_dir_all(&install_dir)
            .context("Failed to create installation directory")?;
        
        // Download or copy binaries
        self.install_binaries(&install_dir).await?;
        
        // Configure PATH
        info!("Configuring PATH...");
        crate::platform::CurrentPlatform::add_to_path(&install_dir)?;
        
        // Create desktop shortcut
        info!("Creating desktop shortcut...");
        crate::platform::CurrentPlatform::create_desktop_shortcut(&install_dir)?;
        
        // Configure autostart
        info!("Configuring autostart...");
        crate::platform::CurrentPlatform::set_autostart(true)?;
        
        // Start service
        info!("Starting allama service...");
        crate::service::ServiceManager::start_service()?;
        
        info!("Installation completed successfully!");
        
        Ok(())
    }
    
    pub async fn uninstall(&mut self) -> Result<()> {
        info!("Starting allama uninstallation...");
        
        // Stop service
        info!("Stopping allama service...");
        crate::service::ServiceManager::stop_service()?;
        
        // Get installation directory
        let install_dir = if let Some(dir) = &self.install_dir {
            dir.clone()
        } else {
            crate::platform::CurrentPlatform::get_install_dir()?
        };
        
        info!("Uninstalling from: {}", install_dir.display());
        
        // Remove from PATH
        info!("Removing from PATH...");
        crate::platform::CurrentPlatform::remove_from_path(&install_dir)?;
        
        // Remove desktop shortcut
        info!("Removing desktop shortcut...");
        crate::platform::CurrentPlatform::remove_desktop_shortcut()?;
        
        // Disable autostart
        info!("Disabling autostart...");
        crate::platform::CurrentPlatform::set_autostart(false)?;
        
        // Remove installation directory
        if install_dir.exists() {
            info!("Removing installation directory...");
            std::fs::remove_dir_all(&install_dir)?;
        }
        
        // Remove config directory (optional)
        let config_dir = crate::platform::CurrentPlatform::get_config_dir()?;
        if config_dir.exists() {
            warn!("Config directory remains: {}", config_dir.display());
            println!("⚠️  Config directory remains: {}", config_dir.display());
            println!("   Remove manually if desired.");
        }
        
        info!("Uninstallation completed successfully!");
        
        Ok(())
    }
    
    async fn install_binaries(&self, install_dir: &PathBuf) -> Result<()> {
        info!("Installing binaries...");
        
        // Check if we're running from the source directory
        let source_dir = std::env::current_dir()?;
        let source_bin = source_dir.join("../build/bin");
        
        if source_bin.exists() {
            // Copy from local build
            info!("Copying binaries from local build...");
            self.copy_binaries_from_source(&source_bin, install_dir)?;
        } else {
            // Download from GitHub releases
            info!("Downloading binaries from GitHub releases...");
            self.download_binaries(install_dir).await?;
        }
        
        Ok(())
    }
    
    fn copy_binaries_from_source(&self, source_bin: &PathBuf, install_dir: &PathBuf) -> Result<()> {
        #[cfg(windows)]
        {
            let target_dir = install_dir;
            std::fs::create_dir_all(target_dir)?;
            
            // Copy all binaries
            for entry in std::fs::read_dir(source_bin)? {
                let entry = entry?;
                let path = entry.path();
                if path.is_file() && (path.extension().map_or(false, |e| e == "exe") || !path.extension().is_some()) {
                    let dest = target_dir.join(path.file_name().unwrap());
                    std::fs::copy(&path, &dest)?;
                }
            }
        }
        
        #[cfg(target_os = "macos")]
        {
            let resources_dir = install_dir.join("Contents/Resources");
            let lib_dir = install_dir.join("Contents/lib");
            std::fs::create_dir_all(&resources_dir)?;
            std::fs::create_dir_all(&lib_dir)?;
            
            // Copy binaries to Resources
            for entry in std::fs::read_dir(source_bin)? {
                let entry = entry?;
                let path = entry.path();
                if path.is_file() {
                    let filename = path.file_name().unwrap();
                    let ext = path.extension().and_then(|e| e.to_str());
                    
                    if ext == Some("dylib") {
                        let dest = lib_dir.join(filename);
                        std::fs::copy(&path, &dest)?;
                    } else {
                        let dest = resources_dir.join(filename);
                        std::fs::copy(&path, &dest)?;
                    }
                }
            }
        }
        
        #[cfg(target_os = "linux")]
        {
            let bin_dir = install_dir.join("bin");
            let lib_dir = install_dir.join("lib");
            std::fs::create_dir_all(&bin_dir)?;
            std::fs::create_dir_all(&lib_dir)?;
            
            // Copy binaries
            for entry in std::fs::read_dir(source_bin)? {
                let entry = entry?;
                let path = entry.path();
                if path.is_file() {
                    let filename = path.file_name().unwrap();
                    let ext = path.extension().and_then(|e| e.to_str());
                    
                    if ext == Some("so") || ext.map_or(false, |e| e.starts_with("so.")) {
                        let dest = lib_dir.join(filename);
                        std::fs::copy(&path, &dest)?;
                    } else {
                        let dest = bin_dir.join(filename);
                        std::fs::copy(&path, &dest)?;
                        // Make executable
                        #[cfg(unix)]
                        {
                            use std::os::unix::fs::PermissionsExt;
                            let mut perms = std::fs::metadata(&dest)?.permissions();
                            perms.set_mode(0o755);
                            std::fs::set_permissions(&dest, perms)?;
                        }
                    }
                }
            }
        }
        
        Ok(())
    }
    
    async fn download_binaries(&self, install_dir: &PathBuf) -> Result<()> {
        let platform = get_platform_name();
        let version = "1.0.0"; // Should be fetched from latest release
        let download_url = format!(
            "https://github.com/arkCyber/allama/releases/download/v{}/allama-{}-{}.tar.gz",
            version, platform, version
        );
        
        info!("Downloading from: {}", download_url);
        
        let client = reqwest::Client::new();
        let response = client
            .get(&download_url)
            .send()
            .await?;
        
        let temp_dir = std::env::temp_dir();
        let archive_path = temp_dir.join(format!("allama-{}.tar.gz", version));
        
        // Download
        let mut file = std::fs::File::create(&archive_path)?;
        let content = response.bytes().await?;
        std::io::copy(&mut content.as_ref(), &mut file)?;
        
        // Extract
        let extract_dir = temp_dir.join("allama-extract");
        std::fs::create_dir_all(&extract_dir)?;
        
        let file = std::fs::File::open(&archive_path)?;
        let decoder = flate2::read::GzDecoder::new(file);
        let mut archive = tar::Archive::new(decoder);
        archive.unpack(&extract_dir)?;
        
        // Copy to install directory
        fs_extra::dir::copy(&extract_dir, install_dir, &fs_extra::dir::CopyOptions::new())?;
        
        // Cleanup
        std::fs::remove_file(&archive_path)?;
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
