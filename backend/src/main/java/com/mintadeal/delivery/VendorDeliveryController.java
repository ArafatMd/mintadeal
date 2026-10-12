package com.mintadeal.delivery;

import java.util.UUID;

import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.CurrentUser;
import com.mintadeal.delivery.DeliveryDtos.ChargeDto;
import com.mintadeal.delivery.DeliveryDtos.ChargesView;
import com.mintadeal.delivery.DeliveryDtos.CostQuote;
import com.mintadeal.vendor.VendorService;

@RestController
public class VendorDeliveryController {

    private final DeliveryService service;
    private final VendorService vendors;
    private final VendorChargeRepository charges;
    private final DeliveryProperties props;

    public VendorDeliveryController(DeliveryService service, VendorService vendors, VendorChargeRepository charges,
                                    DeliveryProperties props) {
        this.service = service;
        this.vendors = vendors;
        this.charges = charges;
        this.props = props;
    }

    /** What a delivery partner would cost for this order, shown before the shop books one. */
    @GetMapping("/api/vendor/orders/{id}/delivery/quote")
    public CostQuote quote(@PathVariable UUID id) {
        return service.quote(vendors.approvedOwnedBy(CurrentUser.id()).getId(), id);
    }

    @PostMapping("/api/vendor/orders/{id}/delivery")
    public CostQuote request(@PathVariable UUID id) {
        UUID user = CurrentUser.id();
        UUID vendorId = vendors.approvedOwnedBy(user).getId();
        var job = service.request(vendorId, user, id);
        return new CostQuote(job.getCostMinor(), job.getDistanceKm(), charges.outstandingFor(vendorId),
                props.maxOutstandingMinor(), true, null);
    }

    @PostMapping("/api/vendor/orders/{id}/delivery/cancel")
    public void cancel(@PathVariable UUID id) {
        UUID user = CurrentUser.id();
        service.vendorCancel(vendors.approvedOwnedBy(user).getId(), user, id);
    }

    @GetMapping("/api/vendor/charges")
    @Transactional(readOnly = true)
    public ChargesView charges() {
        UUID vendorId = vendors.ownedBy(CurrentUser.id()).getId();
        return new ChargesView(charges.outstandingFor(vendorId), props.maxOutstandingMinor(),
                charges.findByVendorIdOrderByCreatedAtDesc(vendorId, PageRequest.of(0, 100)).map(ChargeDto::of).getContent());
    }
}
