package com.mintadeal.banner;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

import com.mintadeal.vendor.VendorCategory;

/** A banner an admin puts on the customer home screen, optionally opening a category, shop or product. */
@Entity
@Table(name = "home_banner")
public class HomeBanner {

    /** What tapping the banner opens. */
    public enum Target { NONE, CATEGORY, SHOP, LISTING }

    /** Which home view shows it. */
    public enum Scope { NEARBY, CITYWIDE, BOTH }

    @Id
    private UUID id;

    @Column(nullable = false)
    private String title;

    private String subtitle;

    private String kicker;

    @Column(nullable = false)
    private String imageUrl;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Target targetType;

    @Enumerated(EnumType.STRING)
    private VendorCategory targetCategory;

    private UUID targetId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Scope scope;

    private Instant startsAt;

    private Instant endsAt;

    private int position;

    private boolean active;

    @Column(nullable = false)
    private UUID createdBy;

    @Column(nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    @Version
    private Long version;

    protected HomeBanner() {
    }

    HomeBanner(UUID createdBy, Instant now) {
        this.id = UUID.randomUUID();
        this.createdBy = createdBy;
        this.createdAt = now;
    }

    void apply(BannerDtos.BannerRequest r, Instant now) {
        this.title = r.title().trim();
        this.subtitle = blankToNull(r.subtitle());
        this.kicker = blankToNull(r.kicker());
        this.imageUrl = r.imageUrl().trim();
        this.targetType = r.targetType();
        this.targetCategory = r.targetType() == Target.CATEGORY ? r.targetCategory() : null;
        this.targetId = r.targetType() == Target.SHOP || r.targetType() == Target.LISTING ? r.targetId() : null;
        this.scope = r.scope();
        this.startsAt = r.startsAt();
        this.endsAt = r.endsAt();
        this.position = r.position();
        this.active = r.active();
        this.updatedAt = now;
    }

    /** Whether customers see it at this moment. */
    boolean isLive(Instant now) {
        return active && (startsAt == null || !now.isBefore(startsAt)) && (endsAt == null || now.isBefore(endsAt));
    }

    boolean shownIn(Scope view) {
        return scope == Scope.BOTH || scope == view;
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    public UUID getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public String getSubtitle() {
        return subtitle;
    }

    public String getKicker() {
        return kicker;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public Target getTargetType() {
        return targetType;
    }

    public VendorCategory getTargetCategory() {
        return targetCategory;
    }

    public UUID getTargetId() {
        return targetId;
    }

    public Scope getScope() {
        return scope;
    }

    public Instant getStartsAt() {
        return startsAt;
    }

    public Instant getEndsAt() {
        return endsAt;
    }

    public int getPosition() {
        return position;
    }

    public boolean isActive() {
        return active;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
