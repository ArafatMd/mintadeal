package com.mintadeal.routing;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Road distances from a self-hosted OSRM server. Without {@code osrmUrl} everything uses straight-line distances.
 *
 * @param osrmUrl        base URL of the OSRM server, e.g. {@code http://mintadeal-osrm:5000}; blank turns routing off
 * @param timeout        how long a request may take before the straight-line distance is used instead
 * @param durationFactor OSRM assumes empty roads; travel times are multiplied by this to allow for city traffic
 * @param cacheTtl       how long a road distance is remembered
 */
@ConfigurationProperties("mintadeal.routing")
public record RoutingProperties(String osrmUrl, Duration timeout, double durationFactor, Duration cacheTtl) {

    public RoutingProperties {
        timeout = timeout == null ? Duration.ofMillis(1500) : timeout;
        durationFactor = durationFactor <= 0 ? 1.5 : durationFactor;
        cacheTtl = cacheTtl == null ? Duration.ofHours(6) : cacheTtl;
    }

    public boolean enabled() {
        return osrmUrl != null && !osrmUrl.isBlank();
    }
}
