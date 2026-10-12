package com.mintadeal.admin;

import java.time.Clock;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.ApiException;
import com.mintadeal.common.CurrentUser;
import com.mintadeal.identity.PhoneNumbers;
import com.mintadeal.identity.Role;
import com.mintadeal.identity.User;
import com.mintadeal.identity.UserDto;
import com.mintadeal.identity.UserRepository;

/** Grants staff roles such as DELIVERY_AGENT or ADMIN. Users are created on first sign-in or here. */
@RestController
@RequestMapping("/api/admin/users")
public class AdminUserController {

    private final UserRepository users;
    private final AuditService audit;
    private final Clock clock;

    public AdminUserController(UserRepository users, AuditService audit, Clock clock) {
        this.users = users;
        this.audit = audit;
        this.clock = clock;
    }

    public record RoleChange(@NotBlank String phone, @NotNull Role role, boolean granted) {
    }

    @GetMapping
    @Transactional(readOnly = true)
    public UserDto find(@RequestParam String phone) {
        return UserDto.of(users.findByPhone(PhoneNumbers.normalize(phone))
                .orElseThrow(() -> ApiException.notFound("User")));
    }

    @PostMapping("/roles")
    @Transactional
    public UserDto changeRole(@Valid @RequestBody RoleChange req) {
        if (req.role() == Role.CUSTOMER || req.role() == Role.VENDOR) {
            throw ApiException.badRequest("role_not_assignable", "That role is assigned automatically");
        }
        String phone = PhoneNumbers.normalize(req.phone());
        User user = users.findByPhone(phone).orElseGet(() -> users.save(new User(phone, clock.instant())));
        if (!req.granted() && req.role() == Role.ADMIN && user.getId().equals(CurrentUser.id())) {
            throw ApiException.badRequest("cannot_remove_self", "You cannot remove your own admin access");
        }
        if (req.granted()) {
            user.grant(req.role());
        } else {
            user.revoke(req.role());
        }
        audit.record(req.granted() ? "ROLE_GRANTED" : "ROLE_REVOKED", "USER", user.getId(), req.role().name());
        return UserDto.of(user);
    }
}
