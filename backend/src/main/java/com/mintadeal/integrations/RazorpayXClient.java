package com.mintadeal.integrations;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import com.mintadeal.common.ApiException;
import com.mintadeal.settings.IntegrationProvider;
import com.mintadeal.settings.SettingsService;

import tools.jackson.databind.JsonNode;

/**
 * RazorpayX payouts: contact, fund account (UPI or bank), then payout from Mintadeal's RazorpayX account.
 * Every payout request carries an idempotency key, so a retried request never pays twice.
 */
@Component
public class RazorpayXClient {

    public record Destination(String upiId, String accountNumber, String ifsc, String accountName) {

        boolean isUpi() {
            return upiId != null && !upiId.isBlank();
        }
    }

    public record PayoutResult(String id, String status, String utr, String failureReason) {

        public boolean processed() {
            return "processed".equals(status);
        }

        public boolean failed() {
            return "failed".equals(status) || "reversed".equals(status) || "rejected".equals(status)
                    || "cancelled".equals(status);
        }
    }

    private final HttpJson http;
    private final SettingsService settings;
    private final IntegrationProperties props;

    public RazorpayXClient(HttpJson http, SettingsService settings, IntegrationProperties props) {
        this.http = http;
        this.settings = settings;
        this.props = props;
    }

    public boolean enabled() {
        return settings.resolve(IntegrationProvider.RAZORPAYX).enabled();
    }

    public PayoutResult pay(String idempotencyKey, String referenceId, String name, String phone,
                            Destination to, long amountMinor, String narration) {
        String contactId = post("/v1/contacts", Map.of("name", name, "contact", phone, "type", "vendor",
                "reference_id", referenceId), null).path("id").asString();
        Map<String, Object> fund = new LinkedHashMap<>();
        fund.put("contact_id", contactId);
        if (to.isUpi()) {
            fund.put("account_type", "vpa");
            fund.put("vpa", Map.of("address", to.upiId()));
        } else {
            fund.put("account_type", "bank_account");
            fund.put("bank_account", Map.of("name", to.accountName(), "ifsc", to.ifsc(), "account_number", to.accountNumber()));
        }
        String fundId = post("/v1/fund_accounts", fund, null).path("id").asString();
        Map<String, Object> payout = new LinkedHashMap<>();
        payout.put("account_number", accountNumber());
        payout.put("fund_account_id", fundId);
        payout.put("amount", amountMinor);
        payout.put("currency", "INR");
        payout.put("mode", to.isUpi() ? "UPI" : "IMPS");
        payout.put("purpose", "payout");
        payout.put("queue_if_low_balance", true);
        payout.put("reference_id", referenceId);
        payout.put("narration", narration.length() > 30 ? narration.substring(0, 30) : narration);
        return result(post("/v1/payouts", payout, idempotencyKey));
    }

    public PayoutResult fetch(String payoutId) {
        return result(call("GET", "/v1/payouts/" + payoutId, null, null));
    }

    private static PayoutResult result(JsonNode j) {
        return new PayoutResult(j.path("id").asString(), j.path("status").asString(""),
                j.path("utr").asString(null), j.path("status_details").path("description").asString(null));
    }

    private String accountNumber() {
        String n = settings.resolve(IntegrationProvider.RAZORPAYX).get("accountNumber");
        if (n == null) {
            throw ApiException.badRequest("setting_incomplete", "Add the RazorpayX account number first");
        }
        return n;
    }

    private JsonNode post(String path, Object body, String idempotencyKey) {
        return call("POST", path, body, idempotencyKey);
    }

    private JsonNode call(String method, String path, Object body, String idempotencyKey) {
        var cfg = settings.resolve(IntegrationProvider.RAZORPAY);
        String keyId = cfg.get("keyId");
        String keySecret = cfg.get("keySecret");
        if (keyId == null || keySecret == null) {
            throw ApiException.badRequest("setting_incomplete", "Add the Razorpay API keys first");
        }
        Map<String, String> headers = new LinkedHashMap<>();
        headers.put("Authorization", "Basic " + Base64.getEncoder()
                .encodeToString((keyId + ":" + keySecret).getBytes(StandardCharsets.UTF_8)));
        if (idempotencyKey != null) {
            headers.put("X-Payout-Idempotency", idempotencyKey);
        }
        String url = props.razorpayBaseUrl() + path;
        HttpJson.Response res = "GET".equals(method) ? http.get(url, headers) : http.post(url, headers, body);
        if (!res.ok()) {
            String reason = res.body().path("error").path("description").asString("HTTP " + res.status());
            throw new ApiException(HttpStatus.BAD_GATEWAY, "razorpayx_error", "RazorpayX: " + reason);
        }
        return res.body();
    }
}
