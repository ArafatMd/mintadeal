package com.mintadeal.settings;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

@Entity
@Table(name = "integration_setting")
public class IntegrationSetting {

    @Id
    @Enumerated(EnumType.STRING)
    private IntegrationProvider provider;

    private boolean enabled;

    @Column(nullable = false)
    private String configJson = "{}";

    /** AES-GCM encrypted JSON map of secret fields. */
    private String secretCipher;

    private UUID updatedBy;

    @Column(nullable = false)
    private Instant updatedAt;

    @Version
    private Long version;

    protected IntegrationSetting() {
    }

    public IntegrationSetting(IntegrationProvider provider, Instant now) {
        this.provider = provider;
        this.updatedAt = now;
    }

    public IntegrationProvider getProvider() {
        return provider;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public String getConfigJson() {
        return configJson;
    }

    public void setConfigJson(String configJson) {
        this.configJson = configJson;
    }

    public String getSecretCipher() {
        return secretCipher;
    }

    public void setSecretCipher(String secretCipher) {
        this.secretCipher = secretCipher;
    }

    public UUID getUpdatedBy() {
        return updatedBy;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void touch(UUID by, Instant now) {
        this.updatedBy = by;
        this.updatedAt = now;
    }
}
