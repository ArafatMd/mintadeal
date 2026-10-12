package com.mintadeal.notify;

import java.time.Clock;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Executor;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.support.TransactionTemplate;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.integrations.WhatsAppClient;
import com.mintadeal.order.ActorType;
import com.mintadeal.order.Checkout;
import com.mintadeal.order.CheckoutRepository;
import com.mintadeal.order.OrderStatus;
import com.mintadeal.order.OrderStatusEvent;
import com.mintadeal.order.ShopOrder;
import com.mintadeal.order.ShopOrderRepository;
import com.mintadeal.vendor.VendorRepository;

/**
 * WhatsApp order alerts: new orders to the shop, and progress to the customer. Sent only after the change is
 * committed, on a background thread, so a failing provider never blocks or undoes an order.
 */
@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    record Message(String event, String phone, String template, List<String> params) {
    }

    private final WhatsAppClient whatsApp;
    private final ShopOrderRepository orders;
    private final CheckoutRepository checkouts;
    private final VendorRepository vendors;
    private final NotificationRepository notifications;
    private final TransactionTemplate tx;
    private final Executor executor;
    private final Clock clock;

    public NotificationService(WhatsAppClient whatsApp, ShopOrderRepository orders, CheckoutRepository checkouts,
                               VendorRepository vendors, NotificationRepository notifications,
                               PlatformTransactionManager txManager,
                               @Qualifier("notificationExecutor") Executor executor, Clock clock) {
        this.whatsApp = whatsApp;
        this.orders = orders;
        this.checkouts = checkouts;
        this.vendors = vendors;
        this.notifications = notifications;
        // Always a fresh transaction: after commit, the order's own transaction can no longer save anything.
        this.tx = new TransactionTemplate(txManager);
        this.tx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        this.executor = executor;
        this.clock = clock;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onStatus(OrderStatusEvent e) {
        executor.execute(() -> {
            try {
                dispatch(e);
            } catch (RuntimeException ex) {
                log.warn("Notification for order {} failed: {}", e.shopOrderId(), ex.getMessage());
            }
        });
    }

    void dispatch(OrderStatusEvent e) {
        var cfg = whatsApp.config();
        if (!cfg.enabled()) {
            return;
        }
        List<Message> messages = tx.execute(status -> messagesFor(e, cfg.get("newOrderTemplate"),
                cfg.get("orderUpdateTemplate")));
        for (Message m : messages == null ? List.<Message>of() : messages) {
            String providerId = null;
            String error = null;
            try {
                providerId = whatsApp.sendTemplate(cfg, m.phone(), m.template(), m.params());
            } catch (RuntimeException ex) {
                error = ex.getMessage();
            }
            String finalProviderId = providerId;
            String finalError = error;
            tx.executeWithoutResult(s -> notifications.save(new Notification(m.event(), "WHATSAPP", m.phone(), e.shopOrderId(),
                    finalError == null ? "SENT" : "FAILED", finalProviderId, finalError, clock.instant())));
        }
    }

    private List<Message> messagesFor(OrderStatusEvent e, String newOrderTemplate, String updateTemplate) {
        ShopOrder o = orders.findById(e.shopOrderId()).orElse(null);
        if (o == null) {
            return List.of();
        }
        Checkout c = checkouts.findById(o.getCheckoutId()).orElseThrow();
        String shopPhone = vendors.findById(o.getVendorId()).map(v -> v.getPhone()).orElse(null);
        String items = o.getLines().isEmpty() ? "" : o.getLines().getFirst().getQuantity() + " x "
                + o.getLines().getFirst().getTitle() + (o.getLines().size() > 1 ? " and " + (o.getLines().size() - 1) + " more" : "");
        String total = rupees(o.getTotalMinor());
        boolean newForShop = e.status() == OrderStatus.PLACED
                || (e.status() == OrderStatus.ACCEPTED && o.getFulfilmentMode() == FulfilmentMode.VENUE_QR
                    && e.actor() == ActorType.SYSTEM);
        var messages = new java.util.ArrayList<Message>();
        if (newForShop && shopPhone != null) {
            messages.add(new Message("NEW_ORDER", shopPhone, newOrderTemplate,
                    List.of(o.getCode(), items, total, mode(o.getFulfilmentMode()))));
        }
        String update = switch (e.status()) {
            case ACCEPTED -> o.getFulfilmentMode() == FulfilmentMode.VENUE_QR
                    ? "confirmed. Show the QR code in the app at the venue" : "accepted by the shop";
            case READY -> "ready for pickup";
            case OUT_FOR_DELIVERY -> "out for delivery";
            case COMPLETED -> o.getFulfilmentMode() == FulfilmentMode.VENUE_QR ? "used. Enjoy!" : "completed";
            case CANCELLED -> e.actor() == ActorType.CUSTOMER ? null
                    : "cancelled: " + (o.getCancelReason() == null ? "" : o.getCancelReason());
            default -> null;
        };
        if (update != null) {
            messages.add(new Message("ORDER_" + e.status(), c.getContactPhone(), updateTemplate,
                    List.of(o.getCode(), o.getVendorName(), update)));
        }
        return messages;
    }

    private static String mode(FulfilmentMode m) {
        return switch (m) {
            case PICKUP -> "Pickup at your shop";
            case SHOP_DELIVERY -> "You deliver";
            case PARTNER_DELIVERY -> "Book a Mintadeal delivery partner";
            case VENUE_QR -> "Customer will show a QR at your venue";
        };
    }

    private static String rupees(long minor) {
        return minor % 100 == 0 ? "₹" + minor / 100 : String.format("₹%.2f", minor / 100.0);
    }

    /** For the admin log. */
    public List<Notification> forOrder(UUID orderId) {
        return notifications.findByOrderIdOrderByCreatedAt(orderId);
    }
}
