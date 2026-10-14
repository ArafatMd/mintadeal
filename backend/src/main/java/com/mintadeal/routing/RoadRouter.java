package com.mintadeal.routing;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
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
 * Distance and travel time by road, from OSRM's table service.
 *
 * <p>Never fails a request: when routing is off, slow or down, callers get nothing back and use the
 * straight-line distance. After a failure OSRM is left alone for {@link #BACK_OFF} so a dead server costs one
 * timeout, not one per request.
 */
@Service
public class RoadRouter {

    /** A trip by road. */
    public record Road(double km, int minutes) {
    }

    /** A place to route to. */
    public record Point(double lat, double lng) {
    }

    private static final Logger log = LoggerFactory.getLogger(RoadRouter.class);
    private static final Duration BACK_OFF = Duration.ofSeconds(30);
    /** OSRM's default --max-table-size is 100 locations; one is the origin. */
    private static final int MAX_DESTINATIONS = 99;
    private static final int MAX_CACHE = 50_000;
    /** Cached "no road found", so unreachable pairs are not asked for again and again. */
    private static final Road NO_ROAD = new Road(-1, -1);

    private record Cached(Road road, Instant at) {
    }

    private final RoutingProperties props;
    private final ObjectMapper json;
    private final Clock clock;
    private final HttpClient http;
    private final Map<String, Cached> cache = new ConcurrentHashMap<>();
    private volatile Instant downUntil = Instant.MIN;

    public RoadRouter(RoutingProperties props, ObjectMapper json, Clock clock) {
        this.props = props;
        this.json = json;
        this.clock = clock;
        this.http = HttpClient.newBuilder().connectTimeout(props.timeout()).build();
    }

    public boolean enabled() {
        return props.enabled();
    }

    /** Road trip between two points, if routing is on and found one. */
    public Optional<Road> between(double fromLat, double fromLng, double toLat, double toLng) {
        return Optional.ofNullable(fromOrigin(fromLat, fromLng, Map.of("to", new Point(toLat, toLng))).get("to"));
    }

    /**
     * Road trips from one origin (usually the customer) to many destinations. Destinations with no road, or all of
     * them when routing is unavailable, are missing from the result.
     */
    public <K> Map<K, Road> fromOrigin(double lat, double lng, Map<K, Point> destinations) {
        Map<K, Road> out = new HashMap<>();
        if (!props.enabled() || destinations.isEmpty()) {
            return out;
        }
        // About 100 m: close enough for an approximate distance, and customers nearby share cache entries.
        double oLat = Math.round(lat * 1000) / 1000.0;
        double oLng = Math.round(lng * 1000) / 1000.0;
        Instant now = clock.instant();
        List<K> missing = new ArrayList<>();
        destinations.forEach((k, p) -> {
            Cached c = cache.get(key(oLat, oLng, p));
            if (c != null && c.at().plus(props.cacheTtl()).isAfter(now)) {
                if (c.road() != NO_ROAD) {
                    out.put(k, c.road());
                }
            } else {
                missing.add(k);
            }
        });
        if (missing.isEmpty() || now.isBefore(downUntil)) {
            return out;
        }
        for (int from = 0; from < missing.size(); from += MAX_DESTINATIONS) {
            List<K> chunk = missing.subList(from, Math.min(missing.size(), from + MAX_DESTINATIONS));
            List<Point> points = chunk.stream().map(destinations::get).toList();
            List<Road> roads = table(oLat, oLng, points);
            if (roads == null) {
                break;
            }
            if (cache.size() > MAX_CACHE) {
                cache.clear();
            }
            for (int i = 0; i < chunk.size(); i++) {
                Road r = roads.get(i);
                cache.put(key(oLat, oLng, points.get(i)), new Cached(r == null ? NO_ROAD : r, now));
                if (r != null) {
                    out.put(chunk.get(i), r);
                }
            }
        }
        return out;
    }

    /** One OSRM table call; null when OSRM could not answer. */
    private List<Road> table(double lat, double lng, List<Point> points) {
        StringBuilder coords = new StringBuilder(coord(lat, lng));
        for (Point p : points) {
            coords.append(';').append(coord(p.lat(), p.lng()));
        }
        String base = props.osrmUrl().endsWith("/") ? props.osrmUrl() : props.osrmUrl() + "/";
        URI uri = URI.create(base + "table/v1/driving/" + coords + "?sources=0&annotations=distance,duration");
        try {
            HttpResponse<String> res = http.send(HttpRequest.newBuilder(uri).timeout(props.timeout()).GET().build(),
                    HttpResponse.BodyHandlers.ofString());
            JsonNode body = json.readTree(res.body());
            if (res.statusCode() != 200 || !"Ok".equals(body.path("code").asString(""))) {
                return failed("OSRM answered " + res.statusCode() + " " + body.path("code").asString(""));
            }
            JsonNode distances = body.path("distances").path(0);
            JsonNode durations = body.path("durations").path(0);
            List<Road> roads = new ArrayList<>(points.size());
            for (int i = 1; i <= points.size(); i++) {
                JsonNode m = distances.path(i);
                JsonNode s = durations.path(i);
                roads.add(m.isNumber() && s.isNumber() ? road(m.asDouble(), s.asDouble()) : null);
            }
            return roads;
        } catch (IOException | RuntimeException e) {
            return failed("OSRM unreachable: " + e.getClass().getSimpleName() + " " + e.getMessage());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return null;
        }
    }

    private Road road(double metres, double seconds) {
        double km = Math.round(metres / 100.0) / 10.0;
        int minutes = (int) Math.max(1, Math.ceil(seconds * props.durationFactor() / 60.0));
        return new Road(km, minutes);
    }

    private List<Road> failed(String why) {
        if (clock.instant().isAfter(downUntil)) {
            log.warn("{}; using straight-line distances for {}s", why, BACK_OFF.toSeconds());
        }
        downUntil = clock.instant().plus(BACK_OFF);
        return null;
    }

    private static String key(double oLat, double oLng, Point p) {
        return String.format(Locale.ROOT, "%.3f,%.3f>%.5f,%.5f", oLat, oLng, p.lat(), p.lng());
    }

    private static String coord(double lat, double lng) {
        return String.format(Locale.ROOT, "%.6f,%.6f", lng, lat);
    }

    /** Forgets every cached trip; for tests. */
    void clear() {
        cache.clear();
        downUntil = Instant.MIN;
    }
}
