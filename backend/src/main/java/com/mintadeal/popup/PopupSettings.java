package com.mintadeal.popup;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/** The master controls: stalls at once and fee per day, for approved shops and for everyone else. */
@Entity
@Table(name = "popup_settings")
public class PopupSettings {

    @Id
    private Integer id;

    private int shopMaxLive;

    private long shopFeePerDayMinor;

    private int sellerMaxLive;

    private long sellerFeePerDayMinor;

    @Column(nullable = false)
    private Instant updatedAt;

    @Version
    private Long version;

    protected PopupSettings() {
    }

    void update(int shopMaxLive, long shopFeePerDayMinor, int sellerMaxLive, long sellerFeePerDayMinor, Instant now) {
        this.shopMaxLive = shopMaxLive;
        this.shopFeePerDayMinor = shopFeePerDayMinor;
        this.sellerMaxLive = sellerMaxLive;
        this.sellerFeePerDayMinor = sellerFeePerDayMinor;
        this.updatedAt = now;
    }

    public int getShopMaxLive() {
        return shopMaxLive;
    }

    public long getShopFeePerDayMinor() {
        return shopFeePerDayMinor;
    }

    public int getSellerMaxLive() {
        return sellerMaxLive;
    }

    public long getSellerFeePerDayMinor() {
        return sellerFeePerDayMinor;
    }
}
