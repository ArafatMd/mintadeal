package com.mintadeal.geo;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

import org.junit.jupiter.api.Test;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

import com.mintadeal.support.ApiTest;
import com.sun.net.httpserver.HttpServer;

/** Naming a location from OpenStreetMap, cached so the public service is asked as little as possible. */
class PlaceApiTest extends ApiTest {

    static final List<String> REQUESTS = new CopyOnWriteArrayList<>();
    static final List<String> AGENTS = new CopyOnWriteArrayList<>();
    static final HttpServer NOMINATIM;

    static {
        try {
            NOMINATIM = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        NOMINATIM.createContext("/reverse", ex -> {
            REQUESTS.add(ex.getRequestURI().getRawQuery());
            AGENTS.add(ex.getRequestHeaders().getFirst("User-Agent"));
            byte[] body = """
                    {"address":{"road":"80 Feet Road","suburb":"RT Nagar","city_district":"Hebbal",
                     "city":"Bengaluru","postcode":"560 032","country_code":"in"}}"""
                    .getBytes(StandardCharsets.UTF_8);
            ex.sendResponseHeaders(200, body.length);
            ex.getResponseBody().write(body);
            ex.close();
        });
        NOMINATIM.start();
    }

    @DynamicPropertySource
    static void geocoder(DynamicPropertyRegistry registry) {
        registry.add("mintadeal.geocoding.url", () -> "http://127.0.0.1:" + NOMINATIM.getAddress().getPort());
    }

    @Test
    void aLocationIsNamedAfterItsNeighbourhoodWithItsPincode() throws Exception {
        call(GET("/api/discovery/place?lat=13.0213&lng=77.5960"), null, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("RT Nagar"))
                .andExpect(jsonPath("$.pincode").value("560032"));
        // Nearby points (within about 100 m) are answered from the cache.
        call(GET("/api/discovery/place?lat=13.0214&lng=77.5961"), null, null)
                .andExpect(jsonPath("$.name").value("RT Nagar"));
        assertThat(REQUESTS).hasSize(1);
        assertThat(REQUESTS.getFirst()).contains("lat=13.021300").contains("zoom=16");
        assertThat(AGENTS.getFirst()).startsWith("Mintadeal/");
        // A new place asked for straight away waits its turn: the app falls back to the nearest listed area.
        call(GET("/api/discovery/place?lat=12.9116&lng=77.6474"), null, null).andExpect(status().isNoContent());
    }
}
