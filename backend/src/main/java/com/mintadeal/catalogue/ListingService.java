package com.mintadeal.catalogue;

import java.time.Clock;
import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.admin.AuditService;
import com.mintadeal.catalogue.ListingDtos.ListingRequest;
import com.mintadeal.common.ApiException;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorService;

@Service
public class ListingService {

    private final ListingRepository listings;
    private final VendorService vendors;
    private final AuditService audit;
    private final Clock clock;

    public ListingService(ListingRepository listings, VendorService vendors, AuditService audit, Clock clock) {
        this.listings = listings;
        this.vendors = vendors;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<Listing> mine(UUID userId) {
        return listings.findByVendorIdOrderByUpdatedAtDesc(vendors.ownedBy(userId).getId());
    }

    @Transactional
    public Listing create(UUID userId, ListingRequest req) {
        Vendor vendor = vendors.approvedOwnedBy(userId);
        Listing listing = new Listing(vendor.getId(), req.listingType(), clock.instant());
        apply(vendor, listing, req);
        return listings.save(listing);
    }

    @Transactional
    public Listing update(UUID userId, UUID listingId, ListingRequest req) {
        Vendor vendor = vendors.approvedOwnedBy(userId);
        Listing listing = owned(vendor, listingId);
        if (req.listingType() != listing.getListingType()) {
            throw ApiException.badRequest("type_immutable", "A product cannot be changed into an offer, or back");
        }
        apply(vendor, listing, req);
        return listing;
    }

    @Transactional
    public Listing publish(UUID userId, UUID listingId) {
        Vendor vendor = vendors.approvedOwnedBy(userId);
        Listing listing = owned(vendor, listingId);
        // Re-check against the shop's current settings: they may have changed since the listing was saved.
        validateModes(vendor, listing.getListingType(), listing.getFulfilmentModes());
        if (listing.getValidTo() != null && !listing.getValidTo().isAfter(clock.instant())) {
            throw ApiException.badRequest("offer_expired", "Update the end date before publishing");
        }
        listing.setStatus(ListingStatus.ACTIVE);
        listing.touch(clock.instant());
        return listing;
    }

    @Transactional
    public Listing pause(UUID userId, UUID listingId) {
        Listing listing = owned(vendors.approvedOwnedBy(userId), listingId);
        listing.setStatus(ListingStatus.PAUSED);
        listing.touch(clock.instant());
        return listing;
    }

    @Transactional
    public Listing updateStock(UUID userId, UUID listingId, Integer stock) {
        Listing listing = owned(vendors.approvedOwnedBy(userId), listingId);
        listing.setStock(stock);
        listing.touch(clock.instant());
        return listing;
    }

    @Transactional
    public Listing remove(UUID listingId, String reason) {
        Listing listing = listings.findById(listingId).orElseThrow(() -> ApiException.notFound("Listing"));
        listing.setStatus(ListingStatus.REMOVED);
        listing.setRemovedReason(reason);
        listing.touch(clock.instant());
        audit.record("LISTING_REMOVED", "LISTING", listingId, reason);
        return listing;
    }

    private Listing owned(Vendor vendor, UUID listingId) {
        Listing listing = listings.findById(listingId)
                .filter(l -> l.getVendorId().equals(vendor.getId()))
                .orElseThrow(() -> ApiException.notFound("Listing"));
        if (listing.getStatus() == ListingStatus.REMOVED) {
            throw ApiException.forbidden("listing_removed",
                    "This listing was removed by Mintadeal: " + listing.getRemovedReason());
        }
        return listing;
    }

    private void apply(Vendor vendor, Listing l, ListingRequest r) {
        validateModes(vendor, r.listingType(), r.fulfilmentModes());
        if (r.offerPriceMinor() != null && r.offerPriceMinor() >= r.priceMinor()) {
            throw ApiException.badRequest("offer_price_not_lower", "The offer price must be lower than the price");
        }
        Instant now = clock.instant();
        if (r.validFrom() != null && r.validTo() != null && !r.validTo().isAfter(r.validFrom())) {
            throw ApiException.badRequest("invalid_validity", "The end date must be after the start date");
        }
        if (r.listingType() == ListingType.OFFER && r.validTo() == null) {
            throw ApiException.badRequest("offer_needs_end", "Offers need an end date so the QR code can expire");
        }
        if (r.validTo() != null && !r.validTo().isAfter(now)) {
            throw ApiException.badRequest("invalid_validity", "The end date must be in the future");
        }
        l.setTitle(r.title().trim());
        l.setDescription(blankToNull(r.description()));
        l.setCategory(r.category() != null ? r.category() : vendor.getCategory());
        l.setImageUrl(blankToNull(r.imageUrl()));
        l.setPriceMinor(r.priceMinor());
        l.setOfferPriceMinor(r.offerPriceMinor());
        l.setStock(r.stock());
        l.setCapacityPerSlot(r.listingType() == ListingType.OFFER ? r.capacityPerSlot() : null);
        l.setTerms(blankToNull(r.terms()));
        l.setValidFrom(r.validFrom());
        l.setValidTo(r.validTo());
        l.setFulfilmentModes(r.fulfilmentModes());
        l.touch(now);
    }

    static void validateModes(Vendor vendor, ListingType type, Set<FulfilmentMode> modes) {
        if (modes == null || modes.isEmpty()) {
            throw ApiException.badRequest("fulfilment_required", "Choose at least one way to fulfil this listing");
        }
        if (type == ListingType.OFFER && !modes.equals(EnumSet.of(FulfilmentMode.VENUE_QR))) {
            throw ApiException.badRequest("offer_venue_only", "Offers are used at the venue with a QR code");
        }
        if (type == ListingType.PRODUCT && modes.contains(FulfilmentMode.VENUE_QR)) {
            throw ApiException.badRequest("product_no_venue_qr", "Products are delivered or picked up");
        }
        if (modes.contains(FulfilmentMode.SHOP_DELIVERY) && !vendor.isSelfDelivery()) {
            throw ApiException.badRequest("shop_delivery_off", "Turn on shop delivery in your shop settings first");
        }
        if (modes.contains(FulfilmentMode.PARTNER_DELIVERY) && !vendor.isPartnerDelivery()) {
            throw ApiException.badRequest("partner_delivery_off",
                    "Turn on partner delivery in your shop settings first");
        }
        if (modes.contains(FulfilmentMode.PICKUP) && !vendor.isPickup()) {
            throw ApiException.badRequest("pickup_off", "Turn on pickup in your shop settings first");
        }
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
