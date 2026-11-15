package com.mintadeal.order;

import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * A shop that delivers within 3 km can still offer chosen products across Bengaluru. Far-away customers see only
 * those; nearby customers see everything.
 */
class CitywideProductApiTest extends OrderTestBase {

    private static final String NEAR = "lat=12.9116&lng=77.6474";
    private static final String FAR = "lat=12.9698&lng=77.7500";   // Whitefield, about 13 km away

    private Shop bakery;
    private String cookies;
    private String cake;

    private String product(Shop shop, String title, boolean citywide) throws Exception {
        String id = read(call(POST("/api/vendor/listings"), shop.token(), """
                {"listingType":"PRODUCT","title":"%s","priceMinor":30000,"fulfilmentModes":["SHOP_DELIVERY","PICKUP"],
                 "citywide":%s}""".formatted(title, citywide)).andExpect(status().isCreated()), "$.id");
        call(POST("/api/vendor/listings/" + id + "/publish"), shop.token(), null).andExpect(status().isOk());
        return id;
    }

    @BeforeEach
    void seed() throws Exception {
        // The shop's own city-wide delivery stays off.
        bakery = shop("9855500001", "Corner Bakery", "\"selfDelivery\":true,\"pickup\":true");
        cookies = product(bakery, "Butter cookies", true);
        cake = product(bakery, "Fresh cream cake", false);
    }

    @Test
    void farCustomersSeeOnlyTheProductsDeliveredAcrossBengaluru() throws Exception {
        call(GET("/api/discovery/nearby?" + NEAR), null, null)
                .andExpect(jsonPath("$.items[*].listing.title").value(containsInAnyOrder("Butter cookies", "Fresh cream cake")));
        call(GET("/api/discovery/nearby?" + FAR), null, null)
                .andExpect(jsonPath("$.items[*].listing.title").value(contains("Butter cookies")))
                .andExpect(jsonPath("$.items[0].deliverable").value(true));
        call(GET("/api/discovery/bangalore"), null, null)
                .andExpect(jsonPath("$.items[*].listing.title").value(contains("Butter cookies")))
                .andExpect(jsonPath("$.items[0].listing.citywide").value(true));
        // The shop page, opened from far away, does not show the cake.
        call(GET("/api/discovery/vendors/" + bakery.vendorId() + "?" + FAR), null, null)
                .andExpect(jsonPath("$.listings[*].listing.title").value(contains("Butter cookies")));
        call(GET("/api/vendor/shop"), bakery.token(), null).andExpect(jsonPath("$.citywideDelivery").value(false));
    }

    @Test
    void turningOnTheShopsCitywideDeliveryCoversEveryProduct() throws Exception {
        call(PUT("/api/vendor/shop"), bakery.token(), shopJson("Corner Bakery", 12.9121, 77.6446,
                "\"selfDelivery\":true,\"pickup\":true,\"citywideDelivery\":true")).andExpect(status().isOk());
        call(GET("/api/discovery/nearby?" + FAR), null, null)
                .andExpect(jsonPath("$.items[*].listing.title").value(containsInAnyOrder("Butter cookies", "Fresh cream cake")));
    }

    @Test
    void aFarCartWithANearbyOnlyItemSaysWhichItemStopsDelivery() throws Exception {
        String customer = login("9855500002");
        call(POST("/api/customer/checkout/quote"), customer, cart("q1", "PAY_ON_DELIVERY", FAR_ADDRESS, null, cookies, "1"))
                .andExpect(jsonPath("$.groups[0].selectedMode").value("SHOP_DELIVERY"))
                .andExpect(jsonPath("$.groups[0].problems").isEmpty());
        call(POST("/api/customer/checkout/quote"), customer,
                cart("q2", "PAY_ON_DELIVERY", FAR_ADDRESS, null, cookies, "1", cake, "1"))
                .andExpect(jsonPath("$.groups[0].problems", hasItem(containsString(
                        "Fresh cream cake is only delivered within 3 km of Corner Bakery. Remove it to get the rest delivered, or choose pickup."))));
    }

    @Test
    void citywideNeedsDelivery() throws Exception {
        call(POST("/api/vendor/listings"), bakery.token(), """
                {"listingType":"PRODUCT","title":"Pickup only bread","priceMinor":5000,"fulfilmentModes":["PICKUP"],
                 "citywide":true}""").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("citywide_needs_delivery"));
    }
}
