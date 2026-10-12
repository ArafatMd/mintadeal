package com.mintadeal.admin;

import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import jakarta.validation.Valid;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.catalogue.Listing;
import com.mintadeal.catalogue.ListingDtos.ListingDto;
import com.mintadeal.catalogue.ListingDtos.RemoveRequest;
import com.mintadeal.catalogue.ListingRepository;
import com.mintadeal.catalogue.ListingService;
import com.mintadeal.catalogue.ListingStatus;
import com.mintadeal.common.PageResponse;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorRepository;

@RestController
@RequestMapping("/api/admin/listings")
public class AdminListingController {

    private final ListingRepository listings;
    private final VendorRepository vendors;
    private final ListingService service;

    public AdminListingController(ListingRepository listings, VendorRepository vendors, ListingService service) {
        this.listings = listings;
        this.vendors = vendors;
        this.service = service;
    }

    public record AdminListingDto(ListingDto listing, String vendorName) {
    }

    @GetMapping
    @Transactional(readOnly = true)
    public PageResponse<AdminListingDto> list(@RequestParam(required = false) ListingStatus status,
                                              @RequestParam(defaultValue = "0") int page,
                                              @RequestParam(defaultValue = "50") int size) {
        PageRequest pr = PageRequest.of(page, Math.clamp(size, 1, 200), Sort.by("updatedAt").descending());
        Page<Listing> result = status == null ? listings.findAll(pr) : listings.findByStatus(status, pr);
        Map<UUID, String> names = vendors.findAllById(result.map(Listing::getVendorId).toSet()).stream()
                .collect(Collectors.toMap(Vendor::getId, Vendor::getDisplayName));
        return PageResponse.of(result, l -> new AdminListingDto(ListingDto.of(l), names.get(l.getVendorId())));
    }

    @PostMapping("/{id}/remove")
    public ListingDto remove(@PathVariable UUID id, @Valid @RequestBody RemoveRequest req) {
        return ListingDto.of(service.remove(id, req.reason().trim()));
    }
}
