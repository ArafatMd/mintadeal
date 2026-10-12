package com.mintadeal.integrations;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import com.mintadeal.common.ApiException;
import com.mintadeal.settings.IntegrationProvider;
import com.mintadeal.settings.SettingsService;
import com.mintadeal.settings.SettingsService.Resolved;

/**
 * WhatsApp Cloud API. Business-initiated messages must use templates approved in Meta's WhatsApp Manager;
 * the template names and their {{1}}, {{2}}... body parameters are set in the admin website.
 */
@Component
public class WhatsAppClient {

    private final HttpJson http;
    private final SettingsService settings;
    private final IntegrationProperties props;

    public WhatsAppClient(HttpJson http, SettingsService settings, IntegrationProperties props) {
        this.http = http;
        this.settings = settings;
        this.props = props;
    }

    public Resolved config() {
        return settings.resolve(IntegrationProvider.WHATSAPP);
    }

    /** Sends a template message and returns WhatsApp's message id. */
    public String sendTemplate(Resolved cfg, String e164Phone, String template, List<String> params) {
        List<Map<String, String>> parameters = new ArrayList<>();
        params.forEach(p -> parameters.add(Map.of("type", "text", "text", p == null || p.isBlank() ? "-" : p)));
        String language = cfg.get("languageCode") == null ? "en" : cfg.get("languageCode");
        Map<String, Object> body = Map.of(
                "messaging_product", "whatsapp",
                "to", e164Phone.replace("+", ""),
                "type", "template",
                "template", Map.of(
                        "name", template,
                        "language", Map.of("code", language),
                        "components", List.of(Map.of("type", "body", "parameters", parameters))));
        HttpJson.Response res = http.post(props.whatsappBaseUrl() + "/" + cfg.get("phoneNumberId") + "/messages",
                auth(cfg), body);
        if (!res.ok()) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "whatsapp_error",
                    "WhatsApp: " + res.body().path("error").path("message").asString("HTTP " + res.status()));
        }
        return res.body().path("messages").path(0).path("id").asString(null);
    }

    /** Checks the token and phone number id; returns the business phone number. */
    public String check(Resolved cfg) {
        HttpJson.Response res = http.get(props.whatsappBaseUrl() + "/" + cfg.get("phoneNumberId")
                + "?fields=display_phone_number,verified_name", auth(cfg));
        if (!res.ok()) {
            throw ApiException.badRequest("whatsapp_rejected",
                    "WhatsApp: " + res.body().path("error").path("message").asString("HTTP " + res.status()));
        }
        return res.body().path("display_phone_number").asString("") + " "
                + res.body().path("verified_name").asString("");
    }

    private static Map<String, String> auth(Resolved cfg) {
        String token = cfg.get("accessToken");
        if (token == null || cfg.get("phoneNumberId") == null) {
            throw ApiException.badRequest("setting_incomplete", "Add the WhatsApp phone number ID and access token first");
        }
        return Map.of("Authorization", "Bearer " + token);
    }
}
