package com.mintadeal.order;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** Append-only status history of a shop order. */
@Entity
@Table(name = "order_event")
public class OrderEvent {

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID shopOrderId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OrderStatus status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ActorType actorType;

    private UUID actorId;

    private String note;

    @Column(nullable = false)
    private Instant createdAt;

    protected OrderEvent() {
    }

    public OrderEvent(UUID shopOrderId, OrderStatus status, ActorType actorType, UUID actorId, String note,
                      Instant now) {
        this.id = UUID.randomUUID();
        this.shopOrderId = shopOrderId;
        this.status = status;
        this.actorType = actorType;
        this.actorId = actorId;
        this.note = note;
        this.createdAt = now;
    }

    public UUID getShopOrderId() {
        return shopOrderId;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public ActorType getActorType() {
        return actorType;
    }

    public String getNote() {
        return note;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
