use anyhow::{Context, Result};
use std::path::PathBuf;
use super::Platform;
use winreg::{enums::*, RegKey};

pub struct Windows;

impl Windows {
    pub fn new() -> Self {
        Self
    }
}

impl Platform for Windows {
    fn get_install_dir() -> Result<PathBuf> {
        let program_files = std::env::var("ProgramFiles")
            .unwrap_or_else(|_| "C:\\Program Files".to_string());
        Ok(PathBuf::from(program_files).join("allama"))
    }

    fn get_config_dir() -> Result<PathBuf> {
        let appdata = std::env::var("LOCALAPPDATA")
            .context("Failed to get LOCALAPPDATA environment variable")?;
        Ok(PathBuf::from(appdata).join("allama"))
    }

    fn get_data_dir() -> Result<PathBuf> {
        let appdata = std::env::var("LOCALAPPDATA")
            .context("Failed to get LOCALAPPDATA environment variable")?;
        Ok(PathBuf::from(appdata).join("allama").join("data"))
    }

    fn get_log_dir() -> Result<PathBuf> {
        let appdata = std::env::var("LOCALAPPDATA")
            .context("Failed to get LOCALAPPDATA environment variable")?;
        Ok(PathBuf::from(appdata).join("allama").join("logs"))
    }

    fn add_to_path(path: &PathBuf) -> Result<()> {
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);
        let env = hkcu.open_subkey("Environment")?;
        
        let current_path: String = env.get_value("Path")?;
        let path_str = path.to_string_lossy().to_string();
        
        if !current_path.contains(&path_str) {
            let new_path = format!("{};{}", current_path, path_str);
            env.set_value("Path", &new_path)?;
            
            // Notify system of environment change
            unsafe {
                winapi::um::winuser::SendMessageTimeoutW(
                    winapi::um::winuser::HWND_BROADCAST,
                    winapi::um::winuser::WM_SETTINGCHANGE,
                    0,
                    "Environment".as_ptr() as isize,
                    winapi::um::winuser::SMTO_ABORTIFHUNG,
                    5000,
                    std::ptr::null_mut(),
                );
            }
        }
        
        Ok(())
    }

    fn remove_from_path(path: &PathBuf) -> Result<()> {
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);
        let env = hkcu.open_subkey("Environment")?;
        
        let current_path: String = env.get_value("Path")?;
        let path_str = path.to_string_lossy().to_string();
        
        let new_path = current_path
            .split(';')
            .filter(|p| *p != path_str)
            .collect::<Vec<&str>>()
            .join(";");
        
        env.set_value("Path", &new_path)?;
        
        Ok(())
    }

    fn create_desktop_shortcut(app_path: &PathBuf) -> Result<()> {
        let desktop = dirs::desktop_dir()
            .context("Failed to get desktop directory")?;
        
        let shortcut_path = desktop.join("allama.lnk");
        
        // Create shortcut using COM
        // This is a simplified version - production code would use proper COM interfaces
        Ok(())
    }

    fn remove_desktop_shortcut() -> Result<()> {
        let desktop = dirs::desktop_dir()
            .context("Failed to get desktop directory")?;
        
        let shortcut_path = desktop.join("allama.lnk");
        if shortcut_path.exists() {
            std::fs::remove_file(&shortcut_path)?;
        }
        
        Ok(())
    }

    fn set_autostart(enable: bool) -> Result<()> {
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);
        let run_key = hkcu.open_subkey_with_flags(
            "Software\\Microsoft\\Windows\\CurrentVersion\\Run",
            KEY_ALL_ACCESS,
        )?;
        
        if enable {
            let install_dir = Self::get_install_dir()?;
            let exe_path = install_dir.join("allama.exe");
            run_key.set_value("allama", &exe_path.to_string_lossy().to_string())?;
        } else {
            run_key.delete_value("allama").ok();
        }
        
        Ok(())
    }

    fn is_admin() -> bool {
        unsafe {
            let mut token = std::ptr::null_mut();
            if winapi::um::processthreadsapi::OpenProcessToken(
                winapi::um::processthreadsapi::GetCurrentProcess(),
                winapi::um::winnt::TOKEN_QUERY,
                &mut token,
            ) == 0 {
                return false;
            }
            
            let mut elevation = 0;
            let mut size = std::mem::size_of::<u32>() as u32;
            let result = winapi::um::securitybaseapi::GetTokenInformation(
                token,
                winapi::um::winnt::TokenElevation,
                &mut elevation as *mut _ as *mut _,
                size,
                &mut size,
            );
            
            winapi::um::handleapi::CloseHandle(token);
            
            result != 0 && elevation != 0
        }
    }

    fn request_admin() -> Result<()> {
        // In production, this would relaunch the process with elevated privileges
        Ok(())
    }
}
