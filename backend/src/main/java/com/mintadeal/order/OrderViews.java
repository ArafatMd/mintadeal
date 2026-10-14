package com.mintadeal.order;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;

import org.springframework.stereotype.Component;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.common.ApiException;
import com.mintadeal.delivery.DeliveryJobRepository;
import com.mintadeal.delivery.JobStatus;
import com.mintadeal.identity.User;
import com.mintadeal.identity.UserRepository;
import com.mintadeal.order.CheckoutDtos.CheckoutDto;
import com.mintadeal.order.OrderDtos.Action;
import com.mintadeal.order.OrderDtos.AddressDto;
import com.mintadeal.order.OrderDtos.DeliveryInfo;
import com.mintadeal.order.OrderDtos.RedemptionInfo;
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
    private final DeliveryJobRepository jobs;
    private final RedemptionRepository redemptions;
    private final UserRepository users;

    OrderViews(CheckoutRepository checkouts, ShopOrderRepository orders, OrderEventRepository events,
               RefundRepository refunds, VendorRepository vendors, DeliveryJobRepository jobs,
               RedemptionRepository redemptions, UserRepository users) {
        this.checkouts = checkouts;
        this.orders = orders;
        this.events = events;
        this.refunds = refunds;
        this.vendors = vendors;
        this.jobs = jobs;
        this.redemptions = redemptions;
        this.users = users;
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
                delivery(o, viewer), redemption(o, viewer),
                events.findByShopOrderIdOrderByCreatedAt(o.getId()).stream().map(EventDto::of).toList(),
                actions(o, viewer), o.getCreatedAt());
    }

    private DeliveryInfo delivery(ShopOrder o, Viewer viewer) {
        if (o.getFulfilmentMode() != FulfilmentMode.PARTNER_DELIVERY) {
            return null;
        }
        return jobs.findFirstByShopOrderIdOrderByRequestedAtDesc(o.getId()).map(j -> {
            User agent = j.getAgentId() == null ? null : users.findById(j.getAgentId()).orElse(null);
            return new DeliveryInfo(j.getStatus().name(), agent == null ? null : agent.getName(),
                    agent == null ? null : agent.getPhone(), agent == null ? null : agent.getAvatarUrl(),
                    viewer == Viewer.CUSTOMER ? null : j.getCostMinor(),
                    viewer == Viewer.CUSTOMER && j.getStatus().isActive() ? j.getDropCode() : null,
                    j.getRequestedAt(), j.getAssignedAt(), j.getPickedUpAt(), j.getDeliveredAt(), j.getFailureReason());
        }).orElse(null);
    }

    private RedemptionInfo redemption(ShopOrder o, Viewer viewer) {
        return redemptions.findByShopOrderId(o.getId())
                .map(r -> new RedemptionInfo(viewer == Viewer.CUSTOMER && o.getStatus() == OrderStatus.ACCEPTED
                        ? Redemptions.QR_PREFIX + r.getToken() : null,
                        r.getQuantity(), r.getValidFrom(), r.getValidTo(), r.getUsedAt()))
                .orElse(null);
    }

    List<Action> actions(ShopOrder o, Viewer viewer) {
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
                    case ACCEPTED -> {
                        switch (mode) {
                            case PICKUP -> actions.add(Action.MARK_READY);
                            case SHOP_DELIVERY -> actions.add(Action.OUT_FOR_DELIVERY);
                            // Venue offers are completed only by scanning the customer's QR.
                            case VENUE_QR -> actions.add(Action.REDEEM);
                            // The rider moves partner deliveries along; the shop books or cancels the rider.
                            case PARTNER_DELIVERY -> {
                                var job = jobs.findFirstByShopOrderIdAndStatusIn(o.getId(),
                                        EnumSet.of(JobStatus.REQUESTED, JobStatus.ASSIGNED, JobStatus.PICKED_UP));
                                if (job.isEmpty()) {
                                    actions.add(Action.REQUEST_DELIVERY);
                                } else if (job.get().getStatus() != JobStatus.PICKED_UP) {
                                    actions.add(Action.CANCEL_DELIVERY);
                                }
                            }
                        }
                    }
                    case READY -> actions.add(Action.COMPLETE);
                    case OUT_FOR_DELIVERY -> {
                        if (mode == FulfilmentMode.SHOP_DELIVERY) {
                            actions.add(Action.COMPLETE);
                        }
                    }
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
