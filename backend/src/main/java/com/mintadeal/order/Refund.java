package com.mintadeal.order;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/** Money owed back to the customer for a cancelled, prepaid shop order. */
@Entity
@Table(name = "refund")
public class Refund {

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID checkoutId;

    @Column(nullable = false)
    private UUID shopOrderId;

    private long amountMinor;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RefundStatus status = RefundStatus.PENDING;

    private String providerRefundId;

    private String error;

    @Column(nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    @Version
    private Long version;

    protected Refund() {
    }

    public Refund(UUID checkoutId, UUID shopOrderId, long amountMinor, Instant now) {
        this.id = UUID.randomUUID();
        this.checkoutId = checkoutId;
        this.shopOrderId = shopOrderId;
        this.amountMinor = amountMinor;
        this.createdAt = now;
        this.updatedAt = now;
    }

    void processed(String providerRefundId, Instant now) {
        this.status = RefundStatus.PROCESSED;
        this.providerRefundId = providerRefundId;
        this.error = null;
        this.updatedAt = now;
    }

    void failed(String error, Instant now) {
        this.status = RefundStatus.FAILED;
        this.error = error;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getCheckoutId() {
        return checkoutId;
    }

    public UUID getShopOrderId() {
        return shopOrderId;
    }

    public long getAmountMinor() {
        return amountMinor;
    }

    public RefundStatus getStatus() {
        return status;
    }

    public String getProviderRefundId() {
        return providerRefundId;
    }

    public String getError() {
        return error;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
