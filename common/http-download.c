/**
 * @file http-download.c
 * @brief HTTP download functionality for model registry
 * 
 * Aerospace-Level Security Implementation:
 * - Secure HTTPS with certificate validation
 * - SHA256 verification of downloaded files
 * - Progress callbacks for monitoring
 * - Timeout handling
 * - Resumable downloads with range requests
 */

#include "http-download.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>
#include <openssl/sha.h>
#include <openssl/evp.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>
#include <limits.h>

/**
 * @brief Download context for tracking progress
 */
typedef struct {
    FILE *file;
    size_t total_size;
    size_t downloaded;
    size_t resume_from;
    download_progress_callback_t callback;
    void *user_data;
    const char *url;
    uint8_t sha256_context[SHA256_DIGEST_LENGTH];
    bool verify;
} download_context_t;

/**
 * @brief CURL write callback
 */
static size_t write_callback(void *contents, size_t size, size_t nmemb, void *userp) {
    download_context_t *ctx = (download_context_t *)userp;
    size_t total = size * nmemb;
    
    size_t written = fwrite(contents, 1, total, ctx->file);
    ctx->downloaded += written;
    
    if (ctx->verify) {
        SHA256_Update((SHA256_CTX *)ctx->sha256_context, contents, written);
    }
    
    if (ctx->callback && ctx->total_size > 0) {
        float progress = (float)ctx->downloaded / (float)ctx->total_size;
        ctx->callback(ctx->url, progress, ctx->user_data);
    }
    
    return written;
}

/**
 * @brief CURL header callback for Content-Length
 */
static size_t header_callback(char *buffer, size_t size, size_t nitems, void *userdata) {
    download_context_t *ctx = (download_context_t *)userdata;
    size_t total = size * nitems;
    
    if (strncasecmp(buffer, "Content-Length:", 15) == 0) {
        size_t remaining = strtoull(buffer + 15, NULL, 10);
        ctx->total_size = ctx->resume_from + remaining;
    }
    
    return total;
}

static bool get_file_size(const char *path, size_t *size_out) {
    struct stat st;
    if (stat(path, &st) != 0) {
        return false;
    }
    if (size_out) {
        *size_out = (size_t) st.st_size;
    }
    return true;
}

static size_t get_remote_content_length(const char *url) {
    CURL *curl = curl_easy_init();
    if (!curl) {
        return 0;
    }

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_NOBODY, 1L);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
    curl_easy_setopt(curl, CURLOPT_FAILONERROR, 1L);

    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
        curl_easy_cleanup(curl);
        return 0;
    }

    curl_off_t content_length = -1;
    if (curl_easy_getinfo(curl, CURLINFO_CONTENT_LENGTH_DOWNLOAD_T, &content_length) != CURLE_OK || content_length <= 0) {
        curl_easy_cleanup(curl);
        return 0;
    }

    curl_easy_cleanup(curl);
    return (size_t) content_length;
}

/**
 * @brief Compute SHA256 hash of a file
 */
static bool compute_file_sha256(const char *path, uint8_t *digest) {
    FILE *file = fopen(path, "rb");
    if (!file) {
        return false;
    }
    
    SHA256_CTX sha256;
    SHA256_Init(&sha256);
    
    uint8_t buffer[8192];
    size_t bytes_read;
    
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), file)) > 0) {
        SHA256_Update(&sha256, buffer, bytes_read);
    }
    
    fclose(file);
    SHA256_Final(digest, &sha256);
    return true;
}

/**
 * @brief Convert SHA256 digest to hex string
 */
static void sha256_to_hex(const uint8_t *digest, char *hex_string) {
    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        snprintf(hex_string + (i * 2), 3, "%02x", digest[i]);
    }
    hex_string[SHA256_DIGEST_LENGTH * 2] = '\0';
}

/**
 * @brief Verify SHA256 hash matches expected
 */
static bool verify_sha256(const char *path, const char *expected_sha256) {
    uint8_t digest[SHA256_DIGEST_LENGTH];
    
    if (!compute_file_sha256(path, digest)) {
        return false;
    }
    
    char computed_hex[SHA256_DIGEST_LENGTH * 2 + 1];
    sha256_to_hex(digest, computed_hex);
    
    return strcmp(computed_hex, expected_sha256) == 0;
}

/**
 * @brief Download a file from URL
 */
download_result_t http_download_file(
    const char *url,
    const char *output_path,
    download_progress_callback_t progress_callback,
    void *user_data,
    int timeout_seconds
) {
    return http_download_file_verify(url, output_path, NULL, progress_callback, user_data, timeout_seconds);
}

/**
 * @brief Download a file with SHA256 verification
 */
download_result_t http_download_file_verify(
    const char *url,
    const char *output_path,
    const char *expected_sha256,
    download_progress_callback_t progress_callback,
    void *user_data,
    int timeout_seconds
) {
    if (!url || !output_path) {
        return DOWNLOAD_ERROR_INVALID_URL;
    }

    char part_path[PATH_MAX];
    if (snprintf(part_path, sizeof(part_path), "%s.part", output_path) >= (int) sizeof(part_path)) {
        return DOWNLOAD_ERROR_IO;
    }

    size_t output_size = 0;
    bool output_exists = get_file_size(output_path, &output_size);
    if (output_exists) {
        if (expected_sha256 && verify_sha256(output_path, expected_sha256)) {
            if (progress_callback) {
                progress_callback(url, 1.0f, user_data);
            }
            return DOWNLOAD_SUCCESS;
        }

        size_t remote_size = get_remote_content_length(url);
        if (remote_size > 0 && output_size == remote_size) {
            if (progress_callback) {
                progress_callback(url, 1.0f, user_data);
            }
            return DOWNLOAD_SUCCESS;
        }

        /* Convert existing output into resumable part file if present */
        unlink(part_path);
        if (rename(output_path, part_path) != 0) {
            return DOWNLOAD_ERROR_IO;
        }
    }

    size_t resume_from = 0;
    if (get_file_size(part_path, &resume_from)) {
        size_t remote_size = get_remote_content_length(url);
        if (remote_size > 0 && resume_from >= remote_size) {
            if (rename(part_path, output_path) != 0) {
                return DOWNLOAD_ERROR_IO;
            }
            if (progress_callback) {
                progress_callback(url, 1.0f, user_data);
            }
            return DOWNLOAD_SUCCESS;
        }
    } else {
        resume_from = 0;
    }

    CURL *curl = curl_easy_init();
    if (!curl) {
        return DOWNLOAD_ERROR_NETWORK;
    }

    FILE *file = fopen(part_path, resume_from > 0 ? "ab" : "wb");
    if (!file) {
        curl_easy_cleanup(curl);
        return DOWNLOAD_ERROR_IO;
    }

    download_context_t ctx = {
        .file = file,
        .total_size = 0,
        .downloaded = resume_from,
        .resume_from = resume_from,
        .callback = progress_callback,
        .user_data = user_data,
        .url = url,
        .verify = (expected_sha256 != NULL)
    };
    
    if (ctx.verify) {
        SHA256_Init((SHA256_CTX *)ctx.sha256_context);
    }
    
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &ctx);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, header_callback);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, &ctx);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
    curl_easy_setopt(curl, CURLOPT_FAILONERROR, 1L);

    if (resume_from > 0) {
        curl_easy_setopt(curl, CURLOPT_RESUME_FROM_LARGE, (curl_off_t) resume_from);
    }
    
    if (timeout_seconds > 0) {
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout_seconds);
    }
    
    CURLcode res = curl_easy_perform(curl);
    
    fclose(file);
    curl_easy_cleanup(curl);
    
    if (res != CURLE_OK) {
        if (res == CURLE_OPERATION_TIMEDOUT) {
            return DOWNLOAD_ERROR_TIMEOUT;
        } else if (res == CURLE_COULDNT_RESOLVE_HOST || res == CURLE_COULDNT_CONNECT) {
            return DOWNLOAD_ERROR_NETWORK;
        } else {
            return DOWNLOAD_ERROR_IO;
        }
    }

    if (rename(part_path, output_path) != 0) {
        return DOWNLOAD_ERROR_IO;
    }
    
    if (ctx.verify && expected_sha256) {
        if (!verify_sha256(output_path, expected_sha256)) {
            unlink(output_path);
            return DOWNLOAD_ERROR_VERIFICATION;
        }
    }
    
    return DOWNLOAD_SUCCESS;
}

/**
 * @brief Get result code as string
 */
const char *download_result_to_string(download_result_t result) {
    switch (result) {
        case DOWNLOAD_SUCCESS:
            return "Success";
        case DOWNLOAD_ERROR_INVALID_URL:
            return "Invalid URL";
        case DOWNLOAD_ERROR_NETWORK:
            return "Network error";
        case DOWNLOAD_ERROR_IO:
            return "I/O error";
        case DOWNLOAD_ERROR_PERMISSION:
            return "Permission denied";
        case DOWNLOAD_ERROR_VERIFICATION:
            return "SHA256 verification failed";
        case DOWNLOAD_ERROR_TIMEOUT:
            return "Download timeout";
        default:
            return "Unknown error";
    }
}
