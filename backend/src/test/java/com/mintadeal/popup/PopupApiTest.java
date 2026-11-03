package com.mintadeal.popup;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;

import com.mintadeal.support.ApiTest;

/** Pop-up stalls: one live stall per seller by default, gone from customers when its days end, history kept for admins. */
class PopupApiTest extends ApiTest {

    private static final String PHOTO = "http://localhost:8080/files/00000000-0000-0000-0000-000000000001.jpg";
    // A seller near HSR Layout, and a customer about 400 m away.
    private static final String HERE = "\"latitude\":12.9120,\"longitude\":77.6440";
    private static final String CUSTOMER = "lat=12.9116&lng=77.6474";

    private static String stall(String name, String title, int days) {
        return """
                {"name":%s,"items":[{"imageUrl":"%s","title":"%s","priceMinor":4000},{"imageUrl":"%s"}],
                 %s,"days":%d}""".formatted(name == null ? "null" : "\"" + name + "\"", PHOTO, title, PHOTO, HERE,
                days);
    }

    @Test
    void aSellerStartsAStallAndNearbyCustomersSeeIt() throws Exception {
        String seller = login("9811100001");
        call(GET("/api/popup/me"), seller, null)
                .andExpect(jsonPath("$.name").doesNotExist())
                .andExpect(jsonPath("$.defaultDays").value(2))
                .andExpect(jsonPath("$.allowedDays").value(contains(1, 2, 3, 7)));
        call(POST("/api/popup/stalls"), seller, stall(null, "Mangoes", 2))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("name_required"));
        String id = read(call(POST("/api/popup/stalls"), seller, stall("Ravi Fruits", "Mangoes", 2))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Ravi Fruits"))
                .andExpect(jsonPath("$.active[0].status").value("LIVE"))
                .andExpect(jsonPath("$.active[0].items", hasSize(2))), "$.active[0].id");

        call(GET("/api/discovery/popups?" + CUSTOMER), null, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(id))
                .andExpect(jsonPath("$[0].sellerName").value("Ravi Fruits"))
                .andExpect(jsonPath("$[0].phone").value("+919811100001"))
                .andExpect(jsonPath("$[0].distanceKm").value(0.4))
                .andExpect(jsonPath("$[0].items[0].priceMinor").value(4000));
        // Far away (Whitefield) customers do not see it.
        call(GET("/api/discovery/popups?lat=12.9698&lng=77.7500"), null, null).andExpect(jsonPath("$", hasSize(0)));

        // Only one live stall at a time.
        call(POST("/api/popup/stalls"), seller, stall(null, "Bananas", 1))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("popup_live"));
    }

    @Test
    void movingKeepsOneSpotAndStoppingHidesItButKeepsHistory() throws Exception {
        String seller = login("9811100002");
        String id = read(call(POST("/api/popup/stalls"), seller, stall("Lakshmi Flowers", "Jasmine", 3)), "$.active[0].id");
        call(POST("/api/popup/stalls/" + id + "/move"), seller, "{\"latitude\":12.9719,\"longitude\":77.6412}")
                .andExpect(jsonPath("$.active[0].latitude").value(12.9719));
        call(GET("/api/discovery/popups?lat=12.9719&lng=77.6412"), null, null).andExpect(jsonPath("$", hasSize(1)));
        call(GET("/api/discovery/popups?" + CUSTOMER), null, null).andExpect(jsonPath("$", hasSize(0)));

        call(POST("/api/popup/stalls/" + id + "/stop"), seller, null)
                .andExpect(jsonPath("$.active", hasSize(0)))
                .andExpect(jsonPath("$.history[0].status").value("ENDED"));
        call(GET("/api/discovery/popups?lat=12.9719&lng=77.6412"), null, null).andExpect(jsonPath("$", hasSize(0)));
        call(GET("/api/discovery/popups/" + id), null, null).andExpect(status().isNotFound());

        // Sell again reuses the photos at a new spot.
        call(POST("/api/popup/stalls/" + id + "/again"), seller, "{" + HERE + ",\"days\":1}")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.active[0].items[0].title").value("Jasmine"))
                .andExpect(jsonPath("$.active[0].days").value(1));
        String admin = login(ADMIN_PHONE);
        call(GET("/api/admin/popups?filter=ENDED"), admin, null).andExpect(jsonPath("$.items[0].id").value(id));
    }

    @Test
    void rulesAreCheckedBeforeAStallGoesLive() throws Exception {
        String seller = login("9811100003");
        call(POST("/api/popup/stalls"), seller, stall("Corner stall", "Chilled beer", 2))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("not_allowed"));
        call(POST("/api/popup/stalls"), seller, stall("Corner stall", "Peanuts", 5))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("invalid_days"));
        call(POST("/api/popup/stalls"), seller, stall("Corner stall", "Peanuts", 2).replace(HERE,
                "\"latitude\":19.07,\"longitude\":72.87"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("outside_city"));
        call(POST("/api/popup/stalls"), seller, stall("Corner stall", "Peanuts", 2).replace(PHOTO,
                "https://example.com/x.jpg"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("invalid_photo"));
    }

    @Test
    void customerReportsHideAStallAndAdminsDecide() throws Exception {
        String seller = login("9811100004");
        String id = read(call(POST("/api/popup/stalls"), seller, stall("Quick Snacks", "Samosa", 2)), "$.active[0].id");
        String sellerId = read(call(GET("/api/me"), seller, null), "$.id");
        for (String phone : new String[] {"9811100011", "9811100012"}) {
            call(POST("/api/popup/stalls/" + id + "/report"), login(phone), "{\"reason\":\"NOT_THERE\"}")
                    .andExpect(status().isNoContent());
        }
        String admin = login(ADMIN_PHONE);
        call(GET("/api/admin/overview"), admin, null).andExpect(jsonPath("$.attention.reportedPopups").value(1));
        call(GET("/api/discovery/popups?" + CUSTOMER), null, null).andExpect(jsonPath("$", hasSize(1)));
        call(POST("/api/popup/stalls/" + id + "/report"), login("9811100013"),
                "{\"reason\":\"FAKE_OR_MISLEADING\",\"note\":\"No stall here\"}");
        // Three reports: hidden until Mintadeal checks.
        call(GET("/api/discovery/popups?" + CUSTOMER), null, null).andExpect(jsonPath("$", hasSize(0)));
        call(GET("/api/admin/popups?filter=REPORTED"), admin, null)
                .andExpect(jsonPath("$.items[0].status").value("REMOVED"))
                .andExpect(jsonPath("$.items[0].reportCount").value(3))
                .andExpect(jsonPath("$.items[0].reports[0].note").value("No stall here"));

        call(POST("/api/admin/popups/" + id + "/restore"), admin, null).andExpect(jsonPath("$.status").value("LIVE"));
        call(POST("/api/admin/popup-sellers/" + sellerId + "/block"), admin, "{\"reason\":\"Fake stall\"}")
                .andExpect(status().isNoContent());
        call(GET("/api/discovery/popups?" + CUSTOMER), null, null).andExpect(jsonPath("$", hasSize(0)));
        call(GET("/api/popup/me"), seller, null).andExpect(jsonPath("$.blocked").value(true));
        call(POST("/api/popup/stalls"), seller, stall(null, "Samosa", 1)).andExpect(status().isForbidden());
        // Admins can see the seller's whole history.
        call(GET("/api/admin/popups?sellerId=" + sellerId), admin, null).andExpect(jsonPath("$.items", hasSize(1)));
    }

    @Test
    void customersMustSignInToReport() throws Exception {
        String id = read(call(POST("/api/popup/stalls"), login("9811100005"), stall("Toys", "Kites", 2)), "$.active[0].id");
        call(POST("/api/popup/stalls/" + id + "/report"), null, "{\"reason\":\"OTHER\"}")
                .andExpect(status().isUnauthorized());
    }
}
