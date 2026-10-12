package com.mintadeal.finance;

import java.util.UUID;

import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.CurrentUser;
import com.mintadeal.finance.FinanceDtos.Earnings;
import com.mintadeal.finance.FinanceDtos.PayoutDto;
import com.mintadeal.finance.FinanceDtos.StatementLine;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorService;

@RestController
public class VendorEarningsController {

    private final VendorService vendors;
    private final LedgerService ledger;
    private final EntryRepository entries;
    private final PayoutRepository payouts;
    private final CommissionService commission;

    VendorEarningsController(VendorService vendors, LedgerService ledger, EntryRepository entries,
                             PayoutRepository payouts, CommissionService commission) {
        this.vendors = vendors;
        this.ledger = ledger;
        this.entries = entries;
        this.payouts = payouts;
        this.commission = commission;
    }

    /** Balance, statement (newest first) and payouts. Amounts are from the shop's side: + is money to the shop. */
    @GetMapping("/api/vendor/earnings")
    @Transactional(readOnly = true)
    public Earnings earnings() {
        Vendor v = vendors.ownedBy(CurrentUser.id());
        UUID id = v.getId();
        var statement = entries.statement(id, PageRequest.of(0, 200)).map(l ->
                new StatementLine(l.type(), l.description(), l.amountMinor(), l.createdAt())).getContent();
        var list = payouts.findByVendorIdOrderByCreatedAtDesc(id);
        long inPayout = list.stream().filter(p -> p.getStatus() == PayoutStatus.PENDING
                || p.getStatus() == PayoutStatus.PROCESSING).mapToLong(Payout::getAmountMinor).sum();
        return new Earnings(ledger.payableTo(id), inPayout, PayoutService.destination(v), commission.rateFor(v),
                statement, list.stream().map(PayoutDto::of).toList());
    }
}
