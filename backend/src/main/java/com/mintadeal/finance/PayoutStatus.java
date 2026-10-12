package com.mintadeal.finance;

/** PENDING: created, not yet sent. PROCESSING: sent to RazorpayX. PAID, FAILED, CANCELLED are final. */
public enum PayoutStatus {
    PENDING,
    PROCESSING,
    PAID,
    FAILED,
    CANCELLED
}
