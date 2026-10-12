package com.mintadeal.finance;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "payout_batch")
public class PayoutBatch {

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID createdBy;

    private int payoutCount;

    private long totalMinor;

    @Column(nullable = false)
    private Instant createdAt;

    protected PayoutBatch() {
    }

    PayoutBatch(UUID createdBy, Instant now) {
        this.id = UUID.randomUUID();
        this.createdBy = createdBy;
        this.createdAt = now;
    }

    void add(long amountMinor) {
        payoutCount++;
        totalMinor += amountMinor;
    }

    public UUID getId() {
        return id;
    }

    public int getPayoutCount() {
        return payoutCount;
    }

    public long getTotalMinor() {
        return totalMinor;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
