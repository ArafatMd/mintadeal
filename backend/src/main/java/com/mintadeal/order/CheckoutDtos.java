package com.mintadeal.order;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.catalogue.ListingType;

public final class CheckoutDtos {

    private CheckoutDtos() {
    }

    public record CartItem(@NotNull UUID listingId, @Positive int quantity) {
    }

    /** Coordinates come from the customer's chosen area; the line and landmark guide the shop. */
    public record Address(@NotBlank @Size(max = 300) String line, @NotBlank @Size(max = 120) String area,
                          @Size(max = 200) String landmark,
                          @NotNull @DecimalMin("6.0") @DecimalMax("37.5") Double latitude,
                          @NotNull @DecimalMin("68.0") @DecimalMax("97.5") Double longitude) {
    }

    /**
     * @param modes the fulfilment chosen for each group, keyed by {@link QuoteGroup#key()}; groups left out get
     *              the first available mode
     */
    public record QuoteRequest(@NotEmpty @Size(max = 50) List<@Valid CartItem> items,
                               Map<String, FulfilmentMode> modes,
                               PaymentMethod paymentMethod,
                               @Valid Address address) {
    }

    public record PlaceRequest(@NotBlank @Size(max = 64) String clientRequestId,
                               @NotEmpty @Size(max = 50) List<@Valid CartItem> items,
                               Map<String, FulfilmentMode> modes,
                               @NotNull PaymentMethod paymentMethod,
                               @Valid Address address,
                               @Size(max = 120) String contactName,
                               @Size(max = 500) String note) {

        QuoteRequest quote() {
            return new QuoteRequest(items, modes, paymentMethod, address);
        }
    }

    public record QuoteLine(UUID listingId, ListingType listingType, String title, String imageUrl,
                            long unitPriceMinor, long originalPriceMinor, int quantity, long lineTotalMinor,
                            Integer stockLeft, String problem) {
    }

    public record VendorRef(UUID id, String name, String area, String logoUrl, String phone) {
    }

    /** One future shop order: the items from one shop, delivered one way. Offers form their own group. */
    public record QuoteGroup(String key, VendorRef vendor, ListingType kind, List<QuoteLine> lines,
                             List<FulfilmentMode> availableModes, FulfilmentMode selectedMode,
                             long itemsTotalMinor, long deliveryFeeMinor, long totalMinor, long minOrderMinor,
                             List<String> problems) {
    }

    public record Quote(List<QuoteGroup> groups, long itemsTotalMinor, long deliveryTotalMinor,
                        long grandTotalMinor, boolean onlinePaymentAvailable, boolean payOnDeliveryAllowed,
                        boolean addressRequired, List<String> problems, boolean canPlace) {
    }

    public record CheckoutDto(UUID id, String code, PaymentMethod paymentMethod, PaymentStatus paymentStatus,
                              String paymentUrl, Instant paymentDeadline, long itemsTotalMinor,
                              long deliveryTotalMinor, long grandTotalMinor, Instant createdAt,
                              List<OrderDtos.OrderSummary> orders) {
    }
}
