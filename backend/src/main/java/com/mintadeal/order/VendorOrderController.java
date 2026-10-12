package com.mintadeal.order;

import java.util.EnumSet;
import java.util.Set;
import java.util.UUID;

import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.ApiException;
import com.mintadeal.common.CurrentUser;
import com.mintadeal.common.PageResponse;
import com.mintadeal.order.OrderDtos.Action;
import com.mintadeal.order.OrderDtos.OrderDetail;
import com.mintadeal.order.OrderDtos.OrderSummary;
import com.mintadeal.order.OrderDtos.ReasonRequest;
import com.mintadeal.order.OrderDtos.VendorSummaryCounts;
import com.mintadeal.order.OrderViews.Viewer;
import com.mintadeal.vendor.VendorService;

/** The shop's order inbox. Only paid (or pay-on-delivery) orders reach it. */
@RestController
@RequestMapping("/api/vendor/orders")
public class VendorOrderController {

    public enum Filter {
        NEW(EnumSet.of(OrderStatus.PLACED)),
        ACTIVE(EnumSet.of(OrderStatus.ACCEPTED, OrderStatus.READY, OrderStatus.OUT_FOR_DELIVERY)),
        DONE(EnumSet.of(OrderStatus.COMPLETED, OrderStatus.CANCELLED)),
        ALL(EnumSet.complementOf(EnumSet.of(OrderStatus.PENDING_PAYMENT)));

        final Set<OrderStatus> statuses;

        Filter(Set<OrderStatus> statuses) {
            this.statuses = statuses;
        }
    }

    private final VendorService vendors;
    private final OrderService orders;
    private final ShopOrderRepository repo;
    private final OrderViews views;

    public VendorOrderController(VendorService vendors, OrderService orders, ShopOrderRepository repo,
                                 OrderViews views) {
        this.vendors = vendors;
        this.orders = orders;
        this.repo = repo;
        this.views = views;
    }

    @GetMapping
    @Transactional(readOnly = true)
    public PageResponse<OrderSummary> list(@RequestParam(defaultValue = "ALL") Filter filter,
                                           @RequestParam(defaultValue = "0") int page,
                                           @RequestParam(defaultValue = "30") int size) {
        UUID vendorId = vendors.ownedBy(CurrentUser.id()).getId();
        return PageResponse.of(repo.forVendor(vendorId, filter.statuses, PageRequest.of(page, Math.clamp(size, 1, 100))),
                views::summary);
    }

    /** Polled by the vendor app to show a badge and an alert for new orders. */
    @GetMapping("/summary")
    @Transactional(readOnly = true)
    public VendorSummaryCounts summary() {
        UUID vendorId = vendors.ownedBy(CurrentUser.id()).getId();
        return new VendorSummaryCounts(repo.countByVendorIdAndStatus(vendorId, OrderStatus.PLACED),
                repo.countByVendorIdAndStatusIn(vendorId, Filter.ACTIVE.statuses));
    }

    @GetMapping("/{id}")
    @Transactional(readOnly = true)
    public OrderDetail detail(@PathVariable UUID id) {
        UUID vendorId = vendors.ownedBy(CurrentUser.id()).getId();
        ShopOrder o = repo.findById(id)
                .filter(x -> x.getVendorId().equals(vendorId) && x.getStatus() != OrderStatus.PENDING_PAYMENT)
                .orElseThrow(() -> ApiException.notFound("Order"));
        return views.detail(o, Viewer.VENDOR);
    }

    @PostMapping("/{id}/accept")
    public OrderDetail accept(@PathVariable UUID id) {
        return act(id, Action.ACCEPT, null);
    }

    @PostMapping("/{id}/reject")
    public OrderDetail reject(@PathVariable UUID id, @RequestBody ReasonRequest req) {
        return act(id, Action.REJECT, req.reason());
    }

    @PostMapping("/{id}/ready")
    public OrderDetail ready(@PathVariable UUID id) {
        return act(id, Action.MARK_READY, null);
    }

    @PostMapping("/{id}/out-for-delivery")
    public OrderDetail outForDelivery(@PathVariable UUID id) {
        return act(id, Action.OUT_FOR_DELIVERY, null);
    }

    @PostMapping("/{id}/complete")
    public OrderDetail complete(@PathVariable UUID id) {
        return act(id, Action.COMPLETE, null);
    }

    private OrderDetail act(UUID id, Action action, String reason) {
        UUID userId = CurrentUser.id();
        UUID vendorId = vendors.approvedOwnedBy(userId).getId();
        return views.detail(orders.vendorAct(vendorId, userId, id, action, reason), Viewer.VENDOR);
    }
}
