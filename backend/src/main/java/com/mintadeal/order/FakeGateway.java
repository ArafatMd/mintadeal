package com.mintadeal.order;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Local development stand-in for Razorpay, active only when {@code mintadeal.orders.dev-fake-gateway=true}
 * and Razorpay is not enabled. Its payment page is served by {@link DevPaymentController}.
 */
@Component
class FakeGateway implements PaymentGateway {

    static final String NAME = "FAKE";

    private final Map<String, String> paid = new ConcurrentHashMap<>();
    private final String publicBaseUrl;

    FakeGateway(@Value("${mintadeal.files.public-base-url}") String publicBaseUrl) {
        this.publicBaseUrl = publicBaseUrl;
    }

    @Override
    public String name() {
        return NAME;
    }

    @Override
    public Link create(Checkout checkout, Instant deadline) {
        String ref = "fake_" + UUID.randomUUID().toString().replace("-", "");
        return new Link(ref, publicBaseUrl + "/dev/pay/" + ref);
    }

    String pay(String reference) {
        return paid.computeIfAbsent(reference, r -> "fakepay_" + UUID.randomUUID().toString().substring(0, 12));
    }

    @Override
    public Status fetch(String reference) {
        String paymentId = paid.get(reference);
        return new Status(paymentId != null, false, paymentId);
    }

    @Override
    public void cancel(String reference) {
        paid.remove(reference);
    }

    @Override
    public String refund(String paymentId, long amountMinor, String receipt) {
        return "fakerfnd_" + UUID.randomUUID().toString().substring(0, 12);
    }
}
