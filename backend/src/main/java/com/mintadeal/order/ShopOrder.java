package com.mintadeal.order;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.catalogue.ListingType;

/** The part of a checkout one shop fulfils, with its own fulfilment mode, fee and status. */
@Entity
@Table(name = "shop_order")
public class ShopOrder {

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID checkoutId;

    @Column(nullable = false, unique = true)
    private String code;

    @Column(nullable = false)
    private UUID vendorId;

    @Column(nullable = false)
    private String vendorName;

    @Column(nullable = false)
    private UUID customerId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OrderStatus status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private FulfilmentMode fulfilmentMode;

    private long itemsTotalMinor;

    private long deliveryFeeMinor;

    private long totalMinor;

    private Instant acceptDeadline;

    private Instant acceptedAt;

    private Instant readyAt;

    private Instant completedAt;

    private Instant cancelledAt;

    @Enumerated(EnumType.STRING)
    private ActorType cancelledBy;

    private String cancelReason;

    @OneToMany(mappedBy = "shopOrder", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    @OrderBy("position")
    private List<OrderLine> lines = new ArrayList<>();

    @Column(nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    @Version
    private Long version;

    protected ShopOrder() {
    }

    public ShopOrder(Checkout checkout, int index, UUID vendorId, String vendorName, FulfilmentMode mode,
                     OrderStatus status, Instant now) {
        this.id = UUID.randomUUID();
        this.checkoutId = checkout.getId();
        this.code = checkout.getCode() + "-" + index;
        this.vendorId = vendorId;
        this.vendorName = vendorName;
        this.customerId = checkout.getCustomerId();
        this.fulfilmentMode = mode;
        this.status = status;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public void addLine(UUID listingId, ListingType type, String title, String imageUrl, long unitPrice,
                        long originalPrice, int quantity) {
        lines.add(new OrderLine(this, lines.size() + 1, listingId, type, title, imageUrl, unitPrice, originalPrice,
                quantity));
        itemsTotalMinor = lines.stream().mapToLong(OrderLine::getLineTotalMinor).sum();
        totalMinor = itemsTotalMinor + deliveryFeeMinor;
    }

    public void setDeliveryFeeMinor(long fee) {
        this.deliveryFeeMinor = fee;
        this.totalMinor = itemsTotalMinor + fee;
    }

    /** Moves to a new status and stamps the matching timestamp. Callers check the transition is allowed. */
    void moveTo(OrderStatus next, Instant now) {
        this.status = next;
        this.updatedAt = now;
        switch (next) {
            case ACCEPTED -> acceptedAt = now;
            case READY, OUT_FOR_DELIVERY -> readyAt = now;
            case COMPLETED -> completedAt = now;
            case CANCELLED -> cancelledAt = now;
            default -> {
            }
        }
    }

    void awaitAcceptance(Instant deadline) {
        this.acceptDeadline = deadline;
    }

    void cancel(ActorType by, String reason, Instant now) {
        moveTo(OrderStatus.CANCELLED, now);
        this.cancelledBy = by;
        this.cancelReason = reason;
    }

    public boolean isDelivery() {
        return fulfilmentMode.isDelivery();
    }

    public UUID getId() {
        return id;
    }

    public UUID getCheckoutId() {
        return checkoutId;
    }

    public String getCode() {
        return code;
    }

    public UUID getVendorId() {
        return vendorId;
    }

    public String getVendorName() {
        return vendorName;
    }

    public UUID getCustomerId() {
        return customerId;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public FulfilmentMode getFulfilmentMode() {
        return fulfilmentMode;
    }

    public long getItemsTotalMinor() {
        return itemsTotalMinor;
    }

    public long getDeliveryFeeMinor() {
        return deliveryFeeMinor;
    }

    public long getTotalMinor() {
        return totalMinor;
    }

    public Instant getAcceptDeadline() {
        return acceptDeadline;
    }

    public Instant getAcceptedAt() {
        return acceptedAt;
    }

    public Instant getReadyAt() {
        return readyAt;
    }

    public Instant getCompletedAt() {
        return completedAt;
    }

    public Instant getCancelledAt() {
        return cancelledAt;
    }

    public ActorType getCancelledBy() {
        return cancelledBy;
    }

    public String getCancelReason() {
        return cancelReason;
    }

    public List<OrderLine> getLines() {
        return lines;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
