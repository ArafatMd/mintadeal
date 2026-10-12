package com.mintadeal.order;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface RedemptionRepository extends JpaRepository<Redemption, UUID> {

    Optional<Redemption> findByToken(String token);

    Optional<Redemption> findByShopOrderId(UUID shopOrderId);
}
