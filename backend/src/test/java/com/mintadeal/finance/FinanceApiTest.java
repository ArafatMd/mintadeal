package com.mintadeal.finance;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.util.HexFormat;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import com.mintadeal.order.OrderTestBase;
import com.mintadeal.support.ProviderStub;

/** Commission, the ledger and payouts, checked through the balances shops and admins see. */
class FinanceApiTest extends OrderTestBase {

    private static final String UPI = "\"pickup\":true,\"payoutUpiId\":\"lakshmi@okbank\"";

    /** Places a prepaid pickup order through the development payment page and completes it. */
    private String completedPrepaidOrder(Shop shop, String listing, int qty, String requestId) throws Exception {
        String customer = login("9845012345");
        var placed = call(POST("/api/customer/checkout"), customer, cart(requestId, "ONLINE", null, null, listing, "" + qty));
        String url = read(placed, "$.paymentUrl");
        String orderId = read(placed, "$.orders[0].id");
        mvc.perform(POST("/dev/pay/" + url.substring(url.lastIndexOf('/') + 1))).andExpect(status().isOk());
        for (String step : new String[] {"accept", "ready", "complete"}) {
            call(POST("/api/vendor/orders/" + orderId + "/" + step), shop.token(), null).andExpect(status().isOk());
        }
        return orderId;
    }

    @Test
    void prepaidOrderCreditsTheShopMinusCommission() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", UPI);
        String atta = product(shop, "Atta", 50000, null, "\"PICKUP\"");
        completedPrepaidOrder(shop, atta, 2, "r1");

        // ₹1000 of items at the default 5% commission.
        call(GET("/api/vendor/earnings"), shop.token(), null)
                .andExpect(jsonPath("$.balanceMinor").value(100000 - 5000))
                .andExpect(jsonPath("$.commissionBps").value(500))
                .andExpect(jsonPath("$.statement[0].description").value(org.hamcrest.Matchers.startsWith("Commission 5% on")))
                .andExpect(jsonPath("$.statement[0].amountMinor").value(-5000))
                .andExpect(jsonPath("$.statement[1].amountMinor").value(100000));

        String admin = login(ADMIN_PHONE);
        call(GET("/api/admin/finance/summary"), admin, null)
                .andExpect(jsonPath("$.balanced").value(true))
                .andExpect(jsonPath("$.gatewayMinor").value(100000))
                .andExpect(jsonPath("$.customerPrepaidMinor").value(0))
                .andExpect(jsonPath("$.owedToShopsMinor").value(95000))
                .andExpect(jsonPath("$.commissionRevenueMinor").value(5000));
    }

    @Test
    void payOnDeliveryOrderLeavesTheShopOwingCommission() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", UPI);
        String atta = product(shop, "Atta", 50000, null, "\"PICKUP\"");
        String customer = login("9845012345");
        String orderId = read(call(POST("/api/customer/checkout"), customer,
                cart("r1", "PAY_ON_DELIVERY", null, null, atta, "1")), "$.orders[0].id");
        for (String step : new String[] {"accept", "ready", "complete"}) {
            call(POST("/api/vendor/orders/" + orderId + "/" + step), shop.token(), null);
        }
        call(GET("/api/vendor/earnings"), shop.token(), null).andExpect(jsonPath("$.balanceMinor").value(-2500));
        call(GET("/api/admin/finance/summary"), login(ADMIN_PHONE), null)
                .andExpect(jsonPath("$.owedByShopsMinor").value(2500))
                .andExpect(jsonPath("$.gatewayMinor").value(0));
    }

    @Test
    void commissionRateIsFixedWhenTheOrderIsPlaced() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", UPI);
        String atta = product(shop, "Atta", 50000, null, "\"PICKUP\"");
        String customer = login("9845012345");
        String orderId = read(call(POST("/api/customer/checkout"), customer,
                cart("r1", "PAY_ON_DELIVERY", null, null, atta, "1")), "$.orders[0].id");

        String admin = login(ADMIN_PHONE);
        call(PUT("/api/admin/finance/commission"), admin, "{\"defaultBps\":300,\"categoryBps\":{\"GROCERY\":1000}}")
                .andExpect(jsonPath("$.categoryBps.GROCERY").value(1000));
        call(PUT("/api/admin/finance/commission"), admin, "{\"defaultBps\":9000}")
                .andExpect(status().isBadRequest());

        for (String step : new String[] {"accept", "ready", "complete"}) {
            call(POST("/api/vendor/orders/" + orderId + "/" + step), shop.token(), null);
        }
        // Placed at 5%, so 5% applies even though grocery is now 10%.
        call(GET("/api/vendor/earnings"), shop.token(), null)
                .andExpect(jsonPath("$.balanceMinor").value(-2500))
                .andExpect(jsonPath("$.commissionBps").value(1000));
    }

    @Test
    void refundsReturnTheCustomersMoneyInTheLedger() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", UPI);
        String atta = product(shop, "Atta", 50000, null, "\"PICKUP\"");
        String customer = login("9845012345");
        var placed = call(POST("/api/customer/checkout"), customer, cart("r1", "ONLINE", null, null, atta, "1"));
        String url = read(placed, "$.paymentUrl");
        String orderId = read(placed, "$.orders[0].id");
        mvc.perform(POST("/dev/pay/" + url.substring(url.lastIndexOf('/') + 1)));
        call(POST("/api/vendor/orders/" + orderId + "/reject"), shop.token(), "{\"reason\":\"Closed\"}");

        call(GET("/api/admin/finance/summary"), login(ADMIN_PHONE), null)
                .andExpect(jsonPath("$.balanced").value(true))
                .andExpect(jsonPath("$.gatewayMinor").value(0))
                .andExpect(jsonPath("$.customerPrepaidMinor").value(0))
                .andExpect(jsonPath("$.owedToShopsMinor").value(0));
    }

    @Test
    void failedRefundsCanBeRetried() throws Exception {
        String admin = login(ADMIN_PHONE);
        call(PUT("/api/admin/settings/RAZORPAY"), admin, """
                {"enabled":true,"config":{"keyId":"rzp_test_abc"},
                 "secrets":{"keySecret":"secret123","webhookSecret":"whsec_456"}}""");
        Shop shop = shop("9876543210", "Lakshmi Stores", UPI);
        String atta = product(shop, "Atta", 50000, null, "\"PICKUP\"");
        String customer = login("9845012345");
        String checkoutId = read(call(POST("/api/customer/checkout"), customer, cart("r1", "ONLINE", null, null, atta, "1")), "$.id");
        ProviderStub.INSTANCE.linkStatus = "paid";
        String orderId = read(call(POST("/api/customer/checkouts/" + checkoutId + "/refresh-payment"), customer, null),
                "$.orders[0].id");

        ProviderStub.INSTANCE.refundFails = true;
        call(POST("/api/vendor/orders/" + orderId + "/reject"), shop.token(), "{\"reason\":\"Closed\"}")
                .andExpect(jsonPath("$.refund.status").value("FAILED"));
        call(GET("/api/admin/finance/summary"), admin, null)
                .andExpect(jsonPath("$.failedRefunds").value(1))
                .andExpect(jsonPath("$.customerPrepaidMinor").value(50000));
        String refundId = read(call(GET("/api/admin/finance/refunds"), admin, null)
                .andExpect(jsonPath("$[0].error").value("Razorpay: The refund could not be processed")), "$[0].id");

        ProviderStub.INSTANCE.refundFails = false;
        call(POST("/api/admin/finance/refunds/" + refundId + "/retry"), admin, null)
                .andExpect(jsonPath("$.status").value("PROCESSED"));
        call(GET("/api/admin/finance/summary"), admin, null)
                .andExpect(jsonPath("$.failedRefunds").value(0))
                .andExpect(jsonPath("$.customerPrepaidMinor").value(0));
    }

    @Test
    void payoutBatchPaysShopsAndRecordsTheBankReference() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", UPI);
        Shop noDetails = shop("9876543211", "No Bank Shop", "\"pickup\":true");
        completedPrepaidOrder(shop, product(shop, "Atta", 50000, null, "\"PICKUP\""), 2, "r1");
        completedPrepaidOrder(noDetails, product(noDetails, "Rice", 50000, null, "\"PICKUP\""), 1, "r2");
        String admin = login(ADMIN_PHONE);

        String payoutId = read(call(POST("/api/admin/finance/payouts/batches"), admin, null)
                .andExpect(jsonPath("$.payoutCount").value(1))
                .andExpect(jsonPath("$.totalMinor").value(95000))
                .andExpect(jsonPath("$.payouts[0].destination").value("UPI lakshmi@okbank"))
                .andExpect(jsonPath("$.skipped[0]").value("No Bank Shop: no UPI ID or bank account")), "$.payouts[0].id");
        // The money is on its way, so a second batch does not pay it again.
        call(POST("/api/admin/finance/payouts/batches"), admin, null).andExpect(jsonPath("$.payoutCount").value(0));
        call(GET("/api/vendor/earnings"), shop.token(), null)
                .andExpect(jsonPath("$.balanceMinor").value(0))
                .andExpect(jsonPath("$.inPayoutMinor").value(95000));

        call(POST("/api/admin/finance/payouts/" + payoutId + "/send"), admin, null)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("razorpayx_off"));
        call(POST("/api/admin/finance/payouts/" + payoutId + "/mark-paid"), admin, "{\"utr\":\"HDFC0001234\"}")
                .andExpect(jsonPath("$.status").value("PAID"))
                .andExpect(jsonPath("$.method").value("MANUAL"));
        call(GET("/api/vendor/earnings"), shop.token(), null)
                .andExpect(jsonPath("$.inPayoutMinor").value(0))
                .andExpect(jsonPath("$.payouts[0].utr").value("HDFC0001234"));
        call(GET("/api/admin/finance/summary"), admin, null)
                .andExpect(jsonPath("$.balanced").value(true))
                .andExpect(jsonPath("$.payoutsInTransitMinor").value(0))
                .andExpect(jsonPath("$.gatewayMinor").value(150000 - 95000));
    }

    @Test
    void razorpayXPayoutIsConfirmedByWebhookOrReturnedIfItFails() throws Exception {
        String admin = login(ADMIN_PHONE);
        call(PUT("/api/admin/settings/RAZORPAY"), admin, """
                {"enabled":false,"config":{"keyId":"rzp_test_abc"},
                 "secrets":{"keySecret":"secret123","webhookSecret":"whsec_456"}}""");
        call(PUT("/api/admin/settings/RAZORPAYX"), admin, "{\"enabled\":true,\"config\":{\"accountNumber\":\"2323230000001\"}}")
                .andExpect(status().isOk());
        Shop shop = shop("9876543210", "Lakshmi Stores", UPI);
        completedPrepaidOrder(shop, product(shop, "Atta", 50000, null, "\"PICKUP\""), 2, "r1");
        call(POST("/api/admin/finance/payouts/batches"), admin, null);

        var sent = call(POST("/api/admin/finance/payouts/send-pending"), admin, null)
                .andExpect(jsonPath("$[0].status").value("PROCESSING"))
                .andExpect(jsonPath("$[0].method").value("RAZORPAYX"));
        String payoutId = read(sent, "$[0].id");
        assertThat(ProviderStub.INSTANCE.requests).anyMatch(r -> r.path().equals("/v1/payouts")
                && r.body().contains("\"amount\":95000") && r.body().contains("\"mode\":\"UPI\"")
                && r.body().contains("\"account_number\":\"2323230000001\""));
        assertThat(ProviderStub.INSTANCE.requests).anyMatch(r -> r.path().equals("/v1/fund_accounts")
                && r.body().contains("lakshmi@okbank"));

        ProviderStub.INSTANCE.payoutStatus = "processed";
        String event = "{\"event\":\"payout.processed\",\"payload\":{\"payout\":{\"entity\":{\"id\":\"pout_1\"}}}}";
        String providerId = jdbc.queryForObject("select provider_payout_id from payout where id = ?::uuid", String.class, payoutId);
        event = event.replace("pout_1", providerId);
        mvc.perform(POST("/api/webhooks/razorpay").contentType(MediaType.APPLICATION_JSON).content(event)
                .header("X-Razorpay-Signature", hmac("whsec_456", event))).andExpect(status().isOk());
        call(GET("/api/vendor/earnings"), shop.token(), null)
                .andExpect(jsonPath("$.payouts[0].status").value("PAID"))
                .andExpect(jsonPath("$.payouts[0].utr").value("UTR123456"));

        // A second shop's payout fails at the bank and its money returns to its balance.
        Shop other = shop("9876543211", "Other Stores", "\"pickup\":true,\"payoutUpiId\":\"other@okbank\"");
        completedPrepaidOrder(other, product(other, "Rice", 20000, null, "\"PICKUP\""), 1, "r2");
        call(POST("/api/admin/finance/payouts/batches"), admin, null);
        ProviderStub.INSTANCE.payoutStatus = "processing";
        String failing = read(call(POST("/api/admin/finance/payouts/send-pending"), admin, null), "$[0].id");
        ProviderStub.INSTANCE.payoutStatus = "reversed";
        call(POST("/api/admin/finance/payouts/" + failing + "/refresh"), admin, null)
                .andExpect(jsonPath("$.status").value("FAILED"))
                .andExpect(jsonPath("$.failureReason").value("Beneficiary bank down"));
        call(GET("/api/vendor/earnings"), other.token(), null).andExpect(jsonPath("$.balanceMinor").value(19000));
        call(GET("/api/admin/finance/summary"), admin, null).andExpect(jsonPath("$.balanced").value(true));
    }

    @Test
    void deliveryChargesAreNettedAgainstEarnings() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", UPI);
        completedPrepaidOrder(shop, product(shop, "Atta", 50000, null, "\"PICKUP\""), 1, "r1");
        String admin = login(ADMIN_PHONE);
        call(GET("/api/admin/delivery/charges?vendorId=" + shop.vendorId()), admin, null)
                .andExpect(jsonPath("$.outstandingMinor").value(0));
        call(GET("/api/admin/finance/vendor-balances"), admin, null)
                .andExpect(jsonPath("$[0].vendorName").value("Lakshmi Stores"))
                .andExpect(jsonPath("$[0].balanceMinor").value(47500));
    }

    private static String hmac(String secret, String body) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        return HexFormat.of().formatHex(mac.doFinal(body.getBytes(StandardCharsets.UTF_8)));
    }
}
