package com.mintadeal.identity;

import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

import com.mintadeal.integrations.TwoFactorClient;

/** Sends codes through 2Factor when an admin has enabled it, otherwise only logs that a code was issued. */
@Component
@Primary
class RoutingSmsSender implements SmsSender {

    private final TwoFactorClient twoFactor;
    private final SmsSender fallback = new LoggingSmsSender();

    RoutingSmsSender(TwoFactorClient twoFactor) {
        this.twoFactor = twoFactor;
    }

    @Override
    public boolean delivers() {
        return twoFactor.enabled();
    }

    @Override
    public void sendOtp(String phone, String code) {
        if (twoFactor.enabled()) {
            twoFactor.sendOtp(phone, code);
        } else {
            fallback.sendOtp(phone, code);
        }
    }
}
