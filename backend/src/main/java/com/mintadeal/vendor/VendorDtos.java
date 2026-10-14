package com.mintadeal.vendor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

public final class VendorDtos {

    private VendorDtos() {
    }

    /** Shop details and fulfilment settings, used both to apply and to update. */
    public record VendorProfileRequest(
            @NotBlank @Size(max = 120) String displayName,
            @Size(max = 200) String legalName,
            @NotNull VendorCategory category,
            @NotBlank String phone,
            @Size(max = 1000) String description,
            @NotBlank @Size(max = 300) String addressLine,
            @NotBlank @Size(max = 120) String area,
            @NotBlank @Pattern(regexp = "\\d{6}", message = "must be a 6-digit pincode") String pincode,
            @NotNull @DecimalMin("6.0") @DecimalMax("37.5") Double latitude,
            @NotNull @DecimalMin("68.0") @DecimalMax("97.5") Double longitude,
            @Pattern(regexp = "^$|\\d{2}[A-Z]{5}\\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$", message = "is not a valid GSTIN")
            String gstNumber,
            @Size(max = 200) String openingHours,
            @Size(max = 500) String logoUrl,
            @Size(max = 500) String coverUrl,
            @Size(max = 100) String payoutUpiId,
            @Size(max = 30) String payoutAccountNumber,
            @Pattern(regexp = "^$|[A-Z]{4}0[A-Z0-9]{6}", message = "is not a valid IFSC") String payoutIfsc,
            boolean selfDelivery,
            boolean partnerDelivery,
            boolean pickup,
            boolean citywideDelivery,
            @NotNull @DecimalMin("0") @DecimalMax("50") BigDecimal deliveryRadiusKm,
            @PositiveOrZero long deliveryFeeMinor,
            @PositiveOrZero long minOrderMinor) {
    }

    /** Full view for the vendor itself and for admins. */
    public record VendorDto(
            UUID id, UUID ownerUserId, String displayName, String legalName, VendorCategory category,
            VendorType vendorType, VendorStatus status, String phone, String description,
            String addressLine, String area, String city, String pincode, double latitude, double longitude,
            String gstNumber, String openingHours, String logoUrl, String coverUrl,
            String payoutUpiId, String payoutAccountNumber, String payoutIfsc,
            boolean selfDelivery, boolean partnerDelivery, boolean pickup, boolean citywideDelivery,
            BigDecimal deliveryRadiusKm, long deliveryFeeMinor, long minOrderMinor,
            String reviewNote, Instant createdAt, Instant updatedAt) {

        public static VendorDto of(Vendor v) {
            return new VendorDto(v.getId(), v.getOwnerUserId(), v.getDisplayName(), v.getLegalName(),
                    v.getCategory(), v.getVendorType(), v.getStatus(), v.getPhone(), v.getDescription(),
                    v.getAddressLine(), v.getArea(), v.getCity(), v.getPincode(), v.getLatitude(),
                    v.getLongitude(), v.getGstNumber(), v.getOpeningHours(), v.getLogoUrl(), v.getCoverUrl(),
                    v.getPayoutUpiId(), maskAccount(v.getPayoutAccountNumber()), v.getPayoutIfsc(),
                    v.isSelfDelivery(), v.isPartnerDelivery(), v.isPickup(), v.isCitywideDelivery(),
                    v.getDeliveryRadiusKm(), v.getDeliveryFeeMinor(), v.getMinOrderMinor(),
                    v.getReviewNote(), v.getCreatedAt(), v.getUpdatedAt());
        }

        private static String maskAccount(String account) {
            if (account == null || account.length() <= 4) {
                return account;
            }
            return "•".repeat(account.length() - 4) + account.substring(account.length() - 4);
        }
    }

    /** What customers see on a storefront. No payout or review details. */
    public record VendorPublicDto(
            UUID id, String displayName, VendorCategory category, String description, String phone,
            String addressLine, String area, String city, double latitude, double longitude,
            String openingHours, String logoUrl, String coverUrl, boolean selfDelivery, boolean partnerDelivery,
            boolean pickup, boolean citywideDelivery, BigDecimal deliveryRadiusKm,
            long deliveryFeeMinor, long minOrderMinor, boolean mintadealOwn) {

        public static VendorPublicDto of(Vendor v) {
            return new VendorPublicDto(v.getId(), v.getDisplayName(), v.getCategory(), v.getDescription(),
                    v.getPhone(), v.getAddressLine(), v.getArea(), v.getCity(), v.getLatitude(),
                    v.getLongitude(), v.getOpeningHours(), v.getLogoUrl(), v.getCoverUrl(), v.isSelfDelivery(),
                    v.isPartnerDelivery(), v.isPickup(), v.isCitywideDelivery(), v.getDeliveryRadiusKm(),
                    v.getDeliveryFeeMinor(), v.getMinOrderMinor(), v.getVendorType() == VendorType.INTERNAL);
        }
    }

    public record ReviewNote(@Size(max = 500) String note) {
    }

    public record TypeChange(@NotNull VendorType vendorType) {
    }
}
