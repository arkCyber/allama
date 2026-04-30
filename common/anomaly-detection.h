/*
 * Anomaly Detection System for allama
 * Aerospace-level anomaly detection
 * 
 * Provides:
 * - Statistical anomaly detection
 * - Behavioral pattern analysis
 * - Resource usage anomaly detection
 * - Security event correlation
 * - Machine learning-based detection (placeholder)
 * - Alert generation and response
 */

#ifndef ANOMALY_DETECTION_H
#define ANOMALY_DETECTION_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Anomaly types */
typedef enum {
    ANOMALY_TYPE_RESOURCE = 0,
    ANOMALY_TYPE_SECURITY = 1,
    ANOMALY_TYPE_PERFORMANCE = 2,
    ANOMALY_TYPE_BEHAVIOR = 3,
    ANOMALY_TYPE_NETWORK = 4
} anomaly_type_t;

/* Anomaly severity */
typedef enum {
    ANOMALY_SEVERITY_INFO = 0,
    ANOMALY_SEVERITY_WARNING = 1,
    ANOMALY_SEVERITY_CRITICAL = 2
} anomaly_severity_t;

/* Anomaly detection methods */
typedef enum {
    ANOMALY_METHOD_STATISTICAL = 0,
    ANOMALY_METHOD_ML = 1,
    ANOMALY_METHOD_RULE_BASED = 2,
    ANOMALY_METHOD_HYBRID = 3
} anomaly_method_t;

/* Anomaly event */
typedef struct {
    uint64_t event_id;
    anomaly_type_t type;
    anomaly_severity_t severity;
    anomaly_method_t method;
    time_t timestamp;
    char description[512];
    char component[128];
    double score; /* 0.0 to 1.0, higher = more anomalous */
    uint64_t user_id;
    char ip_address[64];
    bool is_resolved;
} anomaly_event_t;

/* Statistical model parameters */
typedef struct {
    double mean;
    double std_dev;
    double threshold; /* Number of standard deviations */
    uint32_t window_size;
    double data[1000]; /* Sliding window */
    uint32_t data_count;
} statistical_model_t;

/* Anomaly detection configuration */
typedef struct {
    bool enabled;
    anomaly_method_t method;
    double sensitivity; /* 0.0 to 1.0 */
    uint32_t alert_threshold;
    bool auto_mitigation;
    uint32_t learning_period; /* Seconds */
} anomaly_config_t;

/* Alert callback */
typedef void (*anomaly_alert_callback_t)(const anomaly_event_t *event);

/* Initialize anomaly detection system */
int anomaly_detection_init(const anomaly_config_t *config);

/* Shutdown anomaly detection system */
void anomaly_detection_shutdown(void);

/* Update statistical model with new data point */
int anomaly_detection_update_statistical_model(statistical_model_t *model, double value);

/* Detect anomaly using statistical method */
anomaly_event_t *anomaly_detection_detect_statistical(statistical_model_t *model, double value,
                                                     anomaly_type_t type, const char *component);

/* Detect anomaly using rule-based method */
anomaly_event_t *anomaly_detection_detect_rule_based(double value, double min, double max,
                                                     anomaly_type_t type, const char *component);

/* Detect anomaly in resource usage */
anomaly_event_t *anomaly_detection_detect_resource(const char *resource, double value,
                                                   uint64_t user_id, const char *ip_address);

/* Detect anomaly in security events */
anomaly_event_t *anomaly_detection_detect_security(const char *event_type, uint64_t count,
                                                   uint64_t user_id, const char *ip_address);

/* Detect anomaly in performance metrics */
anomaly_event_t *anomaly_detection_detect_performance(const char *metric, double value,
                                                       uint64_t user_id);

/* Create statistical model */
statistical_model_t *anomaly_detection_create_model(double threshold, uint32_t window_size);

/* Destroy statistical model */
void anomaly_detection_destroy_model(statistical_model_t *model);

/* Set alert callback */
int anomaly_detection_set_alert_callback(anomaly_alert_callback_t callback);

/* Get anomaly statistics */
void anomaly_detection_get_stats(uint64_t *total_events, uint64_t *critical_events,
                                 uint64_t *resolved_events);

/* Resolve anomaly event */
int anomaly_detection_resolve_event(uint64_t event_id);

/* Get anomaly event by ID */
anomaly_event_t *anomaly_detection_get_event(uint64_t event_id);

/* Get recent anomalies */
void anomaly_detection_get_recent(anomaly_event_t *events, uint32_t max_count, uint32_t *actual_count);

/* Get anomaly type string */
const char *anomaly_type_to_string(anomaly_type_t type);

/* Get severity string */
const char *anomaly_severity_to_string(anomaly_severity_t severity);

#ifdef __cplusplus
}
#endif

#endif /* ANOMALY_DETECTION_H */
