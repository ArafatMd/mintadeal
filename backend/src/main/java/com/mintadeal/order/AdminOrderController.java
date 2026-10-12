package com.mintadeal.order;

import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.admin.AuditService;
import com.mintadeal.common.ApiException;
import com.mintadeal.common.CurrentUser;
import com.mintadeal.common.PageResponse;
import com.mintadeal.order.OrderDtos.OrderDetail;
import com.mintadeal.order.OrderDtos.OrderSummary;
import com.mintadeal.order.OrderDtos.ReasonRequest;
import com.mintadeal.order.OrderViews.Viewer;

@RestController
@RequestMapping("/api/admin/orders")
public class AdminOrderController {

    private final ShopOrderRepository repo;
    private final OrderService orders;
    private final OrderViews views;
    private final AuditService audit;

    public AdminOrderController(ShopOrderRepository repo, OrderService orders, OrderViews views, AuditService audit) {
        this.repo = repo;
        this.orders = orders;
        this.views = views;
        this.audit = audit;
    }

    /** @param q order code, customer phone or shop name */
    @GetMapping
    @Transactional(readOnly = true)
    public PageResponse<OrderSummary> search(@RequestParam(required = false) OrderStatus status,
                                             @RequestParam(required = false) String q,
                                             @RequestParam(defaultValue = "0") int page,
                                             @RequestParam(defaultValue = "50") int size) {
        String query = q == null ? "" : q.trim();
        return PageResponse.of(repo.search(status, query, PageRequest.of(page, Math.clamp(size, 1, 200))),
                views::summary);
    }

    @GetMapping("/{id}")
    @Transactional(readOnly = true)
    public OrderDetail detail(@PathVariable UUID id) {
        return views.detail(repo.findById(id).orElseThrow(() -> ApiException.notFound("Order")), Viewer.ADMIN);
    }

    @PostMapping("/{id}/cancel")
    @Transactional
    public OrderDetail cancel(@PathVariable UUID id, @Valid @RequestBody ReasonRequest req) {
        ShopOrder o = orders.adminCancel(CurrentUser.id(), id, req.reason());
        audit.record("ORDER_CANCELLED", "ORDER", id, req.reason());
        return views.detail(o, Viewer.ADMIN);
    }
}
