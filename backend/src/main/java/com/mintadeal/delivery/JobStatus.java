package com.mintadeal.delivery;

/** REQUESTED (waiting for a rider), ASSIGNED, PICKED_UP, then DELIVERED, FAILED or CANCELLED. */
public enum JobStatus {
    REQUESTED,
    ASSIGNED,
    PICKED_UP,
    DELIVERED,
    FAILED,
    CANCELLED;

    public boolean isActive() {
        return this == REQUESTED || this == ASSIGNED || this == PICKED_UP;
    }
}
