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

    public record Storefront(VendorPublicDto vendor, Double distanceKm, boolean followed, long followers,
                             List<DiscoveryItem> listings) {
    }
}
