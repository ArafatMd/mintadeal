package com.mintadeal;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.empty;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import org.junit.jupiter.api.Test;

import com.mintadeal.support.ApiTest;

/** Shop cover photos, profile photos and admin-managed home banners. */
class ImagesAndBannersApiTest extends ApiTest {

    private static final String HSR = "lat=12.9116&lng=77.6474";
    private static final String COVER = "http://localhost/files/11111111-1111-1111-1111-111111111111.jpg";
    private static final String DEAL_PHOTO = "http://localhost/files/22222222-2222-2222-2222-222222222222.jpg";

    @Test
    void shopCoverIsUsedOnTheCardAndStorefront() throws Exception {
        String shop = approvedVendor("9876543210", shopJson("Lakshmi Stores", 12.9121, 77.6446, "\"pickup\":true"));
        String listing = read(call(POST("/api/vendor/listings"), shop, """
                {"listingType":"PRODUCT","title":"Atta","priceMinor":100,"imageUrl":"%s","fulfilmentModes":["PICKUP"]}"""
                .formatted(DEAL_PHOTO)).andExpect(status().isCreated()), "$.id");
        call(POST("/api/vendor/listings/" + listing + "/publish"), shop, null).andExpect(status().isOk());

        // Without a cover the card borrows the deal's photo.
        call(GET("/api/discovery/nearby/shops?" + HSR), null, null)
                .andExpect(jsonPath("$.items[0].coverImageUrl").value(DEAL_PHOTO));

        call(PUT("/api/vendor/shop"), shop, shopJson("Lakshmi Stores", 12.9121, 77.6446,
                "\"pickup\":true,\"coverUrl\":\"" + COVER + "\""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coverUrl").value(COVER));
        call(GET("/api/discovery/nearby/shops?" + HSR), null, null)
                .andExpect(jsonPath("$.items[0].coverImageUrl").value(COVER));
        String vendorId = read(call(GET("/api/vendor/shop"), shop, null), "$.id");
        call(GET("/api/discovery/vendors/" + vendorId), null, null)
                .andExpect(jsonPath("$.vendor.coverUrl").value(COVER));
    }

    @Test
    void shopRecordsWhetherItsLocationWasPinned() throws Exception {
        String shop = approvedVendor("9876543210", shopJson("Lakshmi Stores", 12.9121, 77.6446, "\"pickup\":true"));
        call(GET("/api/vendor/shop"), shop, null).andExpect(jsonPath("$.locationPinned").value(false));
        call(PUT("/api/vendor/shop"), shop, shopJson("Lakshmi Stores", 12.91234, 77.64478,
                "\"pickup\":true,\"locationPinned\":true"))
                .andExpect(jsonPath("$.locationPinned").value(true))
                .andExpect(jsonPath("$.latitude").value(12.91234));
        // Saving without the flag (e.g. an older app) keeps it.
        call(PUT("/api/vendor/shop"), shop, shopJson("Lakshmi Stores", 12.91234, 77.64478, "\"pickup\":true"))
                .andExpect(jsonPath("$.locationPinned").value(true));
    }

    @Test
    void anyoneCanSetAndClearTheirProfilePhoto() throws Exception {
        String rider = login("9845000001");
        call(PATCH("/api/me"), rider, "{\"avatarUrl\":\"" + COVER + "\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.avatarUrl").value(COVER));
        // Changing the name leaves the photo alone; an empty value clears it.
        call(PATCH("/api/me"), rider, "{\"name\":\"Ravi\"}").andExpect(jsonPath("$.avatarUrl").value(COVER));
        call(PATCH("/api/me"), rider, "{\"avatarUrl\":\"\"}").andExpect(jsonPath("$.avatarUrl").doesNotExist());
    }

    @Test
    void adminBannersShowOnHomeWithinTheirDatesAndScope() throws Exception {
        String admin = login(ADMIN_PHONE);
        String nearby = read(call(POST("/api/admin/banners"), admin, banner("Fresh vegetables", "CATEGORY",
                "\"targetCategory\":\"GROCERY\"", "NEARBY", 2, null)).andExpect(status().isCreated()), "$.id");
        call(POST("/api/admin/banners"), admin, banner("Diwali sale", "NONE", null, "BOTH", 1, null))
                .andExpect(status().isCreated());
        call(POST("/api/admin/banners"), admin, banner("Next month", "NONE", null, "BOTH", 0,
                "\"startsAt\":\"" + Instant.now().plus(30, ChronoUnit.DAYS) + "\""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.live").value(false));

        // Ordered by position; future banners and the other view's banners are left out.
        call(GET("/api/discovery/banners?scope=NEARBY"), null, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].title").value(contains("Diwali sale", "Fresh vegetables")))
                .andExpect(jsonPath("$[1].targetCategory").value("GROCERY"));
        call(GET("/api/discovery/banners?scope=CITYWIDE"), null, null)
                .andExpect(jsonPath("$[*].title").value(contains("Diwali sale")));

        call(PUT("/api/admin/banners/" + nearby), admin, banner("Fresh vegetables", "CATEGORY",
                "\"targetCategory\":\"GROCERY\"", "NEARBY", 2, null).replace("\"active\":true", "\"active\":false"))
                .andExpect(status().isOk());
        call(delete("/api/admin/banners/" + nearby), admin, null).andExpect(status().isNoContent());
        call(GET("/api/admin/banners"), admin, null).andExpect(jsonPath("$[*].title")
                .value(contains("Next month", "Diwali sale")));
    }

    @Test
    void bannersAreValidatedAndOnlyForAdmins() throws Exception {
        String admin = login(ADMIN_PHONE);
        call(POST("/api/admin/banners"), admin, banner("No category", "CATEGORY", null, "BOTH", 0, null))
                .andExpect(status().isBadRequest());
        call(POST("/api/admin/banners"), admin, banner("Missing shop", "SHOP",
                "\"targetId\":\"33333333-3333-3333-3333-333333333333\"", "BOTH", 0, null))
                .andExpect(status().isBadRequest());
        String customer = login("9845012345");
        call(POST("/api/admin/banners"), customer, banner("Sneaky", "NONE", null, "BOTH", 0, null))
                .andExpect(status().isForbidden());
        call(GET("/api/discovery/banners"), null, null).andExpect(jsonPath("$").value(empty()));
    }

    private static String banner(String title, String target, String targetFields, String scope, int position,
                                 String extra) {
        return """
                {"title":"%s","subtitle":"Up to 40%% off","imageUrl":"%s","targetType":"%s",%s"scope":"%s",
                 "position":%d,"active":true%s}"""
                .formatted(title, COVER, target, targetFields == null ? "" : targetFields + ",", scope, position,
                        extra == null ? "" : "," + extra);
    }
}
