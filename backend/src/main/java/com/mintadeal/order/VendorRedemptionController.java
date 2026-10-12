package com.mintadeal.order;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.CurrentUser;
import com.mintadeal.order.Redemptions.Check;
import com.mintadeal.order.Redemptions.CodeRequest;
import com.mintadeal.vendor.VendorService;

/** The shop scans a customer's venue offer QR: check shows what it is, redeem uses it up. */
@RestController
@RequestMapping("/api/vendor/redemptions")
public class VendorRedemptionController {

    private final Redemptions redemptions;
    private final VendorService vendors;

    public VendorRedemptionController(Redemptions redemptions, VendorService vendors) {
        this.redemptions = redemptions;
        this.vendors = vendors;
    }

    @PostMapping("/check")
    public Check check(@RequestBody CodeRequest req) {
        return redemptions.check(vendors.approvedOwnedBy(CurrentUser.id()).getId(), req);
    }

    @PostMapping("/redeem")
    public Check redeem(@RequestBody CodeRequest req) {
        var userId = CurrentUser.id();
        return redemptions.redeem(vendors.approvedOwnedBy(userId).getId(), userId, req);
    }
}
