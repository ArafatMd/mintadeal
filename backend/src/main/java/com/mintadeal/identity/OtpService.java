package com.mintadeal.identity;

import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import com.mintadeal.common.ApiException;

@Service
public class OtpService {

    /** How the code is sent: by SMS, or on WhatsApp when the SMS did not arrive. */
    public enum Channel { SMS, WHATSAPP }

    private final OtpChallengeRepository challenges;
    private final SmsSender sms;
    private final WhatsAppCodes whatsApp;
    private final OtpProperties props;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public OtpService(OtpChallengeRepository challenges, SmsSender sms, WhatsAppCodes whatsApp, OtpProperties props,
                      Clock clock) {
        this.whatsApp = whatsApp;
        this.challenges = challenges;
        this.sms = sms;
        this.props = props;
        this.clock = clock;
    }

    /** Whether codes can be sent on WhatsApp, so the apps can offer it. */
    public boolean whatsAppAvailable() {
        return whatsApp.available();
    }

    @Transactional
    public void issue(String phone) {
        issue(phone, Channel.SMS);
    }

    @Transactional
    public void issue(String phone, Channel channel) {
        if (channel == Channel.WHATSAPP && !whatsApp.available()) {
            throw ApiException.badRequest("whatsapp_unavailable", "Codes on WhatsApp are not available. Try SMS.");
        }
        Instant now = clock.instant();
        challenges.findFirstByPhoneOrderByCreatedAtDesc(phone).ifPresent(last -> {
            if (last.getCreatedAt().plus(props.resendCooldown()).isAfter(now)) {
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "otp_cooldown",
                        "Please wait a few seconds before requesting another code");
            }
        });
        if (challenges.countByPhoneAndCreatedAtAfter(phone, now.minus(Duration.ofHours(1))) >= props.maxPerHour()) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "otp_limit",
                    "Too many codes requested. Try again later");
        }
        // The fixed development code is only used while no SMS provider is switched on.
        boolean review = props.isReviewPhone(phone);
        boolean delivers = channel == Channel.WHATSAPP || sms.delivers();
        boolean fixed = review || StringUtils.hasText(props.devFixedCode()) && !delivers;
        String code = review ? props.reviewCode()
                : fixed ? props.devFixedCode() : String.format("%06d", random.nextInt(1_000_000));
        challenges.save(new OtpChallenge(phone, hash(phone, code), now, now.plus(props.ttl())));
        if (!fixed && channel == Channel.WHATSAPP) {
            whatsApp.send(phone, code);
        } else if (!fixed) {
            sms.sendOtp(phone, code);
        }
    }

    /** Checks the latest code for this phone; consumes it on success. */
    @Transactional(noRollbackFor = ApiException.class)
    public void verify(String phone, String code) {
        OtpChallenge challenge = challenges.findFirstByPhoneOrderByCreatedAtDesc(phone)
                .orElseThrow(() -> invalid());
        if (challenge.isConsumed() || challenge.getExpiresAt().isBefore(clock.instant())) {
            throw ApiException.badRequest("otp_expired", "This code has expired. Request a new one");
        }
        if (challenge.getAttempts() >= props.maxAttempts()) {
            throw ApiException.badRequest("otp_locked", "Too many wrong attempts. Request a new code");
        }
        challenge.recordAttempt();
        boolean matches = MessageDigest.isEqual(
                challenge.getCodeHash().getBytes(StandardCharsets.UTF_8),
                hash(phone, code == null ? "" : code.trim()).getBytes(StandardCharsets.UTF_8));
        if (!matches) {
            throw invalid();
        }
        challenge.consume();
    }

    private static ApiException invalid() {
        return ApiException.badRequest("otp_invalid", "The code is incorrect");
    }

    private String hash(String phone, String code) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(props.pepper().getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal((phone + ":" + code).getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new IllegalStateException(e);
        }
    }
}
