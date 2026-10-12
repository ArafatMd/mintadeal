package com.mintadeal.finance;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "ledger_entry")
public class LedgerEntry {

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID journalId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Account account;

    private UUID vendorId;

    /** Debit positive, credit negative. */
    private long amountMinor;

    @Column(nullable = false)
    private Instant createdAt;

    protected LedgerEntry() {
    }

    LedgerEntry(UUID journalId, Account account, UUID vendorId, long amountMinor, Instant now) {
        this.id = UUID.randomUUID();
        this.journalId = journalId;
        this.account = account;
        this.vendorId = vendorId;
        this.amountMinor = amountMinor;
        this.createdAt = now;
    }

    public UUID getJournalId() {
        return journalId;
    }

    public Account getAccount() {
        return account;
    }

    public UUID getVendorId() {
        return vendorId;
    }

    public long getAmountMinor() {
        return amountMinor;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
