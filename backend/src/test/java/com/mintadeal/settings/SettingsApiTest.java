package com.mintadeal.settings;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import com.mintadeal.support.ApiTest;
import com.mintadeal.support.ProviderStub;

class SettingsApiTest extends ApiTest {

    @Autowired
    JdbcTemplate jdbc;

    @Test
    void secretsAreEncryptedAndNeverReturned() throws Exception {
        String admin = login(ADMIN_PHONE);
        call(PUT("/api/admin/settings/RAZORPAY"), admin, """
                {"enabled":true,"config":{"keyId":"rzp_test_abc"},"secrets":{"keySecret":"supersecret99"}}""")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("setting_incomplete"));

        call(PUT("/api/admin/settings/RAZORPAY"), admin, """
                {"enabled":true,"config":{"keyId":"rzp_test_abc"},
                 "secrets":{"keySecret":"supersecret99","webhookSecret":"whsec_456"}}""")
                .andExpect(jsonPath("$.setting.enabled").value(true))
                .andExpect(jsonPath("$.setting.config.keyId").value("rzp_test_abc"))
                .andExpect(jsonPath("$.setting.secrets.keySecret.set").value(true))
                .andExpect(jsonPath("$.setting.secrets.keySecret.hint").value("••••et99"))
                .andExpect(jsonPath("$.info.mode").value("TEST"))
                .andExpect(jsonPath("$.info.webhookUrl").value(org.hamcrest.Matchers.endsWith("/api/webhooks/razorpay")));

        String stored = jdbc.queryForObject("select coalesce(secret_cipher,'') || config_json from integration_setting",
                String.class);
        assertThat(stored).doesNotContain("supersecret99").doesNotContain("whsec_456");

        // Saving again with blank secrets keeps the stored ones.
        call(PUT("/api/admin/settings/RAZORPAY"), admin, """
                {"enabled":false,"config":{"keyId":"rzp_live_xyz"},"secrets":{"keySecret":""}}""")
                .andExpect(jsonPath("$.setting.secrets.keySecret.set").value(true))
                .andExpect(jsonPath("$.info.mode").value("LIVE"));

        String customer = login("9845012345");
        call(GET("/api/admin/settings"), customer, null).andExpect(status().isForbidden());
    }

    @Test
    void testButtonsCheckCredentialsWithTheProviders() throws Exception {
        String admin = login(ADMIN_PHONE);
        call(PUT("/api/admin/settings/RAZORPAY"), admin, """
                {"enabled":false,"config":{"keyId":"rzp_test_abc"},
                 "secrets":{"keySecret":"secret123","webhookSecret":"whsec_456"}}""");
        call(POST("/api/admin/settings/RAZORPAY/test"), admin, "{}")
                .andExpect(jsonPath("$.ok").value(true))
                .andExpect(jsonPath("$.message").value("Connected to Razorpay in TEST mode"));
        assertThat(ProviderStub.INSTANCE.requests).anyMatch(r -> r.path().startsWith("/v1/payment_links")
                && r.authorization().startsWith("Basic "));

        call(PUT("/api/admin/settings/TWO_FACTOR"), admin, """
                {"enabled":false,"config":{"templateName":"MintadealOTP"},"secrets":{"apiKey":"key-123"}}""");
        call(POST("/api/admin/settings/TWO_FACTOR/test"), admin, "{\"phone\":\"9811122233\"}")
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("+919811122233")));
        assertThat(ProviderStub.INSTANCE.requests).anyMatch(r -> r.path().startsWith("/API/V1/key-123/SMS/919811122233/")
                && r.path().endsWith("/MintadealOTP"));
    }

    @Test
    void signInCodesGoThroughTwoFactorWhenEnabled() throws Exception {
        String admin = login(ADMIN_PHONE);
        call(PUT("/api/admin/settings/TWO_FACTOR"), admin, """
                {"enabled":true,"config":{"templateName":""},"secrets":{"apiKey":"key-123"}}""")
                .andExpect(jsonPath("$.setting.enabled").value(true));

        call(POST("/api/auth/otp/request"), null, "{\"phone\":\"9845012345\"}").andExpect(status().isAccepted());
        assertThat(ProviderStub.INSTANCE.requests).anyMatch(r -> r.path().matches("/API/V1/key-123/SMS/919845012345/\\d{6}"));
        // With a real SMS provider on, the development code no longer works.
        call(POST("/api/auth/otp/verify"), null, "{\"phone\":\"9845012345\",\"code\":\"123456\"}")
                .andExpect(status().isBadRequest());

        ProviderStub.INSTANCE.smsFails = true;
        call(POST("/api/auth/otp/request"), null, "{\"phone\":\"9845012399\"}")
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.code").value("sms_failed"));
    }
}
