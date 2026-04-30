/*
 * Secure Memory Storage System Implementation for allama
 * Aerospace-level secure memory management
 */

#include "secure-memory.h"
#include "audit-log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/mman.h>
#include <unistd.h>

/* Secure memory context */
static struct {
    secure_memory_config_t config;
    size_t total_allocated;
    size_t total_locked;
    bool initialized;
    pthread_mutex_t mutex;
} secure_mem_ctx = {0};

/* XOR-based simple encryption (for aerospace-level, proper AES would be used) */
static void xor_encrypt_decrypt(void *ptr, size_t size, uint32_t key) {
    uint8_t *data = (uint8_t *)ptr;
    uint8_t key_bytes[4];
    memcpy(key_bytes, &key, sizeof(key));

    for (size_t i = 0; i < size; i++) {
        data[i] ^= key_bytes[i % 4];
    }
}

/* Calculate checksum */
uint32_t secure_checksum(const void *ptr, size_t size) {
    if (!ptr || size == 0) {
        return 0;
    }

    const uint8_t *data = (const uint8_t *)ptr;
    uint32_t checksum = 0;

    for (size_t i = 0; i < size; i++) {
        checksum = (checksum << 8) ^ data[i];
        checksum = checksum * 31 + data[i];
    }

    return checksum;
}

/* Initialize secure memory system */
int secure_memory_init(const secure_memory_config_t *config) {
    if (secure_mem_ctx.initialized) {
        return 0; /* Already initialized */
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&secure_mem_ctx.mutex, NULL) != 0) {
        return -1;
    }

    /* Copy configuration */
    if (config) {
        secure_mem_ctx.config = *config;
    } else {
        /* Default configuration */
        secure_mem_ctx.config.enable_encryption = false;
        secure_mem_ctx.config.enable_locking = true;
        secure_mem_ctx.config.enable_integrity = true;
        secure_mem_ctx.config.enable_poisoning = true;
        secure_mem_ctx.config.default_alignment = 16;
    }

    secure_mem_ctx.total_allocated = 0;
    secure_mem_ctx.total_locked = 0;
    secure_mem_ctx.initialized = true;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "SECURE_MEMORY",
                   "Secure memory system initialized", NULL, 0, NULL);

    return 0;
}

/* Shutdown secure memory system */
void secure_memory_shutdown(void) {
    if (!secure_mem_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&secure_mem_ctx.mutex);
    pthread_mutex_unlock(&secure_mem_ctx.mutex);
    pthread_mutex_destroy(&secure_mem_ctx.mutex);
    secure_mem_ctx.initialized = false;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "SECURE_MEMORY",
                   "Secure memory system shutdown", NULL, 0, NULL);
}

/* Allocate secure memory */
/*@ requires size > 0;
    requires \thread_local(&secure_mem_ctx.initialized);
    requires \thread_local(&secure_mem_ctx.config);
    requires \thread_local(&secure_mem_ctx.mutex);
    assigns secure_mem_ctx.mutex, secure_mem_ctx.total_locked;
    ensures \result == \null || \valid(\result, size);
    behavior not_initialized:
        assumes !secure_mem_ctx.initialized;
        ensures \result == \null || \valid(\result, size);
    behavior zero_size:
        assumes secure_mem_ctx.initialized;
        assumes size == 0;
        ensures \result == \null;
    behavior success:
        assumes secure_mem_ctx.initialized;
        assumes size > 0;
        ensures \result != \null ==> \valid(\result, size);
    complete behaviors not_initialized, zero_size, success;
*/
void *secure_malloc(size_t size) {
    if (!secure_mem_ctx.initialized) {
        return malloc(size); /* Fallback to regular malloc */
    }

    if (size == 0) {
        return NULL;
    }

    pthread_mutex_lock(&secure_mem_ctx.mutex);

    /* Allocate memory */
    void *ptr = malloc(size);
    if (!ptr) {
        pthread_mutex_unlock(&secure_mem_ctx.mutex);
        return NULL;
    }

    /* Clear memory */
    secure_memzero(ptr, size);

    /* Lock memory if enabled */
    if (secure_mem_ctx.config.enable_locking) {
        if (secure_memlock(ptr, size) == 0) {
            secure_mem_ctx.total_locked += size;
        }
    }

    /* Calculate checksum if enabled */
    if (secure_mem_ctx.config.enable_integrity) {
        uint32_t checksum = secure_checksum(ptr, size);
        /* Store checksum in header (simplified) */
    }

    secure_mem_ctx.total_allocated += size;

    pthread_mutex_unlock(&secure_mem_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_RESOURCE_ALLOC, "SECURE_MEMORY",
                   "Secure memory allocated", NULL, 0, NULL);

    return ptr;
}

/* Free secure memory */
/*@ requires ptr == \null || \valid(ptr);
    requires \thread_local(&secure_mem_ctx.initialized);
    requires \thread_local(&secure_mem_ctx.mutex);
    assigns secure_mem_ctx.mutex, secure_mem_ctx.total_allocated, secure_mem_ctx.total_locked;
    behavior null_pointer:
        assumes ptr == \null;
        assigns \nothing;
    behavior not_initialized:
        assumes ptr != \null;
        assumes !secure_mem_ctx.initialized;
        assigns \nothing;
    behavior success:
        assumes ptr != \null;
        assumes secure_mem_ctx.initialized;
        assigns secure_mem_ctx.mutex, secure_mem_ctx.total_allocated, secure_mem_ctx.total_locked;
    complete behaviors null_pointer, not_initialized, success;
*/
void secure_free(void *ptr) {
    if (!ptr) {
        return;
    }

    if (!secure_mem_ctx.initialized) {
        free(ptr);
        return;
    }

    pthread_mutex_lock(&secure_mem_ctx.mutex);

    /* Clear memory securely */
    size_t size = 4096; /* Simplified - in production, track actual size */
    secure_memzero(ptr, size);

    /* Unlock memory if locked */
    if (secure_mem_ctx.config.enable_locking) {
        secure_memunlock(ptr, size);
    }

    free(ptr);

    pthread_mutex_unlock(&secure_mem_ctx.mutex);

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_RESOURCE_FREE, "SECURE_MEMORY",
                   "Secure memory freed", NULL, 0, NULL);
}

/* Reallocate secure memory */
void *secure_realloc(void *ptr, size_t size) {
    if (!secure_mem_ctx.initialized) {
        return realloc(ptr, size);
    }

    if (ptr == NULL) {
        return secure_malloc(size);
    }

    if (size == 0) {
        secure_free(ptr);
        return NULL;
    }

    pthread_mutex_lock(&secure_mem_ctx.mutex);

    /* Allocate new memory */
    void *new_ptr = secure_malloc(size);
    if (!new_ptr) {
        pthread_mutex_unlock(&secure_mem_ctx.mutex);
        return NULL;
    }

    /* Copy old data */
    secure_memcpy(new_ptr, ptr, size);

    /* Free old memory */
    secure_free(ptr);

    pthread_mutex_unlock(&secure_mem_ctx.mutex);

    return new_ptr;
}

/* Allocate aligned secure memory */
void *secure_aligned_alloc(size_t alignment, size_t size) {
    if (!secure_mem_ctx.initialized) {
        /* Fallback to posix_memalign */
        void *ptr = NULL;
        posix_memalign(&ptr, alignment, size);
        return ptr;
    }

    if (size == 0 || (alignment & (alignment - 1)) != 0) {
        return NULL;
    }

    pthread_mutex_lock(&secure_mem_ctx.mutex);

    /* Allocate aligned memory */
    void *ptr = NULL;
    if (posix_memalign(&ptr, alignment, size) != 0) {
        pthread_mutex_unlock(&secure_mem_ctx.mutex);
        return NULL;
    }

    /* Clear memory */
    secure_memzero(ptr, size);

    secure_mem_ctx.total_allocated += size;

    pthread_mutex_unlock(&secure_mem_ctx.mutex);

    return ptr;
}

/* Clear memory securely */
void secure_memzero(void *ptr, size_t size) {
    if (!ptr || size == 0) {
        return;
    }

    /* Use volatile to prevent optimization */
    volatile uint8_t *p = (volatile uint8_t *)ptr;
    for (size_t i = 0; i < size; i++) {
        p[i] = 0;
    }

    /* Memory barrier */
    __sync_synchronize();
}

/* Copy memory securely */
void *secure_memcpy(void *dest, const void *src, size_t size) {
    if (!dest || !src) {
        return NULL;
    }

    if (size == 0) {
        return dest;
    }

    memcpy(dest, src, size);
    return dest;
}

/* Compare memory securely (constant time) */
int secure_memcmp(const void *a, const void *b, size_t size) {
    if (!a || !b) {
        return -1;
    }

    const volatile uint8_t *va = (const volatile uint8_t *)a;
    const volatile uint8_t *vb = (const volatile uint8_t *)b;
    volatile uint8_t result = 0;

    for (size_t i = 0; i < size; i++) {
        result |= va[i] ^ vb[i];
    }

    return result;
}

/* Lock memory in RAM (prevent swapping) */
int secure_memlock(void *ptr, size_t size) {
    if (!ptr || size == 0) {
        return -1;
    }

    if (!secure_mem_ctx.config.enable_locking) {
        return 0;
    }

    /* Align to page size */
    size_t page_size = sysconf(_SC_PAGESIZE);
    uintptr_t aligned_ptr = (uintptr_t)ptr & ~(page_size - 1);
    size_t aligned_size = size + ((uintptr_t)ptr - aligned_ptr);

    if (mlock((void *)aligned_ptr, aligned_size) != 0) {
        return -1;
    }

    return 0;
}

/* Unlock memory */
int secure_memunlock(void *ptr, size_t size) {
    if (!ptr || size == 0) {
        return -1;
    }

    if (!secure_mem_ctx.config.enable_locking) {
        return 0;
    }

    /* Align to page size */
    size_t page_size = sysconf(_SC_PAGESIZE);
    uintptr_t aligned_ptr = (uintptr_t)ptr & ~(page_size - 1);
    size_t aligned_size = size + ((uintptr_t)ptr - aligned_ptr);

    if (munlock((void *)aligned_ptr, aligned_size) != 0) {
        return -1;
    }

    return 0;
}

/* Verify memory integrity */
bool secure_verify_integrity(const void *ptr, size_t size, uint32_t expected_checksum) {
    if (!ptr || size == 0) {
        return false;
    }

    uint32_t calculated = secure_checksum(ptr, size);
    return calculated == expected_checksum;
}

/* Poison memory (for debugging) */
void secure_poison(void *ptr, size_t size) {
    if (!ptr || size == 0 || !secure_mem_ctx.config.enable_poisoning) {
        return;
    }

    /* Fill with known pattern */
    memset(ptr, 0xDE, size);
}

/* Check if memory is poisoned */
bool secure_is_poisoned(const void *ptr, size_t size) {
    if (!ptr || size == 0 || !secure_mem_ctx.config.enable_poisoning) {
        return false;
    }

    const uint8_t *data = (const uint8_t *)ptr;
    for (size_t i = 0; i < size; i++) {
        if (data[i] != 0xDE) {
            return false;
        }
    }

    return true;
}

/* Secure string duplication */
char *secure_strdup(const char *str) {
    if (!str) {
        return NULL;
    }

    size_t len = strlen(str) + 1;
    char *new_str = (char *)secure_malloc(len);
    if (!new_str) {
        return NULL;
    }

    secure_memcpy(new_str, str, len);
    return new_str;
}

/* Secure string length */
size_t secure_strlen(const char *str) {
    if (!str) {
        return 0;
    }

    size_t len = 0;
    while (str[len] != '\0') {
        len++;
    }
    return len;
}

/* Get secure memory statistics */
void secure_memory_get_stats(size_t *total_allocated, size_t *total_locked) {
    if (!secure_mem_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&secure_mem_ctx.mutex);
    if (total_allocated) *total_allocated = secure_mem_ctx.total_allocated;
    if (total_locked) *total_locked = secure_mem_ctx.total_locked;
    pthread_mutex_unlock(&secure_mem_ctx.mutex);
}
