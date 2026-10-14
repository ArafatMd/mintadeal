package com.mintadeal.review;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ReviewRepository extends JpaRepository<Review, UUID> {

    Optional<Review> findByShopOrderId(UUID shopOrderId);

    Page<Review> findByVendorIdAndHiddenFalseOrderByCreatedAtDesc(UUID vendorId, Pageable page);

    Page<Review> findByVendorIdOrderByCreatedAtDesc(UUID vendorId, Pageable page);

    Page<Review> findAllByOrderByCreatedAtDesc(Pageable page);

    Page<Review> findByHiddenTrueOrderByCreatedAtDesc(Pageable page);

    /** Visible reviews per shop, as (vendorId, average, count) rows. */
    @Query("select r.vendorId, avg(r.rating), count(r) from Review r"
            + " where r.hidden = false and r.vendorId in :vendorIds group by r.vendorId")
    List<Object[]> summaries(Collection<UUID> vendorIds);
}
