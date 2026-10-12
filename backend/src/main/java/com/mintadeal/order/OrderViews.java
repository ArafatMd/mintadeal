package com.mintadeal.order;

import java.util.ArrayList;
import java.util.List;

import org.springframework.stereotype.Component;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.common.ApiException;
import com.mintadeal.order.CheckoutDtos.CheckoutDto;
import com.mintadeal.order.OrderDtos.Action;
import com.mintadeal.order.OrderDtos.AddressDto;
import com.mintadeal.order.OrderDtos.EventDto;
import com.mintadeal.order.OrderDtos.LineDto;
import com.mintadeal.order.OrderDtos.OrderDetail;
import com.mintadeal.order.OrderDtos.OrderSummary;
import com.mintadeal.order.OrderDtos.Party;
import com.mintadeal.order.OrderDtos.RefundDto;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorRepository;

/** Builds order views for each kind of viewer, including which actions that viewer may take. */
@Component
public class OrderViews {

    public enum Viewer {
        CUSTOMER, VENDOR, ADMIN
    }

    private final CheckoutRepository checkouts;
    private final ShopOrderRepository orders;
    private final OrderEventRepository events;
    private final RefundRepository refunds;
    private final VendorRepository vendors;

    OrderViews(CheckoutRepository checkouts, ShopOrderRepository orders, OrderEventRepository events,
               RefundRepository refunds, VendorRepository vendors) {
        this.checkouts = checkouts;
        this.orders = orders;
        this.events = events;
        this.refunds = refunds;
        this.vendors = vendors;
    }

    CheckoutDto checkout(Checkout c) {
        List<OrderSummary> list = orders.findByCheckoutIdOrderByCode(c.getId()).stream()
                .map(o -> summary(o, c)).toList();
        return new CheckoutDto(c.getId(), c.getCode(), c.getPaymentMethod(), c.getPaymentStatus(),
                c.getPaymentStatus() == PaymentStatus.PENDING ? c.getPaymentUrl() : null, c.getPaymentDeadline(),
                c.getItemsTotalMinor(), c.getDeliveryTotalMinor(), c.getGrandTotalMinor(), c.getCreatedAt(), list);
    }

    OrderSummary summary(ShopOrder o) {
        return summary(o, checkoutOf(o));
    }

    OrderSummary summary(ShopOrder o, Checkout c) {
        // Number of different items, so "Atta and 1 more" never counts two packs of atta as two items.
        int count = o.getLines().size();
        return new OrderSummary(o.getId(), o.getCode(), c.getCode(), o.getVendorId(), o.getVendorName(),
                o.getStatus(), o.getFulfilmentMode(), count,
                o.getLines().isEmpty() ? null : o.getLines().getFirst().getTitle(), o.getTotalMinor(),
                c.getPaymentMethod(), c.getPaymentStatus(), o.getAcceptDeadline(), o.getCreatedAt());
    }

    OrderDetail detail(ShopOrder o, Viewer viewer) {
        Checkout c = checkoutOf(o);
        Vendor v = vendors.findById(o.getVendorId()).orElse(null);
        boolean seesCustomer = viewer != Viewer.CUSTOMER;
        AddressDto address = o.isDelivery() && c.hasAddress()
                ? new AddressDto(c.getAddressLine(), c.getAddressArea(), c.getAddressLandmark(),
                        c.getAddressLatitude(), c.getAddressLongitude())
                : null;
        return new OrderDetail(o.getId(), o.getCode(), c.getId(), c.getCode(), o.getStatus(), o.getFulfilmentMode(),
                new Party(o.getVendorName(), v == null ? null : v.getPhone()), o.getVendorId(),
                v == null ? null : v.getAddressLine() + ", " + v.getArea(),
                seesCustomer ? new Party(c.getContactName(), c.getContactPhone()) : null,
                address, c.getNote(),
                o.getLines().stream().map(LineDto::of).toList(),
                o.getItemsTotalMinor(), o.getDeliveryFeeMinor(), o.getTotalMinor(),
                c.getPaymentMethod(), c.getPaymentStatus(),
                viewer == Viewer.CUSTOMER && c.getPaymentStatus() == PaymentStatus.PENDING ? c.getPaymentUrl() : null,
                o.getAcceptDeadline(), o.getAcceptedAt(), o.getReadyAt(), o.getCompletedAt(), o.getCancelledAt(),
                o.getCancelledBy(), o.getCancelReason(),
                RefundDto.of(refunds.findByShopOrderId(o.getId()).orElse(null)),
                events.findByShopOrderIdOrderByCreatedAt(o.getId()).stream().map(EventDto::of).toList(),
                actions(o, viewer), o.getCreatedAt());
    }

    static List<Action> actions(ShopOrder o, Viewer viewer) {
        List<Action> actions = new ArrayList<>();
        FulfilmentMode mode = o.getFulfilmentMode();
        switch (viewer) {
            case CUSTOMER -> {
                if (o.getStatus() == OrderStatus.PENDING_PAYMENT) {
                    actions.add(Action.PAY);
                }
                if (o.getStatus() == OrderStatus.PENDING_PAYMENT || o.getStatus() == OrderStatus.PLACED) {
                    actions.add(Action.CANCEL);
                }
            }
            case VENDOR -> {
                switch (o.getStatus()) {
                    case PLACED -> {
                        actions.add(Action.ACCEPT);
                        actions.add(Action.REJECT);
                    }
                    case ACCEPTED -> actions.add(mode == FulfilmentMode.PICKUP ? Action.MARK_READY
                            : mode == FulfilmentMode.VENUE_QR ? Action.COMPLETE : Action.OUT_FOR_DELIVERY);
                    case READY, OUT_FOR_DELIVERY -> actions.add(Action.COMPLETE);
                    default -> {
                    }
                }
            }
            case ADMIN -> {
                if (o.getStatus().isOpen()) {
                    actions.add(Action.CANCEL);
                }
            }
        }
        return actions;
    }

    private Checkout checkoutOf(ShopOrder o) {
        return checkouts.findById(o.getCheckoutId()).orElseThrow(() -> ApiException.notFound("Checkout"));
    }
}
