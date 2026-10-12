package com.mintadeal.admin;

import java.time.Clock;
import java.util.UUID;

import org.springframework.stereotype.Service;

import com.mintadeal.common.CurrentUser;

@Service
public class AuditService {

    private final AuditRepository repo;
    private final Clock clock;

    public AuditService(AuditRepository repo, Clock clock) {
        this.repo = repo;
        this.clock = clock;
    }

    public void record(String action, String entityType, UUID entityId, String detail) {
        repo.save(new AuditEvent(CurrentUser.id(), action, entityType, entityId, detail, clock.instant()));
    }
}
