package com.mintadeal.account;

import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Accounts deleted at their owner's request. Sign-in tokens last 30 days, so a token issued before the deletion is
 * refused by checking this set on every request.
 */
@Component
public class DeletedAccounts {

    private final JdbcTemplate jdbc;
    private volatile Set<UUID> ids;

    public DeletedAccounts(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public boolean contains(UUID id) {
        return ids().contains(id);
    }

    void add(UUID id) {
        ids().add(id);
    }

    private Set<UUID> ids() {
        Set<UUID> s = ids;
        if (s == null) {
            synchronized (this) {
                if (ids == null) {
                    Set<UUID> loaded = ConcurrentHashMap.newKeySet();
                    loaded.addAll(jdbc.queryForList("select id from app_user where deleted_at is not null", UUID.class));
                    ids = loaded;
                }
                s = ids;
            }
        }
        return s;
    }
}
