package com.mintadeal.review;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/** A customer's rating of one completed order, with the shop's optional reply. */
@Entity
@Table(name = "vendor_review")
public class Review {

    @Id
    private UUID id;

    @Column(nullable = false, unique = true)
    private UUID shopOrderId;

    @Column(nullable = false)
    private UUID vendorId;

    @Column(nullable = false)
    private UUID customerId;

    private short rating;

    private String comment;

    private String reply;

    private Instant repliedAt;

    private boolean hidden;

    private String hiddenReason;

    @Column(nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    @Version
    private Long version;

    protected Review() {
    }

    Review(UUID shopOrderId, UUID vendorId, UUID customerId, Instant now) {
        this.id = UUID.randomUUID();
        this.shopOrderId = shopOrderId;
        this.vendorId = vendorId;
        this.customerId = customerId;
        this.createdAt = now;
    }

    void rate(int rating, String comment, Instant now) {
        this.rating = (short) rating;
        this.comment = comment;
        this.updatedAt = now;
    }

    void reply(String reply, Instant now) {
        this.reply = reply;
        this.repliedAt = reply == null ? null : now;
        this.updatedAt = now;
    }

    void hide(String reason, Instant now) {
        this.hidden = true;
        this.hiddenReason = reason;
        this.updatedAt = now;
    }

    void unhide(Instant now) {
        this.hidden = false;
        this.hiddenReason = null;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getShopOrderId() {
        return shopOrderId;
    }

    public UUID getVendorId() {
        return vendorId;
    }

    public UUID getCustomerId() {
        return customerId;
    }

    public int getRating() {
        return rating;
    }

    public String getComment() {
        return comment;
    }

    public String getReply() {
        return reply;
    }

    public Instant getRepliedAt() {
        return repliedAt;
    }

    public boolean isHidden() {
        return hidden;
    }

    public String getHiddenReason() {
        return hiddenReason;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
