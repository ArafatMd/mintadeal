package com.mintadeal.finance;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** One money movement, e.g. "order MD-ABC-1 completed". Its entries always balance. */
@Entity
@Table(name = "ledger_journal")
public class LedgerJournal {

    @Id
    private UUID id;

    @Column(nullable = false)
    private String journalType;

    @Column(nullable = false)
    private UUID referenceId;

    @Column(nullable = false)
    private String description;

    @Column(nullable = false)
    private Instant createdAt;

    protected LedgerJournal() {
    }

    LedgerJournal(String type, UUID referenceId, String description, Instant now) {
        this.id = UUID.randomUUID();
        this.journalType = type;
        this.referenceId = referenceId;
        this.description = description;
        this.createdAt = now;
    }

    public UUID getId() {
        return id;
    }

    public String getJournalType() {
        return journalType;
    }

    public UUID getReferenceId() {
        return referenceId;
    }

    public String getDescription() {
        return description;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
