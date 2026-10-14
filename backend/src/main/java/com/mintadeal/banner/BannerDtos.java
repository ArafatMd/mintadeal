package com.mintadeal.banner;

import java.time.Instant;
import java.util.UUID;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import com.mintadeal.banner.HomeBanner.Scope;
import com.mintadeal.banner.HomeBanner.Target;
import com.mintadeal.vendor.VendorCategory;

public final class BannerDtos {

    private BannerDtos() {
    }

    /**
     * @param targetCategory required when the banner opens a category
     * @param targetId       the shop or listing it opens
     * @param position       lower numbers show first
     */
    public record BannerRequest(
            @NotBlank @Size(max = 60) String title,
            @Size(max = 100) String subtitle,
            @Size(max = 40) String kicker,
            @NotBlank @Size(max = 500) String imageUrl,
            @NotNull Target targetType,
            VendorCategory targetCategory,
            UUID targetId,
            @NotNull Scope scope,
            Instant startsAt,
            Instant endsAt,
            @Min(0) @Max(999) int position,
            boolean active) {
    }

    /** Admin view, with whether customers can see it right now. */
    public record BannerDto(UUID id, String title, String subtitle, String kicker, String imageUrl,
                            Target targetType, VendorCategory targetCategory, UUID targetId, String targetName,
                            Scope scope, Instant startsAt, Instant endsAt, int position, boolean active,
                            boolean live, Instant updatedAt) {
    }

    /** What the customer app needs to draw and open a banner. */
    public record PublicBanner(UUID id, String title, String subtitle, String kicker, String imageUrl,
                               Target targetType, VendorCategory targetCategory, UUID targetId) {
    }
}
