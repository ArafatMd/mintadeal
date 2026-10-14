package com.mintadeal.review;

import java.time.Instant;
import java.util.UUID;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public final class ReviewDtos {

    private ReviewDtos() {
    }

    public record RateRequest(@Min(1) @Max(5) int rating, @Size(max = 500) String comment) {
    }

    public record ReplyRequest(@Size(max = 500) String reply) {
    }

    public record HideRequest(@Size(max = 300) String reason) {
    }

    /** A shop's average rating, rounded to one decimal, and how many visible reviews it has. */
    public record RatingSummary(double average, long count) {

        public static final RatingSummary NONE = new RatingSummary(0, 0);
    }

    /**
     * A review as customers and shops see it. Customers are shown by first name and last initial only.
     *
     * @param mine whether the signed-in customer wrote it
     */
    public record ReviewDto(UUID id, int rating, String comment, String customerName, String reply,
                            Instant repliedAt, Instant createdAt, String orderCode, boolean mine) {
    }

    /** What the order screen needs: whether the customer may rate it, and their review if any. */
    public record OrderReview(boolean canReview, ReviewDto review) {
    }

    /** Admin view, including hidden reviews and who wrote them. */
    public record AdminReviewDto(UUID id, UUID vendorId, String vendorName, int rating, String comment,
                                 String customerPhone, String reply, String orderCode, boolean hidden,
                                 String hiddenReason, Instant createdAt) {
    }
}
