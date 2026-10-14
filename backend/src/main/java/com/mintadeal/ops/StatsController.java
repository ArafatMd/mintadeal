package com.mintadeal.ops;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.CurrentUser;
import com.mintadeal.ops.StatsDtos.AdminOverview;
import com.mintadeal.ops.StatsDtos.VendorStats;
import com.mintadeal.vendor.VendorService;

@RestController
public class StatsController {

    private final StatsService stats;
    private final VendorService vendors;

    public StatsController(StatsService stats, VendorService vendors) {
        this.stats = stats;
        this.vendors = vendors;
    }

    @GetMapping("/api/admin/overview")
    public AdminOverview overview() {
        return stats.overview();
    }

    /** @param days 7, 30 or 90 */
    @GetMapping("/api/vendor/stats")
    public VendorStats vendor(@RequestParam(defaultValue = "30") int days) {
        return stats.forVendor(vendors.ownedBy(CurrentUser.id()).getId(), days);
    }
}
