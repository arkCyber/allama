#ifndef HTTP_DOWNLOAD_H
#define HTTP_DOWNLOAD_H

/**
 * @file http-download.h
 * @brief HTTP download functionality for model registry
 * 
 * This module provides functionality for downloading files from remote
 * HTTP/HTTPS servers with progress callbacks and resumable downloads.
 * 
 * Aerospace-Level Security Features:
 * - Secure HTTPS with certificate validation
 * - SHA256 verification of downloaded files
 * - Progress callbacks for monitoring
 * - Timeout handling
 * - Resumable downloads with range requests
 */

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Download progress callback
 * 
 * @param url URL being downloaded
 * @param progress Progress from 0.0 to 1.0
 * @param user_data User-provided context
 */
typedef void (*download_progress_callback_t)(
    const char *url,
    float progress,
    void *user_data
);

/**
 * @brief Download result codes
 */
typedef enum {
    DOWNLOAD_SUCCESS = 0,
    DOWNLOAD_ERROR_INVALID_URL = -1,
    DOWNLOAD_ERROR_NETWORK = -2,
    DOWNLOAD_ERROR_IO = -3,
    DOWNLOAD_ERROR_PERMISSION = -4,
    DOWNLOAD_ERROR_VERIFICATION = -5,
    DOWNLOAD_ERROR_TIMEOUT = -6
} download_result_t;

/**
 * @brief Download a file from URL
 * 
 * @param url URL to download from
 * @param output_path Local file path to save to
 * @param progress_callback Optional progress callback
 * @param user_data User data for callback
 * @param timeout_seconds Timeout in seconds (0 for no timeout)
 * @return download_result_t Result code
 */
download_result_t http_download_file(
    const char *url,
    const char *output_path,
    download_progress_callback_t progress_callback,
    void *user_data,
    int timeout_seconds
);

/**
 * @brief Download a file with SHA256 verification
 * 
 * @param url URL to download from
 * @param output_path Local file path to save to
 * @param expected_sha256 Expected SHA256 hash (hex string, 64 chars)
 * @param progress_callback Optional progress callback
 * @param user_data User data for callback
 * @param timeout_seconds Timeout in seconds (0 for no timeout)
 * @return download_result_t Result code
 */
download_result_t http_download_file_verify(
    const char *url,
    const char *output_path,
    const char *expected_sha256,
    download_progress_callback_t progress_callback,
    void *user_data,
    int timeout_seconds
);

/**
 * @brief Get result code as string
 * 
 * @param result Result code
 * @return const char* String representation
 */
const char *download_result_to_string(download_result_t result);

#ifdef __cplusplus
}
#endif

#endif /* HTTP_DOWNLOAD_H */
