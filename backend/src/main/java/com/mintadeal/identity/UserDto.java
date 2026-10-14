package com.mintadeal.identity;

import java.util.List;
import java.util.UUID;

public record UserDto(UUID id, String phone, String name, String email, String avatarUrl, List<Role> roles) {

    public static UserDto of(User u) {
        return new UserDto(u.getId(), u.getPhone(), u.getName(), u.getEmail(), u.getAvatarUrl(),
                u.getRoles().stream().sorted().toList());
    }
}
