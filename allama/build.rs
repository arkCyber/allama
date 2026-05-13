fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=../build/bin");

    // Set version from git if available
    if let Ok(output) = std::process::Command::new("git")
        .args(&["describe", "--tags", "--always"])
        .output()
    {
        if output.status.success() {
            let version = String::from_utf8_lossy(&output.stdout);
            let version = version.trim();
            println!("cargo:rustc-env=CARGO_PKG_VERSION={}", version);
        }
    }

    // Set up linking paths for llama.cpp when inference feature is enabled.
    // CARGO_FEATURE_INFERENCE is set by cargo when the "inference" feature is active.
    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();

    if std::env::var("CARGO_FEATURE_INFERENCE").is_ok() {
        // Repo layout: `allama/` crate next to top-level `build/bin` (llama.cpp artifacts).
        let llama_lib_dir = std::path::Path::new(&manifest_dir).join("../build/bin");
        let llama_lib_abs = std::fs::canonicalize(&llama_lib_dir).unwrap_or_else(|e| {
            panic!(
                "inference feature: could not resolve llama library directory.\n\
                 Expected a built llama.cpp at {:?} (error: {}).\n\
                 Build from the repository root first, e.g. `mkdir -p build && cd build && cmake .. && cmake --build .`.",
                llama_lib_dir, e
            );
        });
        let llama_lib_path = llama_lib_abs.to_string_lossy();

        println!("cargo:rustc-link-search={}", llama_lib_path);
        println!("cargo:rustc-link-lib=dylib=llama");

        // Add include path for llama.h
        let include_path = format!("{}/../include", manifest_dir);
        println!("cargo:rustc-cfg=llama_cpp_include_path=\"{}\"", include_path);

        // Add rpath for runtime library lookup (platform-specific)
        #[cfg(target_os = "macos")]
        {
            println!("cargo:rustc-link-arg=-Wl,-rpath,{}", llama_lib_path);
        }

        #[cfg(target_os = "linux")]
        {
            println!("cargo:rustc-link-arg=-Wl,-rpath,{}", llama_lib_path);
        }

        #[cfg(windows)]
        {
            // On Windows, add the library directory to the PATH instead
            // The DLL needs to be in the same directory as the executable or in PATH
            println!("cargo:warning=On Windows, ensure llama.dll is in the same directory as allama.exe or in PATH");
        }
    }
}
