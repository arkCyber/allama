/*
 * Network Isolation System for allama
 * Aerospace-level network security
 * 
 * Provides:
 * - Network interface binding control
 * - IP whitelist/blacklist
 * - Port access control
 * - Network traffic filtering
 * - Firewall integration
 * - Network segmentation
 */

#ifndef NETWORK_ISOLATION_H
#define NETWORK_ISOLATION_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Network isolation modes */
typedef enum {
    NETWORK_ISOLATION_NONE = 0,
    NETWORK_ISOLATION_LOOPBACK = 1,
    NETWORK_ISOLATION_LOCAL = 2,
    NETWORK_ISOLATION_WHITELIST = 3,
    NETWORK_ISOLATION_BLACKLIST = 4,
    NETWORK_ISOLATION_FULL = 5
} network_isolation_mode_t;

/* IP address entry */
typedef struct {
    char ip_address[64];
    uint32_t prefix_len;
    bool is_whitelist;
    bool is_active;
} ip_entry_t;

/* Network isolation configuration */
typedef struct {
    network_isolation_mode_t mode;
    char bind_address[64];
    uint16_t bind_port;
    bool enable_firewall;
    bool enable_logging;
    uint32_t max_connections;
    uint32_t connection_timeout;
} network_isolation_config_t;

/* Connection info */
typedef struct {
    char ip_address[64];
    uint16_t port;
    time_t connect_time;
    bool is_allowed;
} connection_info_t;

/* Initialize network isolation system */
int network_isolation_init(const network_isolation_config_t *config);

/* Shutdown network isolation system */
void network_isolation_shutdown(void);

/* Set isolation mode */
int network_isolation_set_mode(network_isolation_mode_t mode);

/* Get isolation mode */
network_isolation_mode_t network_isolation_get_mode(void);

/* Add IP to whitelist */
int network_isolation_add_whitelist(const char *ip_address, uint32_t prefix_len);

/* Remove IP from whitelist */
int network_isolation_remove_whitelist(const char *ip_address);

/* Add IP to blacklist */
int network_isolation_add_blacklist(const char *ip_address, uint32_t prefix_len);

/* Remove IP from blacklist */
int network_isolation_remove_blacklist(const char *ip_address);

/* Check if IP is allowed */
bool network_isolation_is_allowed(const char *ip_address);

/* Check connection attempt */
bool network_isolation_check_connection(const char *ip_address, uint16_t port);

/* Set bind address */
int network_isolation_set_bind_address(const char *address, uint16_t port);

/* Get bind address */
void network_isolation_get_bind_address(char *address, size_t size, uint16_t *port);

/* Enable/disable firewall */
int network_isolation_set_firewall(bool enable);

/* Get firewall status */
bool network_isolation_get_firewall_status(void);

/* Get connection statistics */
void network_isolation_get_stats(uint64_t *total_connections, uint64_t *allowed_connections,
                                uint64_t *blocked_connections);

/* Log connection attempt */
void network_isolation_log_connection(const char *ip_address, uint16_t port, bool allowed);

/* Get mode string */
const char *network_isolation_mode_to_string(network_isolation_mode_t mode);

#ifdef __cplusplus
}
#endif

#endif /* NETWORK_ISOLATION_H */
