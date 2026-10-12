package com.mintadeal.customer;

import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "vendor_follow")
public class VendorFollow {

    @Embeddable
    public record Key(@Column(name = "customer_id") UUID customerId,
                      @Column(name = "vendor_id") UUID vendorId) implements Serializable {
    }

    @EmbeddedId
    private Key id;

    @Column(nullable = false)
    private Instant createdAt;

    protected VendorFollow() {
    }

    public VendorFollow(UUID customerId, UUID vendorId, Instant now) {
        this.id = new Key(customerId, vendorId);
        this.createdAt = now;
    }

    public Key getId() {
        return id;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
