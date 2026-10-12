package com.mintadeal.order;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.finance.PayoutService;
import com.mintadeal.integrations.RazorpayClient;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * Razorpay calls this when a payment link is paid or closes. The signature is checked against the raw body
 * before anything is trusted. Register it in the Razorpay dashboard with the webhook secret from the admin settings.
 */
@RestController
public class RazorpayWebhookController {

    private static final Logger log = LoggerFactory.getLogger(RazorpayWebhookController.class);

    private final RazorpayClient razorpay;
    private final PaymentService payments;
    private final CheckoutRepository checkouts;
    private final ObjectMapper json;
    private final PayoutService payouts;

    public RazorpayWebhookController(RazorpayClient razorpay, PaymentService payments, CheckoutRepository checkouts,
                                     ObjectMapper json, PayoutService payouts) {
        this.payouts = payouts;
        this.razorpay = razorpay;
        this.payments = payments;
        this.checkouts = checkouts;
        this.json = json;
    }

    @PostMapping("/api/webhooks/razorpay")
    public ResponseEntity<Void> handle(@RequestBody String body,
                                       @RequestHeader(value = "X-Razorpay-Signature", required = false) String sig) {
        if (!razorpay.verifyWebhook(body, sig)) {
            log.warn("Rejected Razorpay webhook with a bad or missing signature");
            return ResponseEntity.status(401).build();
        }
        JsonNode event = json.readTree(body);
        String type = event.path("event").asString("");
        if (type.startsWith("payout.")) {
            String payoutId = event.path("payload").path("payout").path("entity").path("id").asString(null);
            if (payoutId != null) {
                payouts.onProviderUpdate(payoutId);
            }
            return ResponseEntity.ok().build();
        }
        String linkId = event.path("payload").path("payment_link").path("entity").path("id").asString(null);
        if (linkId == null) {
            return ResponseEntity.ok().build();
        }
        switch (type) {
            case "payment_link.paid" -> payments.confirmPaidByReference(linkId,
                    event.path("payload").path("payment").path("entity").path("id").asString(null));
            case "payment_link.expired", "payment_link.cancelled" ->
                    checkouts.findByPaymentReference(linkId).ifPresent(c -> payments.refresh(c.getId()));
            default -> log.debug("Ignoring Razorpay event {}", type);
        }
        return ResponseEntity.ok().build();
    }
}
