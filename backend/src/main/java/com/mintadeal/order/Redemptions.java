package com.mintadeal.order;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.Objects;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.catalogue.Listing;
import com.mintadeal.catalogue.ListingRepository;
import com.mintadeal.common.ApiException;

/**
 * Venue offer QR codes. The QR holds a random server-checked reference, never order details; it works only at
 * the shop that sold the offer, only within the offer's dates, and only once.
 */
@Service
public class Redemptions {

    public static final String QR_PREFIX = "MINTADEAL:";

    /**
     * Result of checking a code before redeeming it.
     *
     * @param problem why it cannot be used, or null if it can
     */
    public record Check(boolean valid, String problem, UUID orderId, String orderCode, String title, int quantity,
                        String customerName, Instant validTo, Instant usedAt) {
    }

    /** The code from the QR, or the order number plus the last 4 digits of the customer's phone. */
    public record CodeRequest(String code, String orderCode, String phoneLast4) {
    }

    private final RedemptionRepository redemptions;
    private final ShopOrderRepository orders;
    private final CheckoutRepository checkouts;
    private final ListingRepository listings;
    private final OrderService orderService;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public Redemptions(RedemptionRepository redemptions, ShopOrderRepository orders, CheckoutRepository checkouts,
                       ListingRepository listings, OrderService orderService, Clock clock) {
        this.redemptions = redemptions;
        this.orders = orders;
        this.checkouts = checkouts;
        this.listings = listings;
        this.orderService = orderService;
        this.clock = clock;
    }

    /** Issues the QR code for a paid venue offer order. Idempotent. */
    void issue(ShopOrder o) {
        if (o.getFulfilmentMode() != FulfilmentMode.VENUE_QR || redemptions.findByShopOrderId(o.getId()).isPresent()) {
            return;
        }
        Instant from = null;
        Instant to = null;
        int quantity = 0;
        for (OrderLine line : o.getLines()) {
            quantity += line.getQuantity();
            Listing l = listings.findById(line.getListingId()).orElse(null);
            if (l == null) {
                continue;
            }
            // The code is valid only while every offer in the order is.
            if (l.getValidFrom() != null && (from == null || l.getValidFrom().isAfter(from))) {
                from = l.getValidFrom();
            }
            if (l.getValidTo() != null && (to == null || l.getValidTo().isBefore(to))) {
                to = l.getValidTo();
            }
        }
        byte[] bytes = new byte[24];
        random.nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        redemptions.save(new Redemption(o.getId(), o.getVendorId(), token, quantity, from, to, clock.instant()));
    }

    @Transactional(readOnly = true)
    public Check check(UUID vendorId, CodeRequest req) {
        Redemption r = find(vendorId, req);
        return evaluate(r, vendorId);
    }

    @Transactional
    public Check redeem(UUID vendorId, UUID actorId, CodeRequest req) {
        Redemption r = find(vendorId, req);
        Check check = evaluate(r, vendorId);
        if (!check.valid()) {
            throw ApiException.conflict("code_not_usable", check.problem());
        }
        Instant now = clock.instant();
        r.markUsed(actorId, now);
        ShopOrder o = orders.findById(r.getShopOrderId()).orElseThrow();
        orderService.move(o, OrderStatus.COMPLETED, ActorType.VENDOR, actorId,
                "Used at the venue (" + r.getQuantity() + (r.getQuantity() == 1 ? " person" : " people") + ")", now);
        return evaluate(r, vendorId);
    }

    private Redemption find(UUID vendorId, CodeRequest req) {
        if (req.code() != null && !req.code().isBlank()) {
            String token = req.code().trim();
            if (token.startsWith(QR_PREFIX)) {
                token = token.substring(QR_PREFIX.length());
            }
            return redemptions.findByToken(token)
                    .orElseThrow(() -> ApiException.notFound("This is not a Mintadeal offer code. Order"));
        }
        // Fallback when the camera or the customer's screen does not cooperate.
        if (req.orderCode() == null || req.phoneLast4() == null || !req.phoneLast4().trim().matches("\\d{4}")) {
            throw ApiException.badRequest("code_required",
                    "Scan the QR, or enter the order number and the last 4 digits of the customer's phone");
        }
        String code = req.orderCode().trim().toUpperCase();
        ShopOrder o = orders.findByVendorIdAndFulfilmentModeAndCodeStartingWith(vendorId, FulfilmentMode.VENUE_QR, code)
                .stream()
                .filter(x -> x.getCode().equals(code) || x.getCode().startsWith(code + "-"))
                .filter(x -> checkouts.findById(x.getCheckoutId())
                        .map(c -> c.getContactPhone().endsWith(req.phoneLast4().trim())).orElse(false))
                .findFirst()
                .orElseThrow(() -> ApiException.notFound("No offer with that order number and phone at your shop. Order"));
        return redemptions.findByShopOrderId(o.getId())
                .orElseThrow(() -> ApiException.conflict("not_paid", "This offer has not been paid yet"));
    }

    private Check evaluate(Redemption r, UUID vendorId) {
        ShopOrder o = orders.findById(r.getShopOrderId()).orElseThrow();
        Checkout c = checkouts.findById(o.getCheckoutId()).orElseThrow();
        Instant now = clock.instant();
        String title = o.getLines().isEmpty() ? "" : o.getLines().getFirst().getTitle();
        String problem = null;
        if (!Objects.equals(r.getVendorId(), vendorId)) {
            // Do not reveal another shop's order details.
            return new Check(false, "This code is for a different shop", null, null, null, 0, null, null, null);
        } else if (r.isUsed()) {
            problem = "Already used";
        } else if (o.getStatus() == OrderStatus.CANCELLED) {
            problem = "This order was cancelled";
        } else if (o.getStatus() != OrderStatus.ACCEPTED) {
            problem = "This order is not ready to use";
        } else if (r.getValidFrom() != null && r.getValidFrom().isAfter(now)) {
            problem = "Not valid yet";
        } else if (r.getValidTo() != null && !r.getValidTo().isAfter(now)) {
            problem = "This offer has expired";
        }
        return new Check(problem == null, problem, o.getId(), o.getCode(), title, r.getQuantity(), c.getContactName(),
                r.getValidTo(), r.getUsedAt());
    }
}
