package com.mintadeal.finance;

import java.time.Instant;
import java.util.UUID;

/** A statement line for one shop: the journal's description and the shop's side of it. */
public record VendorLine(UUID journalId, String type, String description, long amountMinor, Instant createdAt) {
}
