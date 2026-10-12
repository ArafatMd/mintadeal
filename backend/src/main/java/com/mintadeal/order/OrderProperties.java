package com.mintadeal.order;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param acceptTimeout how long a shop has to accept before the order is cancelled automatically
 * @param paymentTimeout how long an online payment link stays open
 * @param devFakeGateway local development only: simulate online payment when Razorpay is not configured
 */
@ConfigurationProperties("mintadeal.orders")
public record OrderProperties(Duration acceptTimeout, Duration paymentTimeout, int maxQuantity,
                              boolean devFakeGateway) {
}
