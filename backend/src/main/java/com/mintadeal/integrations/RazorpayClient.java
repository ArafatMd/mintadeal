package com.mintadeal.integrations;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import com.mintadeal.common.ApiException;
import com.mintadeal.settings.IntegrationProvider;
import com.mintadeal.settings.SettingsService;
import com.mintadeal.settings.SettingsService.Resolved;

import tools.jackson.databind.JsonNode;

/**
 * Razorpay Payment Links: one hosted payment page per checkout, which works the same from the mobile apps and
 * the web. Payment is confirmed only by Razorpay itself (signed webhook or a server-side status fetch),
 * never by the customer's browser coming back.
 */
@Component
public class RazorpayClient {

    public record PaymentLink(String id, String shortUrl, String status) {
    }

    /** @param paymentId the captured payment, when paid */
    public record LinkStatus(String status, String paymentId) {

        public boolean paid() {
            return "paid".equals(status);
        }

        public boolean closed() {
            return "expired".equals(status) || "cancelled".equals(status);
        }
    }

    public record RefundResult(String id, String status) {
    }

    private final HttpJson http;
    private final SettingsService settings;
    private final IntegrationProperties props;

    public RazorpayClient(HttpJson http, SettingsService settings, IntegrationProperties props) {
        this.http = http;
        this.settings = settings;
        this.props = props;
    }

    public boolean enabled() {
        return settings.resolve(IntegrationProvider.RAZORPAY).enabled();
    }

    public PaymentLink createPaymentLink(long amountMinor, String referenceId, String description,
                                         String customerName, String customerPhone, long expireByEpochSeconds,
                                         Map<String, String> notes) {
        Map<String, Object> customer = new LinkedHashMap<>();
        if (customerName != null) {
            customer.put("name", customerName);
        }
        customer.put("contact", customerPhone);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("amount", amountMinor);
        body.put("currency", "INR");
        body.put("accept_partial", false);
        body.put("reference_id", referenceId);
        body.put("description", description);
        body.put("customer", customer);
        body.put("notify", Map.of("sms", false, "email", false));
        body.put("reminder_enable", false);
        body.put("expire_by", expireByEpochSeconds);
        body.put("notes", notes);
        JsonNode res = call("POST", "/v1/payment_links", body, settings.resolve(IntegrationProvider.RAZORPAY));
        return new PaymentLink(res.path("id").asString(), res.path("short_url").asString(), res.path("status").asString());
    }

    public LinkStatus fetchPaymentLink(String linkId) {
        JsonNode res = call("GET", "/v1/payment_links/" + linkId, null, settings.resolve(IntegrationProvider.RAZORPAY));
        String paymentId = null;
        for (JsonNode p : res.path("payments")) {
            if ("captured".equals(p.path("status").asString(""))) {
                paymentId = p.path("payment_id").asString(null);
            }
        }
        return new LinkStatus(res.path("status").asString(""), paymentId);
    }

    public void cancelPaymentLink(String linkId) {
        call("POST", "/v1/payment_links/" + linkId + "/cancel", Map.of(), settings.resolve(IntegrationProvider.RAZORPAY));
    }

    public RefundResult refund(String paymentId, long amountMinor, String receipt) {
        JsonNode res = call("POST", "/v1/payments/" + paymentId + "/refund",
                Map.of("amount", amountMinor, "receipt", receipt), settings.resolve(IntegrationProvider.RAZORPAY));
        return new RefundResult(res.path("id").asString(), res.path("status").asString());
    }

    /** Checks the keys by listing one payment link. */
    public void testConnection(Resolved cfg) {
        call("GET", "/v1/payment_links?count=1", null, cfg);
    }

    /** Verifies the X-Razorpay-Signature header of a webhook body. */
    public boolean verifyWebhook(String body, String signature) {
        String secret = settings.resolve(IntegrationProvider.RAZORPAY).get("webhookSecret");
        if (secret == null || signature == null) {
            return false;
        }
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            String expected = HexFormat.of().formatHex(mac.doFinal(body.getBytes(StandardCharsets.UTF_8)));
            return MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8),
                    signature.trim().getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    public static boolean isLiveKey(String keyId) {
        return keyId != null && keyId.startsWith("rzp_live_");
    }

    private JsonNode call(String method, String path, Object body, Resolved cfg) {
        String keyId = cfg.get("keyId");
        String keySecret = cfg.get("keySecret");
        if (keyId == null || keySecret == null) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "payments_unavailable",
                    "Online payment is not set up yet");
        }
        Map<String, String> auth = Map.of("Authorization", "Basic " + Base64.getEncoder()
                .encodeToString((keyId + ":" + keySecret).getBytes(StandardCharsets.UTF_8)));
        String url = props.razorpayBaseUrl() + path;
        HttpJson.Response res = "GET".equals(method) ? http.get(url, auth) : http.post(url, auth, body);
        if (res.status() == 401) {
            throw ApiException.badRequest("razorpay_auth", "Razorpay rejected the key ID or key secret");
        }
        if (!res.ok()) {
            String reason = res.body().path("error").path("description").asString("HTTP " + res.status());
            throw new ApiException(HttpStatus.BAD_GATEWAY, "razorpay_error", "Razorpay: " + reason);
        }
        return res.body();
    }
}
