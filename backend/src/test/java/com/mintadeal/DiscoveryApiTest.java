package com.mintadeal;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.empty;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.mintadeal.support.ApiTest;

/**
 * The "where listings appear" table from the business architecture:
 * Nearby shows only what this customer can receive; Bangalore shows city-wide delivery and venue offers.
 */
class DiscoveryApiTest extends ApiTest {

    // HSR Layout customer; Whitefield is ~13 km away.
    private static final String HSR = "lat=12.9116&lng=77.6474";
    private static final String WHITEFIELD = "lat=12.9698&lng=77.7500";

    private String grocery;

    @BeforeEach
    void seed() throws Exception {
        grocery = approvedVendor("9876543210", shopJson("Local Grocery", 12.9121, 77.6446,
                "\"selfDelivery\":true,\"pickup\":true"));
        publish(grocery, """
                {"listingType":"PRODUCT","title":"Local atta","priceMinor":100,
                 "fulfilmentModes":["SHOP_DELIVERY","PICKUP"]}""");

        String boutique = approvedVendor("9876543211", shopJson("Citywide Boutique", 12.9107, 77.6493,
                "\"selfDelivery\":true,\"citywideDelivery\":true"));
        publish(boutique, """
                {"listingType":"PRODUCT","title":"Citywide kurta","priceMinor":100,
                 "fulfilmentModes":["SHOP_DELIVERY"]}""");

        String salon = approvedVendor("9876543212", shopJson("HSR Salon", 12.9155, 77.6470, null));
        publish(salon, """
                {"listingType":"OFFER","title":"Salon offer","priceMinor":100,"fulfilmentModes":["VENUE_QR"],
                 "validTo":"%s"}""".formatted(Instant.now().plus(10, ChronoUnit.DAYS)));
    }

    @Test
    void nearbyShowsLocalDeliveryPickupAndVenueOffers() throws Exception {
        call(GET("/api/discovery/nearby?" + HSR), null, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].listing.title")
                        .value(containsInAnyOrder("Local atta", "Citywide kurta", "Salon offer")));
    }

    @Test
    void farCustomerOnlySeesCitywideDelivery() throws Exception {
        call(GET("/api/discovery/nearby?" + WHITEFIELD), null, null)
                .andExpect(jsonPath("$.items[*].listing.title").value(contains("Citywide kurta")))
                .andExpect(jsonPath("$.items[0].deliverable").value(true));
    }

    @Test
    void bangaloreShowsOnlyCitywideDeliveryAndVenueOffers() throws Exception {
        call(GET("/api/discovery/bangalore"), null, null)
                .andExpect(jsonPath("$.items[*].listing.title")
                        .value(containsInAnyOrder("Citywide kurta", "Salon offer")));
    }

    @Test
    void homeScreenGroupsDealsIntoShopCards() throws Exception {
        publish(grocery, """
                {"listingType":"PRODUCT","title":"Local dal","priceMinor":200,"offerPriceMinor":150,
                 "fulfilmentModes":["PICKUP"]}""");
        call(GET("/api/discovery/nearby/shops?" + HSR), null, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(3))
                // Nearest first: the boutique is about 0.2 km away, the grocery 0.3 km.
                .andExpect(jsonPath("$.items[0].vendor.displayName").value("Citywide Boutique"))
                .andExpect(jsonPath("$.items[1].vendor.displayName").value("Local Grocery"))
                .andExpect(jsonPath("$.items[1].dealCount").value(2))
                .andExpect(jsonPath("$.items[1].bestDiscountPercent").value(25))
                .andExpect(jsonPath("$.items[1].tag").value("NEW"))
                .andExpect(jsonPath("$.items[1].followers").value(0));
        call(GET("/api/discovery/nearby/shops?" + HSR + "&type=OFFER"), null, null)
                .andExpect(jsonPath("$.items[*].vendor.displayName").value(contains("HSR Salon")))
                .andExpect(jsonPath("$.items[0].bestDiscountPercent").doesNotExist());
        call(GET("/api/discovery/bangalore/shops"), null, null)
                .andExpect(jsonPath("$.items[*].vendor.displayName")
                        .value(containsInAnyOrder("Citywide Boutique", "HSR Salon")));
    }

    @Test
    void outOfStockAndPausedListingsAreHidden() throws Exception {
        String id = publish(grocery, """
                {"listingType":"PRODUCT","title":"Sold out rice","priceMinor":100,"stock":0,
                 "fulfilmentModes":["PICKUP"]}""");
        String paused = publish(grocery, """
                {"listingType":"PRODUCT","title":"Paused dal","priceMinor":100,"fulfilmentModes":["PICKUP"]}""");
        call(POST("/api/vendor/listings/" + paused + "/pause"), grocery, null).andExpect(status().isOk());

        call(GET("/api/discovery/nearby?" + HSR + "&q=rice"), null, null)
                .andExpect(jsonPath("$.items").value(empty()));
        call(PUT("/api/vendor/listings/" + id + "/stock"), grocery, "{\"stock\":5}").andExpect(status().isOk());
        call(GET("/api/discovery/nearby?" + HSR + "&q=rice"), null, null)
                .andExpect(jsonPath("$.items[0].listing.title").value("Sold out rice"));
        call(GET("/api/discovery/nearby?" + HSR + "&q=dal"), null, null)
                .andExpect(jsonPath("$.items").value(empty()));
    }

    @Test
    void suspendedShopDisappears() throws Exception {
        String admin = login(ADMIN_PHONE);
        String vendorId = read(call(GET("/api/vendor/shop"), grocery, null), "$.id");
        call(POST("/api/admin/vendors/" + vendorId + "/suspend"), admin, "{\"note\":\"Complaints\"}")
                .andExpect(status().isOk());
        call(GET("/api/discovery/nearby?" + HSR + "&q=atta"), null, null)
                .andExpect(jsonPath("$.items").value(empty()));
        call(GET("/api/discovery/vendors/" + vendorId), null, null).andExpect(status().isNotFound());
    }

    @Test
    void followedShopsComeFirstAndCanBeFiltered() throws Exception {
        String customer = login("9845012345");
        String vendorId = read(call(GET("/api/vendor/shop"), grocery, null), "$.id");
        call(PUT("/api/customer/follows/" + vendorId), customer, null).andExpect(status().isNoContent());

        call(GET("/api/discovery/nearby?" + HSR + "&followedOnly=true"), customer, null)
                .andExpect(jsonPath("$.items[*].listing.title").value(contains("Local atta")))
                .andExpect(jsonPath("$.items[0].followed").value(true));
        call(GET("/api/discovery/vendors/" + vendorId + "?" + HSR), customer, null)
                .andExpect(jsonPath("$.followed").value(true))
                .andExpect(jsonPath("$.followers").value(1));
        call(GET("/api/customer/follows"), customer, null)
                .andExpect(jsonPath("$[0].displayName").value("Local Grocery"));
    }

    private String publish(String token, String listingJson) throws Exception {
        String id = read(call(POST("/api/vendor/listings"), token, listingJson).andExpect(status().isCreated()), "$.id");
        call(POST("/api/vendor/listings/" + id + "/publish"), token, null).andExpect(status().isOk());
        return id;
    }
}
