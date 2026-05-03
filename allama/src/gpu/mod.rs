use anyhow::Result;
use serde::{Deserialize, Serialize};
use sysinfo::System;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GPUInfo {
    pub name: String,
    pub vendor: String,
    pub vram_mb: u64,
    pub compute_capability: Option<String>,
    pub supports_metal: bool,
    pub supports_cuda: bool,
    pub supports_rocm: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemResources {
    pub total_memory_mb: u64,
    pub available_memory_mb: u64,
    pub cpu_cores: usize,
    pub gpus: Vec<GPUInfo>,
    pub recommended_context_length: usize,
}

pub fn detect_gpu() -> Result<SystemResources> {
    let mut sys = System::new_all();
    sys.refresh_all();
    
    let total_memory = sys.total_memory() / 1024 / 1024; // Convert to MB
    let available_memory = sys.available_memory() / 1024 / 1024;
    let cpu_cores = sys.cpus().len();
    
    let gpus = detect_gpus(&mut sys)?;
    
    let recommended_context_length = calculate_recommended_context(&gpus, total_memory);
    
    Ok(SystemResources {
        total_memory_mb: total_memory,
        available_memory_mb: available_memory,
        cpu_cores,
        gpus,
        recommended_context_length,
    })
}

fn detect_gpus(_sys: &mut System) -> Result<Vec<GPUInfo>> {
    let mut gpus = Vec::new();
    
    #[cfg(target_os = "macos")]
    {
        // Apple Silicon detection
        if let Ok(output) = std::process::Command::new("sysctl")
            .args(&["-n", "machdep.cpu.brand_string"])
            .output()
        {
            let brand = String::from_utf8_lossy(&output.stdout);
            if brand.contains("Apple") {
                gpus.push(GPUInfo {
                    name: brand.trim().to_string(),
                    vendor: "Apple".to_string(),
                    vram_mb: get_apple_gpu_memory()?,
                    compute_capability: None,
                    supports_metal: true,
                    supports_cuda: false,
                    supports_rocm: false,
                });
            }
        }
    }
    
    #[cfg(target_os = "linux")]
    {
        // NVIDIA GPU detection
        if let Ok(output) = std::process::Command::new("nvidia-smi")
            .args(&["--query-gpu=name,memory.total", "--format=csv,noheader"])
            .output()
        {
            for line in String::from_utf8_lossy(&output.stdout).lines() {
                if let Some((name, memory)) = line.split_once(',') {
                    let vram_mb = memory.trim()
                        .trim_end_matches(" MiB")
                        .parse::<u64>()
                        .unwrap_or(0);
                    
                    gpus.push(GPUInfo {
                        name: name.trim().to_string(),
                        vendor: "NVIDIA".to_string(),
                        vram_mb,
                        compute_capability: get_cuda_compute_capability(),
                        supports_metal: false,
                        supports_cuda: true,
                        supports_rocm: false,
                    });
                }
            }
        }
        
        // AMD GPU detection
        if let Ok(output) = std::process::Command::new("rocm-smi")
            .arg("--showmeminfo")
            .output()
        {
            // Parse ROCm output
        }
    }
    
    #[cfg(windows)]
    {
        // Windows GPU detection using WMI or DirectX
        if let Ok(output) = std::process::Command::new("wmic")
            .args(&["path", "win32_videocontroller", "get", "name,adapterram"])
            .output()
        {
            // Parse WMI output
        }
    }
    
    Ok(gpus)
}

#[cfg(target_os = "macos")]
fn get_apple_gpu_memory() -> Result<u64> {
    if let Ok(output) = std::process::Command::new("sysctl")
        .args(&["-n", "hw.memsize"])
        .output()
    {
        let memsize = String::from_utf8_lossy(&output.stdout);
        let total_memory: u64 = memsize.trim().parse().unwrap_or(0);
        // Apple Silicon GPUs use unified memory
        // Reserve some for system
        Ok((total_memory / 1024 / 1024) * 70 / 100) // 70% of system memory
    } else {
        Ok(0)
    }
}

#[cfg(target_os = "linux")]
fn get_cuda_compute_capability() -> Option<String> {
    if let Ok(output) = std::process::Command::new("nvidia-smi")
        .args(&["--query-gpu=compute_cap", "--format=csv,noheader"])
        .output()
    {
        String::from_utf8_lossy(&output.stdout)
            .lines()
            .next()
            .map(|s| s.trim().to_string())
    } else {
        None
    }
}

fn calculate_recommended_context(gpus: &[GPUInfo], total_memory_mb: u64) -> usize {
    let max_vram = gpus.iter().map(|g| g.vram_mb).max().unwrap_or(0);
    
    if max_vram > 0 {
        // GPU available
        if max_vram >= 24 * 1024 {
            8192 // 8k context for 24GB+ VRAM
        } else if max_vram >= 16 * 1024 {
            4096 // 4k context for 16GB+ VRAM
        } else if max_vram >= 8 * 1024 {
            2048 // 2k context for 8GB+ VRAM
        } else {
            1024 // 1k context for smaller VRAM
        }
    } else {
        // CPU only - use system memory
        if total_memory_mb >= 32 * 1024 {
            2048
        } else if total_memory_mb >= 16 * 1024 {
            1024
        } else {
            512
        }
    }
}

pub fn print_gpu_info(resources: &SystemResources) {
    println!("System Resources:");
    println!("  Total Memory: {} MB", resources.total_memory_mb);
    println!("  Available Memory: {} MB", resources.available_memory_mb);
    println!("  CPU Cores: {}", resources.cpu_cores);
    println!("  GPUs Detected:");
    
    if resources.gpus.is_empty() {
        println!("    None (CPU inference only)");
    } else {
        for gpu in &resources.gpus {
            println!("    - {} ({})", gpu.name, gpu.vendor);
            println!("      VRAM: {} MB", gpu.vram_mb);
            println!("      Metal: {}", gpu.supports_metal);
            println!("      CUDA: {}", gpu.supports_cuda);
            println!("      ROCm: {}", gpu.supports_rocm);
        }
    }
    
    println!("  Recommended Context Length: {}", resources.recommended_context_length);
}
