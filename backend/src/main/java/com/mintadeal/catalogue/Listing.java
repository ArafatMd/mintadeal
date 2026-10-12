package com.mintadeal.catalogue;

import java.time.Instant;
import java.util.EnumSet;
import java.util.Set;
import java.util.UUID;

import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

import com.mintadeal.vendor.VendorCategory;

@Entity
@Table(name = "listing")
public class Listing {

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID vendorId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ListingType listingType;

    @Column(nullable = false)
    private String title;

    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private VendorCategory category;

    private String imageUrl;

    private long priceMinor;

    private Long offerPriceMinor;

    /** Null means the vendor does not track stock; the item is simply available. */
    private Integer stock;

    private Integer capacityPerSlot;

    private String terms;

    private Instant validFrom;

    private Instant validTo;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ListingStatus status = ListingStatus.DRAFT;

    private String removedReason;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "listing_fulfilment_mode", joinColumns = @JoinColumn(name = "listing_id"))
    @Column(name = "mode")
    @Enumerated(EnumType.STRING)
    private Set<FulfilmentMode> fulfilmentModes = EnumSet.noneOf(FulfilmentMode.class);

    @Column(nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    @Version
    private Long version;

    protected Listing() {
    }

    public Listing(UUID vendorId, ListingType type, Instant now) {
        this.id = UUID.randomUUID();
        this.vendorId = vendorId;
        this.listingType = type;
        this.createdAt = now;
        this.updatedAt = now;
    }

    /** Whether a customer can buy this right now, ignoring location. */
    public boolean isPurchasable(Instant now) {
        return status == ListingStatus.ACTIVE
                && (validFrom == null || !validFrom.isAfter(now))
                && (validTo == null || validTo.isAfter(now))
                && (stock == null || stock > 0);
    }

    public long effectivePriceMinor() {
        return offerPriceMinor != null ? offerPriceMinor : priceMinor;
    }

    public void touch(Instant now) {
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getVendorId() {
        return vendorId;
    }

    public ListingType getListingType() {
        return listingType;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public VendorCategory getCategory() {
        return category;
    }

    public void setCategory(VendorCategory category) {
        this.category = category;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public void setImageUrl(String imageUrl) {
        this.imageUrl = imageUrl;
    }

    public long getPriceMinor() {
        return priceMinor;
    }

    public void setPriceMinor(long priceMinor) {
        this.priceMinor = priceMinor;
    }

    public Long getOfferPriceMinor() {
        return offerPriceMinor;
    }

    public void setOfferPriceMinor(Long offerPriceMinor) {
        this.offerPriceMinor = offerPriceMinor;
    }

    public Integer getStock() {
        return stock;
    }

    public void setStock(Integer stock) {
        this.stock = stock;
    }

    public Integer getCapacityPerSlot() {
        return capacityPerSlot;
    }

    public void setCapacityPerSlot(Integer capacityPerSlot) {
        this.capacityPerSlot = capacityPerSlot;
    }

    public String getTerms() {
        return terms;
    }

    public void setTerms(String terms) {
        this.terms = terms;
    }

    public Instant getValidFrom() {
        return validFrom;
    }

    public void setValidFrom(Instant validFrom) {
        this.validFrom = validFrom;
    }

    public Instant getValidTo() {
        return validTo;
    }

    public void setValidTo(Instant validTo) {
        this.validTo = validTo;
    }

    public ListingStatus getStatus() {
        return status;
    }

    public void setStatus(ListingStatus status) {
        this.status = status;
    }

    public String getRemovedReason() {
        return removedReason;
    }

    public void setRemovedReason(String removedReason) {
        this.removedReason = removedReason;
    }

    public Set<FulfilmentMode> getFulfilmentModes() {
        return fulfilmentModes;
    }

    public void setFulfilmentModes(Set<FulfilmentMode> modes) {
        this.fulfilmentModes.clear();
        this.fulfilmentModes.addAll(modes);
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
