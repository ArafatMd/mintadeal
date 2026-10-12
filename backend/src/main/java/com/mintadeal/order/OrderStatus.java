package com.mintadeal.order;

/**
 * Shop order lifecycle. Pickup: PLACED, ACCEPTED, READY, COMPLETED. Delivery: PLACED, ACCEPTED,
 * OUT_FOR_DELIVERY, COMPLETED. Venue offer: ACCEPTED as soon as it is paid, COMPLETED when used.
 */
public enum OrderStatus {
    /** Waiting for the customer's online payment. */
    PENDING_PAYMENT,
    /** Waiting for the shop to accept, until the acceptance deadline. */
    PLACED,
    ACCEPTED,
    /** Ready for the customer to pick up. */
    READY,
    OUT_FOR_DELIVERY,
    COMPLETED,
    CANCELLED;

    public boolean isOpen() {
        return this != COMPLETED && this != CANCELLED;
    }
}
