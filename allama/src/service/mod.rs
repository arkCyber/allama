use anyhow::{Context, Result};
use std::path::PathBuf;
use crate::platform::Platform;

pub struct ServiceManager;

impl ServiceManager {
    pub fn start_service() -> Result<()> {
        let install_dir = crate::platform::CurrentPlatform::get_install_dir()?;
        
        #[cfg(windows)]
        {
            Self::start_windows_service(&install_dir)?;
        }
        
        #[cfg(target_os = "macos")]
        {
            Self::start_macos_service(&install_dir)?;
        }
        
        #[cfg(target_os = "linux")]
        {
            Self::start_linux_service(&install_dir)?;
        }
        
        Ok(())
    }
    
    pub fn stop_service() -> Result<()> {
        #[cfg(windows)]
        {
            Self::stop_windows_service()?;
        }
        
        #[cfg(target_os = "macos")]
        {
            Self::stop_macos_service()?;
        }
        
        #[cfg(target_os = "linux")]
        {
            Self::stop_linux_service()?;
        }
        
        Ok(())
    }
    
    pub fn get_status() -> Result<String> {
        #[cfg(windows)]
        {
            Self::get_windows_status()
        }
        
        #[cfg(target_os = "macos")]
        {
            Self::get_macos_status()
        }
        
        #[cfg(target_os = "linux")]
        {
            Self::get_linux_status()
        }
        
        #[cfg(not(any(windows, target_os = "macos", target_os = "linux")))]
        {
            Ok("Unknown platform".to_string())
        }
    }
    
    #[cfg(windows)]
    fn start_windows_service(install_dir: &PathBuf) -> Result<()> {
        let exe_path = install_dir.join("allama.exe");
        std::process::Command::new(&exe_path)
            .arg("serve")
            .spawn()
            .context("Failed to start allama service")?;
        Ok(())
    }
    
    #[cfg(target_os = "macos")]
    fn start_macos_service(install_dir: &PathBuf) -> Result<()> {
        let binary_path = install_dir.join("Contents/Resources/allama");
        std::process::Command::new(&binary_path)
            .arg("serve")
            .spawn()
            .context("Failed to start allama service")?;
        Ok(())
    }
    
    #[cfg(target_os = "linux")]
    fn start_linux_service(install_dir: &PathBuf) -> Result<()> {
        let binary_path = install_dir.join("bin/allama");
        std::process::Command::new(&binary_path)
            .arg("serve")
            .spawn()
            .context("Failed to start allama service")?;
        Ok(())
    }
    
    #[cfg(windows)]
    fn stop_windows_service() -> Result<()> {
        std::process::Command::new("taskkill")
            .args(&["/F", "/IM", "allama.exe"])
            .output()?;
        Ok(())
    }
    
    #[cfg(target_os = "macos")]
    fn stop_macos_service() -> Result<()> {
        std::process::Command::new("pkill")
            .arg("allama")
            .output()?;
        Ok(())
    }
    
    #[cfg(target_os = "linux")]
    fn stop_linux_service() -> Result<()> {
        std::process::Command::new("pkill")
            .arg("allama")
            .output()?;
        Ok(())
    }
    
    #[cfg(windows)]
    fn get_windows_status() -> Result<String> {
        let output = std::process::Command::new("tasklist")
            .args(&["/FI", "IMAGENAME eq allama.exe"])
            .output()?;
        
        let output = String::from_utf8_lossy(&output.stdout);
        if output.contains("allama.exe") {
            Ok("Running".to_string())
        } else {
            Ok("Stopped".to_string())
        }
    }
    
    #[cfg(target_os = "macos")]
    fn get_macos_status() -> Result<String> {
        let output = std::process::Command::new("pgrep")
            .arg("-x")
            .arg("allama")
            .output()?;
        
        if output.stdout.is_empty() {
            Ok("Stopped".to_string())
        } else {
            Ok("Running".to_string())
        }
    }
    
    #[cfg(target_os = "linux")]
    fn get_linux_status() -> Result<String> {
        let output = std::process::Command::new("pgrep")
            .arg("-x")
            .arg("allama")
            .output()?;
        
        if output.stdout.is_empty() {
            Ok("Stopped".to_string())
        } else {
            Ok("Running".to_string())
        }
    }
}
