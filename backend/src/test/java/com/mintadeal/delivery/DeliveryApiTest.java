package com.mintadeal.delivery;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import com.mintadeal.support.ApiTest;

/** Partner delivery from the shop booking a rider to the customer's handover code. */
class DeliveryApiTest extends ApiTest {

    static final String ADDRESS = """
            {"line":"Flat 4B, Green Residency","area":"HSR Layout","landmark":"Near BDA park",
             "latitude":12.9116,"longitude":77.6474}""";

    @Autowired
    JdbcTemplate jdbc;

    record Setup(String shop, String vendorId, String customer, String orderId) {
    }

    private Setup acceptedPartnerOrder() throws Exception {
        String shop = approvedVendor("9876543210", shopJson("Fresh Meats", 12.9121, 77.6446,
                "\"partnerDelivery\":true,\"deliveryRadiusKm\":5"));
        String vendorId = read(call(GET("/api/vendor/shop"), shop, null), "$.id");
        String listing = read(call(POST("/api/vendor/listings"), shop, """
                {"listingType":"PRODUCT","title":"Chicken 1 kg","priceMinor":28000,"fulfilmentModes":["PARTNER_DELIVERY"]}"""), "$.id");
        call(POST("/api/vendor/listings/" + listing + "/publish"), shop, null);
        String customer = login("9845012345");
        String orderId = read(call(POST("/api/customer/checkout"), customer, """
                {"clientRequestId":"r1","items":[{"listingId":"%s","quantity":2}],"paymentMethod":"PAY_ON_DELIVERY",
                 "address":%s,"contactName":"Asha"}""".formatted(listing, ADDRESS)), "$.orders[0].id");
        call(POST("/api/vendor/orders/" + orderId + "/accept"), shop, null)
                .andExpect(jsonPath("$.actions").value(hasItem("REQUEST_DELIVERY")));
        return new Setup(shop, vendorId, customer, orderId);
    }

    private String rider(String phone, String name) throws Exception {
        String admin = login(ADMIN_PHONE);
        call(POST("/api/admin/users/roles"), admin, "{\"phone\":\"" + phone + "\",\"role\":\"DELIVERY_AGENT\",\"granted\":true}");
        String token = login(phone);
        call(PATCH("/api/me"), token, "{\"name\":\"" + name + "\"}");
        return token;
    }

    @Test
    void shopBooksRiderWhoPicksUpAndHandsOverWithTheCustomersCode() throws Exception {
        Setup s = acceptedPartnerOrder();

        // About 0.3 km away: base fee plus one started km.
        call(GET("/api/vendor/orders/" + s.orderId() + "/delivery/quote"), s.shop(), null)
                .andExpect(jsonPath("$.costMinor").value(3000 + 800))
                .andExpect(jsonPath("$.allowed").value(true));
        call(POST("/api/vendor/orders/" + s.orderId() + "/delivery"), s.shop(), null).andExpect(status().isOk());
        call(POST("/api/vendor/orders/" + s.orderId() + "/delivery"), s.shop(), null).andExpect(status().isConflict());

        String dropCode = read(call(GET("/api/customer/orders/" + s.orderId()), s.customer(), null)
                .andExpect(jsonPath("$.delivery.status").value("REQUESTED"))
                .andExpect(jsonPath("$.delivery.costMinor").doesNotExist()), "$.delivery.dropCode");
        call(GET("/api/vendor/orders/" + s.orderId()), s.shop(), null)
                .andExpect(jsonPath("$.delivery.costMinor").value(3800))
                .andExpect(jsonPath("$.delivery.dropCode").doesNotExist())
                .andExpect(jsonPath("$.actions").value(hasItem("CANCEL_DELIVERY")));

        String ravi = rider("9123456780", "Ravi");
        String sunil = rider("9123456781", "Sunil");
        call(GET("/api/delivery/jobs/available"), ravi, null)
                .andExpect(jsonPath("$[0].drop.area").value("HSR Layout"))
                .andExpect(jsonPath("$[0].drop.phone").doesNotExist())
                .andExpect(jsonPath("$[0].drop.address").doesNotExist())
                .andExpect(jsonPath("$[0].cashToCollectMinor").value(56000 + 2000)); // items plus the delivery fee
        String jobId = read(call(GET("/api/delivery/jobs/available"), ravi, null), "$[0].id");

        call(POST("/api/delivery/jobs/" + jobId + "/claim"), ravi, null)
                .andExpect(jsonPath("$.status").value("ASSIGNED"))
                .andExpect(jsonPath("$.drop.phone").value("+919845012345"))
                .andExpect(jsonPath("$.drop.address").value("Flat 4B, Green Residency (Near BDA park)"));
        call(POST("/api/delivery/jobs/" + jobId + "/claim"), sunil, null).andExpect(status().isConflict());
        call(POST("/api/delivery/jobs/" + jobId + "/picked-up"), sunil, null).andExpect(status().isNotFound());
        // Customers and shops cannot use the delivery API.
        call(GET("/api/delivery/jobs/available"), s.customer(), null).andExpect(status().isForbidden());

        call(POST("/api/delivery/jobs/" + jobId + "/picked-up"), ravi, null)
                .andExpect(jsonPath("$.status").value("PICKED_UP"));
        call(GET("/api/customer/orders/" + s.orderId()), s.customer(), null)
                .andExpect(jsonPath("$.status").value("OUT_FOR_DELIVERY"))
                .andExpect(jsonPath("$.delivery.agentName").value("Ravi"));
        call(GET("/api/vendor/charges"), s.shop(), null)
                .andExpect(jsonPath("$.outstandingMinor").value(3800))
                .andExpect(jsonPath("$.charges[0].description").value(org.hamcrest.Matchers.startsWith("Delivery partner for order")));

        String wrong = dropCode.equals("0000") ? "1111" : "0000";
        call(POST("/api/delivery/jobs/" + jobId + "/delivered"), ravi, "{\"code\":\"" + wrong + "\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("drop_code_wrong"));
        call(POST("/api/delivery/jobs/" + jobId + "/delivered"), ravi, "{\"code\":\"" + dropCode + "\"}")
                .andExpect(jsonPath("$.status").value("DELIVERED"));
        call(GET("/api/customer/orders/" + s.orderId()), s.customer(), null)
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.delivery.dropCode").doesNotExist());
        call(GET("/api/delivery/jobs?scope=HISTORY"), ravi, null).andExpect(jsonPath("$[0].id").value(jobId));
    }

    @Test
    void failedDeliveryGoesBackToTheShop() throws Exception {
        Setup s = acceptedPartnerOrder();
        call(POST("/api/vendor/orders/" + s.orderId() + "/delivery"), s.shop(), null);
        String ravi = rider("9123456780", "Ravi");
        String jobId = read(call(GET("/api/delivery/jobs/available"), ravi, null), "$[0].id");
        call(POST("/api/delivery/jobs/" + jobId + "/claim"), ravi, null);
        call(POST("/api/delivery/jobs/" + jobId + "/failed"), ravi, "{\"reason\":\"Not picked up yet\"}")
                .andExpect(status().isConflict());
        call(POST("/api/delivery/jobs/" + jobId + "/picked-up"), ravi, null);
        call(POST("/api/delivery/jobs/" + jobId + "/failed"), ravi, "{\"reason\":\"Customer not reachable\"}")
                .andExpect(jsonPath("$.status").value("FAILED"));

        call(GET("/api/vendor/orders/" + s.orderId()), s.shop(), null)
                .andExpect(jsonPath("$.status").value("ACCEPTED"))
                .andExpect(jsonPath("$.delivery.failureReason").value("Customer not reachable"))
                .andExpect(jsonPath("$.actions").value(hasItem("REQUEST_DELIVERY")));
    }

    @Test
    void shopOverItsUnpaidChargesLimitCannotBookMoreRiders() throws Exception {
        Setup s = acceptedPartnerOrder();
        jdbc.update("""
                insert into vendor_charge (id, vendor_id, shop_order_id, charge_type, amount_minor, description, status,
                                           created_at, version)
                values (gen_random_uuid(), ?::uuid, ?::uuid, 'PARTNER_DELIVERY', 199000, 'Earlier deliveries',
                        'OUTSTANDING', now(), 0)""", s.vendorId(), s.orderId());
        call(GET("/api/vendor/orders/" + s.orderId() + "/delivery/quote"), s.shop(), null)
                .andExpect(jsonPath("$.allowed").value(false))
                .andExpect(jsonPath("$.problem").value(org.hamcrest.Matchers.containsString("₹1990")));
        call(POST("/api/vendor/orders/" + s.orderId() + "/delivery"), s.shop(), null)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("delivery_not_allowed"));
    }

    @Test
    void adminAssignsRidersAndCancellingTheOrderCancelsTheJob() throws Exception {
        Setup s = acceptedPartnerOrder();
        call(POST("/api/vendor/orders/" + s.orderId() + "/delivery"), s.shop(), null);
        String ravi = rider("9123456780", "Ravi");
        String admin = login(ADMIN_PHONE);
        String jobId = read(call(GET("/api/admin/delivery/jobs"), admin, null)
                .andExpect(jsonPath("$.items[0].costMinor").value(3800)), "$.items[0].id");

        call(POST("/api/admin/delivery/jobs/" + jobId + "/assign"), admin, "{\"phone\":\"9845012345\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("not_an_agent"));
        call(POST("/api/admin/delivery/jobs/" + jobId + "/assign"), admin, "{\"phone\":\"9123456780\"}")
                .andExpect(jsonPath("$.agentName").value("Ravi"));
        call(GET("/api/delivery/jobs"), ravi, null).andExpect(jsonPath("$[0].id").value(jobId));

        call(POST("/api/admin/orders/" + s.orderId() + "/cancel"), admin, "{\"reason\":\"Customer moved\"}");
        call(GET("/api/delivery/jobs/" + jobId), ravi, null).andExpect(jsonPath("$.status").value("CANCELLED"));
        assertThat(jdbc.queryForObject("select count(*) from vendor_charge", Long.class)).isZero();
    }
}
