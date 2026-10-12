package com.mintadeal.notify;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;

import com.mintadeal.order.OrderTestBase;
import com.mintadeal.support.ProviderStub;

/** WhatsApp alerts: new orders to the shop, progress to the customer, never blocking the order. */
class NotificationApiTest extends OrderTestBase {

    private String enableWhatsApp() throws Exception {
        String admin = login(ADMIN_PHONE);
        call(PUT("/api/admin/settings/WHATSAPP"), admin, """
                {"enabled":true,"config":{"phoneNumberId":"1098","languageCode":"en",
                 "newOrderTemplate":"md_new_order","orderUpdateTemplate":"md_order_update"},
                 "secrets":{"accessToken":"EAAG-token"}}""").andExpect(status().isOk());
        return admin;
    }

    @Test
    void shopHearsAboutNewOrdersAndCustomerAboutProgress() throws Exception {
        String admin = enableWhatsApp();
        call(POST("/api/admin/settings/WHATSAPP/test"), admin, "{}")
                .andExpect(jsonPath("$.message").value("Connected to WhatsApp number +91 80000 00000 Mintadeal"));
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta 5 kg", 29500, null, "\"PICKUP\"");
        String customer = login("9845012345");
        String orderId = read(call(POST("/api/customer/checkout"), customer,
                cart("r1", "PAY_ON_DELIVERY", null, null, atta, "2")), "$.orders[0].id");

        var toShop = ProviderStub.INSTANCE.requests.stream().filter(r -> r.path().equals("/wa/1098/messages")).toList();
        assertThat(toShop).hasSize(1);
        assertThat(toShop.getFirst().authorization()).isEqualTo("Bearer EAAG-token");
        assertThat(toShop.getFirst().body()).contains("\"to\":\"919876543210\"").contains("\"name\":\"md_new_order\"")
                .contains("2 x Atta 5 kg").contains("₹590").contains("Pickup at your shop");

        call(POST("/api/vendor/orders/" + orderId + "/accept"), shop.token(), null);
        var toCustomer = ProviderStub.INSTANCE.requests.stream()
                .filter(r -> r.path().equals("/wa/1098/messages") && r.body().contains("md_order_update")).toList();
        assertThat(toCustomer).hasSize(1);
        assertThat(toCustomer.getFirst().body()).contains("\"to\":\"919845012345\"").contains("accepted by the shop");

        call(GET("/api/admin/finance/notifications"), admin, null)
                .andExpect(jsonPath("$.items[0].event").value("ORDER_ACCEPTED"))
                .andExpect(jsonPath("$.items[0].status").value("SENT"))
                .andExpect(jsonPath("$.items[0].recipient").value("+9198******45"))
                .andExpect(jsonPath("$.items[1].event").value("NEW_ORDER"));
    }

    @Test
    void nothingIsSentWhileWhatsAppIsOff() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta", 29500, null, "\"PICKUP\"");
        call(POST("/api/customer/checkout"), login("9845012345"), cart("r1", "PAY_ON_DELIVERY", null, null, atta, "1"))
                .andExpect(status().isCreated());
        assertThat(ProviderStub.INSTANCE.requests).noneMatch(r -> r.path().startsWith("/wa/"));
    }

    @Test
    void aFailingProviderIsLoggedButNeverBlocksTheOrder() throws Exception {
        String admin = enableWhatsApp();
        ProviderStub.INSTANCE.whatsappFails = true;
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta", 29500, null, "\"PICKUP\"");
        call(POST("/api/customer/checkout"), login("9845012345"), cart("r1", "PAY_ON_DELIVERY", null, null, atta, "1"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.orders[0].status").value("PLACED"));
        call(GET("/api/admin/finance/notifications"), admin, null)
                .andExpect(jsonPath("$.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.items[0].error").value("WhatsApp: Template not approved"));
    }
}
