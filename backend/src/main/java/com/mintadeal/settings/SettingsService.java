package com.mintadeal.settings;

import java.time.Clock;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.admin.AuditService;
import com.mintadeal.common.ApiException;
import com.mintadeal.common.CurrentUser;

import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

/** Reads and updates integration settings, keeping secrets encrypted in the database. */
@Service
public class SettingsService {

    private static final TypeReference<Map<String, String>> MAP = new TypeReference<>() {
    };

    /** The effective settings of one integration, secrets decrypted. Only for server-side use. */
    public record Resolved(boolean enabled, Map<String, String> config, Map<String, String> secrets) {

        public String get(String field) {
            String v = config.containsKey(field) ? config.get(field) : secrets.get(field);
            return v == null || v.isBlank() ? null : v;
        }

        static Resolved disabled() {
            return new Resolved(false, Map.of(), Map.of());
        }
    }

    public record SecretState(boolean set, String hint) {
    }

    /** What the admin website sees: config values, and for secrets only whether they are set. */
    public record SettingView(IntegrationProvider provider, boolean enabled, boolean complete,
                              Map<String, String> config, Map<String, SecretState> secrets, Instant updatedAt) {
    }

    /**
     * @param secrets new secret values; a missing or blank value keeps the stored secret
     */
    public record UpdateRequest(boolean enabled, Map<String, String> config, Map<String, String> secrets) {
    }

    private final IntegrationSettingRepository repo;
    private final SecretCipher cipher;
    private final ObjectMapper json;
    private final AuditService audit;
    private final Clock clock;

    public SettingsService(IntegrationSettingRepository repo, SecretCipher cipher, ObjectMapper json,
                           AuditService audit, Clock clock) {
        this.repo = repo;
        this.cipher = cipher;
        this.json = json;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public Resolved resolve(IntegrationProvider provider) {
        return repo.findById(provider)
                .map(s -> new Resolved(s.isEnabled(), config(s), secrets(s)))
                .orElse(Resolved.disabled());
    }

    @Transactional(readOnly = true)
    public SettingView view(IntegrationProvider provider) {
        IntegrationSetting s = repo.findById(provider).orElse(null);
        Map<String, String> config = s == null ? Map.of() : config(s);
        Map<String, String> secrets = s == null ? Map.of() : secrets(s);
        Map<String, String> configOut = new LinkedHashMap<>();
        provider.configFields().forEach(f -> configOut.put(f, config.getOrDefault(f, "")));
        Map<String, SecretState> secretsOut = new LinkedHashMap<>();
        provider.secretFields().forEach(f -> secretsOut.put(f, state(secrets.get(f))));
        return new SettingView(provider, s != null && s.isEnabled(), missing(provider, config, secrets) == null,
                configOut, secretsOut, s == null ? null : s.getUpdatedAt());
    }

    @Transactional
    public SettingView update(IntegrationProvider provider, UpdateRequest req) {
        IntegrationSetting s = repo.findById(provider)
                .orElseGet(() -> repo.save(new IntegrationSetting(provider, clock.instant())));
        Map<String, String> config = new LinkedHashMap<>();
        for (String f : provider.configFields()) {
            String v = req.config() == null ? null : req.config().get(f);
            config.put(f, v == null ? "" : v.trim());
        }
        Map<String, String> secrets = new LinkedHashMap<>(secrets(s));
        if (req.secrets() != null) {
            for (String f : provider.secretFields()) {
                String v = req.secrets().get(f);
                if (v != null && !v.isBlank()) {
                    secrets.put(f, v.trim());
                }
            }
        }
        String missing = missing(provider, config, secrets);
        if (req.enabled() && missing != null) {
            throw ApiException.badRequest("setting_incomplete", "Fill in " + missing + " before turning this on");
        }
        s.setEnabled(req.enabled());
        s.setConfigJson(json.writeValueAsString(config));
        s.setSecretCipher(secrets.isEmpty() ? null : cipher.encrypt(json.writeValueAsString(secrets)));
        s.touch(CurrentUser.id(), clock.instant());
        // Record which fields changed, never their values.
        audit.record("SETTINGS_UPDATED", "SETTINGS", UUID.nameUUIDFromBytes(provider.name().getBytes()),
                provider + (req.enabled() ? " enabled" : " disabled"));
        return view(provider);
    }

    private static String missing(IntegrationProvider provider, Map<String, String> config,
                                  Map<String, String> secrets) {
        for (String f : provider.required()) {
            String v = config.containsKey(f) ? config.get(f) : secrets.get(f);
            if (v == null || v.isBlank()) {
                return f;
            }
        }
        return null;
    }

    private static SecretState state(String secret) {
        if (secret == null || secret.isBlank()) {
            return new SecretState(false, null);
        }
        return new SecretState(true, "••••" + (secret.length() > 8 ? secret.substring(secret.length() - 4) : ""));
    }

    private Map<String, String> config(IntegrationSetting s) {
        return json.readValue(s.getConfigJson(), MAP);
    }

    private Map<String, String> secrets(IntegrationSetting s) {
        return s.getSecretCipher() == null ? Map.of() : json.readValue(cipher.decrypt(s.getSecretCipher()), MAP);
    }
}
