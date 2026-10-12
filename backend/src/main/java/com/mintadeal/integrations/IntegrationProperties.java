package com.mintadeal.integrations;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Base URLs are configurable so tests (and a future sandbox) can point at a stand-in server. */
@ConfigurationProperties("mintadeal.integrations")
public record IntegrationProperties(String razorpayBaseUrl, String twoFactorBaseUrl, String whatsappBaseUrl) {
}
