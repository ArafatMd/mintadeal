package com.mintadeal.routing;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.CopyOnWriteArrayList;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

import com.mintadeal.common.Geo;
import com.mintadeal.support.ApiTest;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

/** Road distances from OSRM when it is configured, and straight-line distances whenever it cannot answer. */
class RoadDistanceApiTest extends ApiTest {

    private static final String HSR = "lat=12.9116&lng=77.6474";

    /** Answers OSRM table requests with roads 1.5 times the straight line, driven at 18 km/h. */
    static final class OsrmStub {

        static final OsrmStub INSTANCE = new OsrmStub();

        final List<String> requests = new CopyOnWriteArrayList<>();
        volatile boolean fails = false;
        private final HttpServer server;

        private OsrmStub() {
            try {
                server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
            } catch (IOException e) {
                throw new UncheckedIOException(e);
            }
            server.createContext("/", this::handle);
            server.start();
        }

        String baseUrl() {
            return "http://127.0.0.1:" + server.getAddress().getPort();
        }

        private void handle(HttpExchange ex) throws IOException {
            String path = ex.getRequestURI().getRawPath();
            requests.add(path + "?" + ex.getRequestURI().getRawQuery());
            String out;
            int status = 200;
            if (fails) {
                status = 500;
                out = "{\"code\":\"InternalError\"}";
            } else {
                String[] coords = path.substring("/table/v1/driving/".length()).split(";");
                double[] origin = lngLat(coords[0]);
                List<String> metres = new ArrayList<>();
                List<String> seconds = new ArrayList<>();
                for (String c : coords) {
                    double[] p = lngLat(c);
                    double m = Geo.distanceKm(origin[1], origin[0], p[1], p[0]) * 1000 * 1.5;
                    metres.add(String.format(Locale.ROOT, "%.1f", m));
                    seconds.add(String.format(Locale.ROOT, "%.1f", m / 5.0));
                }
                out = "{\"code\":\"Ok\",\"distances\":[[" + String.join(",", metres) + "]],\"durations\":[["
                        + String.join(",", seconds) + "]]}";
            }
            byte[] bytes = out.getBytes(StandardCharsets.UTF_8);
            ex.getResponseHeaders().add("Content-Type", "application/json");
            ex.sendResponseHeaders(status, bytes.length);
            ex.getResponseBody().write(bytes);
            ex.close();
        }

        private static double[] lngLat(String c) {
            String[] parts = c.split(",");
            return new double[] {Double.parseDouble(parts[0]), Double.parseDouble(parts[1])};
        }
    }

    @DynamicPropertySource
    static void osrm(DynamicPropertyRegistry registry) {
        registry.add("mintadeal.routing.osrm-url", OsrmStub.INSTANCE::baseUrl);
    }

    @Autowired
    private RoadRouter router;

    private String shopId;

    @BeforeEach
    void seed() throws Exception {
        router.clear();
        OsrmStub.INSTANCE.requests.clear();
        OsrmStub.INSTANCE.fails = false;
        // About 1.3 km from the customer in a straight line.
        String shop = approvedVendor("9876543210", shopJson("Corner Store", 12.9230, 77.6460,
                "\"selfDelivery\":true,\"pickup\":true"));
        shopId = read(call(GET("/api/vendor/shop"), shop, null), "$.id");
        String id = read(call(POST("/api/vendor/listings"), shop, """
                {"listingType":"PRODUCT","title":"Atta","priceMinor":100,
                 "fulfilmentModes":["SHOP_DELIVERY","PICKUP"]}""").andExpect(status().isCreated()), "$.id");
        call(POST("/api/vendor/listings/" + id + "/publish"), shop, null).andExpect(status().isOk());
    }

    @Test
    void shopCardsStorefrontAndDealsCarryTheRoadDistanceAndTime() throws Exception {
        call(GET("/api/discovery/nearby/shops?" + HSR), null, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].distanceKm").value(1.3))
                .andExpect(jsonPath("$.items[0].roadKm").value(1.8))
                // Routed from the customer rounded to about 100 m: 1.8 km at 18 km/h is 6.1 minutes, times 1.6 for traffic.
                .andExpect(jsonPath("$.items[0].roadMinutes").value(10));
        call(GET("/api/discovery/vendors/" + shopId + "?" + HSR), null, null)
                .andExpect(jsonPath("$.roadKm").value(1.8))
                .andExpect(jsonPath("$.listings[0].roadKm").value(1.8));
        call(GET("/api/discovery/nearby?" + HSR), null, null)
                .andExpect(jsonPath("$.items[0].roadMinutes").value(10));
        // The same customer and shop are answered from the cache after the first request.
        assertThat(OsrmStub.INSTANCE.requests).hasSize(1);
        assertThat(OsrmStub.INSTANCE.requests.getFirst()).contains("77.647000,12.912000;77.646000,12.923000").contains("sources=0");
    }

    @Test
    void straightLineDistancesAreUsedWhenRoutingFails() throws Exception {
        OsrmStub.INSTANCE.fails = true;
        call(GET("/api/discovery/nearby/shops?" + HSR), null, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].distanceKm").value(1.3))
                .andExpect(jsonPath("$.items[0].roadKm").doesNotExist());
        // After a failure OSRM is left alone for a while instead of slowing every request down.
        call(GET("/api/discovery/vendors/" + shopId + "?" + HSR), null, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.roadKm").doesNotExist());
        assertThat(OsrmStub.INSTANCE.requests).hasSize(1);
    }

    @Test
    void partnerDeliveryIsPricedByRoad() {
        assertThat(router.between(12.9116, 77.6474, 12.9230, 77.6460))
                .hasValueSatisfying(r -> assertThat(r.km()).isEqualTo(1.8));
    }
}
