package com.mintadeal.popup;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;

import com.mintadeal.support.ApiTest;

/** Shops running stalls, how many stalls a seller may run, and listing fees. */
class PopupLimitsAndFeesApiTest extends ApiTest {

    private static final String PHOTO = "http://localhost:8080/files/00000000-0000-0000-0000-000000000001.jpg";
    private static final String HERE = "\"latitude\":12.9120,\"longitude\":77.6440";
    private static final String CUSTOMER = "lat=12.9116&lng=77.6474";

    private static String stall(String name, String stallName, int days) {
        return """
                {"name":%s,"stallName":%s,"items":[{"imageUrl":"%s","title":"Biryani","priceMinor":15000}],%s,"days":%d}"""
                .formatted(q(name), q(stallName), PHOTO, HERE, days);
    }

    private static String q(String s) {
        return s == null ? "null" : "\"" + s + "\"";
    }

    private void settings(String admin, int shopMax, long shopFee, int sellerMax, long sellerFee) throws Exception {
        call(PUT("/api/admin/popup-settings"), admin, """
                {"shopMaxLive":%d,"shopFeePerDayMinor":%d,"sellerMaxLive":%d,"sellerFeePerDayMinor":%d}"""
                .formatted(shopMax, shopFee, sellerMax, sellerFee)).andExpect(status().isOk());
    }

    @Test
    void anApprovedShopRunsStallsUnderItsOwnNameAndCustomersSeeTheShop() throws Exception {
        String shop = approvedVendor("9833300001", shopJson("Koramangala Residency", 12.9352, 77.6245, "\"pickup\":true"));
        String vendorId = read(call(GET("/api/vendor/shop"), shop, null), "$.id");
        call(GET("/api/popup/me"), shop, null)
                .andExpect(jsonPath("$.shopName").value("Koramangala Residency"))
                .andExpect(jsonPath("$.maxLive").value(1));
        // No name needed: the shop's name is used, and each stall can have its own.
        call(POST("/api/popup/stalls"), shop, stall(null, "Koramangala Residency – Food Fest stall", 2))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Koramangala Residency"))
                .andExpect(jsonPath("$.active[0].name").value("Koramangala Residency – Food Fest stall"));
        call(GET("/api/discovery/popups?" + CUSTOMER), null, null)
                .andExpect(jsonPath("$[0].vendorId").value(vendorId))
                .andExpect(jsonPath("$[0].vendorName").value("Koramangala Residency"))
                .andExpect(jsonPath("$[0].sellerName").value("Koramangala Residency – Food Fest stall"));
        // One at a time by default; the admin raises it for every shop.
        call(POST("/api/popup/stalls"), shop, stall(null, "Second stall", 1)).andExpect(status().isConflict());
        String admin = login(ADMIN_PHONE);
        settings(admin, 2, 0, 1, 0);
        call(POST("/api/popup/stalls"), shop, stall(null, "Second stall", 1))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.active", hasSize(2)));
        call(POST("/api/popup/stalls"), shop, stall(null, "Third stall", 1)).andExpect(status().isConflict());
        call(GET("/api/admin/popups?filter=SHOPS"), admin, null).andExpect(jsonPath("$.items", hasSize(2)));
        // Other sellers keep their own default.
        String hawker = login("9833300002");
        call(POST("/api/popup/stalls"), hawker, stall("Ravi", null, 1)).andExpect(status().isCreated());
        call(POST("/api/popup/stalls"), hawker, stall(null, null, 1)).andExpect(status().isConflict());
    }

    @Test
    void anAdminSetsOneSellersLimitAndFee() throws Exception {
        String admin = login(ADMIN_PHONE);
        settings(admin, 1, 0, 1, 2500);
        String hawker = login("9833300003");
        String userId = read(call(GET("/api/me"), hawker, null), "$.id");
        call(PUT("/api/admin/popup-sellers/" + userId + "/limits"), admin, "{\"maxLive\":3,\"feePerDayMinor\":0}")
                .andExpect(jsonPath("$.effectiveMaxLive").value(3))
                .andExpect(jsonPath("$.effectiveFeePerDayMinor").value(0));
        for (int i = 0; i < 3; i++) {
            call(POST("/api/popup/stalls"), hawker, stall("Asha Crafts", null, 1))
                    .andExpect(status().isCreated()).andExpect(jsonPath("$.active[0].status").value("LIVE"));
        }
        call(POST("/api/popup/stalls"), hawker, stall(null, null, 1)).andExpect(status().isConflict());
        // Back to the defaults.
        call(PUT("/api/admin/popup-sellers/" + userId + "/limits"), admin, "{}")
                .andExpect(jsonPath("$.maxLive").doesNotExist())
                .andExpect(jsonPath("$.effectiveMaxLive").value(1))
                .andExpect(jsonPath("$.effectiveFeePerDayMinor").value(2500));
    }

    @Test
    void sellersPayTheFeeOnlineBeforeTheStallGoesLive() throws Exception {
        String admin = login(ADMIN_PHONE);
        settings(admin, 1, 0, 1, 2000);
        String hawker = login("9833300004");
        call(GET("/api/popup/me"), hawker, null).andExpect(jsonPath("$.feePerDayMinor").value(2000));
        String body = call(POST("/api/popup/stalls"), hawker, stall("Lakshmi Flowers", null, 2))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.active[0].status").value("PENDING_PAYMENT"))
                .andExpect(jsonPath("$.active[0].feeMinor").value(4000))
                .andReturn().getResponse().getContentAsString();
        String id = com.jayway.jsonpath.JsonPath.read(body, "$.active[0].id");
        String url = com.jayway.jsonpath.JsonPath.read(body, "$.active[0].paymentUrl");
        call(GET("/api/discovery/popups?" + CUSTOMER), null, null).andExpect(jsonPath("$", hasSize(0)));
        // Unpaid stalls count towards the limit.
        call(POST("/api/popup/stalls"), hawker, stall(null, null, 1)).andExpect(status().isConflict());

        String ref = url.substring(url.lastIndexOf('/') + 1);
        mvc.perform(GET("/dev/pay/" + ref)).andExpect(status().isOk());
        mvc.perform(POST("/dev/pay/" + ref)).andExpect(status().isOk());
        call(POST("/api/popup/stalls/" + id + "/check-payment"), hawker, null)
                .andExpect(jsonPath("$.active[0].status").value("LIVE"))
                .andExpect(jsonPath("$.active[0].paymentUrl").doesNotExist());
        call(GET("/api/discovery/popups?" + CUSTOMER), null, null).andExpect(jsonPath("$", hasSize(1)));
        call(GET("/api/admin/finance/summary"), admin, null)
                .andExpect(jsonPath("$.popupFeesMinor").value(4000))
                .andExpect(jsonPath("$.balanced").value(true));
    }

    @Test
    void aShopsFeeComesOffItsBalanceAndTheStallIsLiveAtOnce() throws Exception {
        String admin = login(ADMIN_PHONE);
        settings(admin, 1, 1500, 1, 0);
        String shop = approvedVendor("9833300005", shopJson("Sweet Corner", 12.9121, 77.6446, "\"pickup\":true"));
        call(POST("/api/popup/stalls"), shop, stall(null, null, 3))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.active[0].status").value("LIVE"))
                .andExpect(jsonPath("$.active[0].feeMinor").value(4500));
        call(GET("/api/admin/finance/summary"), admin, null)
                .andExpect(jsonPath("$.popupFeesMinor").value(4500))
                .andExpect(jsonPath("$.owedByShopsMinor").value(4500))
                .andExpect(jsonPath("$.balanced").value(true));
    }

    @Test
    void stoppingAnUnpaidStallFreesTheSlot() throws Exception {
        settings(login(ADMIN_PHONE), 1, 0, 1, 1000);
        String hawker = login("9833300006");
        String id = read(call(POST("/api/popup/stalls"), hawker, stall("Toys", null, 1)), "$.active[0].id");
        call(POST("/api/popup/stalls/" + id + "/stop"), hawker, null).andExpect(jsonPath("$.active", hasSize(0)));
        call(POST("/api/popup/stalls"), hawker, stall(null, null, 1)).andExpect(status().isCreated());
    }
}
