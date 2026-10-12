package com.mintadeal.finance;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.mintadeal.vendor.VendorCategory;

public interface CommissionRuleRepository extends JpaRepository<CommissionRule, UUID> {

    Optional<CommissionRule> findByCategory(VendorCategory category);

    Optional<CommissionRule> findByCategoryIsNull();
}
