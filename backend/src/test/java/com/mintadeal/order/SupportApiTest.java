package com.mintadeal.order;

import static org.hamcrest.Matchers.contains;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;

/** Help requests from customers and shops, and the staff queue. */
class SupportApiTest extends OrderTestBase {

    private static String ticket(String topic, String subject, String orderId) {
        return """
                {"topic":"%s","subject":"%s","message":"Please help with this.","orderId":%s}"""
                .formatted(topic, subject, orderId == null ? "null" : "\"" + orderId + "\"");
    }

    @Test
    void customerAsksAboutAnOrderAndStaffAnswer() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta 5 kg", 29500, null, "\"PICKUP\"");
        String customer = login("9845012345");
        String orderId = read(call(POST("/api/customer/checkout"), customer,
                cart("r1", "PAY_ON_DELIVERY", null, null, atta, "1")).andExpect(status().isCreated()), "$.orders[0].id");

        String id = read(call(POST("/api/support/tickets"), customer, ticket("ORDER", "Wrong item", orderId))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.ticket.code").value(org.hamcrest.Matchers.startsWith("HELP-")))
                .andExpect(jsonPath("$.ticket.status").value("OPEN"))
                .andExpect(jsonPath("$.ticket.orderCode").value(org.hamcrest.Matchers.startsWith("MD-")))
                .andExpect(jsonPath("$.messages[0].body").value("Please help with this.")), "$.ticket.id");

        // Someone else's order cannot be attached, and someone else's ticket cannot be read.
        String stranger = login("9845012399");
        call(POST("/api/support/tickets"), stranger, ticket("ORDER", "Not mine", orderId)).andExpect(status().isNotFound());
        call(GET("/api/support/tickets/" + id), stranger, null).andExpect(status().isNotFound());

        String admin = login(ADMIN_PHONE);
        call(GET("/api/admin/support?status=OPEN"), admin, null)
                .andExpect(jsonPath("$.items[0].openerPhone").value("+919845012345"));
        call(POST("/api/admin/support/" + id + "/messages"), admin, "{\"body\":\"Sorry! The shop will replace it.\"}")
                .andExpect(jsonPath("$.ticket.status").value("ANSWERED"))
                .andExpect(jsonPath("$.messages[1].authorName").value("Mintadeal support"));

        call(GET("/api/support/tickets"), customer, null)
                .andExpect(jsonPath("$.items[0].status").value("ANSWERED"));
        call(POST("/api/support/tickets/" + id + "/messages"), customer, "{\"body\":\"Thanks, received.\"}")
                .andExpect(jsonPath("$.ticket.status").value("OPEN"))
                .andExpect(jsonPath("$.messages[*].staff").value(contains(false, true, false)));
        call(POST("/api/support/tickets/" + id + "/close"), customer, null)
                .andExpect(jsonPath("$.ticket.status").value("CLOSED"));
        call(GET("/api/admin/support?status=OPEN"), customer, null).andExpect(status().isForbidden());
    }

    @Test
    void shopsAndCustomersSeeOnlyTheirOwnRequests() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        call(POST("/api/support/tickets?as=VENDOR"), shop.token(), ticket("PAYOUT", "Payout missing", null))
                .andExpect(status().isCreated());
        // The same person asking as a customer starts a separate list.
        call(GET("/api/support/tickets?as=CUSTOMER"), shop.token(), null).andExpect(jsonPath("$.total").value(0));
        call(GET("/api/support/tickets?as=VENDOR"), shop.token(), null)
                .andExpect(jsonPath("$.items[0].subject").value("Payout missing"));

        // Only shop owners can ask as a shop, and nobody as an admin.
        String customer = login("9845012345");
        call(POST("/api/support/tickets?as=VENDOR"), customer, ticket("OTHER", "x", null)).andExpect(status().isForbidden());
        call(POST("/api/support/tickets?as=ADMIN"), customer, ticket("OTHER", "x", null)).andExpect(status().isForbidden());

        // At most five open requests at a time.
        for (int i = 0; i < 5; i++) {
            call(POST("/api/support/tickets"), customer, ticket("OTHER", "Question " + i, null))
                    .andExpect(status().isCreated());
        }
        call(POST("/api/support/tickets"), customer, ticket("OTHER", "One more", null)).andExpect(status().isConflict());
    }
}
