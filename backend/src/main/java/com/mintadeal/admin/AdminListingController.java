package com.mintadeal.admin;

import java.util.UUID;

import jakarta.validation.Valid;

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

import com.mintadeal.catalogue.ListingDtos.ListingDto;
import com.mintadeal.catalogue.ListingDtos.RemoveRequest;
import com.mintadeal.catalogue.ListingRepository;
import com.mintadeal.catalogue.ListingService;
import com.mintadeal.catalogue.ListingStatus;
import com.mintadeal.common.PageResponse;

@RestController
@RequestMapping("/api/admin/listings")
public class AdminListingController {

    private final ListingRepository listings;
    private final ListingService service;

    public AdminListingController(ListingRepository listings, ListingService service) {
        this.listings = listings;
        this.service = service;
    }

    @GetMapping
    @Transactional(readOnly = true)
    public PageResponse<ListingDto> list(@RequestParam(required = false) ListingStatus status,
                                         @RequestParam(defaultValue = "0") int page,
                                         @RequestParam(defaultValue = "50") int size) {
        PageRequest pr = PageRequest.of(page, Math.clamp(size, 1, 200), Sort.by("updatedAt").descending());
        return PageResponse.of(status == null ? listings.findAll(pr) : listings.findByStatus(status, pr),
                ListingDto::of);
    }

    @PostMapping("/{id}/remove")
    public ListingDto remove(@PathVariable UUID id, @Valid @RequestBody RemoveRequest req) {
        return ListingDto.of(service.remove(id, req.reason().trim()));
    }
}
