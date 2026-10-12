package com.mintadeal.integrations;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import com.mintadeal.common.ApiException;
import com.mintadeal.settings.IntegrationProvider;
import com.mintadeal.settings.SettingsService;
import com.mintadeal.settings.SettingsService.Resolved;

/**
 * 2Factor.in SMS OTP. Mintadeal generates and verifies the code itself; 2Factor only delivers it, using the
 * DLT-approved OTP template named in the admin settings (or the account default when left empty).
 */
@Component
public class TwoFactorClient {

    private final HttpJson http;
    private final SettingsService settings;
    private final IntegrationProperties props;

    public TwoFactorClient(HttpJson http, SettingsService settings, IntegrationProperties props) {
        this.http = http;
        this.settings = settings;
        this.props = props;
    }

    public boolean enabled() {
        return settings.resolve(IntegrationProvider.TWO_FACTOR).enabled();
    }

    public void sendOtp(String e164Phone, String code) {
        sendOtp(settings.resolve(IntegrationProvider.TWO_FACTOR), e164Phone, code);
    }

    public void sendOtp(Resolved cfg, String e164Phone, String code) {
        String phone = e164Phone.replace("+", "");
        String template = cfg.get("templateName");
        String url = base(cfg) + "/SMS/" + enc(phone) + "/" + enc(code) + (template == null ? "" : "/" + enc(template));
        HttpJson.Response res = http.get(url, Map.of());
        if (!res.ok() || !"Success".equalsIgnoreCase(res.body().path("Status").asString(""))) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "sms_failed",
                    "Could not send the code by SMS: " + res.body().path("Details").asString("unknown error"));
        }
    }

    /** Checks the API key by reading the SMS balance; no message is sent. */
    public String balance(Resolved cfg) {
        HttpJson.Response res = http.get(base(cfg) + "/BAL/SMS", Map.of());
        if (!res.ok() || !"Success".equalsIgnoreCase(res.body().path("Status").asString(""))) {
            throw ApiException.badRequest("two_factor_rejected",
                    "2Factor rejected the API key: " + res.body().path("Details").asString("HTTP " + res.status()));
        }
        return res.body().path("Details").asString("");
    }

    private String base(Resolved cfg) {
        String key = cfg.get("apiKey");
        if (key == null) {
            throw ApiException.badRequest("setting_incomplete", "Add the 2Factor API key first");
        }
        return props.twoFactorBaseUrl() + "/API/V1/" + enc(key);
    }

    private static String enc(String s) {
        return URLEncoder.encode(s, StandardCharsets.UTF_8).replace("+", "%20");
    }
}
