package com.mintadeal.finance;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Posts balanced journals. Each journal has a type and a reference (order, refund, payout...) and is posted at
 * most once, so retries and duplicate webhooks never count money twice.
 */
@Service
public class LedgerService {

    public record Leg(Account account, UUID vendorId, long amountMinor) {

        public static Leg debit(Account a, long amount) {
            return new Leg(a, null, amount);
        }

        public static Leg credit(Account a, long amount) {
            return new Leg(a, null, -amount);
        }

        public static Leg debitVendor(UUID vendorId, long amount) {
            return new Leg(Account.VENDOR_PAYABLE, vendorId, amount);
        }

        public static Leg creditVendor(UUID vendorId, long amount) {
            return new Leg(Account.VENDOR_PAYABLE, vendorId, -amount);
        }
    }

    private final JournalRepository journals;
    private final EntryRepository entries;
    private final Clock clock;

    LedgerService(JournalRepository journals, EntryRepository entries, Clock clock) {
        this.journals = journals;
        this.entries = entries;
        this.clock = clock;
    }

    /** Returns false if this journal was already posted. */
    @Transactional(propagation = Propagation.MANDATORY)
    public boolean post(String type, UUID referenceId, String description, List<Leg> legs) {
        long sum = legs.stream().mapToLong(Leg::amountMinor).sum();
        if (sum != 0) {
            throw new IllegalStateException("Unbalanced journal " + type + " " + referenceId + ": " + sum);
        }
        if (legs.stream().allMatch(l -> l.amountMinor() == 0) || journals.existsByJournalTypeAndReferenceId(type, referenceId)) {
            return false;
        }
        Instant now = clock.instant();
        LedgerJournal journal = journals.save(new LedgerJournal(type, referenceId, description, now));
        for (Leg leg : legs) {
            if (leg.amountMinor() != 0) {
                entries.save(new LedgerEntry(journal.getId(), leg.account(), leg.vendorId(), leg.amountMinor(), now));
            }
        }
        return true;
    }

    /** What Mintadeal owes the shop (positive) or the shop owes Mintadeal (negative). */
    @Transactional(readOnly = true)
    public long payableTo(UUID vendorId) {
        return -entries.vendorBalance(vendorId);
    }

    /** What the shop owes Mintadeal after everything Mintadeal owes it is netted off. */
    @Transactional(readOnly = true)
    public long duesOf(UUID vendorId) {
        return Math.max(0, -payableTo(vendorId));
    }
}
