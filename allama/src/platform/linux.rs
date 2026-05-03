use anyhow::{Context, Result};
use std::path::PathBuf;
use super::Platform;

pub struct Linux;

impl Linux {
    pub fn new() -> Self {
        Self
    }
}

impl Platform for Linux {
    fn get_install_dir() -> Result<PathBuf> {
        Ok(PathBuf::from("/opt/allama"))
    }

    fn get_config_dir() -> Result<PathBuf> {
        let home = std::env::var("HOME")
            .context("Failed to get HOME environment variable")?;
        Ok(PathBuf::from(home).join(".allama"))
    }

    fn get_data_dir() -> Result<PathBuf> {
        let home = std::env::var("HOME")
            .context("Failed to get HOME environment variable")?;
        Ok(PathBuf::from(home).join(".allama").join("data"))
    }

    fn get_log_dir() -> Result<PathBuf> {
        Ok(PathBuf::from("/var/log/allama"))
    }

    fn add_to_path(path: &PathBuf) -> Result<()> {
        let shell_config = std::env::var("SHELL")
            .unwrap_or_else(|_| "/bin/bash".to_string());
        
        let config_file = if shell_config.contains("zsh") {
            PathBuf::from(std::env::var("HOME")?).join(".zshrc")
        } else {
            PathBuf::from(std::env::var("HOME")?).join(".bashrc")
        };
        
        let path_str = path.join("bin").to_string_lossy().to_string();
        let export_line = format!("export PATH=\"{}:$PATH\"\n", path_str);
        
        if config_file.exists() {
            let content = std::fs::read_to_string(&config_file)?;
            if !content.contains(&path_str) {
                std::fs::write(&config_file, format!("{}\n{}", content, export_line))?;
            }
        } else {
            std::fs::write(&config_file, export_line)?;
        }
        
        Ok(())
    }

    fn remove_from_path(path: &PathBuf) -> Result<()> {
        let shell_config = std::env::var("SHELL")
            .unwrap_or_else(|_| "/bin/bash".to_string());
        
        let config_file = if shell_config.contains("zsh") {
            PathBuf::from(std::env::var("HOME")?).join(".zshrc")
        } else {
            PathBuf::from(std::env::var("HOME")?).join(".bashrc")
        };
        
        if config_file.exists() {
            let content = std::fs::read_to_string(&config_file)?;
            let path_str = path.join("bin").to_string_lossy().to_string();
            let new_content: String = content
                .lines()
                .filter(|line| !line.contains(&path_str))
                .collect::<Vec<&str>>()
                .join("\n");
            
            std::fs::write(&config_file, new_content)?;
        }
        
        Ok(())
    }

    fn create_desktop_shortcut(app_path: &PathBuf) -> Result<()> {
        let desktop_dir = dirs::desktop_dir()
            .context("Failed to get desktop directory")?;
        
        let desktop_entry = format!(
            r#"[Desktop Entry]
Version=1.0
Type=Application
Name=allama
Comment=Aerospace-Level Security Enhanced LLM Inference Engine
Exec={}/allama
Icon={}
Terminal=false
Categories=Development;AI;
"#,
            app_path.join("bin").display(),
            app_path.join("share/icons/allama.png").display()
        );
        
        let shortcut_path = desktop_dir.join("allama.desktop");
        std::fs::write(&shortcut_path, desktop_entry)?;
        
        Ok(())
    }

    fn remove_desktop_shortcut() -> Result<()> {
        let desktop_dir = dirs::desktop_dir()
            .context("Failed to get desktop directory")?;
        
        let shortcut_path = desktop_dir.join("allama.desktop");
        if shortcut_path.exists() {
            std::fs::remove_file(&shortcut_path)?;
        }
        
        Ok(())
    }

    fn set_autostart(enable: bool) -> Result<()> {
        let autostart_dir = PathBuf::from(std::env::var("HOME")?)
            .join(".config").join("autostart");
        
        std::fs::create_dir_all(&autostart_dir)?;
        
        let desktop_entry_path = autostart_dir.join("allama.desktop");
        
        if enable {
            let install_dir = Self::get_install_dir()?;
            let desktop_entry = format!(
                r#"[Desktop Entry]
Version=1.0
Type=Application
Name=allama
Comment=Aerospace-Level Security Enhanced LLM Inference Engine
Exec={}/allama serve
Icon={}
Terminal=false
X-MATE-Autostart-enabled=true
"#,
                install_dir.join("bin").display(),
                install_dir.join("share/icons/allama.png").display()
            );
            
            std::fs::write(&desktop_entry_path, desktop_entry)?;
        } else {
            if desktop_entry_path.exists() {
                std::fs::remove_file(&desktop_entry_path)?;
            }
        }
        
        Ok(())
    }

    fn is_admin() -> bool {
        std::process::Command::new("id")
            .arg("-u")
            .output()
            .map(|output| output.stdout == b"0\n")
            .unwrap_or(false)
    }

    fn request_admin() -> Result<()> {
        // On Linux, use pkexec or sudo
        Ok(())
    }
}
