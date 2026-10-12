package com.mintadeal.identity;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;

import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.ApiException;
import com.mintadeal.common.CurrentUser;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/me")
public class MeController {

    private final UserRepository users;
    private final TokenService tokens;

    public MeController(UserRepository users, TokenService tokens) {
        this.users = users;
        this.tokens = tokens;
    }

    public record UpdateProfile(@Size(max = 120) String name, @Email @Size(max = 200) String email) {
    }

    @GetMapping
    public UserDto me() {
        return UserDto.of(load());
    }

    @PatchMapping
    @Transactional
    public UserDto update(@Valid @RequestBody UpdateProfile req) {
        User user = load();
        if (req.name() != null) {
            user.setName(req.name().isBlank() ? null : req.name().trim());
        }
        if (req.email() != null) {
            user.setEmail(req.email().isBlank() ? null : req.email().trim());
        }
        return UserDto.of(user);
    }

    /** Issues a fresh token, e.g. after the user was granted a new role. */
    @PostMapping("/token")
    public AuthController.AuthResponse refresh() {
        User user = load();
        return new AuthController.AuthResponse(tokens.issue(user), UserDto.of(user));
    }

    private User load() {
        return users.findById(CurrentUser.id()).orElseThrow(() -> ApiException.notFound("User"));
    }
}
