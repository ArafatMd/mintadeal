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
}
