package com.mintadeal.review;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.admin.AuditService;
import com.mintadeal.common.ApiException;
import com.mintadeal.common.PageResponse;
import com.mintadeal.identity.User;
import com.mintadeal.identity.UserRepository;
import com.mintadeal.order.OrderStatus;
import com.mintadeal.order.ShopOrder;
import com.mintadeal.order.ShopOrderRepository;
import com.mintadeal.review.ReviewDtos.AdminReviewDto;
import com.mintadeal.review.ReviewDtos.OrderReview;
import com.mintadeal.review.ReviewDtos.RatingSummary;
import com.mintadeal.review.ReviewDtos.ReviewDto;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorRepository;

/** Ratings: only the customer of a completed order can rate it, within 30 days. */
@Service
public class ReviewService {

    static final Duration RATING_WINDOW = Duration.ofDays(30);

    private final ReviewRepository reviews;
    private final ShopOrderRepository orders;
    private final UserRepository users;
    private final VendorRepository vendors;
    private final AuditService audit;
    private final Clock clock;

    public ReviewService(ReviewRepository reviews, ShopOrderRepository orders, UserRepository users,
                         VendorRepository vendors, AuditService audit, Clock clock) {
        this.reviews = reviews;
        this.orders = orders;
        this.users = users;
        this.vendors = vendors;
        this.audit = audit;
        this.clock = clock;
    }

    /** Average rating and count for each shop that has visible reviews. */
    @Transactional(readOnly = true)
    public Map<UUID, RatingSummary> summaries(Collection<UUID> vendorIds) {
        Map<UUID, RatingSummary> out = new HashMap<>();
        if (vendorIds.isEmpty()) {
            return out;
        }
        for (Object[] row : reviews.summaries(vendorIds)) {
            out.put((UUID) row[0], new RatingSummary(Math.round(((Number) row[1]).doubleValue() * 10) / 10.0,
                    ((Number) row[2]).longValue()));
        }
        return out;
    }

    @Transactional(readOnly = true)
    public RatingSummary summary(UUID vendorId) {
        return summaries(java.util.List.of(vendorId)).getOrDefault(vendorId, RatingSummary.NONE);
    }

    @Transactional(readOnly = true)
    public OrderReview forOrder(UUID orderId, UUID customerId) {
        ShopOrder o = customersOrder(orderId, customerId);
        ReviewDto mine = reviews.findByShopOrderId(o.getId()).map(r -> toDto(r, o.getCode(), customerId)).orElse(null);
        return new OrderReview(canRate(o), mine);
    }

    @Transactional
    public ReviewDto rate(UUID orderId, UUID customerId, int rating, String comment) {
        ShopOrder o = customersOrder(orderId, customerId);
        if (!canRate(o)) {
            throw ApiException.badRequest("cannot_review",
                    o.getStatus() == OrderStatus.COMPLETED ? "Orders can be rated for 30 days after completion"
                            : "You can rate an order once it is completed");
        }
        Instant now = clock.instant();
        Review r = reviews.findByShopOrderId(o.getId())
                .orElseGet(() -> new Review(o.getId(), o.getVendorId(), customerId, now));
        r.rate(rating, blankToNull(comment), now);
        reviews.save(r);
        return toDto(r, o.getCode(), customerId);
    }

    @Transactional(readOnly = true)
    public PageResponse<ReviewDto> forShop(UUID vendorId, UUID viewerId, boolean includeHidden, int page) {
        PageRequest p = PageRequest.of(Math.max(page, 0), 20);
        Page<Review> result = includeHidden ? reviews.findByVendorIdOrderByCreatedAtDesc(vendorId, p)
                : reviews.findByVendorIdAndHiddenFalseOrderByCreatedAtDesc(vendorId, p);
        return new PageResponse<>(result.map(r -> toDto(r, orderCode(r), viewerId)).getContent(), result.getNumber(),
                result.getSize(), result.getTotalElements());
    }

    @Transactional
    public ReviewDto reply(UUID reviewId, Vendor shop, String reply) {
        Review r = reviews.findById(reviewId).filter(x -> x.getVendorId().equals(shop.getId()))
                .orElseThrow(() -> ApiException.notFound("Review"));
        r.reply(blankToNull(reply), clock.instant());
        return toDto(r, orderCode(r), null);
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminReviewDto> forAdmin(boolean hiddenOnly, int page) {
        PageRequest p = PageRequest.of(Math.max(page, 0), 30);
        Page<Review> result = hiddenOnly ? reviews.findByHiddenTrueOrderByCreatedAtDesc(p)
                : reviews.findAllByOrderByCreatedAtDesc(p);
        return new PageResponse<>(result.map(this::toAdmin).getContent(), result.getNumber(), result.getSize(),
                result.getTotalElements());
    }

    @Transactional
    public AdminReviewDto setHidden(UUID reviewId, boolean hidden, String reason) {
        Review r = reviews.findById(reviewId).orElseThrow(() -> ApiException.notFound("Review"));
        if (hidden) {
            r.hide(blankToNull(reason), clock.instant());
        } else {
            r.unhide(clock.instant());
        }
        audit.record(hidden ? "REVIEW_HIDDEN" : "REVIEW_SHOWN", "REVIEW", r.getId(), reason);
        return toAdmin(r);
    }

    private boolean canRate(ShopOrder o) {
        return o.getStatus() == OrderStatus.COMPLETED && o.getCompletedAt() != null
                && o.getCompletedAt().plus(RATING_WINDOW).isAfter(clock.instant());
    }

    private ShopOrder customersOrder(UUID orderId, UUID customerId) {
        return orders.findById(orderId).filter(o -> o.getCustomerId().equals(customerId))
                .orElseThrow(() -> ApiException.notFound("Order"));
    }

    private String orderCode(Review r) {
        return orders.findById(r.getShopOrderId()).map(ShopOrder::getCode).orElse(null);
    }

    private ReviewDto toDto(Review r, String orderCode, UUID viewerId) {
        String name = users.findById(r.getCustomerId()).map(ReviewService::shortName).orElse("A customer");
        return new ReviewDto(r.getId(), r.getRating(), r.getComment(), name, r.getReply(), r.getRepliedAt(),
                r.getCreatedAt(), orderCode, r.getCustomerId().equals(viewerId));
    }

    private AdminReviewDto toAdmin(Review r) {
        return new AdminReviewDto(r.getId(), r.getVendorId(),
                vendors.findById(r.getVendorId()).map(Vendor::getDisplayName).orElse(null), r.getRating(),
                r.getComment(), users.findById(r.getCustomerId()).map(User::getPhone).orElse(null), r.getReply(),
                orderCode(r), r.isHidden(), r.getHiddenReason(), r.getCreatedAt());
    }

    /** "Priya S." from "Priya Sharma"; "A customer" without a name. */
    static String shortName(User u) {
        String n = u.getName();
        if (n == null || n.isBlank()) {
            return "A customer";
        }
        String[] parts = n.trim().split("\\s+");
        return parts.length == 1 ? parts[0] : parts[0] + " " + Character.toUpperCase(parts[parts.length - 1].charAt(0)) + ".";
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
