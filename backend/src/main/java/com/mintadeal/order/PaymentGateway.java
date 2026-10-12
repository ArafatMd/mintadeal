package com.mintadeal.order;

import java.time.Instant;

/** An online payment provider that collects one checkout's total through a hosted payment page. */
public interface PaymentGateway {

    record Link(String reference, String url) {
    }

    /** @param paymentId the provider's id of the captured payment, when paid */
    record Status(boolean paid, boolean closed, String paymentId) {
    }

    String name();

    Link create(Checkout checkout, Instant deadline);

    Status fetch(String reference);

    void cancel(String reference);

    /** Returns the provider's refund id. */
    String refund(String paymentId, long amountMinor, String receipt);
}
