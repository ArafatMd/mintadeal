package com.mintadeal.delivery;

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

/**
 * A pickup-and-drop job for a Mintadeal delivery partner. Pickup and drop details are copied in when the shop
 * requests the rider, so later edits to the shop or checkout do not move a job that is on the road.
 */
@Entity
@Table(name = "delivery_job")
public class DeliveryJob {

    @Id
    private UUID id;

    @Column(nullable = false)
    private UUID shopOrderId;

    @Column(nullable = false)
    private String orderCode;

    @Column(nullable = false)
    private UUID vendorId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private JobStatus status = JobStatus.REQUESTED;

    private UUID agentId;

    private long costMinor;

    @Column(nullable = false, precision = 6, scale = 2)
    private BigDecimal distanceKm;

    private long cashToCollectMinor;

    @Column(nullable = false)
    private String pickupName;

    @Column(nullable = false)
    private String pickupPhone;

    @Column(nullable = false)
    private String pickupAddress;

    @Column(nullable = false)
    private String pickupArea;

    private double pickupLatitude;

    private double pickupLongitude;

    private String dropName;

    @Column(nullable = false)
    private String dropPhone;

    @Column(nullable = false)
    private String dropAddress;

    @Column(nullable = false)
    private String dropArea;

    private double dropLatitude;

    private double dropLongitude;

    /** Told to the customer; the rider enters it to prove the handover. */
    @Column(nullable = false)
    private String dropCode;

    private int dropCodeAttempts;

    private int itemCount;

    private String failureReason;

    @Column(nullable = false)
    private Instant requestedAt;

    private Instant assignedAt;

    private Instant pickedUpAt;

    private Instant deliveredAt;

    private Instant closedAt;

    @Version
    private Long version;

    protected DeliveryJob() {
    }

    DeliveryJob(UUID shopOrderId, String orderCode, UUID vendorId, long costMinor, BigDecimal distanceKm,
                long cashToCollectMinor, int itemCount, String dropCode, Instant now) {
        this.id = UUID.randomUUID();
        this.shopOrderId = shopOrderId;
        this.orderCode = orderCode;
        this.vendorId = vendorId;
        this.costMinor = costMinor;
        this.distanceKm = distanceKm;
        this.cashToCollectMinor = cashToCollectMinor;
        this.itemCount = itemCount;
        this.dropCode = dropCode;
        this.requestedAt = now;
    }

    void pickup(String name, String phone, String address, String area, double lat, double lng) {
        this.pickupName = name;
        this.pickupPhone = phone;
        this.pickupAddress = address;
        this.pickupArea = area;
        this.pickupLatitude = lat;
        this.pickupLongitude = lng;
    }

    void drop(String name, String phone, String address, String area, double lat, double lng) {
        this.dropName = name;
        this.dropPhone = phone;
        this.dropAddress = address;
        this.dropArea = area;
        this.dropLatitude = lat;
        this.dropLongitude = lng;
    }

    void assign(UUID agentId, Instant now) {
        this.agentId = agentId;
        this.status = JobStatus.ASSIGNED;
        this.assignedAt = now;
    }

    void release() {
        this.agentId = null;
        this.status = JobStatus.REQUESTED;
        this.assignedAt = null;
    }

    void pickedUp(Instant now) {
        this.status = JobStatus.PICKED_UP;
        this.pickedUpAt = now;
    }

    void delivered(Instant now) {
        this.status = JobStatus.DELIVERED;
        this.deliveredAt = now;
        this.closedAt = now;
    }

    void close(JobStatus status, String reason, Instant now) {
        this.status = status;
        this.failureReason = reason;
        this.closedAt = now;
    }

    /** Returns true if the code matches; counts wrong tries. */
    boolean checkDropCode(String code) {
        boolean ok = dropCode.equals(code == null ? "" : code.trim());
        if (!ok) {
            dropCodeAttempts++;
        }
        return ok;
    }

    public UUID getId() {
        return id;
    }

    public UUID getShopOrderId() {
        return shopOrderId;
    }

    public String getOrderCode() {
        return orderCode;
    }

    public UUID getVendorId() {
        return vendorId;
    }

    public JobStatus getStatus() {
        return status;
    }

    public UUID getAgentId() {
        return agentId;
    }

    public long getCostMinor() {
        return costMinor;
    }

    public BigDecimal getDistanceKm() {
        return distanceKm;
    }

    public long getCashToCollectMinor() {
        return cashToCollectMinor;
    }

    public String getPickupName() {
        return pickupName;
    }

    public String getPickupPhone() {
        return pickupPhone;
    }

    public String getPickupAddress() {
        return pickupAddress;
    }

    public String getPickupArea() {
        return pickupArea;
    }

    public double getPickupLatitude() {
        return pickupLatitude;
    }

    public double getPickupLongitude() {
        return pickupLongitude;
    }

    public String getDropName() {
        return dropName;
    }

    public String getDropPhone() {
        return dropPhone;
    }

    public String getDropAddress() {
        return dropAddress;
    }

    public String getDropArea() {
        return dropArea;
    }

    public double getDropLatitude() {
        return dropLatitude;
    }

    public double getDropLongitude() {
        return dropLongitude;
    }

    public String getDropCode() {
        return dropCode;
    }

    public int getDropCodeAttempts() {
        return dropCodeAttempts;
    }

    public int getItemCount() {
        return itemCount;
    }

    public String getFailureReason() {
        return failureReason;
    }

    public Instant getRequestedAt() {
        return requestedAt;
    }

    public Instant getAssignedAt() {
        return assignedAt;
    }

    public Instant getPickedUpAt() {
        return pickedUpAt;
    }

    public Instant getDeliveredAt() {
        return deliveredAt;
    }

    public Instant getClosedAt() {
        return closedAt;
    }
}
