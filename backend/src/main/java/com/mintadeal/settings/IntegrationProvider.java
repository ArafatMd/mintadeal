package com.mintadeal.settings;

import java.util.List;

/**
 * Third-party services an admin can configure from the admin website.
 *
 * @param configFields non-secret settings, returned to the admin as-is
 * @param secretFields secrets, stored encrypted and never returned
 * @param required fields that must be filled in before the integration can be enabled
 */
public enum IntegrationProvider {
    RAZORPAY(List.of("keyId"), List.of("keySecret", "webhookSecret"), List.of("keyId", "keySecret", "webhookSecret")),
    TWO_FACTOR(List.of("templateName"), List.of("apiKey"), List.of("apiKey")),
    /** Automatic payouts to shops. Uses the Razorpay API keys; needs a RazorpayX current account. */
    RAZORPAYX(List.of("accountNumber"), List.of(), List.of("accountNumber")),
    /** WhatsApp Cloud API (Meta) for order alerts, sent with approved message templates. */
    WHATSAPP(List.of("phoneNumberId", "languageCode", "newOrderTemplate", "orderUpdateTemplate"), List.of("accessToken"),
            List.of("phoneNumberId", "newOrderTemplate", "orderUpdateTemplate", "accessToken"));

    private final List<String> configFields;
    private final List<String> secretFields;
    private final List<String> required;

    IntegrationProvider(List<String> configFields, List<String> secretFields, List<String> required) {
        this.configFields = configFields;
        this.secretFields = secretFields;
        this.required = required;
    }

    public List<String> configFields() {
        return configFields;
    }

    public List<String> secretFields() {
        return secretFields;
    }

    public List<String> required() {
        return required;
    }
}
