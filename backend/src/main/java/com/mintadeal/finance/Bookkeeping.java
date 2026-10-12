package com.mintadeal.finance;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.mintadeal.finance.LedgerService.Leg;
import com.mintadeal.order.Checkout;
import com.mintadeal.order.PaymentStatus;
import com.mintadeal.order.ShopOrder;

/** Turns business events into ledger journals. Every method is safe to call more than once. */
@Component
public class Bookkeeping {

    private final LedgerService ledger;

    Bookkeeping(LedgerService ledger) {
        this.ledger = ledger;
    }

    /** The customer paid online: the provider now holds money that belongs to the customer until fulfilment. */
    public void paymentReceived(Checkout c) {
        ledger.post("PAYMENT", c.getId(), "Online payment for " + c.getCode(), List.of(
                Leg.debit(Account.GATEWAY, c.getGrandTotalMinor()),
                Leg.credit(Account.CUSTOMER_PREPAID, c.getGrandTotalMinor())));
    }

    public void refundProcessed(UUID refundId, String orderCode, long amountMinor) {
        ledger.post("REFUND", refundId, "Refund for " + orderCode, List.of(
                Leg.debit(Account.CUSTOMER_PREPAID, amountMinor),
                Leg.credit(Account.GATEWAY, amountMinor)));
    }

    /**
     * A completed order: a prepaid order's money moves from the customer to the shop; either way the shop owes
     * commission on the items (not on its own delivery fee).
     */
    public void orderCompleted(ShopOrder o, Checkout c) {
        if (c.getPaymentStatus() == PaymentStatus.PAID) {
            ledger.post("SETTLEMENT", o.getId(), "Order " + o.getCode() + " (paid online)", List.of(
                    Leg.debit(Account.CUSTOMER_PREPAID, o.getTotalMinor()),
                    Leg.creditVendor(o.getVendorId(), o.getTotalMinor())));
        }
        long commission = CommissionService.commissionOn(o.getItemsTotalMinor(), o.getCommissionBps());
        o.setCommissionMinor(commission);
        ledger.post("COMMISSION", o.getId(), "Commission " + percent(o.getCommissionBps()) + " on " + o.getCode(), List.of(
                Leg.debitVendor(o.getVendorId(), commission),
                Leg.credit(Account.COMMISSION_REVENUE, commission)));
    }

    public void deliveryCharged(UUID jobId, UUID vendorId, String orderCode, long costMinor) {
        ledger.post("DELIVERY_CHARGE", jobId, "Delivery partner for " + orderCode, List.of(
                Leg.debitVendor(vendorId, costMinor),
                Leg.credit(Account.DELIVERY_RECOVERY, costMinor)));
    }

    public void payoutCreated(UUID payoutId, UUID vendorId, long amountMinor, String destination) {
        ledger.post("PAYOUT_CREATED", payoutId, "Payout to " + destination, List.of(
                Leg.debitVendor(vendorId, amountMinor),
                Leg.credit(Account.PAYOUTS_IN_TRANSIT, amountMinor)));
    }

    public void payoutPaid(UUID payoutId, long amountMinor) {
        ledger.post("PAYOUT_PAID", payoutId, "Payout sent", List.of(
                Leg.debit(Account.PAYOUTS_IN_TRANSIT, amountMinor),
                Leg.credit(Account.GATEWAY, amountMinor)));
    }

    /** A payout that did not go through puts the money back on the shop's balance. */
    public void payoutFailed(UUID payoutId, UUID vendorId, long amountMinor, String reason) {
        ledger.post("PAYOUT_FAILED", payoutId, "Payout returned: " + reason, List.of(
                Leg.debit(Account.PAYOUTS_IN_TRANSIT, amountMinor),
                Leg.creditVendor(vendorId, amountMinor)));
    }

    static String percent(int bps) {
        return bps % 100 == 0 ? bps / 100 + "%" : String.format("%.2f%%", bps / 100.0);
    }
}
