package com.mintadeal.finance;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import com.mintadeal.vendor.VendorCategory;

public final class FinanceDtos {

    private FinanceDtos() {
    }

    public record StatementLine(String type, String description, long amountMinor, Instant createdAt) {
    }

    public record PayoutDto(UUID id, UUID batchId, UUID vendorId, String vendorName, long amountMinor,
                            PayoutStatus status, String method, String destination, String utr, String failureReason,
                            Instant createdAt, Instant sentAt, Instant paidAt) {

        static PayoutDto of(Payout p) {
            return new PayoutDto(p.getId(), p.getBatchId(), p.getVendorId(), p.getVendorName(), p.getAmountMinor(),
                    p.getStatus(), p.getMethod(), p.getDestination(), p.getUtr(), p.getFailureReason(),
                    p.getCreatedAt(), p.getSentAt(), p.getPaidAt());
        }
    }

    /**
     * A shop's money with Mintadeal.
     *
     * @param balanceMinor what Mintadeal owes the shop now (negative if the shop owes Mintadeal)
     * @param inPayoutMinor already in payouts that are on their way
     */
    public record Earnings(long balanceMinor, long inPayoutMinor, String payoutDestination, int commissionBps,
                           List<StatementLine> statement, List<PayoutDto> payouts) {
    }

    public record CommissionRates(int defaultBps, Map<VendorCategory, Integer> categoryBps) {
    }

    /** Ledger totals. {@code balanced} is false only if a journal was ever posted out of balance. */
    public record Summary(long gatewayMinor, long customerPrepaidMinor, long owedToShopsMinor, long owedByShopsMinor,
                          long payoutsInTransitMinor, long commissionRevenueMinor, long deliveryRecoveryMinor,
                          boolean balanced, long pendingPayoutsMinor, int pendingPayouts, int failedRefunds) {
    }

    public record VendorBalance(UUID vendorId, String vendorName, long balanceMinor, String payoutDestination) {
    }

    public record BatchDto(UUID id, int payoutCount, long totalMinor, Instant createdAt, List<PayoutDto> payouts,
                           List<String> skipped) {
    }

    public record UtrRequest(@NotBlank @Size(max = 60) String utr) {
    }

    public record ReasonRequest(@NotBlank @Size(max = 500) String reason) {
    }

    public record RefundRow(UUID id, UUID shopOrderId, String orderCode, long amountMinor, String status, String error,
                            Instant createdAt) {
    }

    public record NotificationRow(UUID id, String event, String channel, String recipient, UUID orderId, String status,
                                  String error, Instant createdAt) {
    }
}
