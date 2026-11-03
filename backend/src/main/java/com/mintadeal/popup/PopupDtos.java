package com.mintadeal.popup;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
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

    /** Starts selling. {@code name} is needed the first time only. */
    public record StartRequest(@Size(max = 80) String name, @NotEmpty @Valid List<ItemDto> items,
                               @NotNull Double latitude, @NotNull Double longitude, @NotNull Integer days) {
    }

    /** Sells again from an earlier stall's photos, at a new place. */
    public record AgainRequest(@NotNull Double latitude, @NotNull Double longitude, @NotNull Integer days) {
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
    public record MyPopup(UUID id, Status status, List<ItemDto> items, double latitude, double longitude, int days,
                          Instant startsAt, Instant endsAt, Instant stoppedAt, String removedReason) {

        static MyPopup of(Popup p, Instant now) {
            return new MyPopup(p.getId(), p.status(now), p.getItems().stream().map(ItemDto::of).toList(),
                    p.getLatitude(), p.getLongitude(), p.getDays(), p.getStartsAt(), p.getEndsAt(),
                    p.getStoppedAt(), p.getRemovedReason());
        }
    }

    /**
     * Everything the seller app needs on one screen.
     *
     * @param name     null until the person has posted a stall
     * @param live     the stall customers can see now, or null
     * @param history  earlier stalls, newest first, for "Sell again"
     */
    public record Me(String name, boolean blocked, String blockedReason, MyPopup live, List<MyPopup> history,
                     List<Integer> allowedDays, int defaultDays, int maxItems) {
    }

    /** A live stall as customers see it. The seller agreed to show their phone so customers can call. */
    public record PublicPopup(UUID id, String sellerName, String phone, List<ItemDto> items, double latitude,
                              double longitude, Double distanceKm, Instant startsAt, Instant endsAt) {
    }

    /** A stall in the admin website, with its reports. */
    public record AdminPopup(UUID id, UUID sellerId, String sellerName, String phone, boolean sellerBlocked,
                             Status status, List<ItemDto> items, double latitude, double longitude, int days,
                             Instant startsAt, Instant endsAt, Instant stoppedAt, Instant removedAt,
                             String removedReason, Instant movedAt, long reportCount, List<ReportDto> reports) {
    }

    public record ReportDto(Reason reason, String note, Instant createdAt) {

        static ReportDto of(PopupReport r) {
            return new ReportDto(r.getReason(), r.getNote(), r.getCreatedAt());
        }
    }
}
