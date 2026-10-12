package com.mintadeal.delivery;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DeliveryJobRepository extends JpaRepository<DeliveryJob, UUID> {

    Optional<DeliveryJob> findFirstByShopOrderIdOrderByRequestedAtDesc(UUID shopOrderId);

    Optional<DeliveryJob> findFirstByShopOrderIdAndStatusIn(UUID shopOrderId, Collection<JobStatus> statuses);

    List<DeliveryJob> findByStatusOrderByRequestedAt(JobStatus status);

    Page<DeliveryJob> findByAgentIdAndStatusInOrderByRequestedAtDesc(UUID agentId, Collection<JobStatus> statuses,
                                                                     Pageable pageable);

    Page<DeliveryJob> findByStatusInOrderByRequestedAtDesc(Collection<JobStatus> statuses, Pageable pageable);
}
