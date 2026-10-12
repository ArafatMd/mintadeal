package com.mintadeal.catalogue;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ListingRepository extends JpaRepository<Listing, UUID> {

    List<Listing> findByVendorIdOrderByUpdatedAtDesc(UUID vendorId);

    List<Listing> findByVendorIdAndStatusOrderByUpdatedAtDesc(UUID vendorId, ListingStatus status);

    List<Listing> findByVendorIdInAndStatus(Collection<UUID> vendorIds, ListingStatus status);

    Page<Listing> findByStatus(ListingStatus status, Pageable pageable);
}
