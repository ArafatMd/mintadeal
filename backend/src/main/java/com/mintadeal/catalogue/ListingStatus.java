package com.mintadeal.catalogue;

public enum ListingStatus {
    DRAFT,
    ACTIVE,
    PAUSED,
    /** Taken down by Mintadeal moderation; the vendor cannot republish it. */
    REMOVED
}
