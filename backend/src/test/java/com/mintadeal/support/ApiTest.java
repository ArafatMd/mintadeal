package com.mintadeal.support;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import com.jayway.jsonpath.JsonPath;

/** Full-stack API tests against a real PostgreSQL database (profile "test"). */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public abstract class ApiTest {

    public static final String ADMIN_PHONE = "9000000001";

    @Autowired
    protected MockMvc mvc;

    @Autowired
    private JdbcTemplate jdbc;

    /** All tests talk to the stub instead of the real Razorpay and 2Factor. */
    @DynamicPropertySource
    static void providerUrls(DynamicPropertyRegistry registry) {
        registry.add("mintadeal.integrations.razorpay-base-url", ProviderStub.INSTANCE::baseUrl);
        registry.add("mintadeal.integrations.two-factor-base-url", ProviderStub.INSTANCE::baseUrl);
        registry.add("mintadeal.integrations.whatsapp-base-url", () -> ProviderStub.INSTANCE.baseUrl() + "/wa");
    }

    @BeforeEach
    void cleanDatabase() {
        ProviderStub.INSTANCE.reset();
        jdbc.execute("""
                TRUNCATE home_banner, notification, ledger_entry, ledger_journal, payout, payout_batch, commission_rule, vendor_charge, delivery_job, redemption, refund, order_event, order_line, shop_order, checkout, integration_setting,
                         audit_event, vendor_follow, listing_fulfilment_mode, listing, vendor,
                         otp_challenge, user_role, app_user CASCADE""");
    }

    protected String login(String phone) throws Exception {
        mvc.perform(post("/api/auth/otp/request").contentType(MediaType.APPLICATION_JSON)
                .content("{\"phone\":\"" + phone + "\"}")).andExpect(status().isAccepted());
        String body = mvc.perform(post("/api/auth/otp/verify").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phone\":\"" + phone + "\",\"code\":\"123456\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.accessToken");
    }

    /** Signs in again so the token carries roles granted since the last sign-in. */
    protected String refresh(String token) throws Exception {
        String body = call(post("/api/me/token"), token, null).andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.accessToken");
    }

    protected ResultActions call(MockHttpServletRequestBuilder req, String token, String json) throws Exception {
        if (token != null) {
            req.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        }
        if (json != null) {
            req.contentType(MediaType.APPLICATION_JSON).content(json);
        }
        return mvc.perform(req);
    }

    protected static String read(ResultActions result, String path) throws Exception {
        return JsonPath.read(result.andReturn().getResponse().getContentAsString(), path).toString();
    }

    protected static String shopJson(String name, double lat, double lng, String extra) {
        return """
                {"displayName":"%s","category":"GROCERY","phone":"9876543210",
                 "addressLine":"1 Test Street","area":"HSR Layout","pincode":"560102",
                 "latitude":%s,"longitude":%s,"deliveryRadiusKm":3,"deliveryFeeMinor":2000,
                 "minOrderMinor":0%s}""".formatted(name, lat, lng, extra == null ? "" : "," + extra);
    }

    /** Registers a shop for the given phone, approves it as admin, and returns the vendor's fresh token. */
    protected String approvedVendor(String phone, String shopJson) throws Exception {
        String token = login(phone);
        String vendorId = read(call(post("/api/vendor/shop"), token, shopJson).andExpect(status().isCreated()), "$.id");
        String admin = login(ADMIN_PHONE);
        call(post("/api/admin/vendors/" + vendorId + "/approve"), admin, "{}").andExpect(status().isOk());
        return refresh(token);
    }

    protected static MockHttpServletRequestBuilder GET(String url) {
        return get(url);
    }

    protected static MockHttpServletRequestBuilder POST(String url) {
        return post(url);
    }

    protected static MockHttpServletRequestBuilder PUT(String url) {
        return put(url);
    }

    protected static MockHttpServletRequestBuilder PATCH(String url) {
        return org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch(url);
    }
}
