package com.mintadeal.geo;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * The neighbourhood and pincode of a point, from OpenStreetMap data.
 *
 * <p>OpenStreetMap's public Nominatim allows at most one request a second and asks apps to cache, so answers are
 * kept for 30 days per ~100 m square and requests are spaced out; when the service is busy, slow or off, callers
 * get nothing and show the nearest listed area instead.
 */
@Service
public class PlaceNames {

    /** @param name the neighbourhood, e.g. "RT Nagar"; null when unknown */
    public record Place(String name, String pincode) {
    }

    private static final Logger log = LoggerFactory.getLogger(PlaceNames.class);
    private static final Duration CACHE_FOR = Duration.ofDays(30);
    private static final Duration MIN_GAP = Duration.ofMillis(1100);
    private static final int MAX_CACHE = 50_000;
    private static final String USER_AGENT = "Mintadeal/1.0 (+https://mintadeal.com)";

    private record Cached(Place place, Instant at) {
    }

    private final GeocodingProperties props;
    private final ObjectMapper json;
    private final Clock clock;
    private final HttpClient http;
    private final Map<String, Cached> cache = new ConcurrentHashMap<>();
    private Instant lastCall = Instant.MIN;

    public PlaceNames(GeocodingProperties props, ObjectMapper json, Clock clock) {
        this.props = props;
        this.json = json;
        this.clock = clock;
        this.http = HttpClient.newBuilder().connectTimeout(props.timeout()).build();
    }

    public Optional<Place> at(double lat, double lng) {
        if (!props.enabled()) {
            return Optional.empty();
        }
        String key = String.format(Locale.ROOT, "%.3f,%.3f", lat, lng);
        Instant now = clock.instant();
        Cached c = cache.get(key);
        if (c != null && c.at().plus(CACHE_FOR).isAfter(now)) {
            return Optional.ofNullable(c.place());
        }
        if (!takeTurn(now)) {
            return Optional.empty();
        }
        Place place = fetch(lat, lng);
        if (place != null) {
            if (cache.size() > MAX_CACHE) {
                cache.clear();
            }
            cache.put(key, new Cached(place, now));
        }
        return Optional.ofNullable(place);
    }

    /** One request at a time, at least {@link #MIN_GAP} apart; a request that would have to wait is skipped. */
    private synchronized boolean takeTurn(Instant now) {
        if (lastCall.plus(MIN_GAP).isAfter(now)) {
            return false;
        }
        lastCall = now;
        return true;
    }

    private Place fetch(double lat, double lng) {
        String base = props.url().endsWith("/") ? props.url() : props.url() + "/";
        String uri = String.format(Locale.ROOT,
                "%sreverse?format=jsonv2&lat=%.6f&lon=%.6f&zoom=16&addressdetails=1&accept-language=en", base, lat, lng);
        if (props.key() != null && !props.key().isBlank()) {
            uri += "&key=" + URLEncoder.encode(props.key(), StandardCharsets.UTF_8);
        }
        try {
            HttpResponse<String> res = http.send(HttpRequest.newBuilder(URI.create(uri)).timeout(props.timeout())
                    .header("User-Agent", USER_AGENT).GET().build(), HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() != 200) {
                log.warn("Place names: {} answered {}", props.url(), res.statusCode());
                return null;
            }
            return parse(json.readTree(res.body()).path("address"));
        } catch (IOException | RuntimeException e) {
            log.warn("Place names unavailable: {}", e.getMessage());
            return null;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return null;
        }
    }

    /** The most local name Nominatim gives for an Indian city address, and the pincode. */
    static Place parse(JsonNode a) {
        String name = null;
        for (String field : new String[] {"suburb", "neighbourhood", "quarter", "residential", "city_district",
                "village", "town"}) {
            String v = a.path(field).asString("");
            if (!v.isBlank()) {
                name = v.strip();
                break;
            }
        }
        String pin = a.path("postcode").asString("").replaceAll("\\s", "");
        return new Place(name, pin.matches("\\d{6}") ? pin : null);
    }
}
