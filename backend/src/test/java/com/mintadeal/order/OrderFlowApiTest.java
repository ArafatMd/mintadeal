package com.mintadeal.order;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/** Pay-on-delivery and pickup orders, from cart to completion, including rejections and timeouts. */
class OrderFlowApiTest extends OrderTestBase {

    @Autowired
    OrderService orderService;

    @Test
    void pickupOrderFromPlacementToCollection() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta 5 kg", 29500, 10, "\"PICKUP\"");
        String customer = login("9845012345");

        call(POST("/api/customer/checkout/quote"), customer, cart("q", "PAY_ON_DELIVERY", null, null, atta, "2"))
                .andExpect(jsonPath("$.canPlace").value(true))
                .andExpect(jsonPath("$.addressRequired").value(false))
                .andExpect(jsonPath("$.groups[0].selectedMode").value("PICKUP"))
                .andExpect(jsonPath("$.grandTotalMinor").value(59000));

        String orderId = read(call(POST("/api/customer/checkout"), customer,
                cart("r1", "PAY_ON_DELIVERY", null, null, atta, "2"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.code").value(org.hamcrest.Matchers.startsWith("MD-")))
                .andExpect(jsonPath("$.orders[0].status").value("PLACED")), "$.orders[0].id");
        org.assertj.core.api.Assertions.assertThat(stockOf(atta)).isEqualTo(8);

        call(GET("/api/vendor/orders/summary"), shop.token(), null).andExpect(jsonPath("$.newOrders").value(1));
        call(GET("/api/vendor/orders?filter=NEW"), shop.token(), null)
                .andExpect(jsonPath("$.items[0].id").value(orderId));
        call(GET("/api/vendor/orders/" + orderId), shop.token(), null)
                .andExpect(jsonPath("$.customer.phone").value("+919845012345"))
                .andExpect(jsonPath("$.actions").value(contains("ACCEPT", "REJECT")));

        call(POST("/api/vendor/orders/" + orderId + "/accept"), shop.token(), null)
                .andExpect(jsonPath("$.status").value("ACCEPTED"))
                .andExpect(jsonPath("$.actions").value(contains("MARK_READY")));
        // Delivery steps do not apply to a pickup order.
        call(POST("/api/vendor/orders/" + orderId + "/out-for-delivery"), shop.token(), null)
                .andExpect(status().isConflict());
        call(POST("/api/vendor/orders/" + orderId + "/ready"), shop.token(), null)
                .andExpect(jsonPath("$.status").value("READY"));
        call(POST("/api/vendor/orders/" + orderId + "/complete"), shop.token(), null)
                .andExpect(jsonPath("$.status").value("COMPLETED"));

        call(GET("/api/customer/orders/" + orderId), customer, null)
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.customer").doesNotExist())
                .andExpect(jsonPath("$.events[*].status").value(contains("PLACED", "ACCEPTED", "READY", "COMPLETED")))
                .andExpect(jsonPath("$.lines[0].quantity").value(2));
        // The order keeps the price it was bought at even if the shop edits the listing later.
        call(PUT("/api/vendor/listings/" + atta), shop.token(), """
                {"listingType":"PRODUCT","title":"Atta 5 kg","priceMinor":35000,"fulfilmentModes":["PICKUP"]}""");
        call(GET("/api/customer/orders/" + orderId), customer, null)
                .andExpect(jsonPath("$.lines[0].unitPriceMinor").value(29500));
    }

    @Test
    void cartFromTwoShopsBecomesTwoOrdersWithTheirOwnDeliveryFees() throws Exception {
        Shop grocery = shop("9876543210", "Lakshmi Stores", "\"selfDelivery\":true,\"pickup\":true");
        Shop meat = shop("9876543211", "Fresh Meats", "\"selfDelivery\":true,\"deliveryFeeMinor\":3000");
        String atta = product(grocery, "Atta", 29500, null, "\"SHOP_DELIVERY\",\"PICKUP\"");
        String chicken = product(meat, "Chicken 1 kg", 28000, null, "\"SHOP_DELIVERY\"");
        String customer = login("9845012345");
        String body = cart("r1", "PAY_ON_DELIVERY", HSR_ADDRESS,
                "{\"" + grocery.vendorId() + ":PRODUCT\":\"SHOP_DELIVERY\"}", atta, "1", chicken, "1");

        call(POST("/api/customer/checkout/quote"), customer, body)
                .andExpect(jsonPath("$.groups.length()").value(2))
                .andExpect(jsonPath("$.deliveryTotalMinor").value(2000 + 3000))
                .andExpect(jsonPath("$.grandTotalMinor").value(29500 + 28000 + 5000));
        call(POST("/api/customer/checkout"), customer, body)
                .andExpect(jsonPath("$.orders.length()").value(2))
                .andExpect(jsonPath("$.orders[0].code").value(org.hamcrest.Matchers.endsWith("-1")))
                .andExpect(jsonPath("$.orders[1].code").value(org.hamcrest.Matchers.endsWith("-2")));

        // Each shop sees only its own order, with the delivery address.
        call(GET("/api/vendor/orders"), meat.token(), null)
                .andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.items[0].vendorName").value("Fresh Meats"));
        String meatOrder = read(call(GET("/api/vendor/orders"), meat.token(), null), "$.items[0].id");
        call(GET("/api/vendor/orders/" + meatOrder), meat.token(), null)
                .andExpect(jsonPath("$.address.landmark").value("Near BDA park"))
                .andExpect(jsonPath("$.deliveryFeeMinor").value(3000));
        call(GET("/api/vendor/orders/" + meatOrder), grocery.token(), null).andExpect(status().isNotFound());
    }

    @Test
    void quoteExplainsWhatStopsAnOrder() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"selfDelivery\":true,\"minOrderMinor\":50000");
        String rice = product(shop, "Rice", 10000, 3, "\"SHOP_DELIVERY\"");
        String customer = login("9845012345");

        call(POST("/api/customer/checkout/quote"), customer, cart("q", "PAY_ON_DELIVERY", null, null, rice, "1"))
                .andExpect(jsonPath("$.canPlace").value(false))
                .andExpect(jsonPath("$.problems").value(hasItem("Add a delivery address")));
        call(POST("/api/customer/checkout/quote"), customer, cart("q", "PAY_ON_DELIVERY", HSR_ADDRESS, null, rice, "1"))
                .andExpect(jsonPath("$.groups[0].problems[0]").value("Minimum order for delivery from Lakshmi Stores is ₹500"));
        call(POST("/api/customer/checkout/quote"), customer, cart("q", "PAY_ON_DELIVERY", HSR_ADDRESS, null, rice, "5"))
                .andExpect(jsonPath("$.groups[0].lines[0].problem").value("Only 3 left"));
        call(POST("/api/customer/checkout/quote"), customer, cart("q", "PAY_ON_DELIVERY", FAR_ADDRESS, null, rice, "3"))
                .andExpect(jsonPath("$.groups[0].availableModes").value(empty()))
                .andExpect(jsonPath("$.groups[0].problems[0]").value("Lakshmi Stores does not deliver to your address"));
        call(POST("/api/customer/checkout"), customer, cart("r", "PAY_ON_DELIVERY", FAR_ADDRESS, null, rice, "3"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("cannot_place"));
    }

    @Test
    void retriedCheckoutIsPlacedOnlyOnce() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta", 29500, 10, "\"PICKUP\"");
        String customer = login("9845012345");
        String body = cart("same-request", "PAY_ON_DELIVERY", null, null, atta, "1");
        String first = read(call(POST("/api/customer/checkout"), customer, body), "$.id");
        call(POST("/api/customer/checkout"), customer, body).andExpect(jsonPath("$.id").value(first));
        org.assertj.core.api.Assertions.assertThat(stockOf(atta)).isEqualTo(9);
    }

    @Test
    void shopRejectionNeedsReasonAndPutsStockBack() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta", 29500, 10, "\"PICKUP\"");
        String customer = login("9845012345");
        String orderId = read(call(POST("/api/customer/checkout"), customer,
                cart("r1", "PAY_ON_DELIVERY", null, null, atta, "4")), "$.orders[0].id");

        call(POST("/api/vendor/orders/" + orderId + "/reject"), shop.token(), "{\"reason\":\"\"}")
                .andExpect(status().isBadRequest());
        call(POST("/api/vendor/orders/" + orderId + "/reject"), shop.token(), "{\"reason\":\"Out of stock today\"}")
                .andExpect(jsonPath("$.status").value("CANCELLED"))
                .andExpect(jsonPath("$.cancelledBy").value("VENDOR"));
        org.assertj.core.api.Assertions.assertThat(stockOf(atta)).isEqualTo(10);
        call(GET("/api/customer/orders/" + orderId), customer, null)
                .andExpect(jsonPath("$.cancelReason").value("Shop could not take the order: Out of stock today"));
    }

    @Test
    void ordersNotAcceptedInTimeAreCancelledAutomatically() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta", 29500, 10, "\"PICKUP\"");
        String customer = login("9845012345");
        String orderId = read(call(POST("/api/customer/checkout"), customer,
                cart("r1", "PAY_ON_DELIVERY", null, null, atta, "1")), "$.orders[0].id");

        jdbc.update("update shop_order set accept_deadline = now() - interval '1 minute' where id = ?::uuid", orderId);
        org.assertj.core.api.Assertions.assertThat(orderService.cancelUnacceptedOrders()).isEqualTo(1);

        call(GET("/api/customer/orders/" + orderId), customer, null)
                .andExpect(jsonPath("$.status").value("CANCELLED"))
                .andExpect(jsonPath("$.cancelledBy").value("SYSTEM"))
                .andExpect(jsonPath("$.cancelReason").value("The shop did not respond in time"));
        org.assertj.core.api.Assertions.assertThat(stockOf(atta)).isEqualTo(10);
    }

    @Test
    void customerCanCancelOnlyBeforeAcceptanceAndOnlyOwnOrders() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta", 29500, null, "\"PICKUP\"");
        String customer = login("9845012345");
        String other = login("9845012346");
        String first = read(call(POST("/api/customer/checkout"), customer,
                cart("r1", "PAY_ON_DELIVERY", null, null, atta, "1")), "$.orders[0].id");
        String second = read(call(POST("/api/customer/checkout"), customer,
                cart("r2", "PAY_ON_DELIVERY", null, null, atta, "1")), "$.orders[0].id");

        call(GET("/api/customer/orders/" + first), other, null).andExpect(status().isNotFound());
        call(POST("/api/customer/orders/" + first + "/cancel"), other, null).andExpect(status().isNotFound());

        call(POST("/api/customer/orders/" + first + "/cancel"), customer, null)
                .andExpect(jsonPath("$.status").value("CANCELLED"));
        call(POST("/api/vendor/orders/" + second + "/accept"), shop.token(), null).andExpect(status().isOk());
        call(POST("/api/customer/orders/" + second + "/cancel"), customer, null)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("invalid_transition"));
    }

    @Test
    void adminFindsAndCancelsOrders() throws Exception {
        Shop shop = shop("9876543210", "Lakshmi Stores", "\"pickup\":true");
        String atta = product(shop, "Atta", 29500, null, "\"PICKUP\"");
        String customer = login("9845012345");
        String code = read(call(POST("/api/customer/checkout"), customer,
                cart("r1", "PAY_ON_DELIVERY", null, null, atta, "1")), "$.orders[0].code");
        String admin = login(ADMIN_PHONE);

        call(GET("/api/admin/orders?q=9845012345"), admin, null).andExpect(jsonPath("$.items[0].code").value(code));
        call(GET("/api/admin/orders?q=" + code.toLowerCase()), admin, null).andExpect(jsonPath("$.total").value(1));
        String id = read(call(GET("/api/admin/orders?q=" + code), admin, null), "$.items[0].id");
        call(GET("/api/admin/orders/" + id), admin, null).andExpect(jsonPath("$.customer.phone").value("+919845012345"));
        call(POST("/api/admin/orders/" + id + "/cancel"), admin, "{\"reason\":\"Customer called support\"}")
                .andExpect(jsonPath("$.status").value("CANCELLED"))
                .andExpect(jsonPath("$.cancelledBy").value("ADMIN"));
        call(GET("/api/admin/orders"), customer, null).andExpect(status().isForbidden());
    }
}
