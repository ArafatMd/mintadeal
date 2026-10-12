package com.mintadeal.order;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.util.HexFormat;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import com.mintadeal.support.ProviderStub;

/** Online payment with the development gateway and with Razorpay (via the stub server). */
class OnlinePaymentApiTest extends OrderTestBase {

    @Autowired
    PaymentService payments;

    @Test
    void unpaidOrderStaysHiddenFromShopUntilPaid() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta", 29500, 10, "\"PICKUP\"");
        String customer = login("9845012345");

        var placed = call(POST("/api/customer/checkout"), customer, cart("r1", "ONLINE", null, null, atta, "1"))
                .andExpect(jsonPath("$.paymentStatus").value("PENDING"))
                .andExpect(jsonPath("$.orders[0].status").value("PENDING_PAYMENT"));
        String checkoutId = read(placed, "$.id");
        String payUrl = read(placed, "$.paymentUrl");
        String orderId = read(placed, "$.orders[0].id");
        call(GET("/api/vendor/orders"), shop.token(), null).andExpect(jsonPath("$.total").value(0));
        call(GET("/api/vendor/orders/" + orderId), shop.token(), null).andExpect(status().isNotFound());

        // The development payment page stands in for Razorpay.
        String ref = payUrl.substring(payUrl.lastIndexOf('/') + 1);
        mvc.perform(POST("/dev/pay/" + ref)).andExpect(status().isOk());

        call(POST("/api/customer/checkouts/" + checkoutId + "/refresh-payment"), customer, null)
                .andExpect(jsonPath("$.paymentStatus").value("PAID"))
                .andExpect(jsonPath("$.paymentUrl").doesNotExist())
                .andExpect(jsonPath("$.orders[0].status").value("PLACED"));
        call(GET("/api/vendor/orders?filter=NEW"), shop.token(), null).andExpect(jsonPath("$.items[0].id").value(orderId));
    }

    @Test
    void venueOfferIsConfirmedOnPaymentAndRefundedIfTheShopCancels() throws Exception {
        Shop salon = shop("9876543210", "Glow Salon", null);
        String haircut = offer(salon, "Haircut", 49900);
        String customer = login("9845012345");

        call(POST("/api/customer/checkout/quote"), customer, cart("q", "PAY_ON_DELIVERY", null, null, haircut, "1"))
                .andExpect(jsonPath("$.payOnDeliveryAllowed").value(false))
                .andExpect(jsonPath("$.problems[0]").value("Venue offers must be paid online"));

        var placed = call(POST("/api/customer/checkout"), customer, cart("r1", "ONLINE", null, null, haircut, "2"));
        String payUrl = read(placed, "$.paymentUrl");
        String orderId = read(placed, "$.orders[0].id");
        mvc.perform(POST("/dev/pay/" + payUrl.substring(payUrl.lastIndexOf('/') + 1))).andExpect(status().isOk());

        call(GET("/api/customer/orders/" + orderId), customer, null)
                .andExpect(jsonPath("$.status").value("ACCEPTED"))
                .andExpect(jsonPath("$.fulfilmentMode").value("VENUE_QR"))
                .andExpect(jsonPath("$.totalMinor").value(99800));
        call(GET("/api/vendor/orders/" + orderId), salon.token(), null)
                .andExpect(jsonPath("$.actions[0]").value("REDEEM"))
                .andExpect(jsonPath("$.redemption.token").doesNotExist());

        String admin = login(ADMIN_PHONE);
        call(POST("/api/admin/orders/" + orderId + "/cancel"), admin, "{\"reason\":\"Salon closed for renovation\"}")
                .andExpect(jsonPath("$.refund.status").value("PROCESSED"))
                .andExpect(jsonPath("$.refund.amountMinor").value(99800));
    }

    @Test
    void cancellingAnUnpaidCheckoutCancelsAllItsOrders() throws Exception {
        Shop a = shop("9876543210", "Shop A", "\"pickup\":true");
        Shop b = shop("9876543211", "Shop B", "\"pickup\":true");
        String x = product(a, "X", 10000, 5, "\"PICKUP\"");
        String y = product(b, "Y", 10000, 5, "\"PICKUP\"");
        String customer = login("9845012345");
        var placed = call(POST("/api/customer/checkout"), customer, cart("r1", "ONLINE", null, null, x, "1", y, "1"));
        String first = read(placed, "$.orders[0].id");
        String checkoutId = read(placed, "$.id");

        call(POST("/api/customer/orders/" + first + "/cancel"), customer, null).andExpect(status().isOk());
        call(GET("/api/customer/checkouts/" + checkoutId), customer, null)
                .andExpect(jsonPath("$.paymentStatus").value("CANCELLED"))
                .andExpect(jsonPath("$.orders[0].status").value("CANCELLED"))
                .andExpect(jsonPath("$.orders[1].status").value("CANCELLED"));
        assertThat(stockOf(x)).isEqualTo(5);
        assertThat(stockOf(y)).isEqualTo(5);
    }

    @Test
    void unpaidCheckoutsExpireAndReleaseStock() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta", 29500, 10, "\"PICKUP\"");
        String customer = login("9845012345");
        String checkoutId = read(call(POST("/api/customer/checkout"), customer,
                cart("r1", "ONLINE", null, null, atta, "3")), "$.id");
        assertThat(stockOf(atta)).isEqualTo(7);

        jdbc.update("update checkout set payment_deadline = now() - interval '1 minute' where id = ?::uuid", checkoutId);
        payments.expireUnpaid();

        call(GET("/api/customer/checkouts/" + checkoutId), customer, null)
                .andExpect(jsonPath("$.paymentStatus").value("EXPIRED"))
                .andExpect(jsonPath("$.orders[0].status").value("CANCELLED"));
        assertThat(stockOf(atta)).isEqualTo(10);
    }

    @Test
    void razorpayPaymentLinkIsConfirmedOnlyBySignedWebhook() throws Exception {
        String admin = login(ADMIN_PHONE);
        call(PUT("/api/admin/settings/RAZORPAY"), admin, """
                {"enabled":true,"config":{"keyId":"rzp_test_abc"},
                 "secrets":{"keySecret":"secret123","webhookSecret":"whsec_456"}}""").andExpect(status().isOk());
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta", 29500, 10, "\"PICKUP\"");
        String customer = login("9845012345");

        var placed = call(POST("/api/customer/checkout"), customer, cart("r1", "ONLINE", null, null, atta, "2"))
                .andExpect(jsonPath("$.paymentUrl").value(org.hamcrest.Matchers.startsWith("https://rzp.io/i/")));
        String checkoutId = read(placed, "$.id");
        var create = ProviderStub.INSTANCE.requests.stream()
                .filter(r -> r.path().equals("/v1/payment_links") && r.method().equals("POST")).findFirst().orElseThrow();
        assertThat(create.body()).contains("\"amount\":59000").contains("\"currency\":\"INR\"");
        String linkId = jdbc.queryForObject("select payment_reference from checkout where id = ?::uuid", String.class, checkoutId);

        String event = """
                {"event":"payment_link.paid","payload":{"payment_link":{"entity":{"id":"%s","status":"paid"}},
                 "payment":{"entity":{"id":"pay_123","status":"captured"}}}}""".formatted(linkId);
        mvc.perform(POST("/api/webhooks/razorpay").contentType(MediaType.APPLICATION_JSON).content(event)
                .header("X-Razorpay-Signature", "forged")).andExpect(status().isUnauthorized());
        call(GET("/api/customer/checkouts/" + checkoutId), customer, null)
                .andExpect(jsonPath("$.paymentStatus").value("PENDING"));

        mvc.perform(POST("/api/webhooks/razorpay").contentType(MediaType.APPLICATION_JSON).content(event)
                .header("X-Razorpay-Signature", hmac("whsec_456", event))).andExpect(status().isOk());
        // Razorpay retries webhooks; a second delivery must change nothing.
        mvc.perform(POST("/api/webhooks/razorpay").contentType(MediaType.APPLICATION_JSON).content(event)
                .header("X-Razorpay-Signature", hmac("whsec_456", event))).andExpect(status().isOk());
        call(GET("/api/customer/checkouts/" + checkoutId), customer, null)
                .andExpect(jsonPath("$.paymentStatus").value("PAID"))
                .andExpect(jsonPath("$.orders[0].status").value("PLACED"));

        String orderId = read(call(GET("/api/customer/checkouts/" + checkoutId), customer, null), "$.orders[0].id");
        call(POST("/api/vendor/orders/" + orderId + "/reject"), shop.token(), "{\"reason\":\"Closed today\"}")
                .andExpect(status().isOk());
        assertThat(ProviderStub.INSTANCE.requests).anyMatch(r -> r.path().equals("/v1/payments/pay_123/refund")
                && r.body().contains("\"amount\":59000"));
    }

    @Test
    void customerReturningFromRazorpayGetsStatusFromRazorpayNotTheApp() throws Exception {
        String admin = login(ADMIN_PHONE);
        call(PUT("/api/admin/settings/RAZORPAY"), admin, """
                {"enabled":true,"config":{"keyId":"rzp_test_abc"},
                 "secrets":{"keySecret":"secret123","webhookSecret":"whsec_456"}}""");
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta", 29500, 10, "\"PICKUP\"");
        String customer = login("9845012345");
        String checkoutId = read(call(POST("/api/customer/checkout"), customer,
                cart("r1", "ONLINE", null, null, atta, "1")), "$.id");

        call(POST("/api/customer/checkouts/" + checkoutId + "/refresh-payment"), customer, null)
                .andExpect(jsonPath("$.paymentStatus").value("PENDING"));
        ProviderStub.INSTANCE.linkStatus = "paid";
        call(POST("/api/customer/checkouts/" + checkoutId + "/refresh-payment"), customer, null)
                .andExpect(jsonPath("$.paymentStatus").value("PAID"));
    }

    private static String hmac(String secret, String body) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        return HexFormat.of().formatHex(mac.doFinal(body.getBytes(StandardCharsets.UTF_8)));
    }
}
