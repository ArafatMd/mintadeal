package com.mintadeal.popup;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface PopupRepository extends JpaRepository<Popup, UUID> {

    @Query("""
            select p from Popup p where p.sellerId = :sellerId and p.stoppedAt is null and p.removedAt is null
            and p.endsAt > :now""")
    Optional<Popup> findLive(UUID sellerId, Instant now);

    List<Popup> findTop20BySellerIdOrderByCreatedAtDesc(UUID sellerId);

    long countBySellerIdAndCreatedAtAfter(UUID sellerId, Instant since);

    @Query("""
            select p from Popup p where p.stoppedAt is null and p.removedAt is null and p.endsAt > :now
            and p.latitude between :minLat and :maxLat and p.longitude between :minLng and :maxLng""")
    List<Popup> findLiveIn(double minLat, double maxLat, double minLng, double maxLng, Instant now);

    @Query("""
            select p from Popup p where p.stoppedAt is null and p.removedAt is null and p.endsAt > :now
            order by p.createdAt desc""")
    Page<Popup> findAllLive(Instant now, Pageable page);

    @Query("""
            select p from Popup p where p.removedAt is null and (p.stoppedAt is not null or p.endsAt <= :now)
            order by p.createdAt desc""")
    Page<Popup> findAllEnded(Instant now, Pageable page);

    Page<Popup> findByRemovedAtIsNotNullOrderByRemovedAtDesc(Pageable page);

    @Query("select p from Popup p where p.id in (select r.popupId from PopupReport r) order by p.createdAt desc")
    Page<Popup> findReported(Pageable page);

    Page<Popup> findBySellerIdOrderByCreatedAtDesc(UUID sellerId, Pageable page);
}
