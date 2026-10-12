package com.mintadeal.order;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.common.ApiException;

/**
 * Confirms online payments. A checkout is marked paid only on the provider's word: a signed webhook or a
 * server-side status fetch, never because the customer's app says so.
 */
@Service
public class PaymentService {

    private static final Logger log = LoggerFactory.getLogger(PaymentService.class);

    private final CheckoutRepository checkouts;
    private final ShopOrderRepository orders;
    private final OrderService orderService;
    private final PaymentGateways gateways;
    private final Redemptions redemptions;
    private final OrderProperties props;
    private final Clock clock;

    public PaymentService(CheckoutRepository checkouts, ShopOrderRepository orders, OrderService orderService,
                          PaymentGateways gateways, Redemptions redemptions, OrderProperties props, Clock clock) {
        this.checkouts = checkouts;
        this.orders = orders;
        this.orderService = orderService;
        this.redemptions = redemptions;
        this.gateways = gateways;
        this.props = props;
        this.clock = clock;
    }

    /** Asks the provider for the latest payment status, e.g. when the customer returns from the payment page. */
    @Transactional
    public Checkout refresh(UUID checkoutId) {
        Checkout c = checkouts.findById(checkoutId).orElseThrow(() -> ApiException.notFound("Checkout"));
        if (c.getPaymentStatus() != PaymentStatus.PENDING || c.getPaymentReference() == null) {
            return c;
        }
        PaymentGateway.Status s = gateways.named(c.getPaymentProvider()).fetch(c.getPaymentReference());
        if (s.paid()) {
            confirmPaid(c, s.paymentId());
        } else if (s.closed()) {
            expire(c, "The payment link expired");
        }
        return c;
    }

    @Transactional
    public void confirmPaidByReference(String reference, String paymentId) {
        checkouts.findByPaymentReference(reference).ifPresentOrElse(c -> confirmPaid(c, paymentId),
                () -> log.warn("Payment for unknown reference {}", reference));
    }

    /** Idempotent: webhooks and refreshes may report the same payment more than once. */
    void confirmPaid(Checkout c, String paymentId) {
        if (c.getPaymentStatus() == PaymentStatus.PAID) {
            return;
        }
        Instant now = clock.instant();
        boolean wasPending = c.getPaymentStatus() == PaymentStatus.PENDING;
        c.markPaid(paymentId, now);
        List<ShopOrder> list = orders.findByCheckoutIdOrderByCode(c.getId());
        if (!wasPending) {
            // Paid after the checkout was cancelled or expired: the orders are gone, so return the money.
            log.warn("Late payment {} for closed checkout {}; refunding", paymentId, c.getCode());
            list.forEach(o -> orderService.refund(c, o, now));
            return;
        }
        for (ShopOrder o : list) {
            if (o.getStatus() != OrderStatus.PENDING_PAYMENT) {
                continue;
            }
            if (o.getFulfilmentMode() == FulfilmentMode.VENUE_QR) {
                orderService.move(o, OrderStatus.ACCEPTED, ActorType.SYSTEM, null,
                        "Paid online. Show the QR code at the venue", now);
                redemptions.issue(o);
            } else {
                o.awaitAcceptance(now.plus(props.acceptTimeout()));
                orderService.move(o, OrderStatus.PLACED, ActorType.SYSTEM, null, "Paid online", now);
            }
        }
    }

    /** Closes unpaid checkouts whose payment time ran out, after one last check with the provider. */
    @Transactional
    public int expireUnpaid() {
        List<Checkout> overdue = checkouts.findByPaymentStatusAndPaymentDeadlineBefore(PaymentStatus.PENDING,
                clock.instant());
        for (Checkout c : overdue) {
            try {
                PaymentGateway.Status s = gateways.named(c.getPaymentProvider()).fetch(c.getPaymentReference());
                if (s.paid()) {
                    confirmPaid(c, s.paymentId());
                    continue;
                }
            } catch (RuntimeException e) {
                // If the provider cannot be reached, wait for the next sweep rather than cancel a possibly paid order.
                log.warn("Could not check payment for {}: {}", c.getCode(), e.getMessage());
                continue;
            }
            expire(c, "Payment was not completed in time");
        }
        return overdue.size();
    }

    private void expire(Checkout c, String reason) {
        Instant now = clock.instant();
        c.setPaymentStatus(PaymentStatus.EXPIRED);
        c.touch(now);
        for (ShopOrder o : orders.findByCheckoutIdOrderByCode(c.getId())) {
            if (o.getStatus() == OrderStatus.PENDING_PAYMENT) {
                orderService.cancel(o, ActorType.SYSTEM, null, reason, now);
            }
        }
    }
}
