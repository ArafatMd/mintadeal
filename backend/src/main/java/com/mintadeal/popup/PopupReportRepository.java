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

public interface PopupReportRepository extends JpaRepository<PopupReport, UUID> {

    boolean existsByPopupIdAndReporterId(UUID popupId, UUID reporterId);

    long countByPopupId(UUID popupId);

    List<PopupReport> findByPopupIdOrderByCreatedAtDesc(UUID popupId);

    @Query("select r.popupId, count(r) from PopupReport r where r.popupId in :ids group by r.popupId")
    List<Object[]> countByPopupIds(Collection<UUID> ids);

    @Query("""
            select count(distinct r.popupId) from PopupReport r, Popup p where p.id = r.popupId
            and p.removedAt is null and p.stoppedAt is null and p.endsAt > :now""")
    long countLiveReported(Instant now);
}
