package com.mintadeal.support;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

import com.mintadeal.identity.Role;

/** A help request from a customer, shop or rider, answered by Mintadeal staff. */
@Entity
@Table(name = "support_ticket")
public class SupportTicket {

    public enum Topic { ORDER, PAYMENT_REFUND, DELIVERY, ACCOUNT, SHOP_LISTING, PAYOUT, OTHER }

    /** OPEN: waiting for staff. ANSWERED: staff replied, waiting for the person. CLOSED: done. */
    public enum Status { OPEN, ANSWERED, CLOSED }

    @Id
    private UUID id;

    @Column(nullable = false, unique = true)
    private String code;

    @Column(nullable = false)
    private UUID openedBy;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role openerRole;

    private UUID shopOrderId;

    private String orderCode;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Topic topic;

    @Column(nullable = false)
    private String subject;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Status status;

    @Column(nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant lastMessageAt;

    @Version
    private Long version;

    protected SupportTicket() {
    }

    SupportTicket(String code, UUID openedBy, Role openerRole, UUID shopOrderId, String orderCode, Topic topic,
                  String subject, Instant now) {
        this.id = UUID.randomUUID();
        this.code = code;
        this.openedBy = openedBy;
        this.openerRole = openerRole;
        this.shopOrderId = shopOrderId;
        this.orderCode = orderCode;
        this.topic = topic;
        this.subject = subject;
        this.status = Status.OPEN;
        this.createdAt = now;
        this.lastMessageAt = now;
    }

    void messaged(boolean byStaff, Instant now) {
        this.status = byStaff ? Status.ANSWERED : Status.OPEN;
        this.lastMessageAt = now;
    }

    void setStatus(Status status, Instant now) {
        this.status = status;
        this.lastMessageAt = now;
    }

    public UUID getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public UUID getOpenedBy() {
        return openedBy;
    }

    public Role getOpenerRole() {
        return openerRole;
    }

    public UUID getShopOrderId() {
        return shopOrderId;
    }

    public String getOrderCode() {
        return orderCode;
    }

    public Topic getTopic() {
        return topic;
    }

    public String getSubject() {
        return subject;
    }

    public Status getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getLastMessageAt() {
        return lastMessageAt;
    }
}
