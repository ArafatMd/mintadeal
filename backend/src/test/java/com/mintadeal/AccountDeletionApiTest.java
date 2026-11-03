package com.mintadeal;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

import com.mintadeal.support.ApiTest;

/** Deleting an account from the app, as Google Play requires, and the reviewers' sign-in. */
@TestPropertySource(properties = {"mintadeal.otp.review-phones=9000000999", "mintadeal.otp.review-code=246810"})
class AccountDeletionApiTest extends ApiTest {

    @Test
    void aCustomerDeletesTheirAccountAndTheOldTokenStopsWorking() throws Exception {
        String token = login("9822200001");
        call(PATCH("/api/me"), token, "{\"name\":\"Asha\"}").andExpect(status().isOk());
        call(delete("/api/me"), token, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.deleted").value(true));
        call(GET("/api/me"), token, null).andExpect(status().isUnauthorized());
        // The number is free again: signing in makes a brand new, empty account.
        String again = login("9822200001");
        call(GET("/api/me"), again, null).andExpect(jsonPath("$.name").doesNotExist());
        String admin = login(ADMIN_PHONE);
        call(GET("/api/admin/users?phone=9822200001"), admin, null).andExpect(status().isOk());
    }

    @Test
    void aShopOwnerRequestDeletionThroughSupport() throws Exception {
        String shop = approvedVendor("9822200002", shopJson("Deletable Store", 12.9121, 77.6446, "\"pickup\":true"));
        call(delete("/api/me"), shop, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.deleted").value(false));
        call(GET("/api/support/tickets?as=VENDOR"), shop, null)
                .andExpect(jsonPath("$.items[0].subject").value("Please delete my account"));
        call(GET("/api/me"), shop, null).andExpect(status().isOk());
    }

    @Test
    void reviewersSignInWithTheirFixedCode() throws Exception {
        mvc.perform(POST("/api/auth/otp/request").contentType("application/json").content("{\"phone\":\"9000000999\"}"))
                .andExpect(status().isAccepted());
        mvc.perform(POST("/api/auth/otp/verify").contentType("application/json")
                        .content("{\"phone\":\"9000000999\",\"code\":\"246810\"}"))
                .andExpect(status().isOk());
    }
}
