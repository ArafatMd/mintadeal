package com.mintadeal.support;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import com.mintadeal.identity.Role;
import com.mintadeal.support.SupportTicket.Status;
import com.mintadeal.support.SupportTicket.Topic;

public final class SupportDtos {

    private SupportDtos() {
    }

    /** @param orderId optional: the order this is about */
    public record OpenRequest(@NotNull Topic topic, @NotBlank @Size(max = 120) String subject,
                              @NotBlank @Size(max = 2000) String message, UUID orderId) {
    }

    public record MessageRequest(@NotBlank @Size(max = 2000) String body) {
    }

    public record TicketSummary(UUID id, String code, Topic topic, String subject, Status status, String orderCode,
                                Role openerRole, String openerName, String openerPhone, Instant createdAt,
                                Instant lastMessageAt) {
    }

    /** @param authorName "Mintadeal support" for staff messages */
    public record MessageDto(UUID id, boolean staff, String authorName, String body, Instant createdAt) {
    }

    public record TicketDetail(TicketSummary ticket, UUID orderId, List<MessageDto> messages) {
    }
}
