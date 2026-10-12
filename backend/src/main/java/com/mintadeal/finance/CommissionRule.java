package com.mintadeal.finance;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

import com.mintadeal.vendor.VendorCategory;

/** Commission in basis points (100 = 1%). The rule without a category is the default. */
@Entity
@Table(name = "commission_rule")
public class CommissionRule {

    @Id
    private UUID id;

    @Enumerated(EnumType.STRING)
    private VendorCategory category;

    private int rateBps;

    private UUID updatedBy;

    @Column(nullable = false)
    private Instant updatedAt;

    @Version
    private Long version;

    protected CommissionRule() {
    }

    CommissionRule(VendorCategory category, int rateBps, UUID by, Instant now) {
        this.id = UUID.randomUUID();
        this.category = category;
        this.rateBps = rateBps;
        this.updatedBy = by;
        this.updatedAt = now;
    }

    void update(int rateBps, UUID by, Instant now) {
        this.rateBps = rateBps;
        this.updatedBy = by;
        this.updatedAt = now;
    }

    public VendorCategory getCategory() {
        return category;
    }

    public int getRateBps() {
        return rateBps;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
