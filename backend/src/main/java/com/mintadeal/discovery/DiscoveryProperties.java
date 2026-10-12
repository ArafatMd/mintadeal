package com.mintadeal.discovery;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param nearbyRadiusKm how far away a shop can be for pickup and venue offers to count as "nearby"
 * @param maxSearchRadiusKm outer limit for shops considered at all in Nearby (delivery radius is capped by this)
 */
@ConfigurationProperties("mintadeal.discovery")
public record DiscoveryProperties(double nearbyRadiusKm, double maxSearchRadiusKm) {
}
