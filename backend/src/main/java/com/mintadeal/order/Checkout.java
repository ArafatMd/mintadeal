package com.mintadeal.order;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/** One purchase by a customer; split into one {@link ShopOrder} per shop. Holds the payment. */
@Entity
@Table(name = "checkout")
public class Checkout {

    @Id
    private UUID id;

    @Column(nullable = false, unique = true)
    private String code;

    @Column(nullable = false)
    private UUID customerId;

    @Column(nullable = false)
    private String clientRequestId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentMethod paymentMethod;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentStatus paymentStatus;

    private String paymentProvider;

    private String paymentReference;

    private String paymentUrl;

    private String providerPaymentId;

    private Instant paymentDeadline;

    private Instant paidAt;

    private long itemsTotalMinor;

    private long deliveryTotalMinor;

    private long grandTotalMinor;

    private String contactName;

    @Column(nullable = false)
    private String contactPhone;

    private String addressLine;

    private String addressArea;

    private String addressLandmark;

    private Double addressLatitude;

    private Double addressLongitude;

    private String note;

    @Column(nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    @Version
    private Long version;

    protected Checkout() {
    }

    public Checkout(String code, UUID customerId, String clientRequestId, PaymentMethod method, Instant now) {
        this.id = UUID.randomUUID();
        this.code = code;
        this.customerId = customerId;
        this.clientRequestId = clientRequestId;
        this.paymentMethod = method;
        this.paymentStatus = method == PaymentMethod.ONLINE ? PaymentStatus.PENDING : PaymentStatus.NOT_REQUIRED;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public boolean hasAddress() {
        return addressLine != null;
    }

    public void touch(Instant now) {
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public UUID getCustomerId() {
        return customerId;
    }

    public String getClientRequestId() {
        return clientRequestId;
    }

    public PaymentMethod getPaymentMethod() {
        return paymentMethod;
    }

    public PaymentStatus getPaymentStatus() {
        return paymentStatus;
    }

    public void setPaymentStatus(PaymentStatus paymentStatus) {
        this.paymentStatus = paymentStatus;
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

    public void attachPaymentLink(String provider, String reference, String url, Instant deadline) {
        this.paymentProvider = provider;
        this.paymentReference = reference;
        this.paymentUrl = url;
        this.paymentDeadline = deadline;
    }

    public String getProviderPaymentId() {
        return providerPaymentId;
    }

    public void markPaid(String providerPaymentId, Instant now) {
        this.paymentStatus = PaymentStatus.PAID;
        this.providerPaymentId = providerPaymentId;
        this.paidAt = now;
        this.updatedAt = now;
    }

    public Instant getPaymentDeadline() {
        return paymentDeadline;
    }

    public Instant getPaidAt() {
        return paidAt;
    }

    public long getItemsTotalMinor() {
        return itemsTotalMinor;
    }

    public long getDeliveryTotalMinor() {
        return deliveryTotalMinor;
    }

    public long getGrandTotalMinor() {
        return grandTotalMinor;
    }

    public void setTotals(long items, long delivery) {
        this.itemsTotalMinor = items;
        this.deliveryTotalMinor = delivery;
        this.grandTotalMinor = items + delivery;
    }

    public String getContactName() {
        return contactName;
    }

    public String getContactPhone() {
        return contactPhone;
    }

    public void setContact(String name, String phone) {
        this.contactName = name;
        this.contactPhone = phone;
    }

    public String getAddressLine() {
        return addressLine;
    }

    public String getAddressArea() {
        return addressArea;
    }

    public String getAddressLandmark() {
        return addressLandmark;
    }

    public Double getAddressLatitude() {
        return addressLatitude;
    }

    public Double getAddressLongitude() {
        return addressLongitude;
    }

    public void setAddress(String line, String area, String landmark, Double lat, Double lng) {
        this.addressLine = line;
        this.addressArea = area;
        this.addressLandmark = landmark;
        this.addressLatitude = lat;
        this.addressLongitude = lng;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
