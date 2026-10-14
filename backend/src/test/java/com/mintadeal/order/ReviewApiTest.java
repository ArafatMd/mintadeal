package com.mintadeal.order;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.empty;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;

/** Ratings: customers rate completed orders; shops reply; admins hide abusive reviews. */
class ReviewApiTest extends OrderTestBase {

    private static final String HSR = "lat=12.9116&lng=77.6474";

    /** Places a pickup order for the customer and returns its id, completed if asked. */
    private String order(Shop shop, String listing, String customer, String request, boolean complete) throws Exception {
        String id = read(call(POST("/api/customer/checkout"), customer, cart(request, "PAY_ON_DELIVERY", null, null,
                listing, "1")).andExpect(status().isCreated()), "$.orders[0].id");
        if (complete) {
            call(POST("/api/vendor/orders/" + id + "/accept"), shop.token(), null).andExpect(status().isOk());
            call(POST("/api/vendor/orders/" + id + "/ready"), shop.token(), null).andExpect(status().isOk());
            call(POST("/api/vendor/orders/" + id + "/complete"), shop.token(), null).andExpect(status().isOk());
        }
        return id;
    }

    @Test
    void customersRateCompletedOrdersAndShopsSeeTheirRating() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta 5 kg", 29500, null, "\"PICKUP\"");
        String priya = login("9845012345");
        call(PATCH("/api/me"), priya, "{\"name\":\"Priya Sharma\"}");
        String ravi = login("9845012346");

        String open = order(shop, atta, priya, "r1", false);
        call(GET("/api/customer/orders/" + open + "/review"), priya, null)
                .andExpect(jsonPath("$.canReview").value(false))
                .andExpect(jsonPath("$.review").doesNotExist());
        call(PUT("/api/customer/orders/" + open + "/review"), priya, "{\"rating\":5}")
                .andExpect(status().isBadRequest());

        String done = order(shop, atta, priya, "r2", true);
        call(PUT("/api/customer/orders/" + done + "/review"), priya, "{\"rating\":4,\"comment\":\"Fresh and quick\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.customerName").value("Priya S."))
                .andExpect(jsonPath("$.mine").value(true));
        // Rating again updates the same review.
        call(PUT("/api/customer/orders/" + done + "/review"), priya, "{\"rating\":5,\"comment\":\"Fresh and quick\"}")
                .andExpect(jsonPath("$.rating").value(5));
        // Only the order's own customer can rate it, and only 1 to 5.
        call(PUT("/api/customer/orders/" + done + "/review"), ravi, "{\"rating\":1}").andExpect(status().isNotFound());
        call(PUT("/api/customer/orders/" + done + "/review"), priya, "{\"rating\":6}").andExpect(status().isBadRequest());

        call(PUT("/api/customer/orders/" + order(shop, atta, ravi, "r3", true) + "/review"), ravi, "{\"rating\":2}")
                .andExpect(status().isOk());

        call(GET("/api/discovery/nearby/shops?" + HSR), null, null)
                .andExpect(jsonPath("$.items[0].rating").value(3.5))
                .andExpect(jsonPath("$.items[0].ratingCount").value(2));
        call(GET("/api/discovery/vendors/" + shop.vendorId()), null, null)
                .andExpect(jsonPath("$.rating").value(3.5))
                .andExpect(jsonPath("$.ratingCount").value(2));

        // The shop replies; everyone sees the reply.
        String reviewId = read(call(GET("/api/vendor/reviews"), shop.token(), null)
                .andExpect(jsonPath("$.items[*].rating").value(contains(2, 5))), "$.items[1].id");
        call(PUT("/api/vendor/reviews/" + reviewId + "/reply"), shop.token(), "{\"reply\":\"Thank you, Priya!\"}")
                .andExpect(jsonPath("$.reply").value("Thank you, Priya!"));
        call(GET("/api/discovery/vendors/" + shop.vendorId() + "/reviews"), null, null)
                .andExpect(jsonPath("$.items[1].reply").value("Thank you, Priya!"))
                .andExpect(jsonPath("$.items[0].customerName").value("A customer"));
    }

    @Test
    void adminsHideAbusiveReviewsFromCustomersAndTheAverage() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta 5 kg", 29500, null, "\"PICKUP\"");
        String customer = login("9845012345");
        call(PUT("/api/customer/orders/" + order(shop, atta, customer, "r1", true) + "/review"), customer,
                "{\"rating\":1,\"comment\":\"rude words\"}").andExpect(status().isOk());
        String admin = login(ADMIN_PHONE);
        String id = read(call(GET("/api/admin/reviews"), admin, null)
                .andExpect(jsonPath("$.items[0].customerPhone").value("+919845012345")), "$.items[0].id");
        call(POST("/api/admin/reviews/" + id + "/hide"), admin, "{\"reason\":\"Abusive language\"}")
                .andExpect(jsonPath("$.hidden").value(true));
        call(GET("/api/discovery/vendors/" + shop.vendorId() + "/reviews"), null, null)
                .andExpect(jsonPath("$.items").value(empty()));
        call(GET("/api/discovery/vendors/" + shop.vendorId()), null, null)
                .andExpect(jsonPath("$.ratingCount").value(0))
                .andExpect(jsonPath("$.rating").doesNotExist());
        call(POST("/api/admin/reviews/" + id + "/show"), admin, null).andExpect(jsonPath("$.hidden").value(false));
        call(GET("/api/admin/reviews"), customer, null).andExpect(status().isForbidden());
    }
}
