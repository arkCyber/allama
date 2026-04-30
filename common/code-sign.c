/*
 * Code Signing System Implementation for allama
 * Aerospace-level security code signing
 */

#include "code-sign.h"
#include "audit-log.h"
#include "fault-tolerance.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <openssl/sha.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <pthread.h>

/* Code signing context */
static struct {
    bool initialized;
    pthread_mutex_t mutex;
} sign_ctx = {0};

/* Get hash size for algorithm */
static size_t get_hash_size(sign_algo_t algorithm) {
    switch (algorithm) {
        case SIGN_ALGO_SHA256: return 32;
        case SIGN_ALGO_SHA384: return 48;
        case SIGN_ALGO_SHA512: return 64;
        case SIGN_ALGO_ED25519: return 64;
        default: return 0;
    }
}

/* Initialize code signing system */
int code_sign_init(void) {
    if (sign_ctx.initialized) {
        return 0; /* Already initialized */
    }

    /* Initialize mutex */
    if (pthread_mutex_init(&sign_ctx.mutex, NULL) != 0) {
        return -1;
    }

    sign_ctx.initialized = true;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "CODE_SIGN",
                   "Code signing system initialized", NULL, 0, NULL);

    return 0;
}

/* Shutdown code signing system */
void code_sign_shutdown(void) {
    if (!sign_ctx.initialized) {
        return;
    }

    pthread_mutex_lock(&sign_ctx.mutex);
    pthread_mutex_unlock(&sign_ctx.mutex);
    pthread_mutex_destroy(&sign_ctx.mutex);
    sign_ctx.initialized = false;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "CODE_SIGN",
                   "Code signing system shutdown", NULL, 0, NULL);
}

/* Compute hash of data */
sign_result_t code_sign_hash(const uint8_t *data, size_t len,
                             sign_algo_t algorithm, uint8_t *hash, size_t *hash_len) {
    if (!sign_ctx.initialized || !data || !hash || !hash_len) {
        return SIGN_FAILURE_MISSING;
    }

    size_t expected_hash_len = get_hash_size(algorithm);
    if (expected_hash_len == 0 || *hash_len < expected_hash_len) {
        return SIGN_FAILURE_UNSUPPORTED;
    }

    pthread_mutex_lock(&sign_ctx.mutex);

    switch (algorithm) {
        case SIGN_ALGO_SHA256:
            SHA256(data, len, hash);
            *hash_len = 32;
            break;
        case SIGN_ALGO_SHA384:
            SHA384(data, len, hash);
            *hash_len = 48;
            break;
        case SIGN_ALGO_SHA512:
            SHA512(data, len, hash);
            *hash_len = 64;
            break;
        case SIGN_ALGO_ED25519:
            SHA512(data, len, hash);
            *hash_len = 64;
            break;
        default:
            pthread_mutex_unlock(&sign_ctx.mutex);
            return SIGN_FAILURE_UNSUPPORTED;
    }

    pthread_mutex_unlock(&sign_ctx.mutex);
    return SIGN_SUCCESS;
}

/* Verify hash of data */
sign_result_t code_sign_verify_hash(const uint8_t *data, size_t len,
                                    const uint8_t *expected_hash, size_t hash_len,
                                    sign_algo_t algorithm) {
    if (!sign_ctx.initialized || !data || !expected_hash) {
        return SIGN_FAILURE_MISSING;
    }

    uint8_t computed_hash[64];
    size_t computed_hash_len = sizeof(computed_hash);

    sign_result_t result = code_sign_hash(data, len, algorithm, computed_hash, &computed_hash_len);
    if (result != SIGN_SUCCESS) {
        return result;
    }

    if (computed_hash_len != hash_len) {
        return SIGN_FAILURE_MISMATCH;
    }

    if (memcmp(computed_hash, expected_hash, hash_len) != 0) {
        return SIGN_FAILURE_MISMATCH;
    }

    return SIGN_SUCCESS;
}

/* Generate signature for data */
sign_result_t code_sign_generate(const uint8_t *data, size_t len,
                                 sign_algo_t algorithm, signature_t *sig) {
    if (!sign_ctx.initialized || !data || !sig) {
        return SIGN_FAILURE_MISSING;
    }

    memset(sig, 0, sizeof(signature_t));
    sig->algorithm = algorithm;
    sig->timestamp = time(NULL);

    /* Compute hash */
    sig->hash_len = sizeof(sig->hash);
    sign_result_t result = code_sign_hash(data, len, algorithm, sig->hash, &sig->hash_len);
    if (result != SIGN_SUCCESS) {
        return result;
    }

    /* Generate HMAC signature using OpenSSL */
    /* For aerospace-level security, HMAC-SHA256 provides cryptographic integrity */
    unsigned char hmac[EVP_MAX_MD_SIZE];
    size_t hmac_len = 0;
    
    /* Use a secret key for HMAC signing */
    /* In production, this should come from a secure key management system */
    const unsigned char *secret_key = (const unsigned char *)"allama-secret-key-2024";
    size_t secret_key_len = strlen((const char *)secret_key);
    
    /* Use EVP_MAC for OpenSSL 3.0+ compatibility */
    EVP_MAC *mac = EVP_MAC_fetch(NULL, "HMAC", NULL);
    if (!mac) {
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Failed to fetch HMAC MAC", NULL, 0, NULL);
        return SIGN_FAILURE_CRYPTO;
    }
    
    EVP_MAC_CTX *mac_ctx = EVP_MAC_CTX_new(mac);
    if (!mac_ctx) {
        EVP_MAC_free(mac);
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Failed to create MAC context", NULL, 0, NULL);
        return SIGN_FAILURE_CRYPTO;
    }
    
    OSSL_PARAM params[2];
    params[0] = OSSL_PARAM_construct_utf8_string("digest", "SHA256", 0);
    params[1] = OSSL_PARAM_construct_end();
    
    if (EVP_MAC_init(mac_ctx, secret_key, secret_key_len, params) != 1) {
        EVP_MAC_CTX_free(mac_ctx);
        EVP_MAC_free(mac);
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Failed to initialize MAC", NULL, 0, NULL);
        return SIGN_FAILURE_CRYPTO;
    }
    
    if (EVP_MAC_update(mac_ctx, sig->hash, sig->hash_len) != 1) {
        EVP_MAC_CTX_free(mac_ctx);
        EVP_MAC_free(mac);
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Failed to update MAC", NULL, 0, NULL);
        return SIGN_FAILURE_CRYPTO;
    }
    
    if (EVP_MAC_final(mac_ctx, hmac, &hmac_len, sizeof(hmac)) != 1) {
        EVP_MAC_CTX_free(mac_ctx);
        EVP_MAC_free(mac);
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Failed to finalize MAC", NULL, 0, NULL);
        return SIGN_FAILURE_CRYPTO;
    }
    
    EVP_MAC_CTX_free(mac_ctx);
    EVP_MAC_free(mac);
    
    /* Copy HMAC signature */
    if (hmac_len > sizeof(sig->signature)) {
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "HMAC length exceeds signature buffer size", NULL, 0, NULL);
        return SIGN_FAILURE_INVALID;
    }
    
    memcpy(sig->signature, hmac, hmac_len);
    sig->signature_len = hmac_len;

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "CODE_SIGN",
                   "HMAC signature generated", NULL, 0, NULL);

    return SIGN_SUCCESS;
}

/* Verify signature for data */
sign_result_t code_sign_verify(const uint8_t *data, size_t len,
                                const signature_t *sig) {
    if (!sign_ctx.initialized || !data || !sig) {
        return SIGN_FAILURE_MISSING;
    }

    /* Verify hash */
    uint8_t computed_hash[64];
    size_t computed_hash_len = sizeof(computed_hash);
    sign_result_t result = code_sign_hash(data, len, sig->algorithm, computed_hash, &computed_hash_len);
    if (result != SIGN_SUCCESS) {
        return result;
    }

    if (computed_hash_len != sig->hash_len) {
        return SIGN_FAILURE_MISMATCH;
    }

    if (memcmp(computed_hash, sig->hash, sig->hash_len) != 0) {
        return SIGN_FAILURE_MISMATCH;
    }

    /* Verify HMAC signature */
    unsigned char hmac[EVP_MAX_MD_SIZE];
    size_t hmac_len = 0;
    
    const unsigned char *secret_key = (const unsigned char *)"allama-secret-key-2024";
    size_t secret_key_len = strlen((const char *)secret_key);
    
    /* Use EVP_MAC for OpenSSL 3.0+ compatibility */
    EVP_MAC *mac = EVP_MAC_fetch(NULL, "HMAC", NULL);
    if (!mac) {
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Failed to fetch HMAC MAC for verification", NULL, 0, NULL);
        return SIGN_FAILURE_CRYPTO;
    }
    
    EVP_MAC_CTX *mac_ctx = EVP_MAC_CTX_new(mac);
    if (!mac_ctx) {
        EVP_MAC_free(mac);
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Failed to create MAC context for verification", NULL, 0, NULL);
        return SIGN_FAILURE_CRYPTO;
    }
    
    OSSL_PARAM params[2];
    params[0] = OSSL_PARAM_construct_utf8_string("digest", "SHA256", 0);
    params[1] = OSSL_PARAM_construct_end();
    
    if (EVP_MAC_init(mac_ctx, secret_key, secret_key_len, params) != 1) {
        EVP_MAC_CTX_free(mac_ctx);
        EVP_MAC_free(mac);
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Failed to initialize MAC for verification", NULL, 0, NULL);
        return SIGN_FAILURE_CRYPTO;
    }
    
    if (EVP_MAC_update(mac_ctx, computed_hash, computed_hash_len) != 1) {
        EVP_MAC_CTX_free(mac_ctx);
        EVP_MAC_free(mac);
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Failed to update MAC for verification", NULL, 0, NULL);
        return SIGN_FAILURE_CRYPTO;
    }
    
    if (EVP_MAC_final(mac_ctx, hmac, &hmac_len, sizeof(hmac)) != 1) {
        EVP_MAC_CTX_free(mac_ctx);
        EVP_MAC_free(mac);
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Failed to finalize MAC for verification", NULL, 0, NULL);
        return SIGN_FAILURE_CRYPTO;
    }
    
    EVP_MAC_CTX_free(mac_ctx);
    EVP_MAC_free(mac);
    
    /* Compare HMAC signatures using constant-time comparison */
    if (hmac_len != sig->signature_len) {
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "HMAC length mismatch during verification", NULL, 0, NULL);
        return SIGN_FAILURE_MISMATCH;
    }
    
    /* Constant-time comparison to prevent timing attacks with timeout protection */
    volatile int cmp_result = 0;
    
    ft_timeout_t timeout;
    ft_timeout_init(&timeout, SHORT_TIMEOUT);
    
    for (unsigned int i = 0; i < hmac_len && !ft_timeout_check(&timeout); i++) {
        cmp_result |= hmac[i] ^ sig->signature[i];
    }
    
    ft_timeout_cleanup(&timeout);
    
    if (ft_timeout_check(&timeout)) {
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Signature verification timeout", NULL, 0, NULL);
        return SIGN_FAILURE_TIMEOUT;
    }
    
    if (cmp_result != 0) {
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "HMAC signature verification failed", NULL, 0, NULL);
        return SIGN_FAILURE_MISMATCH;
    }

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "CODE_SIGN",
                   "Signature verified", NULL, 0, NULL);

    return SIGN_SUCCESS;
}

/* Maximum file size for signing (100 MB) */
#define MAX_FILE_SIZE (100 * 1024 * 1024)

/* Read file into buffer with size limit */
static sign_result_t read_file(const char *path, uint8_t **data, size_t *len) {
    if (!path || !data || !len) {
        return SIGN_FAILURE_INVALID;
    }

    FILE *file = fopen(path, "rb");
    if (!file) {
        return SIGN_FAILURE_MISSING;
    }

    /* Get file size */
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    /* Check file size limit */
    if (file_size < 0 || file_size > MAX_FILE_SIZE) {
        fclose(file);
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "File size exceeds limit", path, 0, NULL);
        return SIGN_FAILURE_INVALID;
    }

    /* Allocate buffer */
    *data = (uint8_t *)malloc(file_size);
    if (!*data) {
        fclose(file);
        return SIGN_FAILURE_INVALID;
    }

    /* Read file with timeout protection */
    ft_timeout_t timeout;
    ft_timeout_init(&timeout, MEDIUM_TIMEOUT);
    
    size_t read_size = fread(*data, 1, file_size, file);
    
    ft_timeout_cleanup(&timeout);
    
    fclose(file);

    if (ft_timeout_check(&timeout)) {
        free(*data);
        *data = NULL;
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "File read timeout", path, 0, NULL);
        return SIGN_FAILURE_TIMEOUT;
    }

    if (read_size != (size_t)file_size) {
        free(*data);
        *data = NULL;
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "File read incomplete", path, 0, NULL);
        return SIGN_FAILURE_INVALID;
    }

    *len = read_size;
    return SIGN_SUCCESS;
}

/* Sign model file */
sign_result_t code_sign_model(const char *model_path, signature_t *sig) {
    if (!sign_ctx.initialized || !model_path || !sig) {
        return SIGN_FAILURE_MISSING;
    }

    uint8_t *data = NULL;
    size_t len = 0;

    sign_result_t result = read_file(model_path, &data, &len);
    if (result != SIGN_SUCCESS) {
        return result;
    }

    result = code_sign_generate(data, len, SIGN_ALGO_SHA512, sig);

    free(data);

    if (result == SIGN_SUCCESS) {
        audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "CODE_SIGN",
                       "Model signed", model_path, 0, NULL);
    }

    return result;
}

/* Verify model file signature */
sign_result_t code_sign_verify_model(const char *model_path, const signature_t *sig) {
    if (!sign_ctx.initialized || !model_path || !sig) {
        return SIGN_FAILURE_MISSING;
    }

    uint8_t *data = NULL;
    size_t len = 0;

    sign_result_t result = read_file(model_path, &data, &len);
    if (result != SIGN_SUCCESS) {
        return result;
    }

    result = code_sign_verify(data, len, sig);

    free(data);

    if (result == SIGN_SUCCESS) {
        audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "CODE_SIGN",
                       "Model signature verified", model_path, 0, NULL);
    } else {
        audit_log_security_violation("CODE_SIGN", "model_signature_mismatch", model_path);
    }

    return result;
}

/* Sign binary */
sign_result_t code_sign_binary(const char *binary_path, signature_t *sig) {
    if (!sign_ctx.initialized || !binary_path || !sig) {
        return SIGN_FAILURE_MISSING;
    }

    uint8_t *data = NULL;
    size_t len = 0;

    sign_result_t result = read_file(binary_path, &data, &len);
    if (result != SIGN_SUCCESS) {
        return result;
    }

    result = code_sign_generate(data, len, SIGN_ALGO_SHA512, sig);

    free(data);

    if (result == SIGN_SUCCESS) {
        audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "CODE_SIGN",
                       "Binary signed", binary_path, 0, NULL);
    }

    return result;
}

/* Verify binary signature */
sign_result_t code_sign_verify_binary(const char *binary_path, const signature_t *sig) {
    if (!sign_ctx.initialized || !binary_path || !sig) {
        return SIGN_FAILURE_MISSING;
    }

    uint8_t *data = NULL;
    size_t len = 0;

    sign_result_t result = read_file(binary_path, &data, &len);
    if (result != SIGN_SUCCESS) {
        return result;
    }

    result = code_sign_verify(data, len, sig);

    free(data);

    if (result == SIGN_SUCCESS) {
        audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "CODE_SIGN",
                       "Binary signature verified", binary_path, 0, NULL);
    } else {
        audit_log_security_violation("CODE_SIGN", "binary_signature_mismatch", binary_path);
    }

    return result;
}

/* Load signature from file with timeout protection */
sign_result_t code_sign_load_signature(const char *sig_path, signature_t *sig) {
    if (!sign_ctx.initialized || !sig_path || !sig) {
        return SIGN_FAILURE_MISSING;
    }

    FILE *file = fopen(sig_path, "rb");
    if (!file) {
        return SIGN_FAILURE_MISSING;
    }

    /* Read file with timeout protection */
    ft_timeout_t timeout;
    ft_timeout_init(&timeout, SHORT_TIMEOUT);
    
    size_t read_size = fread(sig, 1, sizeof(signature_t), file);
    
    ft_timeout_cleanup(&timeout);
    
    fclose(file);

    if (ft_timeout_check(&timeout)) {
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Signature load timeout", sig_path, 0, NULL);
        return SIGN_FAILURE_TIMEOUT;
    }

    if (read_size != sizeof(signature_t)) {
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Signature load incomplete", sig_path, 0, NULL);
        return SIGN_FAILURE_INVALID;
    }

    return SIGN_SUCCESS;
}

/* Save signature to file with timeout protection */
sign_result_t code_sign_save_signature(const char *sig_path, const signature_t *sig) {
    if (!sign_ctx.initialized || !sig_path || !sig) {
        return SIGN_FAILURE_MISSING;
    }

    FILE *file = fopen(sig_path, "wb");
    if (!file) {
        return SIGN_FAILURE_INVALID;
    }

    /* Write file with timeout protection */
    ft_timeout_t timeout;
    ft_timeout_init(&timeout, SHORT_TIMEOUT);
    
    size_t write_size = fwrite(sig, 1, sizeof(signature_t), file);
    
    ft_timeout_cleanup(&timeout);
    
    fclose(file);

    if (ft_timeout_check(&timeout)) {
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Signature save timeout", sig_path, 0, NULL);
        return SIGN_FAILURE_TIMEOUT;
    }

    if (write_size != sizeof(signature_t)) {
        audit_log_write(AUDIT_LEVEL_ERROR, AUDIT_EVENT_SECURITY_VIOLATION, "CODE_SIGN",
                       "Signature save incomplete", sig_path, 0, NULL);
        return SIGN_FAILURE_INVALID;
    }

    audit_log_write(AUDIT_LEVEL_INFO, AUDIT_EVENT_AUTH_SUCCESS, "CODE_SIGN",
                   "Signature saved", sig_path, 0, NULL);

    return SIGN_SUCCESS;
}

/* Get signature algorithm string */
const char *code_sign_algo_to_string(sign_algo_t algorithm) {
    switch (algorithm) {
        case SIGN_ALGO_SHA256: return "SHA256";
        case SIGN_ALGO_SHA384: return "SHA384";
        case SIGN_ALGO_SHA512: return "SHA512";
        case SIGN_ALGO_ED25519: return "ED25519";
        default: return "UNKNOWN";
    }
}

/* Get signature result string */
const char *code_sign_result_to_string(sign_result_t result) {
    switch (result) {
        case SIGN_SUCCESS: return "SUCCESS";
        case SIGN_FAILURE_INVALID: return "INVALID";
        case SIGN_FAILURE_MISSING: return "MISSING";
        case SIGN_FAILURE_MISMATCH: return "MISMATCH";
        case SIGN_FAILURE_UNSUPPORTED: return "UNSUPPORTED";
        default: return "UNKNOWN";
    }
}
