package com.mintadeal.notify;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** A record of one message we tried to send, for support and auditing. */
@Entity
@Table(name = "notification")
public class Notification {

    @Id
    private UUID id;

    @Column(nullable = false)
    private String event;

    @Column(nullable = false)
    private String channel;

    @Column(nullable = false)
    private String recipient;

    private UUID orderId;

    @Column(nullable = false)
    private String status;

    private String providerId;

    private String error;

    @Column(nullable = false)
    private Instant createdAt;

    protected Notification() {
    }

    Notification(String event, String channel, String recipient, UUID orderId, String status, String providerId,
                 String error, Instant now) {
        this.id = UUID.randomUUID();
        this.event = event;
        this.channel = channel;
        this.recipient = recipient;
        this.orderId = orderId;
        this.status = status;
        this.providerId = providerId;
        this.error = error == null || error.length() <= 500 ? error : error.substring(0, 500);
        this.createdAt = now;
    }

    public UUID getId() {
        return id;
    }

    public String getEvent() {
        return event;
    }

    public String getChannel() {
        return channel;
    }

    /** Masked phone number: +9198******45. */
    public String getRecipient() {
        return recipient.length() > 7
                ? recipient.substring(0, 5) + "*".repeat(recipient.length() - 7) + recipient.substring(recipient.length() - 2)
                : recipient;
    }

    public UUID getOrderId() {
        return orderId;
    }

    public String getStatus() {
        return status;
    }

    public String getError() {
        return error;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
