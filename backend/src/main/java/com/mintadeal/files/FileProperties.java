package com.mintadeal.files;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Local image storage for the MVP. Swap for object storage (S3-compatible) before running more than one instance.
 *
 * @param publicBaseUrl prefix used to build image URLs returned to the apps
 */
@ConfigurationProperties("mintadeal.files")
public record FileProperties(String directory, String publicBaseUrl) {
}
