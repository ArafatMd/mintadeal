package com.mintadeal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.junit.jupiter.api.Test;

import com.mintadeal.support.ApiTest;
import com.mintadeal.support.ProviderStub;

/** Sign-in codes on WhatsApp, for when the SMS does not arrive. */
class WhatsAppCodeApiTest extends ApiTest {

    private void enableWhatsApp(String loginTemplate) throws Exception {
        String admin = login(ADMIN_PHONE);
        call(PUT("/api/admin/settings/WHATSAPP"), admin, """
                {"enabled":true,"config":{"phoneNumberId":"1098","languageCode":"en",
                 "newOrderTemplate":"md_new_order","orderUpdateTemplate":"md_order_update",
                 "loginCodeTemplate":%s},
                 "secrets":{"accessToken":"EAAG-token"}}""".formatted(loginTemplate == null ? "\"\"" : "\"" + loginTemplate + "\""))
                .andExpect(status().isOk());
    }

    @Test
    void theCodeCanBeSentOnWhatsAppAndSignsIn() throws Exception {
        call(POST("/api/auth/otp/request"), null, "{\"phone\":\"9844400001\"}")
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.channel").value("SMS"))
                .andExpect(jsonPath("$.whatsApp").value(false));

        enableWhatsApp("md_login_code");
        ProviderStub.INSTANCE.requests.clear();
        call(POST("/api/auth/otp/request"), null, "{\"phone\":\"9844400002\",\"channel\":\"WHATSAPP\"}")
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.channel").value("WHATSAPP"))
                .andExpect(jsonPath("$.whatsApp").value(true));

        var sent = ProviderStub.INSTANCE.requests.stream().filter(r -> r.path().equals("/wa/1098/messages")).toList();
        assertThat(sent).hasSize(1);
        String body = sent.getFirst().body();
        assertThat(body).contains("\"name\":\"md_login_code\"").contains("\"to\":\"919844400002\"")
                .contains("\"sub_type\":\"url\"");
        // A real, random code (not the development fixed code), in the body and the copy-code button.
        Matcher m = Pattern.compile("\"text\":\"(\\d{6})\"").matcher(body);
        assertThat(m.find()).isTrue();
        String code = m.group(1);
        assertThat(body.split(code, -1)).hasSize(3);

        call(POST("/api/auth/otp/verify"), null, "{\"phone\":\"9844400002\",\"code\":\"" + code + "\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").exists());
    }

    @Test
    void whatsAppIsRefusedWhenNoLoginTemplateIsSet() throws Exception {
        enableWhatsApp(null);
        call(POST("/api/auth/otp/request"), null, "{\"phone\":\"9844400003\",\"channel\":\"WHATSAPP\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("whatsapp_unavailable"));
        call(POST("/api/auth/otp/request"), null, "{\"phone\":\"9844400003\"}")
                .andExpect(jsonPath("$.whatsApp").value(false));
    }
}
