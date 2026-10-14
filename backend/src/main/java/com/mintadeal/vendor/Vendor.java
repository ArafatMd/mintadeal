package com.mintadeal.vendor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

@Entity
@Table(name = "vendor")
public class Vendor {

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID ownerUserId;

    @Column(nullable = false)
    private String displayName;

    private String legalName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private VendorCategory category;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private VendorType vendorType = VendorType.EXTERNAL;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private VendorStatus status = VendorStatus.PENDING;

    @Column(nullable = false)
    private String phone;

    private String description;

    @Column(nullable = false)
    private String addressLine;

    @Column(nullable = false)
    private String area;

    @Column(nullable = false)
    private String city;

    @Column(nullable = false)
    private String pincode;

    private double latitude;

    private double longitude;

    private String gstNumber;

    private String openingHours;

    private String logoUrl;

    private String coverUrl;

    private String payoutUpiId;

    private String payoutAccountNumber;

    private String payoutIfsc;

    private boolean selfDelivery;

    private boolean partnerDelivery;

    private boolean pickup;

    private boolean citywideDelivery;

    @Column(nullable = false, precision = 5, scale = 2)
    private BigDecimal deliveryRadiusKm = BigDecimal.ZERO;

    private long deliveryFeeMinor;

    private long minOrderMinor;

    private String reviewNote;

    @Column(nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    @Version
    private Long version;

    protected Vendor() {
    }

    public Vendor(UUID ownerUserId, Instant now) {
        this.id = UUID.randomUUID();
        this.ownerUserId = ownerUserId;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public boolean isApproved() {
        return status == VendorStatus.APPROVED;
    }

    public boolean deliversTo(double distanceKm) {
        return (selfDelivery || partnerDelivery)
                && (citywideDelivery || distanceKm <= deliveryRadiusKm.doubleValue());
    }

    public void touch(Instant now) {
        this.updatedAt = now;
    }

    // Getters and setters

    public UUID getId() {
        return id;
    }

    public UUID getOwnerUserId() {
        return ownerUserId;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }

    public String getLegalName() {
        return legalName;
    }

    public void setLegalName(String legalName) {
        this.legalName = legalName;
    }

    public VendorCategory getCategory() {
        return category;
    }

    public void setCategory(VendorCategory category) {
        this.category = category;
    }

    public VendorType getVendorType() {
        return vendorType;
    }

    public void setVendorType(VendorType vendorType) {
        this.vendorType = vendorType;
    }

    public VendorStatus getStatus() {
        return status;
    }

    public void setStatus(VendorStatus status) {
        this.status = status;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getAddressLine() {
        return addressLine;
    }

    public void setAddressLine(String addressLine) {
        this.addressLine = addressLine;
    }

    public String getArea() {
        return area;
    }

    public void setArea(String area) {
        this.area = area;
    }

    public String getCity() {
        return city;
    }

    public void setCity(String city) {
        this.city = city;
    }

    public String getPincode() {
        return pincode;
    }

    public void setPincode(String pincode) {
        this.pincode = pincode;
    }

    public double getLatitude() {
        return latitude;
    }

    public void setLatitude(double latitude) {
        this.latitude = latitude;
    }

    public double getLongitude() {
        return longitude;
    }

    public void setLongitude(double longitude) {
        this.longitude = longitude;
    }

    public String getGstNumber() {
        return gstNumber;
    }

    public void setGstNumber(String gstNumber) {
        this.gstNumber = gstNumber;
    }

    public String getOpeningHours() {
        return openingHours;
    }

    public void setOpeningHours(String openingHours) {
        this.openingHours = openingHours;
    }

    public String getLogoUrl() {
        return logoUrl;
    }

    public void setLogoUrl(String logoUrl) {
        this.logoUrl = logoUrl;
    }

    public String getCoverUrl() {
        return coverUrl;
    }

    public void setCoverUrl(String coverUrl) {
        this.coverUrl = coverUrl;
    }

    public String getPayoutUpiId() {
        return payoutUpiId;
    }

    public void setPayoutUpiId(String payoutUpiId) {
        this.payoutUpiId = payoutUpiId;
    }

    public String getPayoutAccountNumber() {
        return payoutAccountNumber;
    }

    public void setPayoutAccountNumber(String payoutAccountNumber) {
        this.payoutAccountNumber = payoutAccountNumber;
    }

    public String getPayoutIfsc() {
        return payoutIfsc;
    }

    public void setPayoutIfsc(String payoutIfsc) {
        this.payoutIfsc = payoutIfsc;
    }

    public boolean isSelfDelivery() {
        return selfDelivery;
    }

    public void setSelfDelivery(boolean selfDelivery) {
        this.selfDelivery = selfDelivery;
    }

    public boolean isPartnerDelivery() {
        return partnerDelivery;
    }

    public void setPartnerDelivery(boolean partnerDelivery) {
        this.partnerDelivery = partnerDelivery;
    }

    public boolean isPickup() {
        return pickup;
    }

    public void setPickup(boolean pickup) {
        this.pickup = pickup;
    }

    public boolean isCitywideDelivery() {
        return citywideDelivery;
    }

    public void setCitywideDelivery(boolean citywideDelivery) {
        this.citywideDelivery = citywideDelivery;
    }

    public BigDecimal getDeliveryRadiusKm() {
        return deliveryRadiusKm;
    }

    public void setDeliveryRadiusKm(BigDecimal deliveryRadiusKm) {
        this.deliveryRadiusKm = deliveryRadiusKm;
    }

    public long getDeliveryFeeMinor() {
        return deliveryFeeMinor;
    }

    public void setDeliveryFeeMinor(long deliveryFeeMinor) {
        this.deliveryFeeMinor = deliveryFeeMinor;
    }

    public long getMinOrderMinor() {
        return minOrderMinor;
    }

    public void setMinOrderMinor(long minOrderMinor) {
        this.minOrderMinor = minOrderMinor;
    }

    public String getReviewNote() {
        return reviewNote;
    }

    public void setReviewNote(String reviewNote) {
        this.reviewNote = reviewNote;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
