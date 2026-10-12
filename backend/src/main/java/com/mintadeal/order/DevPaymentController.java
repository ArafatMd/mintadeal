package com.mintadeal.order;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.HtmlUtils;

import com.mintadeal.common.ApiException;

/** A pretend payment page for local development. Exists only when the fake gateway is switched on. */
@RestController
@ConditionalOnProperty(name = "mintadeal.orders.dev-fake-gateway", havingValue = "true")
class DevPaymentController {

    private final FakeGateway fake;
    private final PaymentService payments;
    private final CheckoutRepository checkouts;

    DevPaymentController(FakeGateway fake, PaymentService payments, CheckoutRepository checkouts) {
        this.fake = fake;
        this.payments = payments;
        this.checkouts = checkouts;
    }

    @GetMapping(value = "/dev/pay/{reference}", produces = MediaType.TEXT_HTML_VALUE)
    String page(@PathVariable String reference) {
        Checkout c = checkouts.findByPaymentReference(reference).orElseThrow(() -> ApiException.notFound("Payment"));
        String amount = HtmlUtils.htmlEscape(OrderCodes.rupees(c.getGrandTotalMinor()));
        String code = HtmlUtils.htmlEscape(c.getCode());
        String ref = HtmlUtils.htmlEscape(reference);
        return """
                <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
                <title>Test payment</title>
                <style>body{font-family:sans-serif;max-width:420px;margin:40px auto;padding:0 16px;color:#222}
                button{background:#B9530A;color:#fff;border:0;border-radius:8px;padding:14px 20px;font-size:16px;width:100%%}
                .note{background:#fff3cd;padding:10px;border-radius:8px;font-size:14px}</style></head>
                <body><p class="note">Test payment page (development only). No money moves.</p>
                <h2>Pay %s</h2><p>Mintadeal order %s</p>
                <form method="post" action="/dev/pay/%s"><button id="pay">Pay %s</button></form></body></html>
                """.formatted(amount, code, ref, amount);
    }

    @PostMapping(value = "/dev/pay/{reference}", produces = MediaType.TEXT_HTML_VALUE)
    String pay(@PathVariable String reference) {
        checkouts.findByPaymentReference(reference).orElseThrow(() -> ApiException.notFound("Payment"));
        payments.confirmPaidByReference(reference, fake.pay(reference));
        return "<!doctype html><html><body style=\"font-family:sans-serif;text-align:center;margin-top:60px\">"
                + "<h2>Payment successful</h2><p>Return to the Mintadeal app.</p></body></html>";
    }
}
