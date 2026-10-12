package com.mintadeal.order;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface RefundRepository extends JpaRepository<Refund, UUID> {

    Optional<Refund> findByShopOrderId(UUID shopOrderId);
}
