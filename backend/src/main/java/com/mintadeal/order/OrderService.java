package com.mintadeal.order;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.catalogue.ListingRepository;
import com.mintadeal.common.ApiException;
import com.mintadeal.finance.Bookkeeping;
import com.mintadeal.order.OrderDtos.Action;
import com.mintadeal.order.OrderViews.Viewer;

/** Every status change of a shop order goes through here, so the rules and the event trail stay in one place. */
@Service
public class OrderService {

    private static final Logger log = LoggerFactory.getLogger(OrderService.class);

    private final ShopOrderRepository orders;
    private final CheckoutRepository checkouts;
    private final OrderEventRepository events;
    private final RefundRepository refunds;
    private final ListingRepository listings;
    private final PaymentGateways gateways;
    private final OrderViews views;
    private final ApplicationEventPublisher publisher;
    private final Bookkeeping bookkeeping;
    private final Clock clock;

    public OrderService(ShopOrderRepository orders, CheckoutRepository checkouts, OrderEventRepository events,
                        RefundRepository refunds, ListingRepository listings, PaymentGateways gateways,
                        OrderViews views, ApplicationEventPublisher publisher, Bookkeeping bookkeeping, Clock clock) {
        this.bookkeeping = bookkeeping;
        this.orders = orders;
        this.checkouts = checkouts;
        this.events = events;
        this.refunds = refunds;
        this.listings = listings;
        this.gateways = gateways;
        this.views = views;
        this.publisher = publisher;
        this.clock = clock;
    }

    // --- Delivery partner milestones (called by the delivery module) ---

    @Transactional
    public void partnerPickedUp(UUID orderId, UUID agentId, String agentName) {
        ShopOrder o = orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Order"));
        move(o, OrderStatus.OUT_FOR_DELIVERY, ActorType.SYSTEM, agentId,
                "Picked up by delivery partner" + (agentName == null ? "" : " " + agentName), clock.instant());
    }

    @Transactional
    public void partnerDelivered(UUID orderId, UUID agentId) {
        ShopOrder o = orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Order"));
        move(o, OrderStatus.COMPLETED, ActorType.SYSTEM, agentId, "Delivered by the delivery partner", clock.instant());
    }

    /** A failed partner delivery hands the order back to the shop, which can book another rider or call the customer. */
    @Transactional
    public void partnerFailed(UUID orderId, UUID agentId, String reason) {
        ShopOrder o = orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Order"));
        if (o.getStatus() == OrderStatus.OUT_FOR_DELIVERY) {
            move(o, OrderStatus.ACCEPTED, ActorType.SYSTEM, agentId, "Delivery failed: " + reason, clock.instant());
        } else {
            events.save(new OrderEvent(o.getId(), o.getStatus(), ActorType.SYSTEM, agentId,
                    "Delivery partner could not take the job: " + reason, clock.instant()));
        }
    }

    /** Records a note on the order's history without changing its status. */
    @Transactional
    public void note(UUID orderId, ActorType actor, UUID actorId, String note) {
        ShopOrder o = orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Order"));
        events.save(new OrderEvent(o.getId(), o.getStatus(), actor, actorId, note, clock.instant()));
    }

    // --- Shop actions ---

    @Transactional
    public ShopOrder vendorAct(UUID vendorId, UUID actorId, UUID orderId, Action action, String reason) {
        ShopOrder o = orders.findById(orderId).filter(x -> x.getVendorId().equals(vendorId))
                .orElseThrow(() -> ApiException.notFound("Order"));
        require(o, Viewer.VENDOR, action);
        Instant now = clock.instant();
        switch (action) {
            case ACCEPT -> move(o, OrderStatus.ACCEPTED, ActorType.VENDOR, actorId, "Accepted by the shop", now);
            case REJECT -> {
                if (reason == null || reason.isBlank()) {
                    throw ApiException.badRequest("reason_required", "Tell the customer why you cannot take it");
                }
                cancel(o, ActorType.VENDOR, actorId, "Shop could not take the order: " + reason.trim(), now);
            }
            case MARK_READY -> move(o, OrderStatus.READY, ActorType.VENDOR, actorId, "Ready for pickup", now);
            case OUT_FOR_DELIVERY -> move(o, OrderStatus.OUT_FOR_DELIVERY, ActorType.VENDOR, actorId,
                    o.getFulfilmentMode() == FulfilmentMode.PARTNER_DELIVERY ? "Handed to the delivery partner"
                            : "Out for delivery", now);
            case COMPLETE -> move(o, OrderStatus.COMPLETED, ActorType.VENDOR, actorId, switch (o.getFulfilmentMode()) {
                case PICKUP -> "Collected by the customer";
                case VENUE_QR -> "Used at the venue";
                default -> "Delivered";
            }, now);
            default -> throw ApiException.badRequest("invalid_action", "Not a shop action");
        }
        return o;
    }

    // --- Customer actions ---

    /** Cancels before the shop accepts. Unpaid online checkouts are cancelled as a whole, with their payment link. */
    @Transactional
    public ShopOrder customerCancel(UUID customerId, UUID orderId) {
        ShopOrder o = orders.findById(orderId).filter(x -> x.getCustomerId().equals(customerId))
                .orElseThrow(() -> ApiException.notFound("Order"));
        require(o, Viewer.CUSTOMER, Action.CANCEL);
        Instant now = clock.instant();
        if (o.getStatus() == OrderStatus.PENDING_PAYMENT) {
            Checkout c = checkouts.findById(o.getCheckoutId()).orElseThrow();
            closePaymentLink(c);
            c.setPaymentStatus(PaymentStatus.CANCELLED);
            c.touch(now);
            for (ShopOrder sibling : orders.findByCheckoutIdOrderByCode(c.getId())) {
                if (sibling.getStatus() == OrderStatus.PENDING_PAYMENT) {
                    cancel(sibling, ActorType.CUSTOMER, customerId, "Cancelled before payment", now);
                }
            }
        } else {
            cancel(o, ActorType.CUSTOMER, customerId, "Cancelled by the customer", now);
        }
        return o;
    }

    // --- Admin and system ---

    @Transactional
    public ShopOrder adminCancel(UUID adminId, UUID orderId, String reason) {
        ShopOrder o = orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Order"));
        require(o, Viewer.ADMIN, Action.CANCEL);
        cancel(o, ActorType.ADMIN, adminId, "Cancelled by Mintadeal: " + reason.trim(), clock.instant());
        return o;
    }

    /** Cancels orders the shop did not accept in time. Returns how many were cancelled. */
    @Transactional
    public int cancelUnacceptedOrders() {
        Instant now = clock.instant();
        List<ShopOrder> late = orders.findByStatusAndAcceptDeadlineBefore(OrderStatus.PLACED, now);
        late.forEach(o -> cancel(o, ActorType.SYSTEM, null, "The shop did not respond in time", now));
        return late.size();
    }

    // --- Shared ---

    void move(ShopOrder o, OrderStatus next, ActorType actor, UUID actorId, String note, Instant now) {
        o.moveTo(next, now);
        events.save(new OrderEvent(o.getId(), next, actor, actorId, note, now));
        if (next == OrderStatus.COMPLETED) {
            bookkeeping.orderCompleted(o, checkouts.findById(o.getCheckoutId()).orElseThrow());
        }
        publisher.publishEvent(new OrderStatusEvent(o.getId(), next, actor));
    }

    /** Cancels, puts reserved stock back, and refunds the order's share if it was paid online. */
    void cancel(ShopOrder o, ActorType actor, UUID actorId, String reason, Instant now) {
        o.cancel(actor, reason, now);
        events.save(new OrderEvent(o.getId(), OrderStatus.CANCELLED, actor, actorId, reason, now));
        publisher.publishEvent(new OrderCancelledEvent(o.getId(), reason));
        publisher.publishEvent(new OrderStatusEvent(o.getId(), OrderStatus.CANCELLED, actor));
        for (OrderLine line : o.getLines()) {
            listings.findById(line.getListingId()).ifPresent(l -> {
                if (l.getStock() != null) {
                    l.setStock(l.getStock() + line.getQuantity());
                }
            });
        }
        Checkout c = checkouts.findById(o.getCheckoutId()).orElseThrow();
        if (c.getPaymentStatus() == PaymentStatus.PAID) {
            refund(c, o, now);
        }
    }

    void refund(Checkout c, ShopOrder o, Instant now) {
        if (refunds.findByShopOrderId(o.getId()).isPresent()) {
            return;
        }
        Refund refund = refunds.save(new Refund(c.getId(), o.getId(), o.getTotalMinor(), now));
        attemptRefund(refund, c, o, now);
    }

    private void attemptRefund(Refund refund, Checkout c, ShopOrder o, Instant now) {
        try {
            String id = gateways.named(c.getPaymentProvider())
                    .refund(c.getProviderPaymentId(), refund.getAmountMinor(), o.getCode());
            refund.processed(id, now);
            bookkeeping.refundProcessed(refund.getId(), o.getCode(), refund.getAmountMinor());
        } catch (RuntimeException e) {
            // The cancellation stands; the refund is retried by an admin. Never lose the record of money owed.
            log.warn("Refund for order {} failed: {}", o.getCode(), e.getMessage());
            refund.failed(e.getMessage(), now);
        }
    }

    /** An admin retries a refund that the payment provider rejected or could not be reached for. */
    @Transactional
    public Refund retryRefund(UUID refundId) {
        Refund refund = refunds.findById(refundId).orElseThrow(() -> ApiException.notFound("Refund"));
        if (refund.getStatus() != RefundStatus.FAILED) {
            throw ApiException.conflict("refund_not_failed", "Only failed refunds can be retried");
        }
        ShopOrder o = orders.findById(refund.getShopOrderId()).orElseThrow();
        Checkout c = checkouts.findById(refund.getCheckoutId()).orElseThrow();
        attemptRefund(refund, c, o, clock.instant());
        return refund;
    }

    private void closePaymentLink(Checkout c) {
        if (c.getPaymentReference() == null) {
            return;
        }
        try {
            gateways.named(c.getPaymentProvider()).cancel(c.getPaymentReference());
        } catch (RuntimeException e) {
            log.warn("Could not cancel payment link for {}: {}", c.getCode(), e.getMessage());
        }
    }

    private void require(ShopOrder o, Viewer viewer, Action action) {
        if (!views.actions(o, viewer).contains(action)) {
            throw ApiException.conflict("invalid_transition",
                    "This order is " + o.getStatus().name().toLowerCase().replace('_', ' ') + " and cannot be "
                            + switch (action) {
                                case ACCEPT -> "accepted";
                                case REJECT -> "rejected";
                                case MARK_READY -> "marked ready";
                                case OUT_FOR_DELIVERY -> "sent out for delivery";
                                case COMPLETE -> "completed";
                                case CANCEL -> "cancelled";
                                case PAY -> "paid";
                                case REDEEM -> "redeemed";
                                case REQUEST_DELIVERY, CANCEL_DELIVERY -> "changed";
                            } + " now");
        }
    }
}
