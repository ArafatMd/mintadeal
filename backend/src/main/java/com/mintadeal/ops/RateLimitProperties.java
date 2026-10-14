package com.mintadeal.ops;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Request limits per client, in fixed windows.
 *
 * @param enabled  off in tests that send many requests
 * @param perMinute overall requests per minute from one client
 * @param auth     sign-in requests per 10 minutes from one IP (each phone also has its own OTP limits)
 * @param writes   orders, uploads, reviews and help requests per 10 minutes from one client
 */
@ConfigurationProperties("mintadeal.rate-limit")
public record RateLimitProperties(Boolean enabled, Integer perMinute, Integer auth, Integer writes) {

    public RateLimitProperties {
        enabled = enabled == null || enabled;
        perMinute = perMinute == null ? 600 : perMinute;
        auth = auth == null ? 30 : auth;
        writes = writes == null ? 60 : writes;
    }
}
