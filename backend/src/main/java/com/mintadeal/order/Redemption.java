package com.mintadeal.order;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/** The single-use code behind a venue offer's QR. One code covers every unit bought in the order. */
@Entity
@Table(name = "redemption")
public class Redemption {

    @Id
    private UUID id;

    @Column(nullable = false, unique = true)
    private UUID shopOrderId;

    @Column(nullable = false)
    private UUID vendorId;

    @Column(nullable = false, unique = true)
    private String token;

    private int quantity;

    private Instant validFrom;

    private Instant validTo;

    private Instant usedAt;

    private UUID usedBy;

    @Column(nullable = false)
    private Instant createdAt;

    @Version
    private Long version;

    protected Redemption() {
    }

    Redemption(UUID shopOrderId, UUID vendorId, String token, int quantity, Instant validFrom, Instant validTo,
               Instant now) {
        this.id = UUID.randomUUID();
        this.shopOrderId = shopOrderId;
        this.vendorId = vendorId;
        this.token = token;
        this.quantity = quantity;
        this.validFrom = validFrom;
        this.validTo = validTo;
        this.createdAt = now;
    }

    void markUsed(UUID by, Instant now) {
        this.usedAt = now;
        this.usedBy = by;
    }

    public boolean isUsed() {
        return usedAt != null;
    }

    public UUID getShopOrderId() {
        return shopOrderId;
    }

    public UUID getVendorId() {
        return vendorId;
    }

    public String getToken() {
        return token;
    }

    public int getQuantity() {
        return quantity;
    }

    public Instant getValidFrom() {
        return validFrom;
    }

    public Instant getValidTo() {
        return validTo;
    }

    public Instant getUsedAt() {
        return usedAt;
    }
}
