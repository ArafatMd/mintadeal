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

@Entity
@Table(name = "payout")
public class Payout {

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID batchId;

    @Column(nullable = false)
    private UUID vendorId;

    @Column(nullable = false)
    private String vendorName;

    private long amountMinor;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PayoutStatus status = PayoutStatus.PENDING;

    /** RAZORPAYX or MANUAL, set when the payout is sent or recorded. */
    private String method;

    /** Where the money goes, masked: "UPI shop@okbank" or "Bank ••••1234". */
    @Column(nullable = false)
    private String destination;

    private String providerPayoutId;

    private String utr;

    private String failureReason;

    @Column(nullable = false)
    private Instant createdAt;

    private Instant sentAt;

    private Instant paidAt;

    @Version
    private Long version;

    protected Payout() {
    }

    Payout(UUID batchId, UUID vendorId, String vendorName, long amountMinor, String destination, Instant now) {
        this.id = UUID.randomUUID();
        this.batchId = batchId;
        this.vendorId = vendorId;
        this.vendorName = vendorName;
        this.amountMinor = amountMinor;
        this.destination = destination;
        this.createdAt = now;
    }

    void sent(String providerPayoutId, Instant now) {
        this.method = "RAZORPAYX";
        this.providerPayoutId = providerPayoutId;
        this.status = PayoutStatus.PROCESSING;
        this.sentAt = now;
    }

    void paid(String method, String utr, Instant now) {
        if (this.method == null) {
            this.method = method;
        }
        this.utr = utr;
        this.status = PayoutStatus.PAID;
        this.paidAt = now;
    }

    void failed(PayoutStatus status, String reason) {
        this.status = status;
        this.failureReason = reason;
    }

    public UUID getId() {
        return id;
    }

    public UUID getBatchId() {
        return batchId;
    }

    public UUID getVendorId() {
        return vendorId;
    }

    public String getVendorName() {
        return vendorName;
    }

    public long getAmountMinor() {
        return amountMinor;
    }

    public PayoutStatus getStatus() {
        return status;
    }

    public String getMethod() {
        return method;
    }

    public String getDestination() {
        return destination;
    }

    public String getProviderPayoutId() {
        return providerPayoutId;
    }

    public String getUtr() {
        return utr;
    }

    public String getFailureReason() {
        return failureReason;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getSentAt() {
        return sentAt;
    }

    public Instant getPaidAt() {
        return paidAt;
    }
}
