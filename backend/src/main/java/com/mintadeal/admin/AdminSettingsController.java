package com.mintadeal.admin;

import java.security.SecureRandom;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.identity.PhoneNumbers;
import com.mintadeal.integrations.RazorpayClient;
import com.mintadeal.integrations.TwoFactorClient;
import com.mintadeal.integrations.WhatsAppClient;
import com.mintadeal.settings.IntegrationProvider;
import com.mintadeal.settings.SettingsService;
import com.mintadeal.settings.SettingsService.SettingView;
import com.mintadeal.settings.SettingsService.UpdateRequest;

/** Razorpay and 2Factor configuration from the admin website. Secrets are write-only. */
@RestController
@RequestMapping("/api/admin/settings")
public class AdminSettingsController {

    private final SettingsService settings;
    private final RazorpayClient razorpay;
    private final TwoFactorClient twoFactor;
    private final WhatsAppClient whatsApp;
    private final String publicBaseUrl;
    private final SecureRandom random = new SecureRandom();

    public AdminSettingsController(SettingsService settings, RazorpayClient razorpay, TwoFactorClient twoFactor,
                                   WhatsAppClient whatsApp,
                                   @Value("${mintadeal.files.public-base-url}") String publicBaseUrl) {
        this.whatsApp = whatsApp;
        this.settings = settings;
        this.razorpay = razorpay;
        this.twoFactor = twoFactor;
        this.publicBaseUrl = publicBaseUrl;
    }

    /** @param info read-only facts to show next to the form, such as the webhook URL to register */
    public record SettingResponse(SettingView setting, Map<String, String> info) {
    }

    public record TestRequest(String phone) {
    }

    public record TestResult(boolean ok, String message) {
    }

    @GetMapping
    public List<SettingResponse> all() {
        return List.of(IntegrationProvider.values()).stream().map(this::response).toList();
    }

    @GetMapping("/{provider}")
    public SettingResponse one(@PathVariable IntegrationProvider provider) {
        return response(provider);
    }

    @PutMapping("/{provider}")
    public SettingResponse update(@PathVariable IntegrationProvider provider, @RequestBody UpdateRequest req) {
        settings.update(provider, req);
        return response(provider);
    }

    /** Tests the saved settings against the provider, without sending anything to customers. */
    @PostMapping("/{provider}/test")
    public TestResult test(@PathVariable IntegrationProvider provider, @RequestBody(required = false) TestRequest req) {
        var cfg = settings.resolve(provider);
        return switch (provider) {
            case RAZORPAY -> {
                razorpay.testConnection(cfg);
                yield new TestResult(true, "Connected to Razorpay in "
                        + (RazorpayClient.isLiveKey(cfg.get("keyId")) ? "LIVE" : "TEST") + " mode");
            }
            case TWO_FACTOR -> {
                String balance = twoFactor.balance(cfg);
                if (req != null && req.phone() != null && !req.phone().isBlank()) {
                    String phone = PhoneNumbers.normalize(req.phone());
                    twoFactor.sendOtp(cfg, phone, String.format("%06d", random.nextInt(1_000_000)));
                    yield new TestResult(true, "API key works (SMS balance " + balance + "). Test code sent to " + phone);
                }
                yield new TestResult(true, "API key works. SMS balance: " + balance);
            }
            case RAZORPAYX -> {
                razorpay.testConnection(settings.resolve(IntegrationProvider.RAZORPAY));
                yield new TestResult(true, "Razorpay keys work. Payouts use RazorpayX account " + cfg.get("accountNumber")
                        + "; make sure it is activated and funded.");
            }
            case WHATSAPP -> new TestResult(true, "Connected to WhatsApp number " + whatsApp.check(cfg).trim());
        };
    }

    private SettingResponse response(IntegrationProvider provider) {
        SettingView view = settings.view(provider);
        Map<String, String> info = new LinkedHashMap<>();
        if (provider == IntegrationProvider.RAZORPAY) {
            info.put("webhookUrl", publicBaseUrl + "/api/webhooks/razorpay");
            info.put("webhookEvents", "payment_link.paid, payment_link.expired, payment_link.cancelled");
            String keyId = view.config().get("keyId");
            info.put("mode", keyId == null || keyId.isBlank() ? "" : RazorpayClient.isLiveKey(keyId) ? "LIVE" : "TEST");
        } else if (provider == IntegrationProvider.TWO_FACTOR) {
            info.put("usage", "Sign-in codes for all apps are sent by SMS through 2Factor when this is on");
        } else if (provider == IntegrationProvider.RAZORPAYX) {
            info.put("usage", "Uses the Razorpay API keys above. Add the payout webhook events to the same webhook.");
            info.put("webhookEvents", "payout.processed, payout.failed, payout.reversed");
        } else {
            info.put("newOrderTemplate", "To the shop. Body parameters: {{1}} order number, {{2}} items, {{3}} total, "
                    + "{{4}} how it is fulfilled");
            info.put("orderUpdateTemplate", "To the customer. Body parameters: {{1}} order number, {{2}} shop name, "
                    + "{{3}} what happened");
        }
        return new SettingResponse(view, info);
    }
}
