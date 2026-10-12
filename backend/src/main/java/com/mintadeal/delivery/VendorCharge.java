package com.mintadeal.delivery;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/** Money a shop owes Mintadeal, such as a delivery partner's fee. Recovered from payouts in Stage 5. */
@Entity
@Table(name = "vendor_charge")
public class VendorCharge {

    public static final String OUTSTANDING = "OUTSTANDING";

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID vendorId;

    @Column(nullable = false)
    private UUID shopOrderId;

    private UUID deliveryJobId;

    @Column(nullable = false)
    private String chargeType;

    private long amountMinor;

    @Column(nullable = false)
    private String description;

    @Column(nullable = false)
    private String status = OUTSTANDING;

    @Column(nullable = false)
    private Instant createdAt;

    @Version
    private Long version;

    protected VendorCharge() {
    }

    VendorCharge(UUID vendorId, UUID shopOrderId, UUID deliveryJobId, long amountMinor, String description,
                 Instant now) {
        this.id = UUID.randomUUID();
        this.vendorId = vendorId;
        this.shopOrderId = shopOrderId;
        this.deliveryJobId = deliveryJobId;
        this.chargeType = "PARTNER_DELIVERY";
        this.amountMinor = amountMinor;
        this.description = description;
        this.createdAt = now;
    }

    /** The charge has been deducted from a payout. */
    public void recover() {
        if (OUTSTANDING.equals(status)) {
            status = "RECOVERED";
        }
    }

    public UUID getId() {
        return id;
    }

    public UUID getVendorId() {
        return vendorId;
    }

    public UUID getShopOrderId() {
        return shopOrderId;
    }

    public String getChargeType() {
        return chargeType;
    }

    public long getAmountMinor() {
        return amountMinor;
    }

    public String getDescription() {
        return description;
    }

    public String getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
