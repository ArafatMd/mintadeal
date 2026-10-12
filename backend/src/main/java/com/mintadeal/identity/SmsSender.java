package com.mintadeal.identity;

/** Sends one-time passwords. Replace the logging implementation with an SMS/WhatsApp provider before launch. */
public interface SmsSender {

    void sendOtp(String phone, String code);

    /** Whether codes really reach the phone. When false, the dev fixed code (if configured) is used instead. */
    default boolean delivers() {
        return false;
    }
}
