package com.mintadeal.popup;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/** Someone who sells from a pop-up stall. Any signed-in person becomes one by posting their first stall. */
@Entity
@Table(name = "popup_seller")
public class PopupSeller {

    @Id
    private UUID userId;

    @Column(nullable = false)
    private String name;

    private boolean blocked;

    private String blockedReason;

    @Column(nullable = false)
    private Instant createdAt;

    @Version
    private Long version;

    protected PopupSeller() {
    }

    PopupSeller(UUID userId, String name, Instant now) {
        this.userId = userId;
        this.name = name;
        this.createdAt = now;
    }

    public UUID getUserId() {
        return userId;
    }

    public String getName() {
        return name;
    }

    void setName(String name) {
        this.name = name;
    }

    public boolean isBlocked() {
        return blocked;
    }

    public String getBlockedReason() {
        return blockedReason;
    }

    void block(String reason) {
        blocked = true;
        blockedReason = reason;
    }

    void unblock() {
        blocked = false;
        blockedReason = null;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
