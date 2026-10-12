package com.mintadeal.customer;

import java.time.Clock;
import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.ApiException;
import com.mintadeal.common.CurrentUser;
import com.mintadeal.vendor.VendorDtos.VendorPublicDto;
import com.mintadeal.vendor.VendorRepository;

@RestController
@RequestMapping("/api/customer/follows")
public class FollowController {

    private final VendorFollowRepository follows;
    private final VendorRepository vendors;
    private final Clock clock;

    public FollowController(VendorFollowRepository follows, VendorRepository vendors, Clock clock) {
        this.follows = follows;
        this.vendors = vendors;
        this.clock = clock;
    }

    @GetMapping
    @Transactional(readOnly = true)
    public List<VendorPublicDto> list() {
        return vendors.findAllById(follows.vendorIdsFollowedBy(CurrentUser.id())).stream()
                .filter(v -> v.isApproved())
                .map(VendorPublicDto::of)
                .toList();
    }

    @PutMapping("/{vendorId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void follow(@PathVariable UUID vendorId) {
        vendors.findById(vendorId).filter(v -> v.isApproved()).orElseThrow(() -> ApiException.notFound("Shop"));
        VendorFollow.Key key = new VendorFollow.Key(CurrentUser.id(), vendorId);
        if (!follows.existsById(key)) {
            follows.save(new VendorFollow(key.customerId(), vendorId, clock.instant()));
        }
    }

    @DeleteMapping("/{vendorId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void unfollow(@PathVariable UUID vendorId) {
        follows.deleteById(new VendorFollow.Key(CurrentUser.id(), vendorId));
    }
}
