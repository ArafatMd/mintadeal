package com.mintadeal.popup;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OrderColumn;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * A pop-up stall at one place for a few days. Customers see it only while it is live; afterwards it stays as
 * history for admins.
 */
@Entity
@Table(name = "popup")
public class Popup {

    /** LIVE: customers can see it. ENDED: its days ran out or the seller stopped it. REMOVED: taken down. */
    public enum Status { LIVE, ENDED, REMOVED }

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID sellerId;

    @Column(nullable = false)
    private String sellerName;

    private double latitude;

    private double longitude;

    private int days;

    @Column(nullable = false)
    private Instant startsAt;

    @Column(nullable = false)
    private Instant endsAt;

    private Instant stoppedAt;

    private Instant removedAt;

    private String removedReason;

    private Instant movedAt;

    @Column(nullable = false)
    private Instant createdAt;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "popup_item", joinColumns = @JoinColumn(name = "popup_id"))
    @OrderColumn(name = "position")
    private List<PopupItem> items = new ArrayList<>();

    @Version
    private Long version;

    protected Popup() {
    }

    Popup(UUID sellerId, String sellerName, double latitude, double longitude, int days, List<PopupItem> items,
          Instant now) {
        this.id = UUID.randomUUID();
        this.sellerId = sellerId;
        this.sellerName = sellerName;
        this.latitude = latitude;
        this.longitude = longitude;
        this.days = days;
        this.startsAt = now;
        this.endsAt = now.plus(java.time.Duration.ofDays(days));
        this.createdAt = now;
        this.items.addAll(items);
    }

    public Status status(Instant now) {
        if (removedAt != null) {
            return Status.REMOVED;
        }
        return stoppedAt == null && endsAt.isAfter(now) ? Status.LIVE : Status.ENDED;
    }

    void moveTo(double lat, double lng, Instant now) {
        latitude = lat;
        longitude = lng;
        movedAt = now;
    }

    void stop(Instant now) {
        stoppedAt = now;
    }

    void remove(String reason, Instant now) {
        removedAt = now;
        removedReason = reason;
    }

    void restore() {
        removedAt = null;
        removedReason = null;
    }

    public UUID getId() {
        return id;
    }

    public UUID getSellerId() {
        return sellerId;
    }

    public String getSellerName() {
        return sellerName;
    }

    public double getLatitude() {
        return latitude;
    }

    public double getLongitude() {
        return longitude;
    }

    public int getDays() {
        return days;
    }

    public Instant getStartsAt() {
        return startsAt;
    }

    public Instant getEndsAt() {
        return endsAt;
    }

    public Instant getStoppedAt() {
        return stoppedAt;
    }

    public Instant getRemovedAt() {
        return removedAt;
    }

    public String getRemovedReason() {
        return removedReason;
    }

    public Instant getMovedAt() {
        return movedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public List<PopupItem> getItems() {
        return items;
    }
}
