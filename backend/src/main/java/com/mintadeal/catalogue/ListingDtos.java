package com.mintadeal.catalogue;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import com.mintadeal.vendor.VendorCategory;

public final class ListingDtos {

    private ListingDtos() {
    }

    public record ListingRequest(
            @NotNull ListingType listingType,
            @NotBlank @Size(max = 160) String title,
            @Size(max = 2000) String description,
            VendorCategory category,
            @Size(max = 500) String imageUrl,
            @Positive long priceMinor,
            @Positive Long offerPriceMinor,
            @PositiveOrZero Integer stock,
            @Positive Integer capacityPerSlot,
            @Size(max = 2000) String terms,
            Instant validFrom,
            Instant validTo,
            @NotEmpty Set<FulfilmentMode> fulfilmentModes) {
    }

    public record StockUpdate(@PositiveOrZero Integer stock) {
    }

    public record RemoveRequest(@NotBlank @Size(max = 500) String reason) {
    }

    public record ListingDto(
            UUID id, UUID vendorId, ListingType listingType, String title, String description,
            VendorCategory category, String imageUrl, long priceMinor, Long offerPriceMinor,
            Integer discountPercent, Integer stock, Integer capacityPerSlot, String terms,
            Instant validFrom, Instant validTo, ListingStatus status, String removedReason,
            List<FulfilmentMode> fulfilmentModes, Instant createdAt, Instant updatedAt) {

        public static ListingDto of(Listing l) {
            return new ListingDto(l.getId(), l.getVendorId(), l.getListingType(), l.getTitle(),
                    l.getDescription(), l.getCategory(), l.getImageUrl(), l.getPriceMinor(),
                    l.getOfferPriceMinor(), discountPercent(l), l.getStock(), l.getCapacityPerSlot(),
                    l.getTerms(), l.getValidFrom(), l.getValidTo(), l.getStatus(), l.getRemovedReason(),
                    l.getFulfilmentModes().stream().sorted().toList(), l.getCreatedAt(), l.getUpdatedAt());
        }

        static Integer discountPercent(Listing l) {
            if (l.getOfferPriceMinor() == null || l.getOfferPriceMinor() >= l.getPriceMinor()) {
                return null;
            }
            return (int) Math.round(100.0 * (l.getPriceMinor() - l.getOfferPriceMinor()) / l.getPriceMinor());
        }
    }
}
