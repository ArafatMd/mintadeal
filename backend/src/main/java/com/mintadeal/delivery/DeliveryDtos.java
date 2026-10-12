package com.mintadeal.delivery;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public final class DeliveryDtos {

    private DeliveryDtos() {
    }

    /** What a partner delivery will cost the shop, shown before it books one. */
    public record CostQuote(long costMinor, BigDecimal distanceKm, long outstandingMinor, long limitMinor,
                            boolean allowed, String problem) {
    }

    public record Stop(String name, String phone, String address, String area, double latitude, double longitude) {
    }

    /**
     * A job as a delivery partner sees it. Before a rider takes the job, phone numbers and the exact drop address
     * are hidden; the drop code is never shown to riders.
     */
    public record JobView(UUID id, String orderCode, JobStatus status, BigDecimal distanceKm, int itemCount,
                          long cashToCollectMinor, Stop pickup, Stop drop, boolean mine, String agentName,
                          String agentPhone, Long costMinor, String failureReason, Instant requestedAt,
                          Instant assignedAt, Instant pickedUpAt, Instant deliveredAt) {
    }

    public record DropCode(@NotBlank @Size(max = 6) String code) {
    }

    public record Reason(@NotBlank @Size(max = 500) String reason) {
    }

    public record AssignRequest(@NotBlank String phone) {
    }

    public record ChargeDto(UUID id, UUID shopOrderId, String type, long amountMinor, String description,
                            String status, Instant createdAt) {

        static ChargeDto of(VendorCharge c) {
            return new ChargeDto(c.getId(), c.getShopOrderId(), c.getChargeType(), c.getAmountMinor(),
                    c.getDescription(), c.getStatus(), c.getCreatedAt());
        }
    }

    public record ChargesView(long outstandingMinor, long limitMinor, java.util.List<ChargeDto> charges) {
    }
}
