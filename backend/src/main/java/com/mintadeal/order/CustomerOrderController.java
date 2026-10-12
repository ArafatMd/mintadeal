package com.mintadeal.order;

import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.ApiException;
import com.mintadeal.common.CurrentUser;
import com.mintadeal.common.PageResponse;
import com.mintadeal.order.CheckoutDtos.CheckoutDto;
import com.mintadeal.order.CheckoutDtos.PlaceRequest;
import com.mintadeal.order.CheckoutDtos.Quote;
import com.mintadeal.order.CheckoutDtos.QuoteRequest;
import com.mintadeal.order.OrderDtos.OrderDetail;
import com.mintadeal.order.OrderDtos.OrderSummary;
import com.mintadeal.order.OrderViews.Viewer;

@RestController
@RequestMapping("/api/customer")
public class CustomerOrderController {

    private final CheckoutService checkout;
    private final OrderService orders;
    private final PaymentService payments;
    private final ShopOrderRepository orderRepo;
    private final CheckoutRepository checkoutRepo;
    private final OrderViews views;

    public CustomerOrderController(CheckoutService checkout, OrderService orders, PaymentService payments,
                                   ShopOrderRepository orderRepo, CheckoutRepository checkoutRepo, OrderViews views) {
        this.checkout = checkout;
        this.orders = orders;
        this.payments = payments;
        this.orderRepo = orderRepo;
        this.checkoutRepo = checkoutRepo;
        this.views = views;
    }

    @PostMapping("/checkout/quote")
    public Quote quote(@Valid @RequestBody QuoteRequest req) {
        return checkout.quote(req);
    }

    @PostMapping("/checkout")
    @ResponseStatus(HttpStatus.CREATED)
    public CheckoutDto place(@Valid @RequestBody PlaceRequest req) {
        return checkout.place(CurrentUser.id(), req);
    }

    @GetMapping("/checkouts/{id}")
    @Transactional(readOnly = true)
    public CheckoutDto checkout(@PathVariable UUID id) {
        return views.checkout(ownCheckout(id));
    }

    /** Called when the customer comes back from the payment page; asks the provider, not the app, if it was paid. */
    @PostMapping("/checkouts/{id}/refresh-payment")
    @Transactional
    public CheckoutDto refreshPayment(@PathVariable UUID id) {
        ownCheckout(id);
        return views.checkout(payments.refresh(id));
    }

    @GetMapping("/orders")
    @Transactional(readOnly = true)
    public PageResponse<OrderSummary> list(@RequestParam(defaultValue = "0") int page,
                                           @RequestParam(defaultValue = "20") int size) {
        return PageResponse.of(orderRepo.findByCustomerIdOrderByCreatedAtDesc(CurrentUser.id(),
                PageRequest.of(page, Math.clamp(size, 1, 50))), views::summary);
    }

    @GetMapping("/orders/{id}")
    @Transactional(readOnly = true)
    public OrderDetail detail(@PathVariable UUID id) {
        return views.detail(ownOrder(id), Viewer.CUSTOMER);
    }

    @PostMapping("/orders/{id}/cancel")
    @Transactional
    public OrderDetail cancel(@PathVariable UUID id) {
        return views.detail(orders.customerCancel(CurrentUser.id(), id), Viewer.CUSTOMER);
    }

    private Checkout ownCheckout(UUID id) {
        return checkoutRepo.findById(id).filter(c -> c.getCustomerId().equals(CurrentUser.id()))
                .orElseThrow(() -> ApiException.notFound("Checkout"));
    }

    private ShopOrder ownOrder(UUID id) {
        return orderRepo.findById(id).filter(o -> o.getCustomerId().equals(CurrentUser.id()))
                .orElseThrow(() -> ApiException.notFound("Order"));
    }
}
