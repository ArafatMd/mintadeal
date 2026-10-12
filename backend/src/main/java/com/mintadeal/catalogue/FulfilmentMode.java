package com.mintadeal.catalogue;

public enum FulfilmentMode {
    SHOP_DELIVERY,
    PARTNER_DELIVERY,
    PICKUP,
    VENUE_QR;

    public boolean isDelivery() {
        return this == SHOP_DELIVERY || this == PARTNER_DELIVERY;
    }
}
