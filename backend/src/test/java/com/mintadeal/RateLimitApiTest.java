package com.mintadeal;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

import com.mintadeal.support.ApiTest;

@TestPropertySource(properties = {"mintadeal.rate-limit.enabled=true", "mintadeal.rate-limit.auth=3",
        "mintadeal.rate-limit.per-minute=1000"})
class RateLimitApiTest extends ApiTest {

    private static final String OTP = "{\"phone\":\"%s\"}";

    @Test
    void tooManySignInAttemptsFromOneAddressAreTurnedAway() throws Exception {
        for (int i = 0; i < 3; i++) {
            call(POST("/api/auth/otp/request").with(r -> { r.setRemoteAddr("10.0.0.5"); return r; })
                    .header("X-Forwarded-For", "49.36.1.1"), null, OTP.formatted("984501234" + i))
                    .andExpect(status().is2xxSuccessful());
        }
        call(POST("/api/auth/otp/request").with(r -> { r.setRemoteAddr("10.0.0.5"); return r; })
                .header("X-Forwarded-For", "49.36.1.1"), null, OTP.formatted("9845012349"))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"))
                .andExpect(jsonPath("$.code").value("rate_limited"));
        // Another customer behind the same proxy, with their own address, is not affected.
        call(POST("/api/auth/otp/request").with(r -> { r.setRemoteAddr("10.0.0.5"); return r; })
                .header("X-Forwarded-For", "49.36.1.2"), null, OTP.formatted("9845012348"))
                .andExpect(status().is2xxSuccessful());
        // Payment webhooks are never limited.
        for (int i = 0; i < 5; i++) {
            call(POST("/api/webhooks/razorpay").with(r -> { r.setRemoteAddr("49.36.1.1"); return r; }), null, "{}")
                    .andExpect(result -> org.assertj.core.api.Assertions.assertThat(result.getResponse().getStatus())
                            .isNotEqualTo(429));
        }
    }

    @Test
    void forwardedAddressIsOnlyTrustedFromThePrivateNetwork() {
        var direct = new org.springframework.mock.web.MockHttpServletRequest();
        direct.setRemoteAddr("49.36.9.9");
        direct.addHeader("X-Forwarded-For", "1.2.3.4");
        org.assertj.core.api.Assertions.assertThat(com.mintadeal.ops.RateLimitFilter.clientIp(direct)).isEqualTo("49.36.9.9");
        var proxied = new org.springframework.mock.web.MockHttpServletRequest();
        proxied.setRemoteAddr("172.18.0.4");
        proxied.addHeader("X-Forwarded-For", "49.36.9.9");
        org.assertj.core.api.Assertions.assertThat(com.mintadeal.ops.RateLimitFilter.clientIp(proxied)).isEqualTo("49.36.9.9");
    }
}
