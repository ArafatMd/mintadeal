package com.mintadeal.customer;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface VendorFollowRepository extends JpaRepository<VendorFollow, VendorFollow.Key> {

    @Query("select f.id.vendorId from VendorFollow f where f.id.customerId = :customerId")
    List<UUID> vendorIdsFollowedBy(UUID customerId);

    @Query("select count(f) from VendorFollow f where f.id.vendorId = :vendorId")
    long countFollowers(UUID vendorId);

    /** Follower counts for several shops at once, as (vendorId, count) rows; shops with none are left out. */
    @Query("select f.id.vendorId, count(f) from VendorFollow f where f.id.vendorId in :vendorIds group by f.id.vendorId")
    List<Object[]> countFollowers(java.util.Collection<UUID> vendorIds);
}
