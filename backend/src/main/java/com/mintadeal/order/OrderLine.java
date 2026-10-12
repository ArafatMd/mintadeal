package com.mintadeal.order;

import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import com.mintadeal.catalogue.ListingType;

/** A snapshot of what was bought and at what price; later listing edits do not change it. */
@Entity
@Table(name = "order_line")
public class OrderLine {

    @Id
    private UUID id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "shop_order_id")
    private ShopOrder shopOrder;

    private int position;

    @Column(nullable = false)
    private UUID listingId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ListingType listingType;

    @Column(nullable = false)
    private String title;

    private String imageUrl;

    private long unitPriceMinor;

    private long originalPriceMinor;

    private int quantity;

    private long lineTotalMinor;

    protected OrderLine() {
    }

    OrderLine(ShopOrder order, int position, UUID listingId, ListingType type, String title, String imageUrl,
              long unitPrice, long originalPrice, int quantity) {
        this.id = UUID.randomUUID();
        this.shopOrder = order;
        this.position = position;
        this.listingId = listingId;
        this.listingType = type;
        this.title = title;
        this.imageUrl = imageUrl;
        this.unitPriceMinor = unitPrice;
        this.originalPriceMinor = originalPrice;
        this.quantity = quantity;
        this.lineTotalMinor = unitPrice * quantity;
    }

    public UUID getId() {
        return id;
    }

    public int getPosition() {
        return position;
    }

    public UUID getListingId() {
        return listingId;
    }

    public ListingType getListingType() {
        return listingType;
    }

    public String getTitle() {
        return title;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public long getUnitPriceMinor() {
        return unitPriceMinor;
    }

    public long getOriginalPriceMinor() {
        return originalPriceMinor;
    }

    public int getQuantity() {
        return quantity;
    }

    public long getLineTotalMinor() {
        return lineTotalMinor;
    }
}
