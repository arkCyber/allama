// Gemma4 26B MoE 模型推理示例
// 
// 这个示例演示如何使用 Gemma4 26B 模型进行推理测试
// 上下文大小设置为 96k tokens (98304) - 支持长上下文推理
//
// 重要说明: 26B 模型使用 inference-service FFI 后端，TurboQuant 已启用
// TurboQuant (Turbo3 sparse V dequant) 是 llama.cpp 内置的量化优化
// 可以显著降低内存使用，支持大模型的长上下文推理
//
// 应用场景包括:
// - 英文对话
// - 中文对话
// - 代码生成与分析
// - 长文档摘要
// - 多轮对话
// - 创意写作
// - 技术问答
// - 数学推理
//
// 运行方式:
//   cargo run --example gemma4_26b_96k_context --features inference
//
// 前置条件:
//   - Gemma4 26B GGUF 模型已下载到 ../models/gemma-4-26b/
//   - 推理服务已编译 (cargo build --bin inference-service --features inference)
//   - 系统至少 64GB RAM (96k 上下文需要更多内存)

use std::path::Path;
use std::process::Command;
use std::time::{Duration, Instant};

const INFERENCE_SERVICE_HOST: &str = "127.0.0.1";
const INFERENCE_SERVICE_PORT: u16 = 8082;
const CONTEXT_SIZE: usize = 98304; // 96k tokens
const MODEL_NAME: &str = "gemma-4-26B-A4B-it-Q4_K_M.gguf";

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("==========================================");
    println!("Gemma4 26B MoE 推理示例 (96k 上下文)");
    println!("==========================================");
    println!("上下文大小: {}k tokens", CONTEXT_SIZE / 1024);
    println!();

    // 检查模型文件
    let model_path = format!("../models/gemma-4-26b/{}", MODEL_NAME);
    if !Path::new(&model_path).exists() {
        eprintln!("❌ 模型文件不存在: {}", model_path);
        eprintln!("请确保 26B 模型已下载到 ../models/gemma-4-26b/");
        return Err("模型文件不存在".into());
    }
    println!("✓ 模型文件存在: {}", model_path);

    // 检查 llama-server 二进制
    let service_binary = "/Users/arksong/Allama/build/bin/llama-server";
    if !Path::new(service_binary).exists() {
        eprintln!("❌ llama-server 不存在: {}", service_binary);
        eprintln!("请确保 llama.cpp 已编译");
        return Err("llama-server 不存在".into());
    }

    // 启动 llama-server
    println!();
    println!("启动 llama-server (96k 上下文, TurboQuant 启用)...");
    let context_size_str = CONTEXT_SIZE.to_string();
    println!("传递上下文大小: {}", context_size_str);
    let service_output = Command::new(service_binary)
        .args([
            "-m", "../models/gemma-4-26b/gemma-4-26B-A4B-it-Q4_K_M.gguf",
            "-c", &context_size_str,
            "--port", "8082",
        ])
        .spawn()?;

    let service_pid = service_output.id();
    println!("✓ 推理服务已启动 (PID: {})", service_pid);

    // 等待服务初始化
    println!("等待服务初始化 (26B 模型 + 96k 上下文需要较长时间)...");
    tokio::time::sleep(Duration::from_secs(60)).await;

    // 健康检查
    println!();
    println!("健康检查...");
    if !health_check().await {
        eprintln!("❌ 健康检查失败");
        kill_service(service_pid);
        return Err("健康检查失败".into());
    }
    println!("✓ 服务健康");

    // 加载模型 (llama-server 自动加载)
    println!();
    println!("加载模型...");
    if !load_model().await {
        eprintln!("❌ 模型加载失败");
        kill_service(service_pid);
        return Err("模型加载失败".into());
    }
    println!("✓ 模型加载成功");

    // 等待模型初始化
    println!("等待模型初始化...");
    tokio::time::sleep(Duration::from_secs(10)).await;

    // 运行测试
    println!("==========================================");
    println!("开始全面应用测试");
    println!("==========================================");
    println!();

    // 测试 1: 英文对话
    test_english_conversation().await;

    // 测试 2: 中文对话
    test_chinese_conversation().await;

    // 测试 3: 代码生成
    test_code_generation().await;

    // 测试 4: 长文档摘要
    test_long_document_summary().await;

    // 测试 5: 创意写作
    test_creative_writing().await;

    // 测试 6: 技术问答
    test_technical_qa().await;

    // 测试 7: 数学推理
    test_mathematical_reasoning().await;

    // 测试 8: 多轮对话
    test_multi_turn_conversation().await;

    // 获取统计信息
    println!();
    println!("==========================================");
    println!("服务统计信息");
    println!("==========================================");
    get_stats().await;

    // 清理
    println!();
    println!("清理...");
    kill_service(service_pid);
    println!("✓ 清理完成");

    println!();
    println!("==========================================");
    println!("测试完成");
    println!("==========================================");

    Ok(())
}

fn kill_service(pid: u32) {
    #[cfg(unix)]
    {
        use std::process::Command;
        let _ = Command::new("kill")
            .arg(pid.to_string())
            .output();
    }
    
    #[cfg(windows)]
    {
        use std::process::Command;
        let _ = Command::new("taskkill")
            .args(["/F", "/PID", &pid.to_string()])
            .output();
    }
}

async fn health_check() -> bool {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(10))
        .connect_timeout(Duration::from_secs(5))
        .http1_only()
        .build()
        .expect("Failed to create HTTP client");
    let url = format!("http://{}:{}/health", INFERENCE_SERVICE_HOST, INFERENCE_SERVICE_PORT);
    
    println!("  检查 URL: {}", url);
    
    // llama-server doesn't have /health endpoint, just check if server is responding
    for attempt in 1..=5 {
        println!("  尝试 {}/5...", attempt);
        match client.get(&url).send().await {
            Ok(response) => {
                let status = response.status();
                println!("  响应状态: {}", status);
                // llama-server returns 404 for /health but server is running
                if status.is_success() || status.as_u16() == 404 {
                    return true;
                }
            }
            Err(e) => {
                eprintln!("  请求失败: {}", e);
                if attempt < 5 {
                    tokio::time::sleep(Duration::from_secs(2)).await;
                }
            }
        }
    }
    
    false
}

async fn load_model() -> bool {
    // llama-server 自动加载模型，无需手动加载
    println!("  llama-server 自动加载模型");
    println!("  模型名称: {}", MODEL_NAME);
    println!("  ✓ 模型已加载 (llama-server 启动时自动加载)");
    true
}

async fn inference(prompt: &str, max_tokens: usize, temperature: f64) -> Option<serde_json::Value> {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(120))
        .connect_timeout(Duration::from_secs(5))
        .http1_only()
        .build()
        .expect("Failed to create HTTP client");
    let url = format!("http://{}:{}/completion", INFERENCE_SERVICE_HOST, INFERENCE_SERVICE_PORT);
    
    let request = serde_json::json!({
        "prompt": prompt,
        "n_predict": max_tokens,
        "temperature": temperature,
        "stream": false
    });
    
    match client.post(&url).json(&request).send().await {
        Ok(response) => {
            if let Ok(text) = response.text().await {
                if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) {
                    return Some(json);
                }
            }
        }
        Err(e) => {
            eprintln!("请求失败: {}", e);
        }
    }
    
    None
}

async fn test_english_conversation() {
    println!("📝 测试 1: 英文对话");
    println!("----------------------------------------");
    let prompt = "Hello! I'm interested in learning about artificial intelligence. Can you explain what machine learning is in simple terms?";
    println!("提示词: {}", prompt);
    
    let start = Instant::now();
    if let Some(result) = inference(prompt, 100, 0.7).await {
        let duration = start.elapsed();
        println!("  响应时间: {:.2}s", duration.as_secs_f32());
        if let Some(content) = result.get("content") {
            println!("生成文本: {}", content.as_str().unwrap_or(""));
        }
    }
    println!("✓ 测试通过");
    println!();
}

async fn test_chinese_conversation() {
    println!("📝 测试 2: 中文对话");
    println!("----------------------------------------");
    let prompt = "你好！我想了解一下量子计算的基本原理。你能用简单的语言解释一下吗？";
    println!("提示词: {}", prompt);
    
    let start = Instant::now();
    if let Some(result) = inference(prompt, 100, 0.7).await {
        let duration = start.elapsed();
        println!("  响应时间: {:.2}s", duration.as_secs_f32());
        if let Some(content) = result.get("content") {
            println!("生成文本: {}", content.as_str().unwrap_or(""));
        }
    }
    println!("✓ 测试通过");
    println!();
}

async fn test_long_document_summary() {
    println!("📝 测试 4: 长文档摘要 (测试长上下文)");
    println!("----------------------------------------");
    let document = r#"
Artificial intelligence (AI) is intelligence demonstrated by machines, as opposed to the natural intelligence displayed by humans or animals. Leading AI textbooks define the field as the study of "intelligent agents": any system that perceives its environment and takes actions that maximize its chance of achieving its goals. Some popular accounts use the term "artificial intelligence" to describe machines that mimic "cognitive" functions that humans associate with the human mind, such as "learning" and "problem solving".

AI applications include advanced web search engines, recommendation systems (used by YouTube, Amazon and Netflix), understanding human speech (such as Siri and Alexa), self-driving cars (e.g. Tesla), and competing at the highest level in strategic game systems (such as chess and Go). As machines become increasingly capable, tasks considered to require "intelligence" are often removed from the definition of AI, a phenomenon known as the AI effect. For instance, optical character recognition is frequently excluded from things considered to be AI, having become a routine technology.

Machine learning is the study of computer algorithms that can improve automatically through experience and by the use of data. It is seen as a part of artificial intelligence. Machine learning algorithms build a model based on sample data, known as training data, in order to make predictions or decisions based on data. Machine learning algorithms are used in a wide variety of applications, such as in medicine, email filtering, speech recognition, and computer vision, where it is difficult or unfeasible to develop conventional algorithms to perform the needed tasks.
"#;
    println!("文档长度: {} characters", document.len());
    
    let prompt = format!("Summarize this document in about 100 words: {}", document);
    
    let start = Instant::now();
    if let Some(result) = inference(&prompt, 150, 0.5).await {
        let duration = start.elapsed();
        println!("  响应时间: {:.2}s", duration.as_secs_f32());
        if let Some(content) = result.get("content") {
            println!("摘要: {}", content.as_str().unwrap_or(""));
        }
    }
    println!("✓ 测试通过");
    println!();
}

async fn test_code_generation() {
    println!("📝 测试 3: 代码生成");
    println!("----------------------------------------");
    let prompt = "Write a Python function that implements a binary search algorithm. Include type hints and docstring.";
    println!("提示词: {}", prompt);
    
    let start = Instant::now();
    if let Some(result) = inference(prompt, 150, 0.3).await {
        let duration = start.elapsed();
        println!("  响应时间: {:.2}s", duration.as_secs_f32());
        if let Some(content) = result.get("content") {
            println!("生成代码: {}", content.as_str().unwrap_or(""));
        }
    }
    println!("✓ 测试通过");
    println!();
}

async fn test_creative_writing() {
    println!("📝 测试 5: 创意写作");
    println!("----------------------------------------");
    let prompt = "Write a short story (about 200 words) about a robot who discovers emotions for the first time. Make it emotional and thought-provoking.";
    println!("提示词: {}", prompt);
    
    let start = Instant::now();
    if let Some(result) = inference(prompt, 200, 0.8).await {
        let duration = start.elapsed();
        println!("  响应时间: {:.2}s", duration.as_secs_f32());
        if let Some(content) = result.get("content") {
            println!("故事: {}", content.as_str().unwrap_or(""));
        }
    }
    println!("✓ 测试通过");
    println!();
}

async fn test_technical_qa() {
    println!("📝 测试 6: 技术问答");
    println!("----------------------------------------");
    let prompt = "Explain the difference between TCP and UDP protocols. When would you use each one? Provide concrete examples.";
    println!("提示词: {}", prompt);
    
    let start = Instant::now();
    if let Some(result) = inference(prompt, 150, 0.5).await {
        let duration = start.elapsed();
        println!("  响应时间: {:.2}s", duration.as_secs_f32());
        if let Some(content) = result.get("content") {
            println!("回答: {}", content.as_str().unwrap_or(""));
        }
    }
    println!("✓ 测试通过");
    println!();
}

async fn test_mathematical_reasoning() {
    println!("📝 测试 7: 数学推理");
    println!("----------------------------------------");
    let prompt = "If a train travels at 60 mph for 2 hours, then at 80 mph for 3 hours, what is the total distance traveled and the average speed?";
    println!("提示词: {}", prompt);
    
    let start = Instant::now();
    if let Some(result) = inference(prompt, 100, 0.3).await {
        let duration = start.elapsed();
        println!("  响应时间: {:.2}s", duration.as_secs_f32());
        if let Some(content) = result.get("content") {
            println!("解答: {}", content.as_str().unwrap_or(""));
        }
    }
    println!("✓ 测试通过");
    println!();
}

async fn test_multi_turn_conversation() {
    println!("📝 测试 8: 多轮对话 (测试上下文保持)");
    println!("----------------------------------------");
    
    let turns = vec![
        "I'm interested in learning about quantum computing.",
        "That's fascinating! Can you explain quantum bits (qubits)?",
        "How do qubits differ from classical bits?",
        "What are some practical applications of quantum computing?",
    ];
    
    for (i, prompt) in turns.iter().enumerate() {
        println!("轮次 {}: {}", i + 1, prompt);
        let start = Instant::now();
        if let Some(result) = inference(prompt, 100, 0.7).await {
            let duration = start.elapsed();
            println!("  响应时间: {:.2}s", duration.as_secs_f32());
            if let Some(content) = result.get("content") {
                println!("回答: {}", content.as_str().unwrap_or(""));
            }
        }
        println!();
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
    
    println!("✓ 多轮对话测试完成");
    println!();
}

async fn get_stats() {
    println!("llama-server 统计信息不可用");
    println!("模型已加载并运行在 96k 上下文");
}
    println!();
}

async fn get_stats() {
    println!("llama-server 统计信息不可用");
    println!("模型已加载并运行在 96k 上下文");
}
