package com.mintadeal.identity;

import org.springframework.stereotype.Component;

import com.mintadeal.integrations.WhatsAppClient;
import com.mintadeal.settings.SettingsService.Resolved;

/** Sign-in codes on WhatsApp, offered when an admin has switched WhatsApp on and set a login code template. */
@Component
public class WhatsAppCodes {

    private final WhatsAppClient whatsApp;

    public WhatsAppCodes(WhatsAppClient whatsApp) {
        this.whatsApp = whatsApp;
    }

    public boolean available() {
        Resolved cfg = whatsApp.config();
        String template = cfg.get("loginCodeTemplate");
        return cfg.enabled() && template != null && !template.isBlank();
    }

    public void send(String phone, String code) {
        Resolved cfg = whatsApp.config();
        whatsApp.sendAuthCode(cfg, phone, cfg.get("loginCodeTemplate").strip(), code);
    }
}
