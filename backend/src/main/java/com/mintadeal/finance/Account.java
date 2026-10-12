package com.mintadeal.finance;

/**
 * Ledger accounts. Debits are stored as positive amounts, credits as negative, and every journal sums to zero.
 * GATEWAY is money held at the payment provider; CUSTOMER_PREPAID is money paid for orders not yet completed;
 * VENDOR_PAYABLE (one per shop) is what Mintadeal owes the shop, held as a credit.
 */
public enum Account {
    GATEWAY,
    CUSTOMER_PREPAID,
    VENDOR_PAYABLE,
    COMMISSION_REVENUE,
    DELIVERY_RECOVERY,
    PAYOUTS_IN_TRANSIT
}
