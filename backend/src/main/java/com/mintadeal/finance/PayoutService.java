package com.mintadeal.finance;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.common.ApiException;
import com.mintadeal.delivery.VendorChargeRepository;
import com.mintadeal.integrations.RazorpayXClient;
import com.mintadeal.integrations.RazorpayXClient.Destination;
import com.mintadeal.integrations.RazorpayXClient.PayoutResult;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorRepository;

/**
 * Pays shops what Mintadeal owes them. A batch takes each shop's balance (earnings minus commission and delivery
 * charges) into a payout; the payout is then sent through RazorpayX or recorded as paid by hand with the bank's
 * reference. A failed payout returns the money to the shop's balance.
 */
@Service
public class PayoutService {

    private static final Logger log = LoggerFactory.getLogger(PayoutService.class);

    public record BatchResult(PayoutBatch batch, List<Payout> payouts, List<String> skipped) {
    }

    private final PayoutRepository payouts;
    private final PayoutBatchRepository batches;
    private final VendorRepository vendors;
    private final VendorChargeRepository charges;
    private final LedgerService ledger;
    private final Bookkeeping bookkeeping;
    private final RazorpayXClient razorpayX;
    private final long minimumMinor;
    private final Clock clock;

    PayoutService(PayoutRepository payouts, PayoutBatchRepository batches, VendorRepository vendors,
                  VendorChargeRepository charges, LedgerService ledger, Bookkeeping bookkeeping,
                  RazorpayXClient razorpayX, @Value("${mintadeal.payouts.minimum-minor}") long minimumMinor,
                  Clock clock) {
        this.payouts = payouts;
        this.batches = batches;
        this.vendors = vendors;
        this.charges = charges;
        this.ledger = ledger;
        this.bookkeeping = bookkeeping;
        this.razorpayX = razorpayX;
        this.minimumMinor = minimumMinor;
        this.clock = clock;
    }

    @Transactional
    public BatchResult createBatch(UUID adminId) {
        Instant now = clock.instant();
        PayoutBatch batch = batches.save(new PayoutBatch(adminId, now));
        List<Payout> created = new ArrayList<>();
        List<String> skipped = new ArrayList<>();
        for (Vendor v : vendors.findAll()) {
            long balance = ledger.payableTo(v.getId());
            if (balance < minimumMinor) {
                continue;
            }
            String destination = destination(v);
            if (destination == null) {
                skipped.add(v.getDisplayName() + ": no UPI ID or bank account");
                continue;
            }
            if (!v.isApproved()) {
                skipped.add(v.getDisplayName() + ": shop is " + v.getStatus().name().toLowerCase());
                continue;
            }
            Payout p = payouts.save(new Payout(batch.getId(), v.getId(), v.getDisplayName(), balance, destination, now));
            bookkeeping.payoutCreated(p.getId(), v.getId(), balance, destination);
            batch.add(balance);
            created.add(p);
            // Charges owed so far are now netted into this payout.
            charges.findByVendorIdOrderByCreatedAtDesc(v.getId(), org.springframework.data.domain.Pageable.unpaged())
                    .forEach(c -> c.recover());
        }
        return new BatchResult(batch, created, skipped);
    }

    /** Sends a pending payout through RazorpayX. */
    @Transactional
    public Payout send(UUID payoutId) {
        Payout p = payout(payoutId);
        if (p.getStatus() != PayoutStatus.PENDING) {
            throw ApiException.conflict("payout_not_pending", "Only pending payouts can be sent");
        }
        if (!razorpayX.enabled()) {
            throw ApiException.badRequest("razorpayx_off",
                    "Automatic payouts are off. Pay by bank or UPI and record the reference instead.");
        }
        Vendor v = vendors.findById(p.getVendorId()).orElseThrow();
        Destination to = new Destination(v.getPayoutUpiId(), v.getPayoutAccountNumber(), v.getPayoutIfsc(),
                v.getLegalName() != null ? v.getLegalName() : v.getDisplayName());
        PayoutResult result = razorpayX.pay(p.getId().toString(), p.getId().toString(), v.getDisplayName(), v.getPhone(),
                to, p.getAmountMinor(), "Mintadeal payout");
        p.sent(result.id(), clock.instant());
        apply(p, result);
        return p;
    }

    @Transactional
    public List<Payout> sendAllPending() {
        List<Payout> sent = new ArrayList<>();
        for (Payout p : payouts.findByStatus(PayoutStatus.PENDING)) {
            try {
                sent.add(send(p.getId()));
            } catch (ApiException e) {
                if ("razorpayx_off".equals(e.code())) {
                    throw e;
                }
                log.warn("Payout {} to {} not sent: {}", p.getId(), p.getVendorName(), e.getMessage());
            }
        }
        return sent;
    }

    /** Records a payout made outside RazorpayX (bank transfer or UPI), with the bank's reference. */
    @Transactional
    public Payout markPaid(UUID payoutId, String utr) {
        Payout p = payout(payoutId);
        if (p.getStatus() != PayoutStatus.PENDING) {
            throw ApiException.conflict("payout_not_pending", "Only pending payouts can be recorded as paid");
        }
        p.paid("MANUAL", utr.trim(), clock.instant());
        bookkeeping.payoutPaid(p.getId(), p.getAmountMinor());
        return p;
    }

    @Transactional
    public Payout cancel(UUID payoutId, String reason) {
        Payout p = payout(payoutId);
        if (p.getStatus() != PayoutStatus.PENDING) {
            throw ApiException.conflict("payout_not_pending", "Only pending payouts can be cancelled");
        }
        p.failed(PayoutStatus.CANCELLED, reason.trim());
        bookkeeping.payoutFailed(p.getId(), p.getVendorId(), p.getAmountMinor(), reason.trim());
        return p;
    }

    /** Asks RazorpayX for the latest status of a payout in progress. */
    @Transactional
    public Payout refresh(UUID payoutId) {
        Payout p = payout(payoutId);
        if (p.getStatus() == PayoutStatus.PROCESSING && p.getProviderPayoutId() != null) {
            apply(p, razorpayX.fetch(p.getProviderPayoutId()));
        }
        return p;
    }

    /** From the Razorpay webhook (payout.processed, payout.failed, payout.reversed). */
    @Transactional
    public void onProviderUpdate(String providerPayoutId) {
        payouts.findByProviderPayoutId(providerPayoutId).ifPresent(p -> refresh(p.getId()));
    }

    private void apply(Payout p, PayoutResult r) {
        if (r.processed() && p.getStatus() != PayoutStatus.PAID) {
            p.paid("RAZORPAYX", r.utr(), clock.instant());
            bookkeeping.payoutPaid(p.getId(), p.getAmountMinor());
        } else if (r.failed() && p.getStatus() == PayoutStatus.PROCESSING) {
            String reason = r.failureReason() == null ? "Payout " + r.status() : r.failureReason();
            p.failed(PayoutStatus.FAILED, reason);
            bookkeeping.payoutFailed(p.getId(), p.getVendorId(), p.getAmountMinor(), reason);
        }
    }

    private Payout payout(UUID id) {
        return payouts.findById(id).orElseThrow(() -> ApiException.notFound("Payout"));
    }

    static String destination(Vendor v) {
        if (v.getPayoutUpiId() != null && !v.getPayoutUpiId().isBlank()) {
            return "UPI " + v.getPayoutUpiId();
        }
        if (v.getPayoutAccountNumber() != null && v.getPayoutIfsc() != null) {
            String acc = v.getPayoutAccountNumber();
            return "Bank ••••" + acc.substring(Math.max(0, acc.length() - 4)) + " (" + v.getPayoutIfsc() + ")";
        }
        return null;
    }
}
