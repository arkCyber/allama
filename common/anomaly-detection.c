/*
 * Anomaly Detection System Implementation for allama
 * Aerospace-level anomaly detection
 */

#include "anomaly-detection.h"
#include "audit-log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <math.h>

/* Maximum number of anomaly events */
#define MAX_ANOMALY_EVENTS 1000
#define MAX_STATISTICAL_MODELS 100

/* Anomaly detection context */
static struct {
    anomaly_config_t config;
    anomaly_event_t events[MAX_ANOMALY_EVENTS];
    statistical_model_t models[MAX_STATISTICAL_MODELS];
    anomaly_alert_callback_t alert_callback;
    uint64_t total_events;
    uint64_t critical_events;
    uint64_t resolved_events;
    uint64_t event_counter;
    bool initialized;
    pthread_mutex_t mutex;
} anomaly_ctx = {0};

/* Calculate mean of data */
static double calculate_mean(const double *data, uint32_t count) {
    if (count == 0) return 0.0;
    
    double sum = 0.0;
    for (uint32_t i = 0; i < count; i++) {
        sum += data[i];
    }
    return sum / count;
}

/* Calculate standard deviation of data */
static double calculate_std_dev(const double *data, uint32_t count, double mean) {
    if (count == 0) return 0.0;
    
    double sum_squared = 0.0;
    for (uint32_t i = 0; i < count; i++) {
        double diff = data[i] - mean;
        sum_squared += diff * diff;
    }
    return sqrt(sum_squared / count);
}

/* Initialize anomaly detection system */
int anomaly_detection_init(const anomaly_config_t *config) {
    if (anomaly_ctx.initialized) {
        return 0; /* Already initialized */
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&anomaly_ctx.mutex, NULL) != 0) {
        return -1;
    }

    /* Copy configuration */
    if (config) {
        anomaly_ctx.config = *config;
    } else {
        /* Default configuration */
        anomaly_ctx.config.enabled = true;
        anomaly_ctx.config.method = ANOMALY_METHOD_STATISTICAL;
        anomaly_ctx.config.sensitivity = 0.8;
        anomaly_ctx.config.alert_threshold = 10;
        anomaly_ctx.config.auto_mitigation = false;
        anomaly_ctx.config.learning_period = 300; /* 5 minutes */
    }

    /* Initialize events and models */
    memset(anomaly_ctx.events, 0, sizeof(anomaly_ctx.events));
    memset(anomaly_ctx.models, 0, sizeof(anomaly_ctx.models));

    anomaly_ctx.total_events = 0;
    anomaly_ctx.critical_events = 0;
    anomaly_ctx.resolved_events = 0;
    anomaly_ctx.event_counter = 0;
    anomaly_ctx.alert_callback = NULL;
    anomaly_ctx.initialized = true;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "ANOMALY_DETECTION",
                   "Anomaly detection system initialized", NULL, 0, NULL);

    return 0;
}

/* Shutdown anomaly detection system */
void anomaly_detection_shutdown(void) {
    if (!anomaly_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&anomaly_ctx.mutex);
    pthread_mutex_unlock(&anomaly_ctx.mutex);
    pthread_mutex_destroy(&anomaly_ctx.mutex);
    anomaly_ctx.initialized = false;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "ANOMALY_DETECTION",
                   "Anomaly detection system shutdown", NULL, 0, NULL);
}

/* Update statistical model with new data point */
int anomaly_detection_update_statistical_model(statistical_model_t *model, double value) {
    if (!model) {
        return -1;
    }

    /* Add to sliding window */
    if (model->data_count < model->window_size) {
        model->data[model->data_count] = value;
        model->data_count++;
    } else {
        /* Shift window */
        for (uint32_t i = 0; i < model->window_size - 1; i++) {
            model->data[i] = model->data[i + 1];
        }
        model->data[model->window_size - 1] = value;
    }

    /* Recalculate statistics */
    model->mean = calculate_mean(model->data, model->data_count);
    model->std_dev = calculate_std_dev(model->data, model->data_count, model->mean);

    return 0;
}

/* Detect anomaly using statistical method */
anomaly_event_t *anomaly_detection_detect_statistical(statistical_model_t *model, double value,
                                                     anomaly_type_t type, const char *component) {
    if (!anomaly_ctx.initialized || !model || !component) {
        return NULL;
    }

    if (!anomaly_ctx.config.enabled) {
        return NULL;
    }

    pthread_mutex_lock(&anomaly_ctx.mutex);

    /* Calculate z-score */
    double z_score = 0.0;
    if (model->std_dev > 0) {
        z_score = fabs(value - model->mean) / model->std_dev;
    }

    /* Check if anomaly */
    if (z_score > model->threshold) {
        /* Find free event slot */
        int slot = -1;
        for (int i = 0; i < MAX_ANOMALY_EVENTS; i++) {
            if (anomaly_ctx.events[i].event_id == 0) {
                slot = i;
                break;
            }
        }

        if (slot == -1) {
            pthread_mutex_unlock(&anomaly_ctx.mutex);
            return NULL; /* No free slots */
        }

        /* Create anomaly event */
        anomaly_ctx.events[slot].event_id = ++anomaly_ctx.event_counter;
        anomaly_ctx.events[slot].type = type;
        anomaly_ctx.events[slot].severity = (z_score > model->threshold * 2) ? ANOMALY_SEVERITY_CRITICAL : ANOMALY_SEVERITY_WARNING;
        anomaly_ctx.events[slot].method = ANOMALY_METHOD_STATISTICAL;
        anomaly_ctx.events[slot].timestamp = time(NULL);
        snprintf(anomaly_ctx.events[slot].description, sizeof(anomaly_ctx.events[slot].description),
                 "Statistical anomaly detected: value=%.2f, mean=%.2f, std_dev=%.2f, z-score=%.2f",
                 value, model->mean, model->std_dev, z_score);
        strncpy(anomaly_ctx.events[slot].component, component, sizeof(anomaly_ctx.events[slot].component) - 1);
        anomaly_ctx.events[slot].score = z_score / (model->threshold * 3); /* Normalize to 0-1 */
        anomaly_ctx.events[slot].user_id = 0;
        anomaly_ctx.events[slot].ip_address[0] = '\0';
        anomaly_ctx.events[slot].is_resolved = false;

        anomaly_ctx.total_events++;
        if (anomaly_ctx.events[slot].severity == ANOMALY_SEVERITY_CRITICAL) {
            anomaly_ctx.critical_events++;
        }

        /* Log anomaly */
        audit_log_security_violation("ANOMALY_DETECTION", anomaly_type_to_string(type), 
                                    anomaly_ctx.events[slot].description);

        /* Call alert callback */
        if (anomaly_ctx.alert_callback) {
            anomaly_ctx.alert_callback(&anomaly_ctx.events[slot]);
        }

        pthread_mutex_unlock(&anomaly_ctx.mutex);
        return &anomaly_ctx.events[slot];
    }

    pthread_mutex_unlock(&anomaly_ctx.mutex);
    return NULL;
}

/* Detect anomaly using rule-based method */
anomaly_event_t *anomaly_detection_detect_rule_based(double value, double min, double max,
                                                     anomaly_type_t type, const char *component) {
    if (!anomaly_ctx.initialized || !component) {
        return NULL;
    }

    if (!anomaly_ctx.config.enabled) {
        return NULL;
    }

    pthread_mutex_lock(&anomaly_ctx.mutex);

    /* Check if value is outside normal range */
    if (value < min || value > max) {
        /* Find free event slot */
        int slot = -1;
        for (int i = 0; i < MAX_ANOMALY_EVENTS; i++) {
            if (anomaly_ctx.events[i].event_id == 0) {
                slot = i;
                break;
            }
        }

        if (slot == -1) {
            pthread_mutex_unlock(&anomaly_ctx.mutex);
            return NULL; /* No free slots */
        }

        /* Create anomaly event */
        anomaly_ctx.events[slot].event_id = ++anomaly_ctx.event_counter;
        anomaly_ctx.events[slot].type = type;
        anomaly_ctx.events[slot].severity = ANOMALY_SEVERITY_WARNING;
        anomaly_ctx.events[slot].method = ANOMALY_METHOD_RULE_BASED;
        anomaly_ctx.events[slot].timestamp = time(NULL);
        snprintf(anomaly_ctx.events[slot].description, sizeof(anomaly_ctx.events[slot].description),
                 "Rule-based anomaly detected: value=%.2f, min=%.2f, max=%.2f",
                 value, min, max);
        strncpy(anomaly_ctx.events[slot].component, component, sizeof(anomaly_ctx.events[slot].component) - 1);
        anomaly_ctx.events[slot].score = (value < min) ? (min - value) / min : (value - max) / max;
        anomaly_ctx.events[slot].user_id = 0;
        anomaly_ctx.events[slot].ip_address[0] = '\0';
        anomaly_ctx.events[slot].is_resolved = false;

        anomaly_ctx.total_events++;

        /* Log anomaly */
        audit_log_security_violation("ANOMALY_DETECTION", anomaly_type_to_string(type),
                                    anomaly_ctx.events[slot].description);

        /* Call alert callback */
        if (anomaly_ctx.alert_callback) {
            anomaly_ctx.alert_callback(&anomaly_ctx.events[slot]);
        }

        pthread_mutex_unlock(&anomaly_ctx.mutex);
        return &anomaly_ctx.events[slot];
    }

    pthread_mutex_unlock(&anomaly_ctx.mutex);
    return NULL;
}

/* Detect anomaly in resource usage */
anomaly_event_t *anomaly_detection_detect_resource(const char *resource, double value,
                                                   uint64_t user_id, const char *ip_address) {
    if (!resource) {
        return NULL;
    }

    (void)user_id;
    (void)ip_address;

    char component[256];
    snprintf(component, sizeof(component), "RESOURCE_%s", resource);

    /* Use rule-based detection for resources */
    double min = 0.0;
    double max = 100.0; /* Percentage */
    return anomaly_detection_detect_rule_based(value, min, max, ANOMALY_TYPE_RESOURCE, component);
}

/* Detect anomaly in security events */
anomaly_event_t *anomaly_detection_detect_security(const char *event_type, uint64_t count,
                                                   uint64_t user_id, const char *ip_address) {
    if (!event_type) {
        return NULL;
    }

    (void)user_id;
    (void)ip_address;

    char component[256];
    snprintf(component, sizeof(component), "SECURITY_%s", event_type);

    /* Use rule-based detection for security events */
    double min = 0.0;
    double max = 10.0; /* Threshold for abnormal activity */
    return anomaly_detection_detect_rule_based((double)count, min, max, ANOMALY_TYPE_SECURITY, component);
}

/* Detect anomaly in performance metrics */
anomaly_event_t *anomaly_detection_detect_performance(const char *metric, double value,
                                                       uint64_t user_id) {
    if (!metric) {
        return NULL;
    }

    (void)user_id;

    char component[256];
    snprintf(component, sizeof(component), "PERFORMANCE_%s", metric);

    /* Use rule-based detection for performance metrics */
    double min = 0.0;
    double max = 10000.0; /* High latency threshold in ms */
    return anomaly_detection_detect_rule_based(value, min, max, ANOMALY_TYPE_PERFORMANCE, component);
}

/* Create statistical model */
statistical_model_t *anomaly_detection_create_model(double threshold, uint32_t window_size) {
    if (!anomaly_ctx.initialized) {
        return NULL;
    }

    pthread_mutex_lock(&anomaly_ctx.mutex);

    /* Find free slot */
    int slot = -1;
    for (int i = 0; i < MAX_STATISTICAL_MODELS; i++) {
        if (anomaly_ctx.models[i].window_size == 0) {
            slot = i;
            break;
        }
    }

    if (slot == -1) {
        pthread_mutex_unlock(&anomaly_ctx.mutex);
        return NULL; /* No free slots */
    }

    /* Initialize model */
    memset(&anomaly_ctx.models[slot], 0, sizeof(statistical_model_t));
    anomaly_ctx.models[slot].mean = 0.0;
    anomaly_ctx.models[slot].std_dev = 0.0;
    anomaly_ctx.models[slot].threshold = threshold > 0 ? threshold : 3.0; /* 3 sigma by default */
    anomaly_ctx.models[slot].window_size = window_size > 0 ? window_size : 100;
    anomaly_ctx.models[slot].data_count = 0;

    pthread_mutex_unlock(&anomaly_ctx.mutex);
    return &anomaly_ctx.models[slot];
}

/* Destroy statistical model */
void anomaly_detection_destroy_model(statistical_model_t *model) {
    if (!model || !anomaly_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&anomaly_ctx.mutex);
    model->window_size = 0; /* Mark as free */
    pthread_mutex_unlock(&anomaly_ctx.mutex);
}

/* Set alert callback */
int anomaly_detection_set_alert_callback(anomaly_alert_callback_t callback) {
    if (!anomaly_ctx.initialized) {
        return -1;
    }

    pthread_mutex_lock(&anomaly_ctx.mutex);
    anomaly_ctx.alert_callback = callback;
    pthread_mutex_unlock(&anomaly_ctx.mutex);

    return 0;
}

/* Get anomaly statistics */
void anomaly_detection_get_stats(uint64_t *total_events, uint64_t *critical_events,
                                 uint64_t *resolved_events) {
    if (!anomaly_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&anomaly_ctx.mutex);
    if (total_events) *total_events = anomaly_ctx.total_events;
    if (critical_events) *critical_events = anomaly_ctx.critical_events;
    if (resolved_events) *resolved_events = anomaly_ctx.resolved_events;
    pthread_mutex_unlock(&anomaly_ctx.mutex);
}

/* Resolve anomaly event */
int anomaly_detection_resolve_event(uint64_t event_id) {
    if (!anomaly_ctx.initialized) {
        return -1;
    }

    pthread_mutex_lock(&anomaly_ctx.mutex);

    for (int i = 0; i < MAX_ANOMALY_EVENTS; i++) {
        if (anomaly_ctx.events[i].event_id == event_id) {
            anomaly_ctx.events[i].is_resolved = true;
            anomaly_ctx.resolved_events++;
            pthread_mutex_unlock(&anomaly_ctx.mutex);
            return 0;
        }
    }

    pthread_mutex_unlock(&anomaly_ctx.mutex);
    return -1;
}

/* Get anomaly event by ID */
anomaly_event_t *anomaly_detection_get_event(uint64_t event_id) {
    if (!anomaly_ctx.initialized) {
        return NULL;
    }

    pthread_mutex_lock(&anomaly_ctx.mutex);

    for (int i = 0; i < MAX_ANOMALY_EVENTS; i++) {
        if (anomaly_ctx.events[i].event_id == event_id) {
            pthread_mutex_unlock(&anomaly_ctx.mutex);
            return &anomaly_ctx.events[i];
        }
    }

    pthread_mutex_unlock(&anomaly_ctx.mutex);
    return NULL;
}

/* Get recent anomalies */
void anomaly_detection_get_recent(anomaly_event_t *events, uint32_t max_count, uint32_t *actual_count) {
    if (!anomaly_ctx.initialized || !events || !actual_count) {
        return;
    }

    pthread_mutex_lock(&anomaly_ctx.mutex);

    uint32_t count = 0;
    for (int i = 0; i < MAX_ANOMALY_EVENTS && count < max_count; i++) {
        if (anomaly_ctx.events[i].event_id != 0) {
            events[count] = anomaly_ctx.events[i];
            count++;
        }
    }

    *actual_count = count;
    pthread_mutex_unlock(&anomaly_ctx.mutex);
}

/* Get anomaly type string */
const char *anomaly_type_to_string(anomaly_type_t type) {
    switch (type) {
        case ANOMALY_TYPE_RESOURCE: return "RESOURCE";
        case ANOMALY_TYPE_SECURITY: return "SECURITY";
        case ANOMALY_TYPE_PERFORMANCE: return "PERFORMANCE";
        case ANOMALY_TYPE_BEHAVIOR: return "BEHAVIOR";
        case ANOMALY_TYPE_NETWORK: return "NETWORK";
        default: return "UNKNOWN";
    }
}

/* Get severity string */
const char *anomaly_severity_to_string(anomaly_severity_t severity) {
    switch (severity) {
        case ANOMALY_SEVERITY_INFO: return "INFO";
        case ANOMALY_SEVERITY_WARNING: return "WARNING";
        case ANOMALY_SEVERITY_CRITICAL: return "CRITICAL";
        default: return "UNKNOWN";
    }
}
