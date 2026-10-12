package com.mintadeal.order;

import java.util.UUID;

/** A shop order changed status. Used for notifications; published inside the changing transaction. */
public record OrderStatusEvent(UUID shopOrderId, OrderStatus status, ActorType actor) {
}
