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

    /**
     * PENDING_PAYMENT: waiting for the seller to pay the listing fee. LIVE: customers can see it. ENDED: its days ran
     * out, the seller stopped it, or the fee was never paid. REMOVED: taken down.
     */
    public enum Status { PENDING_PAYMENT, LIVE, ENDED, REMOVED }

    /** How a fee was paid when it was not paid online. */
    static final String SHOP_BALANCE = "SHOP_BALANCE";

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

    private UUID vendorId;

    private String vendorName;

    private long feeMinor;

    private String paymentProvider;

    private String paymentReference;

    private String paymentUrl;

    private String paymentId;

    private Instant paymentDeadline;

    private Instant paidAt;

    // Customers' reactions, for admins only. Changed by single UPDATE statements so taps never clash.
    private int viewCount;

    private int callCount;

    private int whatsappCount;

    private int directionsCount;

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
        if (feeMinor > 0 && paidAt == null) {
            return stoppedAt == null && paymentDeadline != null && paymentDeadline.isAfter(now)
                    ? Status.PENDING_PAYMENT : Status.ENDED;
        }
        return stoppedAt == null && endsAt.isAfter(now) ? Status.LIVE : Status.ENDED;
    }

    void fromShop(UUID vendorId, String vendorName) {
        this.vendorId = vendorId;
        this.vendorName = vendorName;
    }

    /** A fee to pay online before the stall goes live. */
    void awaitPayment(long feeMinor, String provider, String reference, String url, Instant deadline) {
        this.feeMinor = feeMinor;
        this.paymentProvider = provider;
        this.paymentReference = reference;
        this.paymentUrl = url;
        this.paymentDeadline = deadline;
    }

    /** A fee taken from the shop's balance: the stall is live at once. */
    void chargedToShop(long feeMinor, Instant now) {
        this.feeMinor = feeMinor;
        this.paymentProvider = SHOP_BALANCE;
        this.paidAt = now;
    }

    /** The online payment arrived: the chosen days start now. */
    void paid(String paymentId, Instant now) {
        this.paymentId = paymentId;
        this.paidAt = now;
        this.startsAt = now;
        this.endsAt = now.plus(java.time.Duration.ofDays(days));
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

    public UUID getVendorId() {
        return vendorId;
    }

    public String getVendorName() {
        return vendorName;
    }

    public long getFeeMinor() {
        return feeMinor;
    }

    public String getPaymentProvider() {
        return paymentProvider;
    }

    public String getPaymentReference() {
        return paymentReference;
    }

    public String getPaymentUrl() {
        return paymentUrl;
    }

    public Instant getPaymentDeadline() {
        return paymentDeadline;
    }

    public Instant getPaidAt() {
        return paidAt;
    }

    public int getViewCount() {
        return viewCount;
    }

    public int getCallCount() {
        return callCount;
    }

    public int getWhatsappCount() {
        return whatsappCount;
    }

    public int getDirectionsCount() {
        return directionsCount;
    }

    public List<PopupItem> getItems() {
        return items;
    }
}
