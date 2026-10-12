package com.mintadeal.identity;

import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Phones that receive the ADMIN role the first time they sign in. */
@ConfigurationProperties("mintadeal.bootstrap")
public record BootstrapProperties(List<String> adminPhones) {

    public BootstrapProperties {
        adminPhones = adminPhones == null ? List.of() : adminPhones.stream().map(PhoneNumbers::normalize).toList();
    }
}
