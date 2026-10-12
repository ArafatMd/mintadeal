package com.mintadeal.admin;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.catalogue.ListingDtos.ListingDto;
import com.mintadeal.catalogue.ListingRepository;
import com.mintadeal.common.ApiException;
import com.mintadeal.common.PageResponse;
import com.mintadeal.vendor.VendorDtos.ReviewNote;
import com.mintadeal.vendor.VendorDtos.TypeChange;
import com.mintadeal.vendor.VendorDtos.VendorDto;
import com.mintadeal.vendor.VendorRepository;
import com.mintadeal.vendor.VendorService;
import com.mintadeal.vendor.VendorStatus;

@RestController
@RequestMapping("/api/admin/vendors")
public class AdminVendorController {

    private final VendorRepository vendors;
    private final VendorService service;
    private final ListingRepository listings;
    private final AuditRepository audit;

    public AdminVendorController(VendorRepository vendors, VendorService service, ListingRepository listings,
                                 AuditRepository audit) {
        this.vendors = vendors;
        this.service = service;
        this.listings = listings;
        this.audit = audit;
    }

    public record VendorDetail(VendorDto vendor, List<ListingDto> listings, List<AuditEvent> history) {
    }

    @GetMapping
    @Transactional(readOnly = true)
    public PageResponse<VendorDto> list(@RequestParam(required = false) VendorStatus status,
                                        @RequestParam(defaultValue = "0") int page,
                                        @RequestParam(defaultValue = "50") int size) {
        PageRequest pr = PageRequest.of(page, Math.clamp(size, 1, 200), Sort.by("createdAt").descending());
        return PageResponse.of(status == null ? vendors.findAll(pr) : vendors.findByStatus(status, pr),
                VendorDto::of);
    }

    @GetMapping("/{id}")
    @Transactional(readOnly = true)
    public VendorDetail detail(@PathVariable UUID id) {
        var vendor = vendors.findById(id).orElseThrow(() -> ApiException.notFound("Shop"));
        return new VendorDetail(VendorDto.of(vendor),
                listings.findByVendorIdOrderByUpdatedAtDesc(id).stream().map(ListingDto::of).toList(),
                audit.findByEntityTypeAndEntityIdOrderByCreatedAtDesc("VENDOR", id));
    }

    @PostMapping("/{id}/approve")
    public VendorDto approve(@PathVariable UUID id, @Valid @RequestBody(required = false) ReviewNote note) {
        return VendorDto.of(service.changeStatus(id, VendorStatus.APPROVED, note(note)));
    }

    @PostMapping("/{id}/reject")
    public VendorDto reject(@PathVariable UUID id, @Valid @RequestBody ReviewNote note) {
        if (note.note() == null || note.note().isBlank()) {
            throw ApiException.badRequest("reason_required", "Tell the shop why it was rejected");
        }
        return VendorDto.of(service.changeStatus(id, VendorStatus.REJECTED, note.note()));
    }

    @PostMapping("/{id}/suspend")
    public VendorDto suspend(@PathVariable UUID id, @Valid @RequestBody ReviewNote note) {
        if (note.note() == null || note.note().isBlank()) {
            throw ApiException.badRequest("reason_required", "Give a reason for suspending the shop");
        }
        return VendorDto.of(service.changeStatus(id, VendorStatus.SUSPENDED, note.note()));
    }

    @PutMapping("/{id}/type")
    public VendorDto type(@PathVariable UUID id, @Valid @RequestBody TypeChange req) {
        return VendorDto.of(service.changeType(id, req.vendorType()));
    }

    private static String note(ReviewNote note) {
        return note == null || note.note() == null || note.note().isBlank() ? null : note.note().trim();
    }
}
