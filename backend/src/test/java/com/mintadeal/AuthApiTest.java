package com.mintadeal;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;

import com.mintadeal.support.ApiTest;

class AuthApiTest extends ApiTest {

    @Test
    void otpLoginCreatesCustomerAndNormalisesPhone() throws Exception {
        String token = login("098450 12345");
        call(GET("/api/me"), token, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.phone").value("+919845012345"))
                .andExpect(jsonPath("$.roles[0]").value("CUSTOMER"));
    }

    @Test
    void wrongCodeIsRejectedAndLocksAfterMaxAttempts() throws Exception {
        call(POST("/api/auth/otp/request"), null, "{\"phone\":\"9845012345\"}").andExpect(status().isAccepted());
        for (int i = 0; i < 5; i++) {
            call(POST("/api/auth/otp/verify"), null, "{\"phone\":\"9845012345\",\"code\":\"000000\"}")
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("otp_invalid"));
        }
        // Even the right code no longer works once the challenge is locked.
        call(POST("/api/auth/otp/verify"), null, "{\"phone\":\"9845012345\",\"code\":\"123456\"}")
                .andExpect(jsonPath("$.code").value("otp_locked"));
    }

    @Test
    void invalidPhoneIsRejected() throws Exception {
        call(POST("/api/auth/otp/request"), null, "{\"phone\":\"12345\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_phone"));
    }

    @Test
    void bootstrapPhoneBecomesAdminAndOthersCannotUseAdminApi() throws Exception {
        String customer = login("9845012345");
        call(GET("/api/admin/vendors"), customer, null).andExpect(status().isForbidden());
        call(GET("/api/admin/vendors"), null, null).andExpect(status().isUnauthorized());

        String admin = login(ADMIN_PHONE);
        call(GET("/api/admin/vendors"), admin, null).andExpect(status().isOk());
    }

    @Test
    void adminGrantsDeliveryAgentRole() throws Exception {
        String admin = login(ADMIN_PHONE);
        call(POST("/api/admin/users/roles"), admin, "{\"phone\":\"9123456780\",\"role\":\"DELIVERY_AGENT\",\"granted\":true}")
                .andExpect(status().isOk());
        String rider = login("9123456780");
        call(GET("/api/me"), rider, null).andExpect(jsonPath("$.roles").value(
                org.hamcrest.Matchers.hasItem("DELIVERY_AGENT")));
    }
}
