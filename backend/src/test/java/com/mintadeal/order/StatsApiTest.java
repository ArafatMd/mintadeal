package com.mintadeal.order;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;

/** The admin home numbers and a shop's performance screen. */
class StatsApiTest extends OrderTestBase {

    @Test
    void shopSeesSalesAcceptanceAndTopItemsAndAdminSeesToday() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta 5 kg", 29500, null, "\"PICKUP\"");
        String dal = product(shop, "Toor dal 1 kg", 18000, null, "\"PICKUP\"");
        String customer = login("9845012345");

        String done = read(call(POST("/api/customer/checkout"), customer, cart("r1", "PAY_ON_DELIVERY", null, null,
                atta, "2", dal, "1")).andExpect(status().isCreated()), "$.orders[0].id");
        call(POST("/api/vendor/orders/" + done + "/accept"), shop.token(), null).andExpect(status().isOk());
        call(POST("/api/vendor/orders/" + done + "/ready"), shop.token(), null).andExpect(status().isOk());
        call(POST("/api/vendor/orders/" + done + "/complete"), shop.token(), null).andExpect(status().isOk());

        String rejected = read(call(POST("/api/customer/checkout"), customer, cart("r2", "PAY_ON_DELIVERY", null, null,
                dal, "1")).andExpect(status().isCreated()), "$.orders[0].id");
        call(POST("/api/vendor/orders/" + rejected + "/reject"), shop.token(), "{\"reason\":\"Out of stock\"}")
                .andExpect(status().isOk());

        call(GET("/api/vendor/stats?days=7"), shop.token(), null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.days").value(7))
                .andExpect(jsonPath("$.orders").value(2))
                .andExpect(jsonPath("$.completed").value(1))
                .andExpect(jsonPath("$.cancelledByShop").value(1))
                .andExpect(jsonPath("$.acceptanceRate").value(0.5))
                .andExpect(jsonPath("$.salesMinor").value(77000))
                .andExpect(jsonPath("$.avgOrderMinor").value(77000))
                .andExpect(jsonPath("$.topItems[0].title").value("Atta 5 kg"))
                .andExpect(jsonPath("$.topItems[0].quantity").value(2))
                .andExpect(jsonPath("$.daily.length()").value(7))
                .andExpect(jsonPath("$.daily[6].orders").value(1));

        String admin = login(ADMIN_PHONE);
        call(GET("/api/admin/overview"), admin, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ordersToday").value(1))
                .andExpect(jsonPath("$.completedToday").value(1))
                .andExpect(jsonPath("$.cancelledToday").value(1))
                .andExpect(jsonPath("$.valueTodayMinor").value(77000))
                .andExpect(jsonPath("$.last7Days.length()").value(7))
                .andExpect(jsonPath("$.liveShops").value(1))
                .andExpect(jsonPath("$.attention.ordersWaitingForShop").value(0));
        call(GET("/api/admin/overview"), shop.token(), null).andExpect(status().isForbidden());
    }
}
