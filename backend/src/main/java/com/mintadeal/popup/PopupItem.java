package com.mintadeal.popup;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;

/** One photo of something the stall sells, with an optional name and price. */
@Embeddable
public class PopupItem {

    @Column(nullable = false)
    private String imageUrl;

    private String title;

    private Long priceMinor;

    protected PopupItem() {
    }

    public PopupItem(String imageUrl, String title, Long priceMinor) {
        this.imageUrl = imageUrl;
        this.title = title;
        this.priceMinor = priceMinor;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public String getTitle() {
        return title;
    }

    public Long getPriceMinor() {
        return priceMinor;
    }
}
