package com.mintadeal.popup;

import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

import com.mintadeal.common.Geo;

/** What a stall may sell and where. Stalls go live without review, so these are checked up front. */
final class PopupRules {

    private PopupRules() {
    }

    /** Things that need a licence or are not allowed, in English and common Hindi and Kannada spellings. */
    private static final List<String> NOT_ALLOWED = List.of(
            "alcohol", "liquor", "beer", "whisky", "whiskey", "vodka", "rum", "wine", "toddy", "arrack", "daru",
            "daaru", "sharab", "sharaab", "cigarette", "cigarettes", "beedi", "bidi", "tobacco", "gutka", "gutkha",
            "pan masala", "hookah", "vape", "ganja", "weed", "charas", "drugs", "fireworks", "firecrackers",
            "crackers", "patake", "pataka", "medicine", "medicines", "tablets", "pills", "injection", "syrup",
            "gun", "pistol", "airgun", "puppy", "puppies", "kitten", "kittens", "parrot", "parrots", "lottery");

    private static final Pattern WORDS = Pattern.compile("\\b(" + String.join("|", NOT_ALLOWED) + ")\\b");

    /** The banned word found in [text], or null. */
    static String notAllowed(String text) {
        if (text == null) {
            return null;
        }
        var m = WORDS.matcher(text.toLowerCase(Locale.ROOT));
        return m.find() ? m.group(1) : null;
    }

    private static final double CITY_LAT = 12.9716;
    private static final double CITY_LNG = 77.5946;

    static boolean inBengaluru(double lat, double lng) {
        return Geo.distanceKm(lat, lng, CITY_LAT, CITY_LNG) <= 40;
    }
}
