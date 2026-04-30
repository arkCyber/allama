/*
 * Secure Memory Storage System for allama
 * Aerospace-level secure memory management
 * 
 * Provides:
 * - Encrypted memory allocation
 * - Memory locking (prevent swapping)
 * - Memory clearing on free
 * - Memory integrity checking
 * - Secure string handling
 * - Memory poisoning protection
 */

#ifndef SECURE_MEMORY_H
#define SECURE_MEMORY_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Secure memory configuration */
typedef struct {
    bool enable_encryption;
    bool enable_locking;
    bool enable_integrity;
    bool enable_poisoning;
    size_t default_alignment;
} secure_memory_config_t;

/* Secure memory handle */
typedef struct {
    void *ptr;
    size_t size;
    uint32_t checksum;
    bool is_locked;
    bool is_encrypted;
} secure_memory_handle_t;

/* Initialize secure memory system */
int secure_memory_init(const secure_memory_config_t *config);

/* Shutdown secure memory system */
void secure_memory_shutdown(void);

/* Allocate secure memory */
void *secure_malloc(size_t size);

/* Free secure memory */
void secure_free(void *ptr);

/* Reallocate secure memory */
void *secure_realloc(void *ptr, size_t size);

/* Allocate aligned secure memory */
void *secure_aligned_alloc(size_t alignment, size_t size);

/* Clear memory securely */
void secure_memzero(void *ptr, size_t size);

/* Copy memory securely */
void *secure_memcpy(void *dest, const void *src, size_t size);

/* Compare memory securely (constant time) */
int secure_memcmp(const void *a, const void *b, size_t size);

/* Lock memory in RAM (prevent swapping) */
int secure_memlock(void *ptr, size_t size);

/* Unlock memory */
int secure_memunlock(void *ptr, size_t size);

/* Calculate memory checksum */
uint32_t secure_checksum(const void *ptr, size_t size);

/* Verify memory integrity */
bool secure_verify_integrity(const void *ptr, size_t size, uint32_t expected_checksum);

/* Poison memory (for debugging) */
void secure_poison(void *ptr, size_t size);

/* Check if memory is poisoned */
bool secure_is_poisoned(const void *ptr, size_t size);

/* Secure string duplication */
char *secure_strdup(const char *str);

/* Secure string length */
size_t secure_strlen(const char *str);

/* Get secure memory statistics */
void secure_memory_get_stats(size_t *total_allocated, size_t *total_locked);

#ifdef __cplusplus
}
#endif

#endif /* SECURE_MEMORY_H */
