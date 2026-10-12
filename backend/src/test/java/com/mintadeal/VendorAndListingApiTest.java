package com.mintadeal;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import org.junit.jupiter.api.Test;

import com.mintadeal.support.ApiTest;

class VendorAndListingApiTest extends ApiTest {

    private static final String PRODUCT = """
            {"listingType":"PRODUCT","title":"Atta 5 kg","priceMinor":29500,"offerPriceMinor":26900,
             "stock":10,"fulfilmentModes":["SHOP_DELIVERY","PICKUP"]}""";

    @Test
    void pendingShopCannotListUntilApproved() throws Exception {
        String token = login("9876543210");
        String vendorId = read(call(POST("/api/vendor/shop"), token,
                shopJson("Lakshmi Stores", 12.91, 77.64, "\"selfDelivery\":true,\"pickup\":true"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("PENDING")), "$.id");

        call(POST("/api/vendor/listings"), token, PRODUCT)
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("vendor_not_approved"));

        String admin = login(ADMIN_PHONE);
        call(POST("/api/admin/vendors/" + vendorId + "/approve"), admin, "{}")
                .andExpect(jsonPath("$.status").value("APPROVED"));

        call(POST("/api/vendor/listings"), token, PRODUCT)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andExpect(jsonPath("$.discountPercent").value(9));

        call(GET("/api/admin/vendors/" + vendorId), admin, null)
                .andExpect(jsonPath("$.history[0].action").value("VENDOR_APPROVED"));
    }

    @Test
    void rejectionNeedsReasonAndEditingSendsShopBackToReview() throws Exception {
        String token = login("9876543210");
        String shop = shopJson("Lakshmi Stores", 12.91, 77.64, "\"pickup\":true");
        String vendorId = read(call(POST("/api/vendor/shop"), token, shop), "$.id");
        String admin = login(ADMIN_PHONE);
        call(POST("/api/admin/vendors/" + vendorId + "/reject"), admin, "{\"note\":\"\"}")
                .andExpect(jsonPath("$.code").value("reason_required"));
        call(POST("/api/admin/vendors/" + vendorId + "/reject"), admin, "{\"note\":\"Add a shop photo\"}")
                .andExpect(jsonPath("$.status").value("REJECTED"));
        call(PUT("/api/vendor/shop"), token, shop)
                .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void listingModesMustMatchShopSettingsAndListingType() throws Exception {
        String token = approvedVendor("9876543210", shopJson("Lakshmi Stores", 12.91, 77.64, "\"pickup\":true"));

        call(POST("/api/vendor/listings"), token, PRODUCT)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("shop_delivery_off"));

        call(POST("/api/vendor/listings"), token, """
                {"listingType":"PRODUCT","title":"Atta","priceMinor":100,"fulfilmentModes":["VENUE_QR"]}""")
                .andExpect(jsonPath("$.code").value("product_no_venue_qr"));

        call(POST("/api/vendor/listings"), token, """
                {"listingType":"OFFER","title":"Buffet","priceMinor":100,"fulfilmentModes":["PICKUP"],
                 "validTo":"%s"}""".formatted(Instant.now().plus(5, ChronoUnit.DAYS)))
                .andExpect(jsonPath("$.code").value("offer_venue_only"));

        call(POST("/api/vendor/listings"), token, """
                {"listingType":"OFFER","title":"Buffet","priceMinor":100,"fulfilmentModes":["VENUE_QR"]}""")
                .andExpect(jsonPath("$.code").value("offer_needs_end"));

        call(POST("/api/vendor/listings"), token, """
                {"listingType":"PRODUCT","title":"Atta","priceMinor":100,"offerPriceMinor":150,
                 "fulfilmentModes":["PICKUP"]}""")
                .andExpect(jsonPath("$.code").value("offer_price_not_lower"));

        call(POST("/api/vendor/listings"), token, """
                {"listingType":"PRODUCT","title":"","priceMinor":0,"fulfilmentModes":[]}""")
                .andExpect(jsonPath("$.code").value("validation_failed"))
                .andExpect(jsonPath("$.fields.title").exists())
                .andExpect(jsonPath("$.fields.priceMinor").exists());
    }

    @Test
    void vendorCannotTouchAnotherShopsListing() throws Exception {
        String a = approvedVendor("9876543210", shopJson("Shop A", 12.91, 77.64, "\"pickup\":true"));
        String b = approvedVendor("9876543211", shopJson("Shop B", 12.91, 77.64, "\"pickup\":true"));
        String listingId = read(call(POST("/api/vendor/listings"), a, """
                {"listingType":"PRODUCT","title":"Atta","priceMinor":100,"fulfilmentModes":["PICKUP"]}"""), "$.id");
        call(POST("/api/vendor/listings/" + listingId + "/publish"), b, null).andExpect(status().isNotFound());
    }

    @Test
    void removedListingDisappearsAndCannotBeRepublished() throws Exception {
        String token = approvedVendor("9876543210", shopJson("Shop A", 12.91, 77.64, "\"pickup\":true"));
        String id = read(call(POST("/api/vendor/listings"), token, """
                {"listingType":"PRODUCT","title":"Atta","priceMinor":100,"fulfilmentModes":["PICKUP"]}"""), "$.id");
        call(POST("/api/vendor/listings/" + id + "/publish"), token, null).andExpect(status().isOk());
        call(GET("/api/discovery/nearby?lat=12.91&lng=77.64"), null, null)
                .andExpect(jsonPath("$.items[*].listing.id").value(hasItem(id)));

        String admin = login(ADMIN_PHONE);
        call(GET("/api/admin/listings?status=ACTIVE"), admin, null)
                .andExpect(jsonPath("$.items[0].vendorName").value("Shop A"))
                .andExpect(jsonPath("$.items[0].listing.id").value(id));
        call(POST("/api/admin/listings/" + id + "/remove"), admin, "{\"reason\":\"Misleading price\"}")
                .andExpect(jsonPath("$.status").value("REMOVED"));

        call(GET("/api/discovery/nearby?lat=12.91&lng=77.64"), null, null)
                .andExpect(jsonPath("$.items[*].listing.id").value(not(hasItem(id))));
        call(POST("/api/vendor/listings/" + id + "/publish"), token, null)
                .andExpect(jsonPath("$.code").value("listing_removed"));
    }
}
