package com.mintadeal.order;

import java.security.SecureRandom;

/** Short codes customers can read out on the phone, e.g. MD-7K3Q9P. No 0/O or 1/I/L. */
final class OrderCodes {

    private static final char[] ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ".toCharArray();
    private static final SecureRandom RANDOM = new SecureRandom();

    private OrderCodes() {
    }

    static String next() {
        StringBuilder sb = new StringBuilder("MD-");
        for (int i = 0; i < 6; i++) {
            sb.append(ALPHABET[RANDOM.nextInt(ALPHABET.length)]);
        }
        return sb.toString();
    }

    static String rupees(long minor) {
        return minor % 100 == 0 ? "₹" + minor / 100 : String.format("₹%.2f", minor / 100.0);
    }
}
