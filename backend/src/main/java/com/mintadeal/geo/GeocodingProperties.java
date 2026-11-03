package com.mintadeal.geo;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Names places from coordinates ("RT Nagar, 560032") with a Nominatim-compatible reverse geocoder.
 *
 * @param url     the service, e.g. OpenStreetMap's public Nominatim or a self-hosted one; blank turns naming off
 * @param key     an API key, for providers such as LocationIQ that use the same API; blank for Nominatim
 * @param timeout how long to wait before giving up and using the nearest listed area
 */
@ConfigurationProperties("mintadeal.geocoding")
public record GeocodingProperties(String url, String key, Duration timeout) {

    public GeocodingProperties {
        timeout = timeout == null ? Duration.ofSeconds(3) : timeout;
    }

    public boolean enabled() {
        return url != null && !url.isBlank();
    }
}
