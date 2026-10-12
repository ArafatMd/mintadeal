package com.mintadeal.order;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Periodically cancels orders shops did not accept in time and closes unpaid checkouts. */
@Component
class OrderSweeper {

    private static final Logger log = LoggerFactory.getLogger(OrderSweeper.class);

    private final OrderService orders;
    private final PaymentService payments;

    OrderSweeper(OrderService orders, PaymentService payments) {
        this.orders = orders;
        this.payments = payments;
    }

    @Scheduled(fixedDelayString = "${mintadeal.orders.sweep-interval-ms}", initialDelay = 30_000)
    void sweep() {
        try {
            int late = orders.cancelUnacceptedOrders();
            int unpaid = payments.expireUnpaid();
            if (late + unpaid > 0) {
                log.info("Order sweep: {} unaccepted cancelled, {} unpaid checked", late, unpaid);
            }
        } catch (RuntimeException e) {
            log.error("Order sweep failed", e);
        }
    }
}
