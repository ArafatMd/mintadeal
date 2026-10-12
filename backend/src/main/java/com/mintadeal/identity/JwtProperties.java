package com.mintadeal.identity;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("mintadeal.jwt")
public record JwtProperties(String secret, String issuer, Duration ttl) {
}
