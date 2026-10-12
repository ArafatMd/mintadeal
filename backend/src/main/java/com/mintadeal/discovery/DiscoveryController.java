package com.mintadeal.discovery;

import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.catalogue.ListingType;
import com.mintadeal.common.CurrentUser;
import com.mintadeal.common.PageResponse;
import com.mintadeal.discovery.DiscoveryDtos.DiscoveryItem;
import com.mintadeal.discovery.DiscoveryDtos.Storefront;
import com.mintadeal.discovery.DiscoveryService.Filter;
import com.mintadeal.vendor.VendorCategory;

/** Public browsing. A signed-in customer additionally gets "followed" flags and the followed-only filter. */
@RestController
@RequestMapping("/api/discovery")
public class DiscoveryController {

    private final DiscoveryService service;

    public DiscoveryController(DiscoveryService service) {
        this.service = service;
    }

    @GetMapping("/nearby")
    public PageResponse<DiscoveryItem> nearby(@RequestParam double lat, @RequestParam double lng,
                                              @RequestParam(required = false) VendorCategory category,
                                              @RequestParam(required = false) ListingType type,
                                              @RequestParam(required = false) String q,
                                              @RequestParam(defaultValue = "false") boolean followedOnly,
                                              @RequestParam(defaultValue = "0") int page,
                                              @RequestParam(defaultValue = "20") int size) {
        return service.nearby(lat, lng, new Filter(category, type, q, followedOnly), CurrentUser.idOrNull(),
                page, size);
    }

    @GetMapping("/bangalore")
    public PageResponse<DiscoveryItem> bangalore(@RequestParam(required = false) Double lat,
                                                 @RequestParam(required = false) Double lng,
                                                 @RequestParam(required = false) VendorCategory category,
                                                 @RequestParam(required = false) ListingType type,
                                                 @RequestParam(required = false) String q,
                                                 @RequestParam(defaultValue = "false") boolean followedOnly,
                                                 @RequestParam(defaultValue = "0") int page,
                                                 @RequestParam(defaultValue = "20") int size) {
        return service.citywide(lat, lng, new Filter(category, type, q, followedOnly), CurrentUser.idOrNull(),
                page, size);
    }

    @GetMapping("/listings/{id}")
    public DiscoveryItem listing(@PathVariable UUID id, @RequestParam(required = false) Double lat,
                                 @RequestParam(required = false) Double lng) {
        return service.listing(id, lat, lng, CurrentUser.idOrNull());
    }

    @GetMapping("/vendors/{id}")
    public Storefront storefront(@PathVariable UUID id, @RequestParam(required = false) Double lat,
                                 @RequestParam(required = false) Double lng) {
        return service.storefront(id, lat, lng, CurrentUser.idOrNull());
    }
}
