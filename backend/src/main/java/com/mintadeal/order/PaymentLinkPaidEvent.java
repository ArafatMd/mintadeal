package com.mintadeal.order;

/**
 * A payment link that is not an order's was paid: told to whoever created it (for example pop-up stall fees), from
 * Razorpay's webhook or the local test payment page.
 */
public record PaymentLinkPaidEvent(String reference, String paymentId) {
}
