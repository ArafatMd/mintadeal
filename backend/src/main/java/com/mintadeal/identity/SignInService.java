package com.mintadeal.identity;

import java.time.Clock;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SignInService {

    private final UserRepository users;
    private final BootstrapProperties bootstrap;
    private final Clock clock;

    public SignInService(UserRepository users, BootstrapProperties bootstrap, Clock clock) {
        this.users = users;
        this.bootstrap = bootstrap;
        this.clock = clock;
    }

    /** The user for a verified phone, created on first sign-in. */
    @Transactional
    public User findOrCreate(String phone) {
        User user = users.findByPhone(phone).orElseGet(() -> users.save(new User(phone, clock.instant())));
        if (bootstrap.adminPhones().contains(phone)) {
            user.grant(Role.ADMIN);
        }
        return user;
    }
}
