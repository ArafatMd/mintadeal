package com.mintadeal.banner;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.admin.AuditService;
import com.mintadeal.banner.BannerDtos.BannerDto;
import com.mintadeal.banner.BannerDtos.BannerRequest;
import com.mintadeal.banner.BannerDtos.PublicBanner;
import com.mintadeal.banner.HomeBanner.Scope;
import com.mintadeal.catalogue.Listing;
import com.mintadeal.catalogue.ListingRepository;
import com.mintadeal.catalogue.ListingStatus;
import com.mintadeal.common.ApiException;
import com.mintadeal.common.CurrentUser;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorRepository;

@Service
public class BannerService {

    private final HomeBannerRepository banners;
    private final VendorRepository vendors;
    private final ListingRepository listings;
    private final AuditService audit;
    private final Clock clock;

    public BannerService(HomeBannerRepository banners, VendorRepository vendors, ListingRepository listings,
                         AuditService audit, Clock clock) {
        this.banners = banners;
        this.vendors = vendors;
        this.listings = listings;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<BannerDto> all() {
        Instant now = clock.instant();
        return banners.findAllByOrderByPositionAscCreatedAtDesc().stream().map(b -> toDto(b, now)).toList();
    }

    @Transactional
    public BannerDto create(BannerRequest r) {
        validate(r);
        HomeBanner b = new HomeBanner(CurrentUser.id(), clock.instant());
        b.apply(r, clock.instant());
        banners.save(b);
        audit.record("BANNER_CREATED", "HOME_BANNER", b.getId(), b.getTitle());
        return toDto(b, clock.instant());
    }

    @Transactional
    public BannerDto update(UUID id, BannerRequest r) {
        validate(r);
        HomeBanner b = banners.findById(id).orElseThrow(() -> ApiException.notFound("Banner"));
        b.apply(r, clock.instant());
        audit.record("BANNER_UPDATED", "HOME_BANNER", b.getId(), b.getTitle());
        return toDto(b, clock.instant());
    }

    @Transactional
    public void delete(UUID id) {
        HomeBanner b = banners.findById(id).orElseThrow(() -> ApiException.notFound("Banner"));
        banners.delete(b);
        audit.record("BANNER_DELETED", "HOME_BANNER", id, b.getTitle());
    }

    /** Banners customers see now in this view; ones whose shop or product is no longer live are skipped. */
    @Transactional(readOnly = true)
    public List<PublicBanner> live(Scope view) {
        Instant now = clock.instant();
        return banners.findByActiveTrueOrderByPositionAscCreatedAtDesc().stream()
                .filter(b -> b.isLive(now) && b.shownIn(view))
                .filter(this::targetIsLive)
                .map(b -> new PublicBanner(b.getId(), b.getTitle(), b.getSubtitle(), b.getKicker(), b.getImageUrl(),
                        b.getTargetType(), b.getTargetCategory(), b.getTargetId()))
                .toList();
    }

    private boolean targetIsLive(HomeBanner b) {
        return switch (b.getTargetType()) {
            case NONE, CATEGORY -> true;
            case SHOP -> vendors.findById(b.getTargetId()).filter(Vendor::isApproved).isPresent();
            case LISTING -> listings.findById(b.getTargetId())
                    .filter(l -> l.getStatus() == ListingStatus.ACTIVE)
                    .flatMap(l -> vendors.findById(l.getVendorId())).filter(Vendor::isApproved).isPresent();
        };
    }

    private void validate(BannerRequest r) {
        if (r.startsAt() != null && r.endsAt() != null && !r.endsAt().isAfter(r.startsAt())) {
            throw ApiException.badRequest("invalid_dates", "The end must be after the start");
        }
        switch (r.targetType()) {
            case NONE -> { }
            case CATEGORY -> {
                if (r.targetCategory() == null) {
                    throw ApiException.badRequest("category_required", "Choose the category this banner opens");
                }
            }
            case SHOP -> {
                if (r.targetId() == null || vendors.findById(r.targetId()).isEmpty()) {
                    throw ApiException.badRequest("shop_required", "Choose the shop this banner opens");
                }
            }
            case LISTING -> {
                if (r.targetId() == null || listings.findById(r.targetId()).isEmpty()) {
                    throw ApiException.badRequest("listing_required", "Choose the product this banner opens");
                }
            }
        }
    }

    private BannerDto toDto(HomeBanner b, Instant now) {
        String targetName = switch (b.getTargetType()) {
            case NONE -> null;
            case CATEGORY -> b.getTargetCategory() == null ? null : b.getTargetCategory().name();
            case SHOP -> vendors.findById(b.getTargetId()).map(Vendor::getDisplayName).orElse(null);
            case LISTING -> listings.findById(b.getTargetId()).map(Listing::getTitle).orElse(null);
        };
        return new BannerDto(b.getId(), b.getTitle(), b.getSubtitle(), b.getKicker(), b.getImageUrl(),
                b.getTargetType(), b.getTargetCategory(), b.getTargetId(), targetName, b.getScope(),
                b.getStartsAt(), b.getEndsAt(), b.getPosition(), b.isActive(), b.isLive(now) && targetIsLive(b),
                b.getUpdatedAt());
    }
}
