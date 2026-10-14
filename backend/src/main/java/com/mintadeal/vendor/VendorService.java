package com.mintadeal.vendor;

import java.time.Clock;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.admin.AuditService;
import com.mintadeal.common.ApiException;
import com.mintadeal.identity.PhoneNumbers;
import com.mintadeal.identity.Role;
import com.mintadeal.identity.User;
import com.mintadeal.identity.UserRepository;
import com.mintadeal.vendor.VendorDtos.VendorProfileRequest;

@Service
public class VendorService {

    static final String CITY = "Bengaluru";

    private final VendorRepository vendors;
    private final UserRepository users;
    private final AuditService audit;
    private final Clock clock;

    public VendorService(VendorRepository vendors, UserRepository users, AuditService audit, Clock clock) {
        this.vendors = vendors;
        this.users = users;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional
    public Vendor apply(UUID userId, VendorProfileRequest req) {
        if (vendors.findByOwnerUserId(userId).isPresent()) {
            throw ApiException.conflict("vendor_exists", "You have already registered a shop");
        }
        User owner = users.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        Vendor vendor = new Vendor(userId, clock.instant());
        apply(vendor, req);
        owner.grant(Role.VENDOR);
        return vendors.save(vendor);
    }

    @Transactional(readOnly = true)
    public Vendor ownedBy(UUID userId) {
        return vendors.findByOwnerUserId(userId)
                .orElseThrow(() -> ApiException.notFound("Shop"));
    }

    /** The caller's shop, which must be approved to sell. */
    @Transactional(readOnly = true)
    public Vendor approvedOwnedBy(UUID userId) {
        Vendor vendor = ownedBy(userId);
        if (!vendor.isApproved()) {
            throw ApiException.forbidden("vendor_not_approved",
                    "Your shop must be approved by Mintadeal before you can do this");
        }
        return vendor;
    }

    @Transactional
    public Vendor update(UUID userId, VendorProfileRequest req) {
        Vendor vendor = ownedBy(userId);
        if (vendor.getStatus() == VendorStatus.SUSPENDED) {
            throw ApiException.forbidden("vendor_suspended", "Your shop is suspended. Contact Mintadeal support");
        }
        apply(vendor, req);
        // A rejected shop that fixes its details goes back into the review queue.
        if (vendor.getStatus() == VendorStatus.REJECTED) {
            vendor.setStatus(VendorStatus.PENDING);
        }
        return vendor;
    }

    @Transactional
    public Vendor changeStatus(UUID vendorId, VendorStatus target, String note) {
        Vendor vendor = vendors.findById(vendorId).orElseThrow(() -> ApiException.notFound("Shop"));
        VendorStatus from = vendor.getStatus();
        boolean allowed = switch (target) {
            case APPROVED -> from == VendorStatus.PENDING || from == VendorStatus.SUSPENDED
                    || from == VendorStatus.REJECTED;
            case REJECTED -> from == VendorStatus.PENDING;
            case SUSPENDED -> from == VendorStatus.APPROVED;
            case PENDING -> false;
        };
        if (!allowed) {
            throw ApiException.conflict("invalid_transition", "Cannot change a " + from + " shop to " + target);
        }
        vendor.setStatus(target);
        vendor.setReviewNote(note);
        vendor.touch(clock.instant());
        audit.record("VENDOR_" + target, "VENDOR", vendorId, note);
        return vendor;
    }

    @Transactional
    public Vendor changeType(UUID vendorId, VendorType type) {
        Vendor vendor = vendors.findById(vendorId).orElseThrow(() -> ApiException.notFound("Shop"));
        audit.record("VENDOR_TYPE", "VENDOR", vendorId, vendor.getVendorType() + " -> " + type);
        vendor.setVendorType(type);
        vendor.touch(clock.instant());
        return vendor;
    }

    private void apply(Vendor v, VendorProfileRequest r) {
        if (r.citywideDelivery() && !(r.selfDelivery() || r.partnerDelivery())) {
            throw ApiException.badRequest("citywide_needs_delivery",
                    "Turn on shop delivery or partner delivery to deliver across Bangalore");
        }
        if (r.selfDelivery() && !r.citywideDelivery() && r.deliveryRadiusKm().signum() <= 0) {
            throw ApiException.badRequest("delivery_radius_required", "Set how far your shop delivers");
        }
        v.setDisplayName(r.displayName().trim());
        v.setLegalName(blankToNull(r.legalName()));
        v.setCategory(r.category());
        v.setPhone(PhoneNumbers.normalize(r.phone()));
        v.setDescription(blankToNull(r.description()));
        v.setAddressLine(r.addressLine().trim());
        v.setArea(r.area().trim());
        v.setCity(CITY);
        v.setPincode(r.pincode());
        v.setLatitude(r.latitude());
        v.setLongitude(r.longitude());
        if (r.locationPinned() != null) {
            v.setLocationPinned(r.locationPinned());
        }
        v.setGstNumber(blankToNull(r.gstNumber()));
        v.setOpeningHours(blankToNull(r.openingHours()));
        v.setLogoUrl(blankToNull(r.logoUrl()));
        v.setCoverUrl(blankToNull(r.coverUrl()));
        v.setPayoutUpiId(blankToNull(r.payoutUpiId()));
        // The DTO masks the account number, so an unchanged masked value must not overwrite the real one.
        if (r.payoutAccountNumber() != null && !r.payoutAccountNumber().contains("•")) {
            v.setPayoutAccountNumber(blankToNull(r.payoutAccountNumber()));
        }
        v.setPayoutIfsc(blankToNull(r.payoutIfsc()));
        v.setSelfDelivery(r.selfDelivery());
        v.setPartnerDelivery(r.partnerDelivery());
        v.setPickup(r.pickup());
        v.setCitywideDelivery(r.citywideDelivery());
        v.setDeliveryRadiusKm(r.deliveryRadiusKm());
        v.setDeliveryFeeMinor(r.deliveryFeeMinor());
        v.setMinOrderMinor(r.minOrderMinor());
        v.touch(clock.instant());
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
