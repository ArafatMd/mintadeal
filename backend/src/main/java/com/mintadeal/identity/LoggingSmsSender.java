package com.mintadeal.identity;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** Used when no SMS provider is enabled: records that a code was issued, never the code itself. */
class LoggingSmsSender implements SmsSender {

    private static final Logger log = LoggerFactory.getLogger(LoggingSmsSender.class);

    @Override
    public void sendOtp(String phone, String code) {
        log.info("OTP issued for {}****{} (no SMS provider enabled)",
                phone.substring(0, 5), phone.substring(phone.length() - 2));
    }
}
