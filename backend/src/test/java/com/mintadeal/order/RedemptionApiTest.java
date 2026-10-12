package com.mintadeal.order;

import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;

/** Venue offers: the QR works once, only at the shop that sold it, only while the offer is valid. */
class RedemptionApiTest extends OrderTestBase {

    record Paid(String orderId, String orderCode, String qr) {
    }

    private Paid buyOffer(String customer, String offerId, int quantity, String requestId) throws Exception {
        var placed = call(POST("/api/customer/checkout"), customer, cart(requestId, "ONLINE", null, null, offerId, "" + quantity));
        String url = read(placed, "$.paymentUrl");
        String orderId = read(placed, "$.orders[0].id");
        mvc.perform(POST("/dev/pay/" + url.substring(url.lastIndexOf('/') + 1))).andExpect(status().isOk());
        var detail = call(GET("/api/customer/orders/" + orderId), customer, null)
                .andExpect(jsonPath("$.status").value("ACCEPTED"))
                .andExpect(jsonPath("$.redemption.token").value(startsWith("MINTADEAL:")));
        return new Paid(orderId, read(detail, "$.code"), read(detail, "$.redemption.token"));
    }

    @Test
    void qrIsCheckedThenUsedOnceAtTheRightShop() throws Exception {
        Shop salon = shop("9876543210", "Glow Salon", null);
        Shop other = shop("9876543211", "Other Salon", null);
        String haircut = offer(salon, "Haircut", 49900);
        String customer = login("9845012345");
        Paid paid = buyOffer(customer, haircut, 2, "r1");

        // The shop never sees the QR payload itself, and cannot just mark the offer used.
        call(GET("/api/vendor/orders/" + paid.orderId()), salon.token(), null)
                .andExpect(jsonPath("$.redemption.token").doesNotExist())
                .andExpect(jsonPath("$.redemption.quantity").value(2));
        call(POST("/api/vendor/orders/" + paid.orderId() + "/complete"), salon.token(), null)
                .andExpect(status().isConflict());

        String body = "{\"code\":\"" + paid.qr() + "\"}";
        call(POST("/api/vendor/redemptions/check"), other.token(), body)
                .andExpect(jsonPath("$.valid").value(false))
                .andExpect(jsonPath("$.problem").value("This code is for a different shop"))
                .andExpect(jsonPath("$.orderCode").doesNotExist());
        call(POST("/api/vendor/redemptions/redeem"), other.token(), body).andExpect(status().isConflict());

        call(POST("/api/vendor/redemptions/check"), salon.token(), body)
                .andExpect(jsonPath("$.valid").value(true))
                .andExpect(jsonPath("$.title").value("Haircut"))
                .andExpect(jsonPath("$.quantity").value(2));
        call(POST("/api/vendor/redemptions/redeem"), salon.token(), body)
                .andExpect(jsonPath("$.usedAt").exists());
        call(GET("/api/customer/orders/" + paid.orderId()), customer, null)
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.redemption.token").doesNotExist());

        call(POST("/api/vendor/redemptions/redeem"), salon.token(), body)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.detail").value("Already used"));
        call(POST("/api/vendor/redemptions/check"), salon.token(), "{\"code\":\"MINTADEAL:made-up\"}")
                .andExpect(status().isNotFound());
    }

    @Test
    void orderNumberAndPhoneDigitsWorkWhenTheQrCannotBeScanned() throws Exception {
        Shop salon = shop("9876543210", "Glow Salon", null);
        String haircut = offer(salon, "Haircut", 49900);
        String customer = login("9845012345");
        Paid paid = buyOffer(customer, haircut, 1, "r1");
        String checkoutCode = paid.orderCode().substring(0, paid.orderCode().lastIndexOf('-'));

        call(POST("/api/vendor/redemptions/check"), salon.token(),
                "{\"orderCode\":\"" + checkoutCode.toLowerCase() + "\",\"phoneLast4\":\"0000\"}")
                .andExpect(status().isNotFound());
        call(POST("/api/vendor/redemptions/redeem"), salon.token(),
                "{\"orderCode\":\"" + checkoutCode.toLowerCase() + "\",\"phoneLast4\":\"2345\"}")
                .andExpect(jsonPath("$.orderCode").value(paid.orderCode()));
    }

    @Test
    void expiredOffersCannotBeUsed() throws Exception {
        Shop salon = shop("9876543210", "Glow Salon", null);
        String haircut = offer(salon, "Haircut", 49900);
        String customer = login("9845012345");
        Paid paid = buyOffer(customer, haircut, 1, "r1");
        jdbc.update("update redemption set valid_to = now() - interval '1 hour' where shop_order_id = ?::uuid",
                paid.orderId());

        call(POST("/api/vendor/redemptions/check"), salon.token(), "{\"code\":\"" + paid.qr() + "\"}")
                .andExpect(jsonPath("$.valid").value(false))
                .andExpect(jsonPath("$.problem").value("This offer has expired"));
    }
}
