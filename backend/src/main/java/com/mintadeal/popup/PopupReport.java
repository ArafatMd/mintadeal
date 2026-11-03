package com.mintadeal.popup;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** A customer telling Mintadeal something is wrong with a stall. One per customer per stall. */
@Entity
@Table(name = "popup_report")
public class PopupReport {

    public enum Reason { NOT_THERE, FAKE_OR_MISLEADING, NOT_ALLOWED, RUDE_OR_UNSAFE, OTHER }

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID popupId;

    @Column(nullable = false)
    private UUID reporterId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Reason reason;

    private String note;

    @Column(nullable = false)
    private Instant createdAt;

    protected PopupReport() {
    }

    PopupReport(UUID popupId, UUID reporterId, Reason reason, String note, Instant now) {
        this.id = UUID.randomUUID();
        this.popupId = popupId;
        this.reporterId = reporterId;
        this.reason = reason;
        this.note = note;
        this.createdAt = now;
    }

    public UUID getPopupId() {
        return popupId;
    }

    public Reason getReason() {
        return reason;
    }

    public String getNote() {
        return note;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
