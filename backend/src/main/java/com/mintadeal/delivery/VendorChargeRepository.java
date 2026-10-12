package com.mintadeal.delivery;

import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface VendorChargeRepository extends JpaRepository<VendorCharge, UUID> {

    Page<VendorCharge> findByVendorIdOrderByCreatedAtDesc(UUID vendorId, Pageable pageable);

    @Query("select coalesce(sum(c.amountMinor), 0) from VendorCharge c where c.vendorId = :vendorId and c.status = 'OUTSTANDING'")
    long outstandingFor(UUID vendorId);
}
