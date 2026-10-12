package com.mintadeal.vendor;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.CurrentUser;
import com.mintadeal.vendor.VendorDtos.VendorDto;
import com.mintadeal.vendor.VendorDtos.VendorProfileRequest;

/** The signed-in vendor's own shop. */
@RestController
@RequestMapping("/api/vendor/shop")
public class VendorController {

    private final VendorService service;

    public VendorController(VendorService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public VendorDto apply(@Valid @RequestBody VendorProfileRequest req) {
        return VendorDto.of(service.apply(CurrentUser.id(), req));
    }

    @GetMapping
    public VendorDto mine() {
        return VendorDto.of(service.ownedBy(CurrentUser.id()));
    }

    @PutMapping
    public VendorDto update(@Valid @RequestBody VendorProfileRequest req) {
        return VendorDto.of(service.update(CurrentUser.id(), req));
    }
}
