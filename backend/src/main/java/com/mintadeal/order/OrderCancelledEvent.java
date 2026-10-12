package com.mintadeal.order;

import java.util.UUID;

/** Published inside the cancelling transaction so other modules (delivery) can close what they hold for the order. */
public record OrderCancelledEvent(UUID shopOrderId, String reason) {
}
