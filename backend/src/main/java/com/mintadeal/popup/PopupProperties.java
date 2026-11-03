package com.mintadeal.popup;

import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param allowedDays     how many days a seller can choose; the first is not the default, {@code defaultDays} is
 * @param defaultDays     what the app picks for them
 * @param nearbyRadiusKm  how far away a stall can be to show in "Pop-ups near you"
 * @param maxItems        photos per stall
 * @param maxPerDay       stalls a seller can start in 24 hours, so stop-and-start cannot flood the list
 * @param hideAfterReports a live stall is hidden for admin review once this many customers report it
 */
@ConfigurationProperties("mintadeal.popups")
public record PopupProperties(List<Integer> allowedDays, int defaultDays, double nearbyRadiusKm, int maxItems,
                              int maxPerDay, int hideAfterReports) {

    public PopupProperties {
        allowedDays = allowedDays == null || allowedDays.isEmpty() ? List.of(1, 2, 3, 7) : List.copyOf(allowedDays);
        defaultDays = defaultDays <= 0 ? 2 : defaultDays;
        nearbyRadiusKm = nearbyRadiusKm <= 0 ? 5 : nearbyRadiusKm;
        maxItems = maxItems <= 0 ? 6 : maxItems;
        maxPerDay = maxPerDay <= 0 ? 3 : maxPerDay;
        hideAfterReports = hideAfterReports <= 0 ? 3 : hideAfterReports;
    }
}
