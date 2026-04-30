/*
 * Code Signing System for allama
 * Aerospace-level security code signing
 * 
 * Provides:
 * - Model file signature verification
 * - Binary integrity checking
 * - Hash-based verification
 * - Signature generation
 * - Certificate validation
 */

#ifndef CODE_SIGN_H
#define CODE_SIGN_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Signature algorithms */
typedef enum {
    SIGN_ALGO_SHA256 = 0,
    SIGN_ALGO_SHA384 = 1,
    SIGN_ALGO_SHA512 = 2,
    SIGN_ALGO_ED25519 = 3
} sign_algo_t;

/* Signature result */
typedef enum {
    SIGN_SUCCESS = 0,
    SIGN_FAILURE_INVALID = 1,
    SIGN_FAILURE_MISSING = 2,
    SIGN_FAILURE_MISMATCH = 3,
    SIGN_FAILURE_UNSUPPORTED = 4,
    SIGN_FAILURE_CRYPTO = 5,
    SIGN_FAILURE_TIMEOUT = 6
} sign_result_t;

/* Signature data */
typedef struct {
    sign_algo_t algorithm;
    uint8_t hash[64];
    size_t hash_len;
    uint8_t signature[128];
    size_t signature_len;
    char certificate[512];
    time_t timestamp;
} signature_t;

/* Initialize code signing system */
int code_sign_init(void);

/* Shutdown code signing system */
void code_sign_shutdown(void);

/* Generate signature for data */
sign_result_t code_sign_generate(const uint8_t *data, size_t len,
                                 sign_algo_t algorithm, signature_t *sig);

/* Verify signature for data */
sign_result_t code_sign_verify(const uint8_t *data, size_t len,
                                const signature_t *sig);

/* Compute hash of data */
sign_result_t code_sign_hash(const uint8_t *data, size_t len,
                             sign_algo_t algorithm, uint8_t *hash, size_t *hash_len);

/* Verify hash of data */
sign_result_t code_sign_verify_hash(const uint8_t *data, size_t len,
                                    const uint8_t *expected_hash, size_t hash_len,
                                    sign_algo_t algorithm);

/* Sign model file */
sign_result_t code_sign_model(const char *model_path, signature_t *sig);

/* Verify model file signature */
sign_result_t code_sign_verify_model(const char *model_path, const signature_t *sig);

/* Sign binary */
sign_result_t code_sign_binary(const char *binary_path, signature_t *sig);

/* Verify binary signature */
sign_result_t code_sign_verify_binary(const char *binary_path, const signature_t *sig);

/* Load signature from file */
sign_result_t code_sign_load_signature(const char *sig_path, signature_t *sig);

/* Save signature to file */
sign_result_t code_sign_save_signature(const char *sig_path, const signature_t *sig);

/* Get signature algorithm string */
const char *code_sign_algo_to_string(sign_algo_t algorithm);

/* Get signature result string */
const char *code_sign_result_to_string(sign_result_t result);

#ifdef __cplusplus
}
#endif

#endif /* CODE_SIGN_H */
