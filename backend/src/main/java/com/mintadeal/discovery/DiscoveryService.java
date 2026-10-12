package com.mintadeal.discovery;

import java.time.Clock;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.catalogue.Listing;
import com.mintadeal.catalogue.ListingDtos.ListingDto;
import com.mintadeal.catalogue.ListingRepository;
import com.mintadeal.catalogue.ListingStatus;
import com.mintadeal.catalogue.ListingType;
import com.mintadeal.common.ApiException;
import com.mintadeal.common.Geo;
import com.mintadeal.common.PageResponse;
import com.mintadeal.customer.VendorFollowRepository;
import com.mintadeal.discovery.DiscoveryDtos.DiscoveryItem;
import com.mintadeal.discovery.DiscoveryDtos.Storefront;
import com.mintadeal.discovery.DiscoveryDtos.VendorSummary;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorCategory;
import com.mintadeal.vendor.VendorDtos.VendorPublicDto;
import com.mintadeal.vendor.VendorRepository;
import com.mintadeal.vendor.VendorType;

/**
 * Applies the "where listings appear" rules: Nearby only shows what this customer can actually receive;
 * Deals in Bangalore shows city-wide delivery and venue offers.
 */
@Service
public class DiscoveryService {

    public record Filter(VendorCategory category, ListingType type, String q, boolean followedOnly) {

        boolean matches(Candidate c) {
            if (category != null && c.listing().getCategory() != category) {
                return false;
            }
            if (type != null && c.listing().getListingType() != type) {
                return false;
            }
            if (q != null && !q.isBlank()) {
                String needle = q.trim().toLowerCase(Locale.ROOT);
                return c.listing().getTitle().toLowerCase(Locale.ROOT).contains(needle)
                        || c.vendor().getDisplayName().toLowerCase(Locale.ROOT).contains(needle)
                        || (c.listing().getDescription() != null
                            && c.listing().getDescription().toLowerCase(Locale.ROOT).contains(needle));
            }
            return true;
        }
    }

    private final DiscoveryRepository repo;
    private final VendorRepository vendors;
    private final ListingRepository listings;
    private final VendorFollowRepository follows;
    private final DiscoveryProperties props;
    private final Clock clock;

    public DiscoveryService(DiscoveryRepository repo, VendorRepository vendors, ListingRepository listings,
                            VendorFollowRepository follows, DiscoveryProperties props, Clock clock) {
        this.repo = repo;
        this.vendors = vendors;
        this.listings = listings;
        this.follows = follows;
        this.props = props;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public PageResponse<DiscoveryItem> nearby(double lat, double lng, Filter filter, UUID customerId,
                                              int page, int size) {
        double r = props.maxSearchRadiusKm();
        double dLat = r / 111.0;
        double dLng = r / (111.0 * Math.cos(Math.toRadians(lat)));
        Set<UUID> followed = followedBy(customerId);
        Instant now = clock.instant();
        List<DiscoveryItem> items = repo.nearbyCandidates(lat - dLat, lat + dLat, lng - dLng, lng + dLng).stream()
                .filter(c -> c.listing().isPurchasable(now))
                .filter(filter::matches)
                .filter(c -> !filter.followedOnly() || followed.contains(c.vendor().getId()))
                .map(c -> toItem(c, lat, lng, followed))
                .filter(i -> i.deliverable() || i.pickupAvailable() || i.venueOffer())
                .sorted(Comparator.comparing(DiscoveryItem::followed).reversed()
                        .thenComparing(DiscoveryItem::distanceKm)
                        .thenComparing(i -> i.listing().updatedAt(), Comparator.reverseOrder()))
                .toList();
        return paginate(items, page, size);
    }

    @Transactional(readOnly = true)
    public PageResponse<DiscoveryItem> citywide(Double lat, Double lng, Filter filter, UUID customerId,
                                                int page, int size) {
        Set<UUID> followed = followedBy(customerId);
        Instant now = clock.instant();
        List<DiscoveryItem> items = repo.citywideCandidates().stream()
                .filter(c -> c.listing().isPurchasable(now))
                .filter(filter::matches)
                .filter(c -> !filter.followedOnly() || followed.contains(c.vendor().getId()))
                .filter(c -> c.listing().getListingType() == ListingType.OFFER
                        || c.listing().getFulfilmentModes().stream().anyMatch(FulfilmentMode::isDelivery))
                .map(c -> toCitywideItem(c, lat, lng, followed))
                .sorted(Comparator.comparing((DiscoveryItem i) -> i.listing().updatedAt()).reversed())
                .toList();
        return paginate(items, page, size);
    }

    @Transactional(readOnly = true)
    public DiscoveryItem listing(UUID listingId, Double lat, Double lng, UUID customerId) {
        Candidate c = repo.byListingId(listingId).stream()
                .filter(x -> x.vendor().isApproved() && x.listing().getStatus() == ListingStatus.ACTIVE)
                .findFirst()
                .orElseThrow(() -> ApiException.notFound("Listing"));
        Set<UUID> followed = followedBy(customerId);
        return lat != null && lng != null ? toItem(c, lat, lng, followed) : toCitywideItem(c, null, null, followed);
    }

    @Transactional(readOnly = true)
    public Storefront storefront(UUID vendorId, Double lat, Double lng, UUID customerId) {
        Vendor vendor = vendors.findById(vendorId).filter(Vendor::isApproved)
                .orElseThrow(() -> ApiException.notFound("Shop"));
        Set<UUID> followed = followedBy(customerId);
        Instant now = clock.instant();
        List<DiscoveryItem> items = listings.findByVendorIdAndStatusOrderByUpdatedAtDesc(vendorId, ListingStatus.ACTIVE)
                .stream()
                .filter(l -> l.isPurchasable(now))
                .map(l -> lat != null && lng != null
                        ? toItem(new Candidate(l, vendor), lat, lng, followed)
                        : toCitywideItem(new Candidate(l, vendor), null, null, followed))
                .toList();
        Double distance = lat != null && lng != null ? round(Geo.distanceKm(lat, lng,
                vendor.getLatitude(), vendor.getLongitude())) : null;
        return new Storefront(VendorPublicDto.of(vendor), distance, followed.contains(vendorId),
                follows.countFollowers(vendorId), items);
    }

    private DiscoveryItem toItem(Candidate c, double lat, double lng, Set<UUID> followed) {
        Listing l = c.listing();
        Vendor v = c.vendor();
        double distance = Geo.distanceKm(lat, lng, v.getLatitude(), v.getLongitude());
        boolean deliverable = canDeliver(l, v) && v.deliversTo(distance);
        boolean pickup = l.getFulfilmentModes().contains(FulfilmentMode.PICKUP) && v.isPickup()
                && distance <= props.nearbyRadiusKm();
        boolean venue = l.getFulfilmentModes().contains(FulfilmentMode.VENUE_QR) && distance <= props.nearbyRadiusKm();
        return new DiscoveryItem(ListingDto.of(l), summary(v), round(distance), deliverable, pickup, venue,
                deliverable ? v.getDeliveryFeeMinor() : null, followed.contains(v.getId()));
    }

    /** City-wide view: a venue offer or city-wide delivery shop is available to anyone in Bengaluru. */
    private DiscoveryItem toCitywideItem(Candidate c, Double lat, Double lng, Set<UUID> followed) {
        Listing l = c.listing();
        Vendor v = c.vendor();
        boolean deliverable = canDeliver(l, v) && v.isCitywideDelivery();
        boolean venue = l.getFulfilmentModes().contains(FulfilmentMode.VENUE_QR);
        Double distance = lat != null && lng != null
                ? round(Geo.distanceKm(lat, lng, v.getLatitude(), v.getLongitude())) : null;
        boolean pickup = l.getFulfilmentModes().contains(FulfilmentMode.PICKUP) && v.isPickup();
        return new DiscoveryItem(ListingDto.of(l), summary(v), distance, deliverable, pickup, venue,
                deliverable ? v.getDeliveryFeeMinor() : null, followed.contains(v.getId()));
    }

    private static boolean canDeliver(Listing l, Vendor v) {
        return (l.getFulfilmentModes().contains(FulfilmentMode.SHOP_DELIVERY) && v.isSelfDelivery())
                || (l.getFulfilmentModes().contains(FulfilmentMode.PARTNER_DELIVERY) && v.isPartnerDelivery());
    }

    private static VendorSummary summary(Vendor v) {
        return new VendorSummary(v.getId(), v.getDisplayName(), v.getCategory(), v.getArea(), v.getLogoUrl(),
                v.getVendorType() == VendorType.INTERNAL);
    }

    private Set<UUID> followedBy(UUID customerId) {
        return customerId == null ? Set.of() : Set.copyOf(follows.vendorIdsFollowedBy(customerId));
    }

    private static double round(double km) {
        return Math.round(km * 10) / 10.0;
    }

    private static <T> PageResponse<T> paginate(List<T> all, int page, int size) {
        int safeSize = Math.clamp(size, 1, 100);
        int safePage = Math.max(page, 0);
        List<T> slice = all.stream().skip((long) safePage * safeSize).limit(safeSize).toList();
        return new PageResponse<>(slice, safePage, safeSize, all.size());
    }
}
