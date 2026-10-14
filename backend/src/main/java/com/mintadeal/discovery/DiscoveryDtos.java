package com.mintadeal.discovery;

import java.util.List;
import java.util.UUID;

import com.mintadeal.catalogue.ListingDtos.ListingDto;
import com.mintadeal.routing.RoadRouter.Road;
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
     * @param distanceKm  straight-line distance; null when the customer did not share a location
     * @param roadKm      distance by road, when road routing is switched on and found a route; else null
     * @param roadMinutes travel time by road, allowing for traffic; null like {@code roadKm}
     */
    public record DiscoveryItem(ListingDto listing, VendorSummary vendor, Double distanceKm,
                                boolean deliverable, boolean pickupAvailable, boolean venueOffer,
                                Long deliveryFeeMinor, boolean followed, Double roadKm, Integer roadMinutes) {

        DiscoveryItem withRoad(Road road) {
            return road == null ? this : new DiscoveryItem(listing, vendor, distanceKm, deliverable, pickupAvailable,
                    venueOffer, deliveryFeeMinor, followed, road.km(), road.minutes());
        }
    }

    /** Why a shop card stands out, shown as a small coloured pill. */
    public enum ShopTag { ENDS_TODAY, NEW, FREE_DELIVERY, VENUE_OFFER, DELIVERY, PICKUP }

    /**
     * A shop on the home screen, summarising the deals of it that this customer can get.
     *
     * @param tagline         the first line of the shop's description, or null
     * @param bestDiscountPercent the largest discount among its deals, or null when none is discounted
     * @param rating          average of visible reviews, one decimal; null when there are none
     * @param coverImageUrl   the shop's cover photo, else the image of its best deal that has one, or null
     * @param roadKm          see {@link DiscoveryItem}
     */
    public record ShopCard(VendorSummary vendor, String tagline, Double distanceKm, boolean followed,
                           long followers, int dealCount, Integer bestDiscountPercent, String coverImageUrl,
                           ShopTag tag, Double rating, long ratingCount, Double roadKm, Integer roadMinutes) {

        ShopCard withRoad(Road road) {
            return road == null ? this : new ShopCard(vendor, tagline, distanceKm, followed, followers, dealCount,
                    bestDiscountPercent, coverImageUrl, tag, rating, ratingCount, road.km(), road.minutes());
        }
    }

    public record Storefront(VendorPublicDto vendor, Double distanceKm, boolean followed, long followers,
                             List<DiscoveryItem> listings, Double rating, long ratingCount, Double roadKm,
                             Integer roadMinutes) {
    }
}
