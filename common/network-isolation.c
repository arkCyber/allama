/*
 * Network Isolation System Implementation for allama
 * Aerospace-level network security
 */

#include "network-isolation.h"
#include "audit-log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <arpa/inet.h>

/* Maximum number of IP entries */
#define MAX_IP_ENTRIES 1000

/* Network isolation context */
static struct {
    network_isolation_config_t config;
    ip_entry_t ip_entries[MAX_IP_ENTRIES];
    uint64_t total_connections;
    uint64_t allowed_connections;
    uint64_t blocked_connections;
    bool initialized;
    pthread_mutex_t mutex;
} network_ctx = {0};

/* Check if IP matches entry (CIDR notation) */
static bool ip_matches_entry(const char *ip, const ip_entry_t *entry) {
    if (!ip || !entry) {
        return false;
    }

    struct in_addr addr, mask;
    if (inet_pton(AF_INET, ip, &addr) != 1) {
        return false;
    }

    if (inet_pton(AF_INET, entry->ip_address, &mask) != 1) {
        return false;
    }

    /* Apply mask based on prefix length */
    if (entry->prefix_len < 32) {
        uint32_t mask_bits = ~((1 << (32 - entry->prefix_len)) - 1);
        uint32_t addr_bits = ntohl(addr.s_addr);
        uint32_t mask_ip_bits = ntohl(mask.s_addr);
        
        return (addr_bits & mask_bits) == (mask_ip_bits & mask_bits);
    }

    return addr.s_addr == mask.s_addr;
}

/* Initialize network isolation system */
int network_isolation_init(const network_isolation_config_t *config) {
    if (network_ctx.initialized) {
        return 0; /* Already initialized */
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&network_ctx.mutex, NULL) != 0) {
        return -1;
    }

    /* Copy configuration */
    if (config) {
        network_ctx.config = *config;
    } else {
        /* Default configuration */
        network_ctx.config.mode = NETWORK_ISOLATION_NONE;
        strncpy(network_ctx.config.bind_address, "0.0.0.0", sizeof(network_ctx.config.bind_address) - 1);
        network_ctx.config.bind_port = 0;
        network_ctx.config.enable_firewall = false;
        network_ctx.config.enable_logging = true;
        network_ctx.config.max_connections = 1000;
        network_ctx.config.connection_timeout = 300;
    }

    /* Initialize IP entries */
    memset(network_ctx.ip_entries, 0, sizeof(network_ctx.ip_entries));

    network_ctx.total_connections = 0;
    network_ctx.allowed_connections = 0;
    network_ctx.blocked_connections = 0;
    network_ctx.initialized = true;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "NETWORK_ISOLATION",
                   "Network isolation system initialized", NULL, 0, NULL);

    return 0;
}

/* Shutdown network isolation system */
void network_isolation_shutdown(void) {
    if (!network_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&network_ctx.mutex);
    pthread_mutex_unlock(&network_ctx.mutex);
    pthread_mutex_destroy(&network_ctx.mutex);
    network_ctx.initialized = false;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "NETWORK_ISOLATION",
                   "Network isolation system shutdown", NULL, 0, NULL);
}

/* Set isolation mode */
int network_isolation_set_mode(network_isolation_mode_t mode) {
    if (!network_ctx.initialized) {
        return -1;
    }

    pthread_mutex_lock(&network_ctx.mutex);
    network_ctx.config.mode = mode;
    pthread_mutex_unlock(&network_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "NETWORK_ISOLATION",
                   "Network isolation mode set", network_isolation_mode_to_string(mode), 0, NULL);

    return 0;
}

/* Get isolation mode */
network_isolation_mode_t network_isolation_get_mode(void) {
    if (!network_ctx.initialized) {
        return NETWORK_ISOLATION_NONE;
    }

    pthread_mutex_lock(&network_ctx.mutex);
    network_isolation_mode_t mode = network_ctx.config.mode;
    pthread_mutex_unlock(&network_ctx.mutex);

    return mode;
}

/* Add IP to whitelist */
int network_isolation_add_whitelist(const char *ip_address, uint32_t prefix_len) {
    if (!network_ctx.initialized || !ip_address) {
        return -1;
    }

    pthread_mutex_lock(&network_ctx.mutex);

    /* Find free slot */
    int slot = -1;
    for (int i = 0; i < MAX_IP_ENTRIES; i++) {
        if (!network_ctx.ip_entries[i].is_active) {
            slot = i;
            break;
        }
    }

    if (slot == -1) {
        pthread_mutex_unlock(&network_ctx.mutex);
        return -1; /* No free slots */
    }

    /* Add entry */
    strncpy(network_ctx.ip_entries[slot].ip_address, ip_address, sizeof(network_ctx.ip_entries[slot].ip_address) - 1);
    network_ctx.ip_entries[slot].prefix_len = prefix_len;
    network_ctx.ip_entries[slot].is_whitelist = true;
    network_ctx.ip_entries[slot].is_active = true;

    pthread_mutex_unlock(&network_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "NETWORK_ISOLATION",
                   "IP added to whitelist", ip_address, 0, NULL);

    return 0;
}

/* Remove IP from whitelist */
int network_isolation_remove_whitelist(const char *ip_address) {
    if (!network_ctx.initialized || !ip_address) {
        return -1;
    }

    pthread_mutex_lock(&network_ctx.mutex);

    for (int i = 0; i < MAX_IP_ENTRIES; i++) {
        if (network_ctx.ip_entries[i].is_active && 
            network_ctx.ip_entries[i].is_whitelist &&
            strcmp(network_ctx.ip_entries[i].ip_address, ip_address) == 0) {
            network_ctx.ip_entries[i].is_active = false;
            pthread_mutex_unlock(&network_ctx.mutex);
            audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "NETWORK_ISOLATION",
                           "IP removed from whitelist", ip_address, 0, NULL);
            return 0;
        }
    }

    pthread_mutex_unlock(&network_ctx.mutex);
    return -1;
}

/* Add IP to blacklist */
int network_isolation_add_blacklist(const char *ip_address, uint32_t prefix_len) {
    if (!network_ctx.initialized || !ip_address) {
        return -1;
    }

    pthread_mutex_lock(&network_ctx.mutex);

    /* Find free slot */
    int slot = -1;
    for (int i = 0; i < MAX_IP_ENTRIES; i++) {
        if (!network_ctx.ip_entries[i].is_active) {
            slot = i;
            break;
        }
    }

    if (slot == -1) {
        pthread_mutex_unlock(&network_ctx.mutex);
        return -1; /* No free slots */
    }

    /* Add entry */
    strncpy(network_ctx.ip_entries[slot].ip_address, ip_address, sizeof(network_ctx.ip_entries[slot].ip_address) - 1);
    network_ctx.ip_entries[slot].prefix_len = prefix_len;
    network_ctx.ip_entries[slot].is_whitelist = false;
    network_ctx.ip_entries[slot].is_active = true;

    pthread_mutex_unlock(&network_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "NETWORK_ISOLATION",
                   "IP added to blacklist", ip_address, 0, NULL);

    return 0;
}

/* Remove IP from blacklist */
int network_isolation_remove_blacklist(const char *ip_address) {
    if (!network_ctx.initialized || !ip_address) {
        return -1;
    }

    pthread_mutex_lock(&network_ctx.mutex);

    for (int i = 0; i < MAX_IP_ENTRIES; i++) {
        if (network_ctx.ip_entries[i].is_active && 
            !network_ctx.ip_entries[i].is_whitelist &&
            strcmp(network_ctx.ip_entries[i].ip_address, ip_address) == 0) {
            network_ctx.ip_entries[i].is_active = false;
            pthread_mutex_unlock(&network_ctx.mutex);
            audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "NETWORK_ISOLATION",
                           "IP removed from blacklist", ip_address, 0, NULL);
            return 0;
        }
    }

    pthread_mutex_unlock(&network_ctx.mutex);
    return -1;
}

/* Check if IP is allowed */
bool network_isolation_is_allowed(const char *ip_address) {
    if (!network_ctx.initialized || !ip_address) {
        return true; /* Default to allow if not initialized */
    }

    pthread_mutex_lock(&network_ctx.mutex);

    /* Check based on mode */
    switch (network_ctx.config.mode) {
        case NETWORK_ISOLATION_NONE:
            pthread_mutex_unlock(&network_ctx.mutex);
            return true;

        case NETWORK_ISOLATION_LOOPBACK:
            pthread_mutex_unlock(&network_ctx.mutex);
            return (strncmp(ip_address, "127.", 4) == 0 || strcmp(ip_address, "::1") == 0);

        case NETWORK_ISOLATION_LOCAL:
            pthread_mutex_unlock(&network_ctx.mutex);
            return (strncmp(ip_address, "192.168.", 8) == 0 || 
                    strncmp(ip_address, "10.", 3) == 0 ||
                    strncmp(ip_address, "172.16.", 7) == 0);

        case NETWORK_ISOLATION_WHITELIST: {
            bool allowed = false;
            for (int i = 0; i < MAX_IP_ENTRIES; i++) {
                if (network_ctx.ip_entries[i].is_active && 
                    network_ctx.ip_entries[i].is_whitelist &&
                    ip_matches_entry(ip_address, &network_ctx.ip_entries[i])) {
                    allowed = true;
                    break;
                }
            }
            pthread_mutex_unlock(&network_ctx.mutex);
            return allowed;
        }

        case NETWORK_ISOLATION_BLACKLIST: {
            bool blocked = false;
            for (int i = 0; i < MAX_IP_ENTRIES; i++) {
                if (network_ctx.ip_entries[i].is_active && 
                    !network_ctx.ip_entries[i].is_whitelist &&
                    ip_matches_entry(ip_address, &network_ctx.ip_entries[i])) {
                    blocked = true;
                    break;
                }
            }
            pthread_mutex_unlock(&network_ctx.mutex);
            return !blocked;
        }

        case NETWORK_ISOLATION_FULL:
            pthread_mutex_unlock(&network_ctx.mutex);
            return false;

        default:
            pthread_mutex_unlock(&network_ctx.mutex);
            return true;
    }
}

/* Check connection attempt */
bool network_isolation_check_connection(const char *ip_address, uint16_t port) {
    if (!network_ctx.initialized) {
        return true;
    }

    network_ctx.total_connections++;

    bool allowed = network_isolation_is_allowed(ip_address);

    pthread_mutex_lock(&network_ctx.mutex);
    if (allowed) {
        network_ctx.allowed_connections++;
    } else {
        network_ctx.blocked_connections++;
    }
    pthread_mutex_unlock(&network_ctx.mutex);

    if (network_ctx.config.enable_logging) {
        network_isolation_log_connection(ip_address, port, allowed);
    }

    return allowed;
}

/* Set bind address */
int network_isolation_set_bind_address(const char *address, uint16_t port) {
    if (!network_ctx.initialized || !address) {
        return -1;
    }

    pthread_mutex_lock(&network_ctx.mutex);
    strncpy(network_ctx.config.bind_address, address, sizeof(network_ctx.config.bind_address) - 1);
    network_ctx.config.bind_port = port;
    pthread_mutex_unlock(&network_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "NETWORK_ISOLATION",
                   "Bind address set", address, 0, NULL);

    return 0;
}

/* Get bind address */
void network_isolation_get_bind_address(char *address, size_t size, uint16_t *port) {
    if (!network_ctx.initialized || !address) {
        return;
    }

    pthread_mutex_lock(&network_ctx.mutex);
    strncpy(address, network_ctx.config.bind_address, size - 1);
    address[size - 1] = '\0';
    if (port) *port = network_ctx.config.bind_port;
    pthread_mutex_unlock(&network_ctx.mutex);
}

/* Enable/disable firewall */
int network_isolation_set_firewall(bool enable) {
    if (!network_ctx.initialized) {
        return -1;
    }

    pthread_mutex_lock(&network_ctx.mutex);
    network_ctx.config.enable_firewall = enable;
    pthread_mutex_unlock(&network_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "NETWORK_ISOLATION",
                   enable ? "Firewall enabled" : "Firewall disabled", NULL, 0, NULL);

    return 0;
}

/* Get firewall status */
bool network_isolation_get_firewall_status(void) {
    if (!network_ctx.initialized) {
        return false;
    }

    pthread_mutex_lock(&network_ctx.mutex);
    bool enabled = network_ctx.config.enable_firewall;
    pthread_mutex_unlock(&network_ctx.mutex);

    return enabled;
}

/* Get connection statistics */
void network_isolation_get_stats(uint64_t *total_connections, uint64_t *allowed_connections,
                                uint64_t *blocked_connections) {
    if (!network_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&network_ctx.mutex);
    if (total_connections) *total_connections = network_ctx.total_connections;
    if (allowed_connections) *allowed_connections = network_ctx.allowed_connections;
    if (blocked_connections) *blocked_connections = network_ctx.blocked_connections;
    pthread_mutex_unlock(&network_ctx.mutex);
}

/* Log connection attempt */
void network_isolation_log_connection(const char *ip_address, uint16_t port, bool allowed) {
    if (!network_ctx.initialized || !ip_address) {
        return;
    }

    char details[256];
    snprintf(details, sizeof(details), "ip=%s port=%u allowed=%s", ip_address, port, allowed ? "yes" : "no");

    if (allowed) {
        audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_API_REQUEST, "NETWORK_ISOLATION",
                       "Connection allowed", details, 0, NULL);
    } else {
        audit_log_security_violation("NETWORK_ISOLATION", "connection_blocked", details);
    }
}

/* Get mode string */
const char *network_isolation_mode_to_string(network_isolation_mode_t mode) {
    switch (mode) {
        case NETWORK_ISOLATION_NONE: return "NONE";
        case NETWORK_ISOLATION_LOOPBACK: return "LOOPBACK";
        case NETWORK_ISOLATION_LOCAL: return "LOCAL";
        case NETWORK_ISOLATION_WHITELIST: return "WHITELIST";
        case NETWORK_ISOLATION_BLACKLIST: return "BLACKLIST";
        case NETWORK_ISOLATION_FULL: return "FULL";
        default: return "UNKNOWN";
    }
}
