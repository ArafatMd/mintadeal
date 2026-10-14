package com.mintadeal.support;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "support_message")
public class SupportMessage {

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID ticketId;

    @Column(nullable = false)
    private UUID authorId;

    /** Written by Mintadeal staff rather than the person who opened the ticket. */
    private boolean staff;

    @Column(nullable = false)
    private String body;

    @Column(nullable = false)
    private Instant createdAt;

    protected SupportMessage() {
    }

    SupportMessage(UUID ticketId, UUID authorId, boolean staff, String body, Instant now) {
        this.id = UUID.randomUUID();
        this.ticketId = ticketId;
        this.authorId = authorId;
        this.staff = staff;
        this.body = body;
        this.createdAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getAuthorId() {
        return authorId;
    }

    public boolean isStaff() {
        return staff;
    }

    public String getBody() {
        return body;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
