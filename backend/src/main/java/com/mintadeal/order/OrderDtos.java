package com.mintadeal.order;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.catalogue.ListingType;

public final class OrderDtos {

    private OrderDtos() {
    }

    /**
     * REDEEM: the shop scans the customer's QR (venue offers). REQUEST_DELIVERY / CANCEL_DELIVERY: the shop books or
     * cancels a Mintadeal delivery partner.
     */
    public enum Action {
        PAY, CANCEL, ACCEPT, REJECT, MARK_READY, OUT_FOR_DELIVERY, COMPLETE, REDEEM, REQUEST_DELIVERY, CANCEL_DELIVERY
    }

    /**
     * The delivery partner job behind a partner-delivery order.
     *
     * @param costMinor what the shop pays for the partner; shown to the shop and admins only
     * @param dropCode the handover code; shown to the customer only
     */
    public record DeliveryInfo(String status, String agentName, String agentPhone, String agentAvatarUrl, Long costMinor, String dropCode,
                               Instant requestedAt, Instant assignedAt, Instant pickedUpAt, Instant deliveredAt,
                               String failureReason) {
    }

    /** @param token the QR payload; shown to the customer only, never to the shop */
    public record RedemptionInfo(String token, int quantity, Instant validFrom, Instant validTo, Instant usedAt) {
    }

    public record ReasonRequest(@NotBlank @Size(max = 500) String reason) {
    }

    public record LineDto(UUID listingId, ListingType listingType, String title, String imageUrl,
                          long unitPriceMinor, long originalPriceMinor, int quantity, long lineTotalMinor) {

        static LineDto of(OrderLine l) {
            return new LineDto(l.getListingId(), l.getListingType(), l.getTitle(), l.getImageUrl(),
                    l.getUnitPriceMinor(), l.getOriginalPriceMinor(), l.getQuantity(), l.getLineTotalMinor());
        }
    }

    public record EventDto(OrderStatus status, ActorType actorType, String note, Instant createdAt) {

        static EventDto of(OrderEvent e) {
            return new EventDto(e.getStatus(), e.getActorType(), e.getNote(), e.getCreatedAt());
        }
    }

    public record Party(String name, String phone) {
    }

    public record AddressDto(String line, String area, String landmark, Double latitude, Double longitude) {
    }

    public record RefundDto(long amountMinor, RefundStatus status, String error, Instant createdAt) {

        static RefundDto of(Refund r) {
            return r == null ? null : new RefundDto(r.getAmountMinor(), r.getStatus(), r.getError(), r.getCreatedAt());
        }
    }

    /** Compact row for order lists. {@code itemCount} is the number of different items. */
    public record OrderSummary(UUID id, String code, String checkoutCode, UUID vendorId, String vendorName,
                               OrderStatus status, FulfilmentMode fulfilmentMode, int itemCount,
                               String firstItemTitle, long totalMinor, PaymentMethod paymentMethod,
                               PaymentStatus paymentStatus, Instant acceptDeadline, Instant createdAt) {
    }

    /**
     * Full order as one viewer sees it. The customer's phone and address are included for the shop that fulfils
     * the order and for admins only.
     */
    public record OrderDetail(UUID id, String code, UUID checkoutId, String checkoutCode, OrderStatus status,
                              FulfilmentMode fulfilmentMode, Party shop, UUID vendorId, String shopArea,
                              Party customer, AddressDto address, String note,
                              List<LineDto> lines, long itemsTotalMinor, long deliveryFeeMinor, long totalMinor,
                              PaymentMethod paymentMethod, PaymentStatus paymentStatus, String paymentUrl,
                              Instant acceptDeadline, Instant acceptedAt, Instant readyAt, Instant completedAt,
                              Instant cancelledAt, ActorType cancelledBy, String cancelReason,
                              RefundDto refund, DeliveryInfo delivery, RedemptionInfo redemption,
                              List<EventDto> events, List<Action> actions, Instant createdAt) {
    }

    public record VendorSummaryCounts(long newOrders, long activeOrders) {
    }
}
