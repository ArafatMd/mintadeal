package com.mintadeal.catalogue;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.catalogue.ListingDtos.ListingDto;
import com.mintadeal.catalogue.ListingDtos.ListingRequest;
import com.mintadeal.catalogue.ListingDtos.StockUpdate;
import com.mintadeal.common.CurrentUser;

@RestController
@RequestMapping("/api/vendor/listings")
public class VendorListingController {

    private final ListingService service;

    public VendorListingController(ListingService service) {
        this.service = service;
    }

    @GetMapping
    public List<ListingDto> mine() {
        return service.mine(CurrentUser.id()).stream().map(ListingDto::of).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ListingDto create(@Valid @RequestBody ListingRequest req) {
        return ListingDto.of(service.create(CurrentUser.id(), req));
    }

    @PutMapping("/{id}")
    public ListingDto update(@PathVariable UUID id, @Valid @RequestBody ListingRequest req) {
        return ListingDto.of(service.update(CurrentUser.id(), id, req));
    }

    @PostMapping("/{id}/publish")
    public ListingDto publish(@PathVariable UUID id) {
        return ListingDto.of(service.publish(CurrentUser.id(), id));
    }

    @PostMapping("/{id}/pause")
    public ListingDto pause(@PathVariable UUID id) {
        return ListingDto.of(service.pause(CurrentUser.id(), id));
    }

    @PutMapping("/{id}/stock")
    public ListingDto stock(@PathVariable UUID id, @Valid @RequestBody StockUpdate req) {
        return ListingDto.of(service.updateStock(CurrentUser.id(), id, req.stock()));
    }
}
