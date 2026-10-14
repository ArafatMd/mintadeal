package com.mintadeal.banner;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface HomeBannerRepository extends JpaRepository<HomeBanner, UUID> {

    List<HomeBanner> findAllByOrderByPositionAscCreatedAtDesc();

    List<HomeBanner> findByActiveTrueOrderByPositionAscCreatedAtDesc();
}
