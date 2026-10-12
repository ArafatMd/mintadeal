package com.mintadeal.identity;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param devFixedCode when set (local development only), every OTP is this code and no SMS is sent
 */
@ConfigurationProperties("mintadeal.otp")
public record OtpProperties(Duration ttl, int maxAttempts, Duration resendCooldown, int maxPerHour,
                            String pepper, String devFixedCode) {
}
