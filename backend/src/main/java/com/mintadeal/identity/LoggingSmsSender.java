package com.mintadeal.identity;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
class LoggingSmsSender implements SmsSender {

    private static final Logger log = LoggerFactory.getLogger(LoggingSmsSender.class);

    @Override
    public void sendOtp(String phone, String code) {
        // Never log the code itself: logs are retained and widely readable.
        log.info("OTP issued for {}****{} (no SMS provider configured)",
                phone.substring(0, 5), phone.substring(phone.length() - 2));
    }
}
