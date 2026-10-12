package com.mintadeal.identity;

import java.util.regex.Pattern;

import com.mintadeal.common.ApiException;

/** Normalises Indian mobile numbers to E.164 (+91XXXXXXXXXX). */
public final class PhoneNumbers {

    private static final Pattern INDIAN_MOBILE = Pattern.compile("[6-9]\\d{9}");

    private PhoneNumbers() {
    }

    public static String normalize(String raw) {
        if (raw == null) {
            throw ApiException.badRequest("invalid_phone", "Enter a 10-digit mobile number");
        }
        String digits = raw.replaceAll("[\\s\\-()]", "");
        if (digits.startsWith("+91")) {
            digits = digits.substring(3);
        } else if (digits.startsWith("91") && digits.length() == 12) {
            digits = digits.substring(2);
        } else if (digits.startsWith("0") && digits.length() == 11) {
            digits = digits.substring(1);
        }
        if (!INDIAN_MOBILE.matcher(digits).matches()) {
            throw ApiException.badRequest("invalid_phone", "Enter a valid 10-digit Indian mobile number");
        }
        return "+91" + digits;
    }
}
