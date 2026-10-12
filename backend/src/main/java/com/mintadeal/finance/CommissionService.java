package com.mintadeal.finance;

import java.time.Clock;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.admin.AuditService;
import com.mintadeal.common.ApiException;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorCategory;
import com.mintadeal.vendor.VendorType;

/**
 * Commission rates. The rate is fixed on each order when it is placed, so a later change never re-prices
 * an order. Mintadeal's own catalogue pays no commission.
 */
@Service
public class CommissionService {

    public record Rates(int defaultBps, Map<VendorCategory, Integer> categoryBps) {
    }

    private final CommissionRuleRepository rules;
    private final AuditService audit;
    private final int fallbackBps;
    private final Clock clock;

    public CommissionService(CommissionRuleRepository rules, AuditService audit,
                             @Value("${mintadeal.commission.default-bps}") int fallbackBps, Clock clock) {
        this.rules = rules;
        this.audit = audit;
        this.fallbackBps = fallbackBps;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public int rateFor(Vendor vendor) {
        if (vendor.getVendorType() == VendorType.INTERNAL) {
            return 0;
        }
        return rules.findByCategory(vendor.getCategory()).map(CommissionRule::getRateBps)
                .or(() -> rules.findByCategoryIsNull().map(CommissionRule::getRateBps))
                .orElse(fallbackBps);
    }

    @Transactional(readOnly = true)
    public Rates rates() {
        Map<VendorCategory, Integer> byCategory = new LinkedHashMap<>();
        rules.findAll().stream().filter(r -> r.getCategory() != null)
                .forEach(r -> byCategory.put(r.getCategory(), r.getRateBps()));
        return new Rates(rules.findByCategoryIsNull().map(CommissionRule::getRateBps).orElse(fallbackBps), byCategory);
    }

    /** Replaces all rates. Categories left out use the default. */
    @Transactional
    public Rates update(UUID adminId, Rates rates) {
        check(rates.defaultBps());
        rates.categoryBps().values().forEach(CommissionService::check);
        var now = clock.instant();
        rules.findByCategoryIsNull().ifPresentOrElse(r -> r.update(rates.defaultBps(), adminId, now),
                () -> rules.save(new CommissionRule(null, rates.defaultBps(), adminId, now)));
        rules.findAll().stream().filter(r -> r.getCategory() != null && !rates.categoryBps().containsKey(r.getCategory()))
                .forEach(rules::delete);
        rates.categoryBps().forEach((category, bps) -> rules.findByCategory(category)
                .ifPresentOrElse(r -> r.update(bps, adminId, now),
                        () -> rules.save(new CommissionRule(category, bps, adminId, now))));
        audit.record("COMMISSION_UPDATED", "SETTINGS", UUID.nameUUIDFromBytes("commission".getBytes()),
                "default " + rates.defaultBps() + " bps, " + rates.categoryBps());
        return rates();
    }

    private static void check(int bps) {
        if (bps < 0 || bps > 5000) {
            throw ApiException.badRequest("invalid_rate", "Commission must be between 0% and 50%");
        }
    }

    public static long commissionOn(long itemsTotalMinor, int bps) {
        return Math.round(itemsTotalMinor * bps / 10_000.0);
    }
}
