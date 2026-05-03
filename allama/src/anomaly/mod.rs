use anyhow::{Context, Result};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Instant;
use tracing::{info, warn, error};
use sysinfo::System;

/// Anomaly detection for aerospace-level security
#[derive(Debug, Clone)]
pub struct AnomalyDetector {
    metrics: Arc<Mutex<HashMap<String, MetricData>>>,
    thresholds: Arc<Mutex<HashMap<String, Threshold>>>,
    enabled: bool,
}

#[derive(Debug, Clone)]
struct MetricData {
    values: Vec<f64>,
    timestamps: Vec<Instant>,
    max_samples: usize,
}

#[derive(Debug, Clone)]
struct Threshold {
    min: f64,
    max: f64,
    anomaly_count: u32,
    max_anomalies: u32,
}

impl AnomalyDetector {
    pub fn new(enabled: bool) -> Self {
        Self {
            metrics: Arc::new(Mutex::new(HashMap::new())),
            thresholds: Arc::new(Mutex::new(HashMap::new())),
            enabled,
        }
    }
    
    #[allow(dead_code)]
    pub fn enable(&mut self) {
        self.enabled = true;
        info!("Anomaly detection enabled");
    }
    
    #[allow(dead_code)]
    pub fn disable(&mut self) {
        self.enabled = false;
        info!("Anomaly detection disabled");
    }
    
    /// Register a metric for monitoring
    pub fn register_metric(&self, name: String, max_samples: usize, min: f64, max: f64) {
        let mut metrics = self.metrics.lock().unwrap();
        let mut thresholds = self.thresholds.lock().unwrap();
        
        metrics.insert(name.clone(), MetricData {
            values: Vec::new(),
            timestamps: Vec::new(),
            max_samples,
        });
        
        thresholds.insert(name.clone(), Threshold {
            min,
            max,
            anomaly_count: 0,
            max_anomalies: 5, // Allow 5 anomalies before alert
        });
        
        info!("Registered metric: {}", name);
    }
    
    /// Record a metric value
    pub fn record_metric(&self, name: &str, value: f64) -> Result<bool> {
        if !self.enabled {
            return Ok(false);
        }
        
        let mut metrics = self.metrics.lock().unwrap();
        let mut thresholds = self.thresholds.lock().unwrap();
        
        let metric_data = metrics.get_mut(name)
            .context(format!("Metric {} not registered", name))?;
        
        let threshold = thresholds.get_mut(name)
            .context(format!("Threshold for {} not found", name))?;
        
        // Check if value is within threshold
        let is_anomaly = value < threshold.min || value > threshold.max;
        
        if is_anomaly {
            threshold.anomaly_count += 1;
            warn!("Anomaly detected in metric {}: value {} (threshold: {}-{})", 
                  name, value, threshold.min, threshold.max);
            
            if threshold.anomaly_count >= threshold.max_anomalies {
                error!("Critical anomaly threshold exceeded for metric: {}", name);
            }
        } else {
            // Reset anomaly count on normal value
            threshold.anomaly_count = threshold.anomaly_count.saturating_sub(1);
        }
        
        // Store value
        metric_data.values.push(value);
        metric_data.timestamps.push(Instant::now());
        
        // Maintain max samples
        if metric_data.values.len() > metric_data.max_samples {
            metric_data.values.remove(0);
            metric_data.timestamps.remove(0);
        }
        
        Ok(is_anomaly)
    }
    
    /// Check if metric is in critical state
    pub fn is_critical(&self, name: &str) -> Result<bool> {
        let thresholds = self.thresholds.lock().unwrap();
        let threshold = thresholds.get(name)
            .context(format!("Threshold for {} not found", name))?;
        
        Ok(threshold.anomaly_count >= threshold.max_anomalies)
    }
    
    /// Get metric statistics
    pub fn get_metric_stats(&self, name: &str) -> Result<MetricStats> {
        let metrics = self.metrics.lock().unwrap();
        let metric_data = metrics.get(name)
            .context(format!("Metric {} not registered", name))?;
        
        if metric_data.values.is_empty() {
            return Ok(MetricStats {
                count: 0,
                min: 0.0,
                max: 0.0,
                avg: 0.0,
                std_dev: 0.0,
            });
        }
        
        let count = metric_data.values.len();
        let min = metric_data.values.iter().cloned().fold(f64::INFINITY, f64::min);
        let max = metric_data.values.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let avg: f64 = metric_data.values.iter().sum::<f64>() / count as f64;
        
        let variance: f64 = metric_data.values.iter()
            .map(|x| (x - avg).powi(2))
            .sum::<f64>() / count as f64;
        let std_dev = variance.sqrt();
        
        Ok(MetricStats {
            count,
            min,
            max,
            avg,
            std_dev,
        })
    }
}

#[derive(Debug)]
pub struct MetricStats {
    #[allow(dead_code)]
    pub count: usize,
    #[allow(dead_code)]
    pub min: f64,
    #[allow(dead_code)]
    pub max: f64,
    pub avg: f64,
    #[allow(dead_code)]
    pub std_dev: f64,
}

/// Resource usage monitoring
#[derive(Debug, Clone)]
pub struct ResourceMonitor {
    anomaly_detector: AnomalyDetector,
}

impl ResourceMonitor {
    pub fn new() -> Self {
        let detector = AnomalyDetector::new(true);
        
        // Register default metrics
        detector.register_metric("cpu_usage".to_string(), 100, 0.0, 100.0);
        detector.register_metric("memory_usage_mb".to_string(), 100, 0.0, 64000.0);
        detector.register_metric("disk_io_mb_s".to_string(), 50, 0.0, 1000.0);
        detector.register_metric("network_io_mb_s".to_string(), 50, 0.0, 1000.0);
        
        Self {
            anomaly_detector: detector,
        }
    }
    
    /// Monitor system resources
    pub async fn monitor_resources(&self) -> Result<()> {
        let mut sys = System::new_all();
        sys.refresh_all();
        
        // CPU usage
        let cpu_usage = sys.global_cpu_info().cpu_usage();
        self.anomaly_detector.record_metric("cpu_usage", cpu_usage as f64)?;
        
        // Memory usage
        let _total_memory = sys.total_memory();
        let used_memory = sys.used_memory();
        let memory_usage_mb = (used_memory / 1024 / 1024) as f64;
        self.anomaly_detector.record_metric("memory_usage_mb", memory_usage_mb)?;
        
        // Check for critical conditions
        if self.anomaly_detector.is_critical("memory_usage_mb")? {
            error!("Critical memory usage detected!");
        }
        
        if self.anomaly_detector.is_critical("cpu_usage")? {
            error!("Critical CPU usage detected!");
        }
        
        Ok(())
    }
    
    /// Get resource statistics
    pub fn get_stats(&self, metric_name: &str) -> Result<MetricStats> {
        self.anomaly_detector.get_metric_stats(metric_name)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_anomaly_detection() {
        let mut detector = AnomalyDetector::new(true);
        detector.register_metric("test_metric".to_string(), 10, 0.0, 100.0);
        
        // Normal value
        assert!(!detector.record_metric("test_metric", 50.0).unwrap());
        
        // Anomalous value
        assert!(detector.record_metric("test_metric", 150.0).unwrap());
        
        // Check critical state
        assert!(!detector.is_critical("test_metric").unwrap());
    }
    
    #[test]
    fn test_metric_stats() {
        let mut detector = AnomalyDetector::new(true);
        detector.register_metric("test_metric".to_string(), 10, 0.0, 100.0);
        
        for i in 0..10 {
            detector.record_metric("test_metric", i as f64 * 10.0).unwrap();
        }
        
        let stats = detector.get_metric_stats("test_metric").unwrap();
        assert_eq!(stats.count, 10);
        assert_eq!(stats.min, 0.0);
        assert_eq!(stats.max, 90.0);
    }
}
