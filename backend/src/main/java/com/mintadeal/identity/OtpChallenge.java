package com.mintadeal.identity;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "otp_challenge")
public class OtpChallenge {

    @Id
    private UUID id;

    @Column(nullable = false)
    private String phone;

    @Column(nullable = false)
    private String codeHash;

    @Column(nullable = false)
    private Instant expiresAt;

    private int attempts;

    private boolean consumed;

    @Column(nullable = false)
    private Instant createdAt;

    protected OtpChallenge() {
    }

    public OtpChallenge(String phone, String codeHash, Instant now, Instant expiresAt) {
        this.id = UUID.randomUUID();
        this.phone = phone;
        this.codeHash = codeHash;
        this.createdAt = now;
        this.expiresAt = expiresAt;
    }

    public String getCodeHash() {
        return codeHash;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public int getAttempts() {
        return attempts;
    }

    public boolean isConsumed() {
        return consumed;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void recordAttempt() {
        attempts++;
    }

    public void consume() {
        consumed = true;
    }
}
