package com.mintadeal.identity;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final OtpService otp;
    private final SignInService signIn;
    private final TokenService tokens;

    public AuthController(OtpService otp, SignInService signIn, TokenService tokens) {
        this.otp = otp;
        this.signIn = signIn;
        this.tokens = tokens;
    }

    /** @param channel SMS (the default), or WHATSAPP when the SMS did not arrive */
    public record OtpRequest(@NotBlank String phone, OtpService.Channel channel) {
    }

    /** @param whatsApp whether the app may offer "Get the code on WhatsApp" */
    public record OtpSent(OtpService.Channel channel, boolean whatsApp) {
    }

    public record OtpVerify(@NotBlank String phone, @NotBlank String code) {
    }

    public record AuthResponse(String accessToken, UserDto user) {
    }

    @PostMapping("/otp/request")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public OtpSent requestOtp(@Valid @RequestBody OtpRequest req) {
        OtpService.Channel channel = req.channel() == null ? OtpService.Channel.SMS : req.channel();
        otp.issue(PhoneNumbers.normalize(req.phone()), channel);
        return new OtpSent(channel, otp.whatsAppAvailable());
    }

    /**
     * Not transactional itself: the OTP check commits its attempt counter on its own, so a wrong code
     * still counts towards the lockout even though this request fails.
     */
    @PostMapping("/otp/verify")
    public AuthResponse verify(@Valid @RequestBody OtpVerify req) {
        String phone = PhoneNumbers.normalize(req.phone());
        otp.verify(phone, req.code());
        User user = signIn.findOrCreate(phone);
        return new AuthResponse(tokens.issue(user), UserDto.of(user));
    }
}
