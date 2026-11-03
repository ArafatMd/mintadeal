package com.mintadeal.popup;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import com.mintadeal.popup.Popup.Status;
import com.mintadeal.popup.PopupReport.Reason;

public final class PopupDtos {

    private PopupDtos() {
    }

    public record ItemDto(@NotBlank @Size(max = 500) String imageUrl, @Size(max = 60) String title,
                          @PositiveOrZero @Max(10_000_000) Long priceMinor) {

        static ItemDto of(PopupItem i) {
            return new ItemDto(i.getImageUrl(), i.getTitle(), i.getPriceMinor());
        }
    }

    /**
     * Starts selling. {@code name} (the seller's) is needed the first time only; {@code stallName} names just this
     * stall, e.g. a shop's "Food Fest stall", and defaults to the seller's name.
     */
    public record StartRequest(@Size(max = 80) String name, @Size(max = 80) String stallName,
                               @NotEmpty @Valid List<ItemDto> items, @NotNull Double latitude,
                               @NotNull Double longitude, @NotNull Integer days) {
    }

    /** Sells again from an earlier stall's photos, at a new place. */
    public record AgainRequest(@NotNull Double latitude, @NotNull Double longitude, @NotNull Integer days,
                               @Size(max = 80) String stallName) {
    }

    /** The master controls. */
    public record SettingsDto(@Min(1) @Max(20) int shopMaxLive, @PositiveOrZero @Max(10_000_000) long shopFeePerDayMinor,
                              @Min(1) @Max(20) int sellerMaxLive,
                              @PositiveOrZero @Max(10_000_000) long sellerFeePerDayMinor) {

        static SettingsDto of(PopupSettings s) {
            return new SettingsDto(s.getShopMaxLive(), s.getShopFeePerDayMinor(), s.getSellerMaxLive(),
                    s.getSellerFeePerDayMinor());
        }
    }

    /** An admin's choice for one seller; a null field goes back to the default. */
    public record LimitsRequest(@Min(1) @Max(20) Integer maxLive, @PositiveOrZero @Max(10_000_000) Long feePerDayMinor) {
    }

    /**
     * One seller's limits.
     *
     * @param shopName the approved shop of this person, if any; shops get the shop defaults
     * @param maxLive  what an admin chose, or null for the default
     */
    public record SellerLimits(UUID userId, String name, String phone, String shopName, Integer maxLive,
                               Long feePerDayMinor, int effectiveMaxLive, long effectiveFeePerDayMinor) {
    }

    public record MoveRequest(@NotNull Double latitude, @NotNull Double longitude) {
    }

    public record NameRequest(@NotBlank @Size(max = 80) String name) {
    }

    public record ReportRequest(@NotNull Reason reason, @Size(max = 300) String note) {
    }

    public record ReasonRequest(@Size(max = 300) String reason) {
    }

    /** A stall as its seller sees it. */
    /** @param paymentUrl where to pay the fee, while the stall is waiting for it */
    public record MyPopup(UUID id, Status status, String name, List<ItemDto> items, double latitude, double longitude,
                          int days, Instant startsAt, Instant endsAt, Instant stoppedAt, String removedReason,
                          long feeMinor, String paymentUrl, Instant paymentDeadline) {

        static MyPopup of(Popup p, Instant now) {
            Status status = p.status(now);
            return new MyPopup(p.getId(), status, p.getSellerName(), p.getItems().stream().map(ItemDto::of).toList(),
                    p.getLatitude(), p.getLongitude(), p.getDays(), p.getStartsAt(), p.getEndsAt(),
                    p.getStoppedAt(), p.getRemovedReason(), p.getFeeMinor(),
                    status == Status.PENDING_PAYMENT ? p.getPaymentUrl() : null, p.getPaymentDeadline());
        }
    }

    /**
     * Everything the seller app needs on one screen.
     *
     * @param name     null until the person has posted a stall
     * @param active   stalls live now or waiting for their fee, newest first
     * @param history  earlier stalls, newest first, for "Sell again"
     * @param maxLive  how many stalls this seller may run at once
     * @param feePerDayMinor the listing fee per day; 0 when free
     * @param shopName the seller's approved shop: its stalls show it, and fees come off the shop's balance
     */
    public record Me(String name, boolean blocked, String blockedReason, List<MyPopup> active, List<MyPopup> history,
                     List<Integer> allowedDays, int defaultDays, int maxItems, int maxLive, long feePerDayMinor,
                     String shopName) {
    }

    /** A live stall as customers see it. The seller agreed to show their phone so customers can call. */
    /** @param vendorId the approved shop running this stall, or null for an independent seller */
    public record PublicPopup(UUID id, String sellerName, String phone, List<ItemDto> items, double latitude,
                              double longitude, Double distanceKm, Instant startsAt, Instant endsAt, UUID vendorId,
                              String vendorName) {
    }

    /** A stall in the admin website, with its reports. */
    public record AdminPopup(UUID id, UUID sellerId, String sellerName, String phone, boolean sellerBlocked,
                             Status status, List<ItemDto> items, double latitude, double longitude, int days,
                             Instant startsAt, Instant endsAt, Instant stoppedAt, Instant removedAt,
                             String removedReason, Instant movedAt, long reportCount, List<ReportDto> reports,
                             UUID vendorId, String vendorName, long feeMinor, String paymentProvider, Instant paidAt) {
    }

    public record ReportDto(Reason reason, String note, Instant createdAt) {

        static ReportDto of(PopupReport r) {
            return new ReportDto(r.getReason(), r.getNote(), r.getCreatedAt());
        }
    }
}
