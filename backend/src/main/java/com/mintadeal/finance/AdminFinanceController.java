package com.mintadeal.finance;

import java.util.EnumSet;
import java.util.List;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import jakarta.validation.Valid;

import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.admin.AuditService;
import com.mintadeal.common.CurrentUser;
import com.mintadeal.common.PageResponse;
import com.mintadeal.finance.FinanceDtos.BatchDto;
import com.mintadeal.finance.FinanceDtos.CommissionRates;
import com.mintadeal.finance.FinanceDtos.NotificationRow;
import com.mintadeal.finance.FinanceDtos.PayoutDto;
import com.mintadeal.finance.FinanceDtos.ReasonRequest;
import com.mintadeal.finance.FinanceDtos.RefundRow;
import com.mintadeal.finance.FinanceDtos.Summary;
import com.mintadeal.finance.FinanceDtos.UtrRequest;
import com.mintadeal.finance.FinanceDtos.VendorBalance;
import com.mintadeal.notify.NotificationRepository;
import com.mintadeal.order.OrderService;
import com.mintadeal.order.Refund;
import com.mintadeal.order.RefundRepository;
import com.mintadeal.order.RefundStatus;
import com.mintadeal.order.ShopOrder;
import com.mintadeal.order.ShopOrderRepository;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorRepository;

@RestController
@RequestMapping("/api/admin/finance")
public class AdminFinanceController {

    private final CommissionService commission;
    private final EntryRepository entries;
    private final PayoutService payoutService;
    private final PayoutRepository payouts;
    private final VendorRepository vendors;
    private final RefundRepository refunds;
    private final ShopOrderRepository orders;
    private final OrderService orderService;
    private final NotificationRepository notifications;
    private final AuditService audit;

    AdminFinanceController(CommissionService commission, EntryRepository entries, PayoutService payoutService,
                           PayoutRepository payouts, VendorRepository vendors, RefundRepository refunds,
                           ShopOrderRepository orders, OrderService orderService, NotificationRepository notifications,
                           AuditService audit) {
        this.commission = commission;
        this.entries = entries;
        this.payoutService = payoutService;
        this.payouts = payouts;
        this.vendors = vendors;
        this.refunds = refunds;
        this.orders = orders;
        this.orderService = orderService;
        this.notifications = notifications;
        this.audit = audit;
    }

    // --- Commission ---

    @GetMapping("/commission")
    public CommissionRates rates() {
        var r = commission.rates();
        return new CommissionRates(r.defaultBps(), r.categoryBps());
    }

    @PutMapping("/commission")
    public CommissionRates updateRates(@RequestBody CommissionRates req) {
        var r = commission.update(CurrentUser.id(), new CommissionService.Rates(req.defaultBps(),
                req.categoryBps() == null ? java.util.Map.of() : req.categoryBps()));
        return new CommissionRates(r.defaultBps(), r.categoryBps());
    }

    // --- Money overview ---

    @GetMapping("/summary")
    @Transactional(readOnly = true)
    public Summary summary() {
        long owedToShops = 0;
        long owedByShops = 0;
        for (Object[] row : entries.vendorBalances()) {
            long payable = -((Number) row[1]).longValue();
            if (payable > 0) {
                owedToShops += payable;
            } else {
                owedByShops -= payable;
            }
        }
        var pending = payouts.findByStatusInOrderByCreatedAtDesc(EnumSet.of(PayoutStatus.PENDING, PayoutStatus.PROCESSING),
                PageRequest.of(0, 1000)).getContent();
        long failedRefunds = refunds.findAll().stream().filter(r -> r.getStatus() == RefundStatus.FAILED).count();
        return new Summary(entries.balance(Account.GATEWAY), -entries.balance(Account.CUSTOMER_PREPAID), owedToShops,
                owedByShops, -entries.balance(Account.PAYOUTS_IN_TRANSIT), -entries.balance(Account.COMMISSION_REVENUE),
                -entries.balance(Account.DELIVERY_RECOVERY), entries.total() == 0,
                pending.stream().mapToLong(Payout::getAmountMinor).sum(), pending.size(), (int) failedRefunds);
    }

    @GetMapping("/vendor-balances")
    @Transactional(readOnly = true)
    public List<VendorBalance> vendorBalances() {
        var byId = vendors.findAll().stream().collect(Collectors.toMap(Vendor::getId, Function.identity()));
        return entries.vendorBalances().stream()
                .map(row -> {
                    Vendor v = byId.get((UUID) row[0]);
                    return new VendorBalance(v.getId(), v.getDisplayName(), -((Number) row[1]).longValue(),
                            PayoutService.destination(v));
                })
                .filter(b -> b.balanceMinor() != 0)
                .sorted(java.util.Comparator.comparingLong(VendorBalance::balanceMinor).reversed())
                .toList();
    }

    // --- Payouts ---

    @PostMapping("/payouts/batches")
    public BatchDto createBatch() {
        var result = payoutService.createBatch(CurrentUser.id());
        audit.record("PAYOUT_BATCH", "PAYOUT_BATCH", result.batch().getId(),
                result.payouts().size() + " payouts, total " + result.batch().getTotalMinor());
        return new BatchDto(result.batch().getId(), result.batch().getPayoutCount(), result.batch().getTotalMinor(),
                result.batch().getCreatedAt(), result.payouts().stream().map(PayoutDto::of).toList(), result.skipped());
    }

    /** @param status a status, or OPEN (default) for pending and processing payouts */
    @GetMapping("/payouts")
    @Transactional(readOnly = true)
    public PageResponse<PayoutDto> payouts(@RequestParam(defaultValue = "OPEN") String status,
                                           @RequestParam(defaultValue = "0") int page) {
        var statuses = switch (status) {
            case "OPEN" -> EnumSet.of(PayoutStatus.PENDING, PayoutStatus.PROCESSING);
            case "ALL" -> EnumSet.allOf(PayoutStatus.class);
            default -> EnumSet.of(PayoutStatus.valueOf(status));
        };
        return PageResponse.of(payouts.findByStatusInOrderByCreatedAtDesc(statuses, PageRequest.of(page, 50)),
                PayoutDto::of);
    }

    @PostMapping("/payouts/send-pending")
    public List<PayoutDto> sendPending() {
        var sent = payoutService.sendAllPending();
        audit.record("PAYOUTS_SENT", "PAYOUT_BATCH", UUID.nameUUIDFromBytes("send".getBytes()), sent.size() + " payouts");
        return sent.stream().map(PayoutDto::of).toList();
    }

    @PostMapping("/payouts/{id}/send")
    public PayoutDto send(@PathVariable UUID id) {
        audit.record("PAYOUT_SENT", "PAYOUT", id, null);
        return PayoutDto.of(payoutService.send(id));
    }

    @PostMapping("/payouts/{id}/mark-paid")
    public PayoutDto markPaid(@PathVariable UUID id, @Valid @RequestBody UtrRequest req) {
        audit.record("PAYOUT_MARKED_PAID", "PAYOUT", id, req.utr());
        return PayoutDto.of(payoutService.markPaid(id, req.utr()));
    }

    @PostMapping("/payouts/{id}/cancel")
    public PayoutDto cancel(@PathVariable UUID id, @Valid @RequestBody ReasonRequest req) {
        audit.record("PAYOUT_CANCELLED", "PAYOUT", id, req.reason());
        return PayoutDto.of(payoutService.cancel(id, req.reason()));
    }

    @PostMapping("/payouts/{id}/refresh")
    public PayoutDto refresh(@PathVariable UUID id) {
        return PayoutDto.of(payoutService.refresh(id));
    }

    // --- Refunds ---

    @GetMapping("/refunds")
    @Transactional(readOnly = true)
    public List<RefundRow> refunds(@RequestParam(defaultValue = "FAILED") RefundStatus status) {
        return refunds.findAll().stream().filter(r -> r.getStatus() == status)
                .sorted(java.util.Comparator.comparing(Refund::getCreatedAt).reversed())
                .map(this::row).toList();
    }

    @PostMapping("/refunds/{id}/retry")
    public RefundRow retry(@PathVariable UUID id) {
        audit.record("REFUND_RETRIED", "REFUND", id, null);
        return row(orderService.retryRefund(id));
    }

    private RefundRow row(Refund r) {
        String code = orders.findById(r.getShopOrderId()).map(ShopOrder::getCode).orElse("");
        return new RefundRow(r.getId(), r.getShopOrderId(), code, r.getAmountMinor(), r.getStatus().name(), r.getError(),
                r.getCreatedAt());
    }

    // --- Notifications ---

    @GetMapping("/notifications")
    @Transactional(readOnly = true)
    public PageResponse<NotificationRow> notifications(@RequestParam(defaultValue = "0") int page) {
        return PageResponse.of(notifications.findAllByOrderByCreatedAtDesc(PageRequest.of(page, 50)),
                n -> new NotificationRow(n.getId(), n.getEvent(), n.getChannel(), n.getRecipient(), n.getOrderId(),
                        n.getStatus(), n.getError(), n.getCreatedAt()));
    }
}
