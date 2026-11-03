package com.mintadeal.identity;

import java.time.Duration;
import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param devFixedCode when set (local development only), every OTP is this code and no SMS is sent
 * @param reviewPhones  phone numbers given to app store reviewers, who cannot receive our SMS; they sign in with
 *                      {@code reviewCode} and get no SMS. Empty in normal running.
 * @param reviewCode    the code for {@code reviewPhones}; ignored unless it is 6 digits
 */
@ConfigurationProperties("mintadeal.otp")
public record OtpProperties(Duration ttl, int maxAttempts, Duration resendCooldown, int maxPerHour,
                            String pepper, String devFixedCode, List<String> reviewPhones, String reviewCode) {

    public OtpProperties {
        reviewPhones = reviewPhones == null ? List.of() : reviewPhones.stream().filter(p -> !p.isBlank())
                .map(PhoneNumbers::normalize).toList();
    }

    boolean isReviewPhone(String phone) {
        return reviewCode != null && reviewCode.matches("\\d{6}") && reviewPhones.contains(phone);
    }
}
