package com.mintadeal.settings;

import org.springframework.data.jpa.repository.JpaRepository;

public interface IntegrationSettingRepository extends JpaRepository<IntegrationSetting, IntegrationProvider> {
}
