package com.mintadeal.dev;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.EnumSet;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.catalogue.Listing;
import com.mintadeal.catalogue.ListingRepository;
import com.mintadeal.catalogue.ListingStatus;
import com.mintadeal.catalogue.ListingType;
import com.mintadeal.identity.Role;
import com.mintadeal.identity.User;
import com.mintadeal.identity.UserRepository;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorCategory;
import com.mintadeal.vendor.VendorRepository;
import com.mintadeal.vendor.VendorStatus;
import com.mintadeal.vendor.VendorType;

/** Demo shops around HSR Layout, Bengaluru, so every app has something to show locally. Dev profile only. */
@Component
@ConditionalOnProperty(name = "mintadeal.seed-demo-data", havingValue = "true")
class DemoDataSeeder implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DemoDataSeeder.class);

    private final UserRepository users;
    private final VendorRepository vendors;
    private final ListingRepository listings;
    private final Clock clock;

    DemoDataSeeder(UserRepository users, VendorRepository vendors, ListingRepository listings, Clock clock) {
        this.users = users;
        this.vendors = vendors;
        this.listings = listings;
        this.clock = clock;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (vendors.count() > 0) {
            return;
        }
        Instant now = clock.instant();

        Vendor grocery = shop("+919000000101", "Sri Lakshmi Provisions", VendorCategory.GROCERY,
                "27th Main, Sector 1", "HSR Layout", "560102", 12.9121, 77.6446, VendorType.EXTERNAL, now);
        grocery.setSelfDelivery(true);
        grocery.setPickup(true);
        grocery.setDeliveryRadiusKm(new BigDecimal("3"));
        grocery.setDeliveryFeeMinor(2000);
        grocery.setMinOrderMinor(19900);
        product(grocery, "Aashirvaad Atta 5 kg", VendorCategory.GROCERY, 29500, 26900L, 40,
                EnumSet.of(FulfilmentMode.SHOP_DELIVERY, FulfilmentMode.PICKUP), now);
        product(grocery, "Fresh toned milk 1 L", VendorCategory.GROCERY, 5600, null, null,
                EnumSet.of(FulfilmentMode.SHOP_DELIVERY, FulfilmentMode.PICKUP), now);

        Vendor meat = shop("+919000000102", "HSR Fresh Meats", VendorCategory.MEAT_FISH,
                "14th Cross, Sector 6", "HSR Layout", "560102", 12.9096, 77.6383, VendorType.EXTERNAL, now);
        meat.setSelfDelivery(true);
        meat.setPartnerDelivery(true);
        meat.setPickup(true);
        meat.setDeliveryRadiusKm(new BigDecimal("4"));
        meat.setDeliveryFeeMinor(3000);
        product(meat, "Chicken curry cut 1 kg", VendorCategory.MEAT_FISH, 32000, 28000L, 25,
                EnumSet.of(FulfilmentMode.SHOP_DELIVERY, FulfilmentMode.PARTNER_DELIVERY, FulfilmentMode.PICKUP), now);

        Vendor hardware = shop("+919000000103", "Balaji Hardware & Paints", VendorCategory.HARDWARE,
                "HSR BDA Complex", "HSR Layout", "560102", 12.9142, 77.6380, VendorType.EXTERNAL, now);
        hardware.setPickup(true);
        hardware.setPartnerDelivery(true);
        hardware.setDeliveryRadiusKm(new BigDecimal("6"));
        hardware.setDeliveryFeeMinor(6000);
        product(hardware, "Bosch 13mm impact drill", VendorCategory.HARDWARE, 389900, 329900L, 6,
                EnumSet.of(FulfilmentMode.PICKUP, FulfilmentMode.PARTNER_DELIVERY), now);

        Vendor clothing = shop("+919000000104", "Threads Boutique", VendorCategory.CLOTHING,
                "19th Main, Sector 4", "HSR Layout", "560102", 12.9107, 77.6493, VendorType.EXTERNAL, now);
        clothing.setPickup(true);
        clothing.setSelfDelivery(true);
        clothing.setCitywideDelivery(true);
        clothing.setDeliveryFeeMinor(9900);
        product(clothing, "Handloom cotton kurta", VendorCategory.CLOTHING, 149900, 99900L, 12,
                EnumSet.of(FulfilmentMode.SHOP_DELIVERY, FulfilmentMode.PICKUP), now);

        Vendor salon = shop("+919000000105", "Glow Unisex Salon", VendorCategory.SALON_SPA,
                "24th Main, Sector 2", "HSR Layout", "560102", 12.9155, 77.6470, VendorType.EXTERNAL, now);
        offer(salon, "Haircut + head massage", VendorCategory.SALON_SPA, 80000, 49900, 10,
                "Valid Mon-Thu. Book by phone after purchase.", now);

        Vendor hotel = shop("+919000000106", "Koramangala Residency", VendorCategory.HOTEL,
                "80 Feet Road", "Koramangala", "560034", 12.9352, 77.6245, VendorType.EXTERNAL, now);
        offer(hotel, "Weekend buffet dinner for 2", VendorCategory.RESTAURANT, 280000, 199900, 20,
                "Friday to Sunday, 7-11 pm. Show QR at the restaurant desk.", now);

        Vendor own = shop("+919000000100", "Mintadeal Deals", VendorCategory.ELECTRONICS,
                "Mintadeal office, Sector 7", "HSR Layout", "560102", 12.9080, 77.6420, VendorType.INTERNAL, now);
        own.setPartnerDelivery(true);
        own.setPickup(true);
        own.setCitywideDelivery(true);
        own.setDeliveryFeeMinor(4900);
        product(own, "Boat Airdopes wireless earbuds", VendorCategory.ELECTRONICS, 299000, 129900L, 50,
                EnumSet.of(FulfilmentMode.PARTNER_DELIVERY, FulfilmentMode.PICKUP), now);

        User rider = users.findByPhone("+919000000201").orElseGet(() -> users.save(new User("+919000000201", now)));
        rider.setName("Demo Rider");
        rider.grant(Role.DELIVERY_AGENT);

        log.info("Seeded demo shops around HSR Layout. Admin 9000000001, vendors 9000000100-106, rider 9000000201; "
                + "OTP 123456");
    }

    private Vendor shop(String phone, String name, VendorCategory category, String address, String area,
                        String pincode, double lat, double lng, VendorType type, Instant now) {
        User owner = users.findByPhone(phone).orElseGet(() -> users.save(new User(phone, now)));
        owner.setName(name + " (owner)");
        owner.grant(Role.VENDOR);
        Vendor v = new Vendor(owner.getId(), now);
        v.setDisplayName(name);
        v.setCategory(category);
        v.setVendorType(type);
        v.setStatus(VendorStatus.APPROVED);
        v.setPhone(phone);
        v.setAddressLine(address);
        v.setArea(area);
        v.setCity("Bengaluru");
        v.setPincode(pincode);
        v.setLatitude(lat);
        v.setLongitude(lng);
        v.setOpeningHours("9 am - 9 pm");
        return vendors.save(v);
    }

    private void product(Vendor v, String title, VendorCategory category, long price, Long offer, Integer stock,
                         Set<FulfilmentMode> modes, Instant now) {
        Listing l = new Listing(v.getId(), ListingType.PRODUCT, now);
        l.setTitle(title);
        l.setCategory(category);
        l.setPriceMinor(price);
        l.setOfferPriceMinor(offer);
        l.setStock(stock);
        l.setFulfilmentModes(modes);
        l.setStatus(ListingStatus.ACTIVE);
        listings.save(l);
    }

    private void offer(Vendor v, String title, VendorCategory category, long price, long offer, int capacity,
                       String terms, Instant now) {
        Listing l = new Listing(v.getId(), ListingType.OFFER, now);
        l.setTitle(title);
        l.setCategory(category);
        l.setPriceMinor(price);
        l.setOfferPriceMinor(offer);
        l.setCapacityPerSlot(capacity);
        l.setTerms(terms);
        l.setValidFrom(now);
        l.setValidTo(now.plus(Duration.ofDays(60)));
        l.setFulfilmentModes(EnumSet.of(FulfilmentMode.VENUE_QR));
        l.setStatus(ListingStatus.ACTIVE);
        listings.save(l);
    }
}
