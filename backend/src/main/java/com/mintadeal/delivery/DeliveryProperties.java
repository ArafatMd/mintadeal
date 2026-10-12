package com.mintadeal.delivery;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Partner delivery pricing and limits. The shop is shown the cost before it requests a rider, and the cost is
 * recovered from the shop.
 *
 * @param maxOutstandingMinor unpaid delivery charges above which a shop cannot request more partner deliveries
 */
@ConfigurationProperties("mintadeal.delivery")
public record DeliveryProperties(long baseFeeMinor, long perKmMinor, long maxOutstandingMinor,
                                 int dropCodeMaxAttempts) {
}
