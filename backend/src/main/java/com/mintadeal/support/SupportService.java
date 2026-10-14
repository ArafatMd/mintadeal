package com.mintadeal.support;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.common.ApiException;
import com.mintadeal.common.PageResponse;
import com.mintadeal.delivery.DeliveryJobRepository;
import com.mintadeal.identity.Role;
import com.mintadeal.identity.User;
import com.mintadeal.identity.UserRepository;
import com.mintadeal.order.ShopOrder;
import com.mintadeal.order.ShopOrderRepository;
import com.mintadeal.support.SupportDtos.MessageDto;
import com.mintadeal.support.SupportDtos.OpenRequest;
import com.mintadeal.support.SupportDtos.TicketDetail;
import com.mintadeal.support.SupportDtos.TicketSummary;
import com.mintadeal.support.SupportTicket.Status;
import com.mintadeal.vendor.VendorRepository;

@Service
public class SupportService {

    /** Stops one person flooding the queue; closed tickets do not count. */
    static final int MAX_OPEN_TICKETS = 5;

    private static final char[] ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ".toCharArray();
    private static final SecureRandom RANDOM = new SecureRandom();

    private final SupportTicketRepository tickets;
    private final SupportMessageRepository messages;
    private final UserRepository users;
    private final ShopOrderRepository orders;
    private final VendorRepository vendors;
    private final DeliveryJobRepository jobs;
    private final Clock clock;

    public SupportService(SupportTicketRepository tickets, SupportMessageRepository messages, UserRepository users,
                          ShopOrderRepository orders, VendorRepository vendors, DeliveryJobRepository jobs,
                          Clock clock) {
        this.tickets = tickets;
        this.messages = messages;
        this.users = users;
        this.orders = orders;
        this.vendors = vendors;
        this.jobs = jobs;
        this.clock = clock;
    }

    @Transactional
    public TicketDetail open(UUID userId, Role as, OpenRequest r) {
        User user = requireRole(userId, as);
        if (tickets.countByOpenedByAndOpenerRoleAndStatusNot(userId, as, Status.CLOSED) >= MAX_OPEN_TICKETS) {
            throw ApiException.conflict("too_many_tickets",
                    "You already have " + MAX_OPEN_TICKETS + " open requests. We will reply to those first.");
        }
        ShopOrder order = r.orderId() == null ? null : orderFor(user, as, r.orderId());
        Instant now = clock.instant();
        SupportTicket t = tickets.save(new SupportTicket(nextCode(), userId, as, order == null ? null : order.getId(),
                order == null ? null : order.getCode(), r.topic(), r.subject().trim(), now));
        messages.save(new SupportMessage(t.getId(), userId, false, r.message().trim(), now));
        return detail(t);
    }

    @Transactional(readOnly = true)
    public PageResponse<TicketSummary> mine(UUID userId, Role as, int page) {
        return page(tickets.findByOpenedByAndOpenerRoleOrderByLastMessageAtDesc(userId, as, PageRequest.of(page, 20)));
    }

    @Transactional(readOnly = true)
    public TicketDetail mine(UUID userId, UUID ticketId) {
        return detail(owned(userId, ticketId));
    }

    @Transactional
    public TicketDetail reply(UUID userId, UUID ticketId, String body) {
        SupportTicket t = owned(userId, ticketId);
        Instant now = clock.instant();
        messages.save(new SupportMessage(t.getId(), userId, false, body.trim(), now));
        t.messaged(false, now);
        return detail(t);
    }

    @Transactional
    public TicketDetail close(UUID userId, UUID ticketId) {
        SupportTicket t = owned(userId, ticketId);
        t.setStatus(Status.CLOSED, clock.instant());
        return detail(t);
    }

    // --- Staff ---

    /** @param status null for the queue: open first, oldest first, then answered */
    @Transactional(readOnly = true)
    public PageResponse<TicketSummary> queue(Status status, int page) {
        PageRequest p = PageRequest.of(Math.max(page, 0), 30);
        return page(status == null ? tickets.findAllByOrderByLastMessageAtDesc(p)
                : tickets.findByStatusInOrderByLastMessageAtAsc(List.of(status), p));
    }

    @Transactional(readOnly = true)
    public TicketDetail staffView(UUID ticketId) {
        return detail(tickets.findById(ticketId).orElseThrow(() -> ApiException.notFound("Ticket")));
    }

    @Transactional
    public TicketDetail staffReply(UUID staffId, UUID ticketId, String body) {
        SupportTicket t = tickets.findById(ticketId).orElseThrow(() -> ApiException.notFound("Ticket"));
        Instant now = clock.instant();
        messages.save(new SupportMessage(t.getId(), staffId, true, body.trim(), now));
        t.messaged(true, now);
        return detail(t);
    }

    @Transactional
    public TicketDetail staffSetStatus(UUID ticketId, Status status) {
        SupportTicket t = tickets.findById(ticketId).orElseThrow(() -> ApiException.notFound("Ticket"));
        t.setStatus(status, clock.instant());
        return detail(t);
    }

    public long openCount() {
        return tickets.countByStatus(Status.OPEN);
    }

    private User requireRole(UUID userId, Role as) {
        User user = users.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        if (as == Role.ADMIN || !user.hasRole(as)) {
            throw ApiException.forbidden("wrong_role", "You cannot open a request as " + as.name().toLowerCase());
        }
        return user;
    }

    /** The order must be the person's own: as its customer, its shop, or the rider who carried it. */
    private ShopOrder orderFor(User user, Role as, UUID orderId) {
        ShopOrder o = orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Order"));
        boolean theirs = switch (as) {
            case CUSTOMER -> o.getCustomerId().equals(user.getId());
            case VENDOR -> vendors.findByOwnerUserId(user.getId()).map(v -> v.getId().equals(o.getVendorId()))
                    .orElse(false);
            case DELIVERY_AGENT -> jobs.findFirstByShopOrderIdOrderByRequestedAtDesc(o.getId())
                    .map(j -> user.getId().equals(j.getAgentId())).orElse(false);
            case ADMIN -> false;
        };
        if (!theirs) {
            throw ApiException.notFound("Order");
        }
        return o;
    }

    private SupportTicket owned(UUID userId, UUID ticketId) {
        return tickets.findById(ticketId).filter(t -> t.getOpenedBy().equals(userId))
                .orElseThrow(() -> ApiException.notFound("Ticket"));
    }

    private PageResponse<TicketSummary> page(Page<SupportTicket> p) {
        return new PageResponse<>(p.map(this::summary).getContent(), p.getNumber(), p.getSize(), p.getTotalElements());
    }

    private TicketSummary summary(SupportTicket t) {
        User u = users.findById(t.getOpenedBy()).orElse(null);
        return new TicketSummary(t.getId(), t.getCode(), t.getTopic(), t.getSubject(), t.getStatus(), t.getOrderCode(),
                t.getOpenerRole(), u == null ? null : u.getName(), u == null ? null : u.getPhone(), t.getCreatedAt(),
                t.getLastMessageAt());
    }

    private TicketDetail detail(SupportTicket t) {
        List<MessageDto> thread = messages.findByTicketIdOrderByCreatedAt(t.getId()).stream()
                .map(m -> new MessageDto(m.getId(), m.isStaff(),
                        m.isStaff() ? "Mintadeal support"
                                : users.findById(m.getAuthorId()).map(User::getName).orElse(null),
                        m.getBody(), m.getCreatedAt()))
                .toList();
        return new TicketDetail(summary(t), t.getShopOrderId(), thread);
    }

    /** "HELP-7K3Q9": short enough to read out on the phone. */
    private String nextCode() {
        while (true) {
            StringBuilder sb = new StringBuilder("HELP-");
            for (int i = 0; i < 5; i++) {
                sb.append(ALPHABET[RANDOM.nextInt(ALPHABET.length)]);
            }
            if (!tickets.existsByCode(sb.toString())) {
                return sb.toString();
            }
        }
    }
}
