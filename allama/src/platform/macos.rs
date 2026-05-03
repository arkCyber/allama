use anyhow::{Context, Result};
use std::path::PathBuf;
use super::Platform;

pub struct MacOs;

impl MacOs {
    #[allow(dead_code)]
    pub fn new() -> Self {
        Self
    }
}

impl Platform for MacOs {
    fn get_install_dir() -> Result<PathBuf> {
        Ok(PathBuf::from("/Applications/allama.app"))
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
        let home = std::env::var("HOME")
            .context("Failed to get HOME environment variable")?;
        Ok(PathBuf::from(home).join("Library").join("Logs").join("allama"))
    }

    fn add_to_path(path: &PathBuf) -> Result<()> {
        let shell_config = std::env::var("SHELL")
            .unwrap_or_else(|_| "/bin/zsh".to_string());
        
        let config_file = if shell_config.contains("zsh") {
            PathBuf::from(std::env::var("HOME")?).join(".zshrc")
        } else {
            PathBuf::from(std::env::var("HOME")?).join(".bash_profile")
        };
        
        let path_str = path.join("Contents/Resources").to_string_lossy().to_string();
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
            .unwrap_or_else(|_| "/bin/zsh".to_string());
        
        let config_file = if shell_config.contains("zsh") {
            PathBuf::from(std::env::var("HOME")?).join(".zshrc")
        } else {
            PathBuf::from(std::env::var("HOME")?).join(".bash_profile")
        };
        
        if config_file.exists() {
            let content = std::fs::read_to_string(&config_file)?;
            let path_str = path.join("Contents/Resources").to_string_lossy().to_string();
            let new_content: String = content
                .lines()
                .filter(|line| !line.contains(&path_str))
                .collect::<Vec<&str>>()
                .join("\n");
            
            std::fs::write(&config_file, new_content)?;
        }
        
        Ok(())
    }

    fn create_desktop_shortcut(_app_path: &PathBuf) -> Result<()> {
        // On macOS, the app itself is the shortcut
        // Just ensure it's in Applications
        Ok(())
    }

    fn remove_desktop_shortcut() -> Result<()> {
        let install_dir = Self::get_install_dir()?;
        if install_dir.exists() {
            std::fs::remove_dir_all(&install_dir)?;
        }
        Ok(())
    }

    fn set_autostart(enable: bool) -> Result<()> {
        let launch_agents_dir = PathBuf::from(std::env::var("HOME")?)
            .join("Library").join("LaunchAgents");
        
        std::fs::create_dir_all(&launch_agents_dir)?;
        
        let plist_path = launch_agents_dir.join("com.allama.plist");
        
        if enable {
            let install_dir = Self::get_install_dir()?;
            let plist_content = format!(
                r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.allama</string>
    <key>ProgramArguments</key>
    <array>
        <string>{}/Contents/Resources/allama</string>
        <string>serve</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
"#,
                install_dir.display()
            );
            
            std::fs::write(&plist_path, plist_content)?;
            
            // Load the launch agent
            std::process::Command::new("launchctl")
                .arg("load")
                .arg(&plist_path)
                .output()?;
        } else {
            if plist_path.exists() {
                std::process::Command::new("launchctl")
                    .arg("unload")
                    .arg(&plist_path)
                    .output()?;
                std::fs::remove_file(&plist_path)?;
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
        // On macOS, use osascript to request admin privileges
        Ok(())
    }
}
