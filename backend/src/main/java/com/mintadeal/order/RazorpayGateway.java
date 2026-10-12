package com.mintadeal.order;

import java.time.Instant;
import java.util.Map;

import org.springframework.stereotype.Component;

import com.mintadeal.integrations.RazorpayClient;

@Component
class RazorpayGateway implements PaymentGateway {

    static final String NAME = "RAZORPAY";

    private final RazorpayClient razorpay;

    RazorpayGateway(RazorpayClient razorpay) {
        this.razorpay = razorpay;
    }

    @Override
    public String name() {
        return NAME;
    }

    @Override
    public Link create(Checkout c, Instant deadline) {
        RazorpayClient.PaymentLink link = razorpay.createPaymentLink(c.getGrandTotalMinor(), c.getCode(),
                "Mintadeal order " + c.getCode(), c.getContactName(), c.getContactPhone(),
                deadline.getEpochSecond(), Map.of("checkout_id", c.getId().toString()));
        return new Link(link.id(), link.shortUrl());
    }

    @Override
    public Status fetch(String reference) {
        RazorpayClient.LinkStatus s = razorpay.fetchPaymentLink(reference);
        return new Status(s.paid(), s.closed(), s.paymentId());
    }

    @Override
    public void cancel(String reference) {
        razorpay.cancelPaymentLink(reference);
    }

    @Override
    public String refund(String paymentId, long amountMinor, String receipt) {
        return razorpay.refund(paymentId, amountMinor, receipt).id();
    }
}
