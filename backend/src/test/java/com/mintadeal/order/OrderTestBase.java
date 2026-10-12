package com.mintadeal.order;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import com.mintadeal.support.ApiTest;

public abstract class OrderTestBase extends ApiTest {

    // A customer in HSR Layout and shops a few hundred metres away.
    protected static final String HSR_ADDRESS = """
            {"line":"Flat 4B, Green Residency","area":"HSR Layout","landmark":"Near BDA park",
             "latitude":12.9116,"longitude":77.6474}""";
    protected static final String FAR_ADDRESS = """
            {"line":"House 9","area":"Whitefield","latitude":12.9698,"longitude":77.7500}""";

    @Autowired
    protected JdbcTemplate jdbc;

    protected record Shop(String token, String vendorId) {
    }

    protected Shop shop(String phone, String name, String settings) throws Exception {
        String token = approvedVendor(phone, shopJson(name, 12.9121, 77.6446, settings));
        return new Shop(token, read(call(GET("/api/vendor/shop"), token, null), "$.id"));
    }

    protected String product(Shop shop, String title, long price, Integer stock, String modes) throws Exception {
        String id = read(call(POST("/api/vendor/listings"), shop.token(), """
                {"listingType":"PRODUCT","title":"%s","priceMinor":%d,"stock":%s,"fulfilmentModes":[%s]}"""
                .formatted(title, price, stock == null ? "null" : stock, modes))
                .andExpect(status().isCreated()), "$.id");
        call(POST("/api/vendor/listings/" + id + "/publish"), shop.token(), null).andExpect(status().isOk());
        return id;
    }

    protected String offer(Shop shop, String title, long price) throws Exception {
        String id = read(call(POST("/api/vendor/listings"), shop.token(), """
                {"listingType":"OFFER","title":"%s","priceMinor":%d,"fulfilmentModes":["VENUE_QR"],"validTo":"%s"}"""
                .formatted(title, price, Instant.now().plus(10, ChronoUnit.DAYS))).andExpect(status().isCreated()), "$.id");
        call(POST("/api/vendor/listings/" + id + "/publish"), shop.token(), null).andExpect(status().isOk());
        return id;
    }

    protected static String cart(String request, String payment, String address, String modes, String... items) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < items.length; i += 2) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append("{\"listingId\":\"").append(items[i]).append("\",\"quantity\":").append(items[i + 1]).append('}');
        }
        return """
                {"clientRequestId":"%s","items":[%s],"modes":%s,"paymentMethod":"%s","address":%s}"""
                .formatted(request, sb, modes == null ? "{}" : modes, payment, address == null ? "null" : address);
    }

    protected Integer stockOf(String listingId) {
        return jdbc.queryForObject("select stock from listing where id = ?::uuid", Integer.class, listingId);
    }
}
