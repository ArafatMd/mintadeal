package com.mintadeal.discovery;

import java.util.List;
import java.util.UUID;

import com.mintadeal.catalogue.ListingDtos.ListingDto;
import com.mintadeal.vendor.VendorCategory;
import com.mintadeal.vendor.VendorDtos.VendorPublicDto;

public final class DiscoveryDtos {

    private DiscoveryDtos() {
    }

    public record VendorSummary(UUID id, String displayName, VendorCategory category, String area,
                                String logoUrl, boolean mintadealOwn) {
    }

    /**
     * A listing as a particular customer sees it: how it can reach them and how far away the shop is.
     *
     * @param distanceKm null when the customer did not share a location
     */
    public record DiscoveryItem(ListingDto listing, VendorSummary vendor, Double distanceKm,
                                boolean deliverable, boolean pickupAvailable, boolean venueOffer,
                                Long deliveryFeeMinor, boolean followed) {
    }

    /** Why a shop card stands out, shown as a small coloured pill. */
    public enum ShopTag { ENDS_TODAY, NEW, FREE_DELIVERY, VENUE_OFFER, DELIVERY, PICKUP }

    /**
     * A shop on the home screen, summarising the deals of it that this customer can get.
     *
     * @param tagline         the first line of the shop's description, or null
     * @param bestDiscountPercent the largest discount among its deals, or null when none is discounted
     * @param coverImageUrl   the image of its best deal that has one, or null
     */
    public record ShopCard(VendorSummary vendor, String tagline, Double distanceKm, boolean followed,
                           long followers, int dealCount, Integer bestDiscountPercent, String coverImageUrl,
                           ShopTag tag) {
    }

    public record Storefront(VendorPublicDto vendor, Double distanceKm, boolean followed, long followers,
                             List<DiscoveryItem> listings) {
    }
}
