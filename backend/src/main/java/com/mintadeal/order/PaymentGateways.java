package com.mintadeal.order;

import java.util.Optional;

import org.springframework.stereotype.Component;

import com.mintadeal.common.ApiException;
import com.mintadeal.integrations.RazorpayClient;

/** Picks the gateway for new payments, and finds the one an existing checkout was paid with. */
@Component
public class PaymentGateways {

    private final RazorpayGateway razorpayGateway;
    private final FakeGateway fakeGateway;
    private final RazorpayClient razorpay;
    private final OrderProperties props;

    PaymentGateways(RazorpayGateway razorpayGateway, FakeGateway fakeGateway, RazorpayClient razorpay,
                    OrderProperties props) {
        this.razorpayGateway = razorpayGateway;
        this.fakeGateway = fakeGateway;
        this.razorpay = razorpay;
        this.props = props;
    }

    public Optional<PaymentGateway> active() {
        if (razorpay.enabled()) {
            return Optional.of(razorpayGateway);
        }
        return props.devFakeGateway() ? Optional.of(fakeGateway) : Optional.empty();
    }

    public PaymentGateway named(String name) {
        return switch (name) {
            case RazorpayGateway.NAME -> razorpayGateway;
            case FakeGateway.NAME -> fakeGateway;
            default -> throw new IllegalStateException("Unknown payment provider " + name);
        };
    }

    PaymentGateway require() {
        return active().orElseThrow(() -> ApiException.badRequest("online_payment_unavailable",
                "Online payment is not available yet. Choose pay on delivery or pickup."));
    }
}
