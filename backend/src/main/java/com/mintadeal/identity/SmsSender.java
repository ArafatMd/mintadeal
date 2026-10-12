package com.mintadeal.identity;

/** Sends one-time passwords. Replace the logging implementation with an SMS/WhatsApp provider before launch. */
public interface SmsSender {

    void sendOtp(String phone, String code);
}
