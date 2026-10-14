package com.mintadeal.support;

import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mintadeal.common.CurrentUser;
import com.mintadeal.common.PageResponse;
import com.mintadeal.identity.Role;
import com.mintadeal.support.SupportDtos.MessageRequest;
import com.mintadeal.support.SupportDtos.OpenRequest;
import com.mintadeal.support.SupportDtos.TicketDetail;
import com.mintadeal.support.SupportDtos.TicketSummary;
import com.mintadeal.support.SupportTicket.Status;

/**
 * Help requests. One person can be a customer, a shop owner and a rider, so each app says which one it is asking
 * as ({@code as}); each sees only its own requests.
 */
@RestController
public class SupportController {

    private final SupportService service;

    public SupportController(SupportService service) {
        this.service = service;
    }

    @PostMapping("/api/support/tickets")
    @ResponseStatus(HttpStatus.CREATED)
    public TicketDetail open(@RequestParam(defaultValue = "CUSTOMER") Role as, @Valid @RequestBody OpenRequest req) {
        return service.open(CurrentUser.id(), as, req);
    }

    @GetMapping("/api/support/tickets")
    public PageResponse<TicketSummary> mine(@RequestParam(defaultValue = "CUSTOMER") Role as,
                                            @RequestParam(defaultValue = "0") int page) {
        return service.mine(CurrentUser.id(), as, Math.max(page, 0));
    }

    @GetMapping("/api/support/tickets/{id}")
    public TicketDetail one(@PathVariable UUID id) {
        return service.mine(CurrentUser.id(), id);
    }

    @PostMapping("/api/support/tickets/{id}/messages")
    public TicketDetail reply(@PathVariable UUID id, @Valid @RequestBody MessageRequest req) {
        return service.reply(CurrentUser.id(), id, req.body());
    }

    @PostMapping("/api/support/tickets/{id}/close")
    public TicketDetail close(@PathVariable UUID id) {
        return service.close(CurrentUser.id(), id);
    }

    // --- Staff ---

    @GetMapping("/api/admin/support")
    public PageResponse<TicketSummary> queue(@RequestParam(required = false) Status status,
                                             @RequestParam(defaultValue = "0") int page) {
        return service.queue(status, page);
    }

    @GetMapping("/api/admin/support/{id}")
    public TicketDetail staffView(@PathVariable UUID id) {
        return service.staffView(id);
    }

    @PostMapping("/api/admin/support/{id}/messages")
    public TicketDetail staffReply(@PathVariable UUID id, @Valid @RequestBody MessageRequest req) {
        return service.staffReply(CurrentUser.id(), id, req.body());
    }

    @PostMapping("/api/admin/support/{id}/close")
    public TicketDetail staffClose(@PathVariable UUID id) {
        return service.staffSetStatus(id, Status.CLOSED);
    }

    @PostMapping("/api/admin/support/{id}/reopen")
    public TicketDetail staffReopen(@PathVariable UUID id) {
        return service.staffSetStatus(id, Status.OPEN);
    }
}
