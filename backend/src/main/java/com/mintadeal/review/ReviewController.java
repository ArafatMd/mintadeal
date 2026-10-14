package com.mintadeal.review;

import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.CurrentUser;
import com.mintadeal.common.PageResponse;
import com.mintadeal.review.ReviewDtos.AdminReviewDto;
import com.mintadeal.review.ReviewDtos.HideRequest;
import com.mintadeal.review.ReviewDtos.OrderReview;
import com.mintadeal.review.ReviewDtos.RateRequest;
import com.mintadeal.review.ReviewDtos.ReplyRequest;
import com.mintadeal.review.ReviewDtos.ReviewDto;
import com.mintadeal.vendor.VendorService;

@RestController
public class ReviewController {

    private final ReviewService service;
    private final VendorService vendors;

    public ReviewController(ReviewService service, VendorService vendors) {
        this.service = service;
        this.vendors = vendors;
    }

    // --- Customers ---

    @GetMapping("/api/customer/orders/{id}/review")
    public OrderReview forOrder(@PathVariable UUID id) {
        return service.forOrder(id, CurrentUser.id());
    }

    @PutMapping("/api/customer/orders/{id}/review")
    public ReviewDto rate(@PathVariable UUID id, @Valid @RequestBody RateRequest req) {
        return service.rate(id, CurrentUser.id(), req.rating(), req.comment());
    }

    /** Public: a shop's visible reviews, newest first. */
    @GetMapping("/api/discovery/vendors/{id}/reviews")
    public PageResponse<ReviewDto> shopReviews(@PathVariable UUID id, @RequestParam(defaultValue = "0") int page) {
        return service.forShop(id, CurrentUser.idOrNull(), false, page);
    }

    // --- Shops ---

    @GetMapping("/api/vendor/reviews")
    public PageResponse<ReviewDto> mine(@RequestParam(defaultValue = "0") int page) {
        return service.forShop(vendors.ownedBy(CurrentUser.id()).getId(), null, false, page);
    }

    @PutMapping("/api/vendor/reviews/{id}/reply")
    public ReviewDto reply(@PathVariable UUID id, @Valid @RequestBody ReplyRequest req) {
        return service.reply(id, vendors.ownedBy(CurrentUser.id()), req.reply());
    }

    // --- Admins ---

    @GetMapping("/api/admin/reviews")
    public PageResponse<AdminReviewDto> all(@RequestParam(defaultValue = "false") boolean hiddenOnly,
                                            @RequestParam(defaultValue = "0") int page) {
        return service.forAdmin(hiddenOnly, page);
    }

    @PostMapping("/api/admin/reviews/{id}/hide")
    public AdminReviewDto hide(@PathVariable UUID id, @Valid @RequestBody HideRequest req) {
        return service.setHidden(id, true, req.reason());
    }

    @PostMapping("/api/admin/reviews/{id}/show")
    public AdminReviewDto show(@PathVariable UUID id) {
        return service.setHidden(id, false, null);
    }
}
