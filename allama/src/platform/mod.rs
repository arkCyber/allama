use anyhow::Result;
use std::path::PathBuf;

#[cfg(windows)]
pub mod windows;
#[cfg(target_os = "macos")]
pub mod macos;
#[cfg(target_os = "linux")]
pub mod linux;

pub trait Platform {
    fn get_install_dir() -> Result<PathBuf>;
    fn get_config_dir() -> Result<PathBuf>;
    #[allow(dead_code)]
    fn get_data_dir() -> Result<PathBuf>;
    #[allow(dead_code)]
    fn get_log_dir() -> Result<PathBuf>;
    fn add_to_path(path: &PathBuf) -> Result<()>;
    fn remove_from_path(path: &PathBuf) -> Result<()>;
    fn create_desktop_shortcut(app_path: &PathBuf) -> Result<()>;
    fn remove_desktop_shortcut() -> Result<()>;
    fn set_autostart(enable: bool) -> Result<()>;
    fn is_admin() -> bool;
    #[allow(dead_code)]
    fn request_admin() -> Result<()>;
}

#[cfg(windows)]
pub use windows::Windows as CurrentPlatform;

#[cfg(target_os = "macos")]
pub use macos::MacOs as CurrentPlatform;

#[cfg(target_os = "linux")]
pub use linux::Linux as CurrentPlatform;

#[allow(dead_code)]
pub fn get_platform() -> CurrentPlatform {
    CurrentPlatform::new()
}
