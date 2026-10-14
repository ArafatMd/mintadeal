package com.mintadeal.discovery;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
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
import com.mintadeal.discovery.DiscoveryDtos.ShopCard;
import com.mintadeal.discovery.DiscoveryDtos.ShopTag;
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
        return paginate(nearbyItems(lat, lng, filter, customerId), page, size);
    }

    @Transactional(readOnly = true)
    public PageResponse<DiscoveryItem> citywide(Double lat, Double lng, Filter filter, UUID customerId,
                                                int page, int size) {
        return paginate(citywideItems(lat, lng, filter, customerId), page, size);
    }

    /** Nearby deals grouped into shops, nearest (and followed) first. */
    @Transactional(readOnly = true)
    public PageResponse<ShopCard> nearbyShops(double lat, double lng, Filter filter, UUID customerId,
                                              int page, int size) {
        return paginate(shops(nearbyItems(lat, lng, filter, customerId)), page, size);
    }

    /** City-wide deals grouped into shops, most recently updated first. */
    @Transactional(readOnly = true)
    public PageResponse<ShopCard> citywideShops(Double lat, Double lng, Filter filter, UUID customerId,
                                                int page, int size) {
        return paginate(shops(citywideItems(lat, lng, filter, customerId)), page, size);
    }

    private List<DiscoveryItem> nearbyItems(double lat, double lng, Filter filter, UUID customerId) {
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
        return items;
    }

    private List<DiscoveryItem> citywideItems(Double lat, Double lng, Filter filter, UUID customerId) {
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
        return items;
    }

    /** Groups deals by shop, keeping the order in which each shop first appears. */
    private List<ShopCard> shops(List<DiscoveryItem> items) {
        Map<UUID, List<DiscoveryItem>> byShop = new LinkedHashMap<>();
        for (DiscoveryItem i : items) {
            byShop.computeIfAbsent(i.vendor().id(), k -> new ArrayList<>()).add(i);
        }
        Map<UUID, Long> followers = new HashMap<>();
        if (!byShop.isEmpty()) {
            for (Object[] row : follows.countFollowers(byShop.keySet())) {
                followers.put((UUID) row[0], (Long) row[1]);
            }
        }
        Map<UUID, String> taglines = new HashMap<>();
        vendors.findAllById(byShop.keySet()).forEach(v -> taglines.put(v.getId(), tagline(v.getDescription())));
        Instant now = clock.instant();
        Instant endOfToday = now.atZone(INDIA).toLocalDate().plusDays(1).atStartOfDay(INDIA).toInstant();
        List<ShopCard> cards = new ArrayList<>();
        byShop.forEach((vendorId, deals) -> {
            // The best deal is the biggest discount; it gives the card its cover image.
            List<DiscoveryItem> best = deals.stream()
                    .sorted(Comparator.comparing((DiscoveryItem i) -> discount(i)).reversed())
                    .toList();
            Integer bestDiscount = discount(best.getFirst()) > 0 ? discount(best.getFirst()) : null;
            String cover = best.stream().map(i -> i.listing().imageUrl()).filter(u -> u != null).findFirst()
                    .orElse(null);
            DiscoveryItem first = deals.getFirst();
            cards.add(new ShopCard(first.vendor(), taglines.get(vendorId), first.distanceKm(), first.followed(),
                    followers.getOrDefault(vendorId, 0L), deals.size(), bestDiscount, cover,
                    tag(deals, now, endOfToday)));
        });
        return cards;
    }

    private static final ZoneId INDIA = ZoneId.of("Asia/Kolkata");

    private static int discount(DiscoveryItem i) {
        return i.listing().discountPercent() == null ? 0 : i.listing().discountPercent();
    }

    private static ShopTag tag(List<DiscoveryItem> deals, Instant now, Instant endOfToday) {
        if (deals.stream().anyMatch(i -> i.listing().validTo() != null && i.listing().validTo().isBefore(endOfToday))) {
            return ShopTag.ENDS_TODAY;
        }
        if (deals.stream().anyMatch(i -> i.listing().createdAt().isAfter(now.minus(Duration.ofDays(7))))) {
            return ShopTag.NEW;
        }
        if (deals.stream().anyMatch(i -> i.deliverable()
                && (i.deliveryFeeMinor() == null || i.deliveryFeeMinor() == 0))) {
            return ShopTag.FREE_DELIVERY;
        }
        if (deals.stream().anyMatch(DiscoveryItem::venueOffer)) {
            return ShopTag.VENUE_OFFER;
        }
        return deals.stream().anyMatch(DiscoveryItem::deliverable) ? ShopTag.DELIVERY : ShopTag.PICKUP;
    }

    /** The first line of a shop's description, kept short for a card. */
    static String tagline(String description) {
        if (description == null || description.isBlank()) {
            return null;
        }
        String line = description.strip().split("\\R|(?<=[.!?])\\s", 2)[0].strip();
        if (line.endsWith(".")) {
            line = line.substring(0, line.length() - 1);
        }
        return line.length() <= 40 ? line : line.substring(0, 39).strip() + "…";
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
