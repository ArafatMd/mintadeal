package com.mintadeal.delivery;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.EnumSet;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.common.ApiException;
import com.mintadeal.common.Geo;
import com.mintadeal.delivery.DeliveryDtos.CostQuote;
import com.mintadeal.identity.PhoneNumbers;
import com.mintadeal.identity.Role;
import com.mintadeal.identity.User;
import com.mintadeal.identity.UserRepository;
import com.mintadeal.order.ActorType;
import com.mintadeal.order.Checkout;
import com.mintadeal.order.CheckoutRepository;
import com.mintadeal.order.OrderCancelledEvent;
import com.mintadeal.order.OrderService;
import com.mintadeal.order.OrderStatus;
import com.mintadeal.order.PaymentStatus;
import com.mintadeal.order.ShopOrder;
import com.mintadeal.order.ShopOrderRepository;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorRepository;

/**
 * Mintadeal delivery partners. The shop books a rider for an accepted partner-delivery order, sees the cost first,
 * and the cost is charged to the shop once the rider picks the order up.
 */
@Service
public class DeliveryService {

    private static final Logger log = LoggerFactory.getLogger(DeliveryService.class);
    private static final EnumSet<JobStatus> ACTIVE = EnumSet.of(JobStatus.REQUESTED, JobStatus.ASSIGNED,
            JobStatus.PICKED_UP);

    private final DeliveryJobRepository jobs;
    private final VendorChargeRepository charges;
    private final ShopOrderRepository orders;
    private final CheckoutRepository checkouts;
    private final VendorRepository vendors;
    private final UserRepository users;
    private final OrderService orderService;
    private final DeliveryProperties props;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public DeliveryService(DeliveryJobRepository jobs, VendorChargeRepository charges, ShopOrderRepository orders,
                           CheckoutRepository checkouts, VendorRepository vendors, UserRepository users,
                           OrderService orderService, DeliveryProperties props, Clock clock) {
        this.jobs = jobs;
        this.charges = charges;
        this.orders = orders;
        this.checkouts = checkouts;
        this.vendors = vendors;
        this.users = users;
        this.orderService = orderService;
        this.props = props;
        this.clock = clock;
    }

    // --- Shop ---

    @Transactional(readOnly = true)
    public CostQuote quote(UUID vendorId, UUID orderId) {
        ShopOrder o = shopOrder(vendorId, orderId);
        Checkout c = checkouts.findById(o.getCheckoutId()).orElseThrow();
        Vendor v = vendors.findById(vendorId).orElseThrow();
        BigDecimal km = distance(v, c);
        long cost = cost(km);
        long outstanding = charges.outstandingFor(vendorId);
        String problem = null;
        if (o.getStatus() != OrderStatus.ACCEPTED || o.getFulfilmentMode() != FulfilmentMode.PARTNER_DELIVERY) {
            problem = "Accept the order first. Partner delivery is only for orders the customer chose it for.";
        } else if (jobs.findFirstByShopOrderIdAndStatusIn(orderId, ACTIVE).isPresent()) {
            problem = "A delivery partner is already booked for this order";
        } else if (outstanding + cost > props.maxOutstandingMinor()) {
            problem = "Your unpaid delivery charges are " + rupees(outstanding) + ". The limit is "
                    + rupees(props.maxOutstandingMinor()) + ". Contact Mintadeal to settle them.";
        }
        return new CostQuote(cost, km, outstanding, props.maxOutstandingMinor(), problem == null, problem);
    }

    @Transactional
    public DeliveryJob request(UUID vendorId, UUID userId, UUID orderId) {
        CostQuote quote = quote(vendorId, orderId);
        if (!quote.allowed()) {
            throw ApiException.conflict("delivery_not_allowed", quote.problem());
        }
        ShopOrder o = shopOrder(vendorId, orderId);
        Checkout c = checkouts.findById(o.getCheckoutId()).orElseThrow();
        Vendor v = vendors.findById(vendorId).orElseThrow();
        long cash = c.getPaymentStatus() == PaymentStatus.PAID ? 0 : o.getTotalMinor();
        int items = o.getLines().stream().mapToInt(l -> l.getQuantity()).sum();
        DeliveryJob job = new DeliveryJob(o.getId(), o.getCode(), vendorId, quote.costMinor(), quote.distanceKm(),
                cash, items, String.format("%04d", random.nextInt(10_000)), clock.instant());
        job.pickup(v.getDisplayName(), v.getPhone(), v.getAddressLine(), v.getArea(), v.getLatitude(), v.getLongitude());
        job.drop(c.getContactName(), c.getContactPhone(),
                c.getAddressLine() + (c.getAddressLandmark() == null ? "" : " (" + c.getAddressLandmark() + ")"),
                c.getAddressArea(), c.getAddressLatitude(), c.getAddressLongitude());
        jobs.save(job);
        orderService.note(o.getId(), ActorType.VENDOR, userId,
                "Delivery partner requested (" + rupees(quote.costMinor()) + " charged to the shop)");
        return job;
    }

    @Transactional
    public void vendorCancel(UUID vendorId, UUID userId, UUID orderId) {
        shopOrder(vendorId, orderId);
        DeliveryJob job = jobs.findFirstByShopOrderIdAndStatusIn(orderId, EnumSet.of(JobStatus.REQUESTED, JobStatus.ASSIGNED))
                .orElseThrow(() -> ApiException.conflict("no_open_job",
                        "There is no delivery partner booking you can cancel"));
        job.close(JobStatus.CANCELLED, "Cancelled by the shop", clock.instant());
        orderService.note(orderId, ActorType.VENDOR, userId, "Delivery partner booking cancelled by the shop");
    }

    // --- Delivery partner ---

    @Transactional
    public DeliveryJob claim(UUID agentId, UUID jobId) {
        DeliveryJob job = job(jobId);
        if (job.getStatus() != JobStatus.REQUESTED) {
            throw ApiException.conflict("job_taken", "Another delivery partner has taken this job");
        }
        job.assign(agentId, clock.instant());
        try {
            jobs.saveAndFlush(job);
        } catch (OptimisticLockingFailureException e) {
            // Two riders pressed "Take job" at the same moment; only the first wins.
            throw ApiException.conflict("job_taken", "Another delivery partner has taken this job");
        }
        String name = name(agentId);
        orderService.note(job.getShopOrderId(), ActorType.SYSTEM, agentId,
                "Delivery partner" + (name == null ? "" : " " + name) + " is on the way to the shop");
        return job;
    }

    @Transactional
    public DeliveryJob release(UUID agentId, UUID jobId) {
        DeliveryJob job = mine(agentId, jobId, JobStatus.ASSIGNED, "You can only hand back a job before pickup");
        job.release();
        orderService.note(job.getShopOrderId(), ActorType.SYSTEM, agentId, "Delivery partner changed; finding another");
        return job;
    }

    @Transactional
    public DeliveryJob pickedUp(UUID agentId, UUID jobId) {
        DeliveryJob job = mine(agentId, jobId, JobStatus.ASSIGNED, "This job is not waiting for pickup");
        Instant now = clock.instant();
        job.pickedUp(now);
        // The rider has done the work from here on, so this is when the shop is charged.
        charges.save(new VendorCharge(job.getVendorId(), job.getShopOrderId(), job.getId(), job.getCostMinor(),
                "Delivery partner for order " + job.getOrderCode() + " (" + job.getDistanceKm() + " km)", now));
        orderService.partnerPickedUp(job.getShopOrderId(), agentId, name(agentId));
        return job;
    }

    @Transactional(noRollbackFor = ApiException.class)
    public DeliveryJob delivered(UUID agentId, UUID jobId, String code) {
        DeliveryJob job = mine(agentId, jobId, JobStatus.PICKED_UP, "Pick up the order before delivering it");
        if (job.getDropCodeAttempts() >= props.dropCodeMaxAttempts()) {
            throw ApiException.conflict("drop_code_locked",
                    "Too many wrong codes. Call Mintadeal support to complete this delivery.");
        }
        if (!job.checkDropCode(code)) {
            throw ApiException.badRequest("drop_code_wrong", "That is not the customer's delivery code");
        }
        job.delivered(clock.instant());
        orderService.partnerDelivered(job.getShopOrderId(), agentId);
        return job;
    }

    @Transactional
    public DeliveryJob failed(UUID agentId, UUID jobId, String reason) {
        DeliveryJob job = mine(agentId, jobId, JobStatus.PICKED_UP,
                "Before pickup, hand the job back instead of marking it failed");
        job.close(JobStatus.FAILED, reason.trim(), clock.instant());
        orderService.partnerFailed(job.getShopOrderId(), agentId, reason.trim());
        return job;
    }

    // --- Admin ---

    @Transactional
    public DeliveryJob assign(UUID jobId, String phone) {
        DeliveryJob job = job(jobId);
        if (job.getStatus() != JobStatus.REQUESTED && job.getStatus() != JobStatus.ASSIGNED) {
            throw ApiException.conflict("job_closed", "Only jobs that are not yet picked up can be assigned");
        }
        User agent = users.findByPhone(PhoneNumbers.normalize(phone))
                .filter(u -> u.hasRole(Role.DELIVERY_AGENT))
                .orElseThrow(() -> ApiException.badRequest("not_an_agent",
                        "That number is not a delivery partner. Add them under Staff & roles first."));
        job.assign(agent.getId(), clock.instant());
        orderService.note(job.getShopOrderId(), ActorType.ADMIN, null,
                "Delivery partner " + (agent.getName() == null ? agent.getPhone() : agent.getName()) + " assigned by Mintadeal");
        return job;
    }

    @Transactional
    public DeliveryJob adminCancel(UUID jobId, String reason) {
        DeliveryJob job = job(jobId);
        if (!job.getStatus().isActive()) {
            throw ApiException.conflict("job_closed", "This job is already closed");
        }
        job.close(JobStatus.CANCELLED, reason.trim(), clock.instant());
        orderService.note(job.getShopOrderId(), ActorType.ADMIN, null, "Delivery job cancelled by Mintadeal: " + reason.trim());
        return job;
    }

    @EventListener
    void onOrderCancelled(OrderCancelledEvent e) {
        jobs.findFirstByShopOrderIdAndStatusIn(e.shopOrderId(), ACTIVE).ifPresent(job -> {
            if (job.getStatus() == JobStatus.PICKED_UP) {
                log.warn("Order {} cancelled while out with a delivery partner; the rider must return it", job.getOrderCode());
            }
            job.close(JobStatus.CANCELLED, "Order cancelled: " + e.reason(), clock.instant());
        });
    }

    // --- Helpers ---

    long cost(BigDecimal km) {
        long wholeKm = km.setScale(0, RoundingMode.CEILING).longValue();
        return props.baseFeeMinor() + props.perKmMinor() * Math.max(1, wholeKm);
    }

    private static BigDecimal distance(Vendor v, Checkout c) {
        if (c.getAddressLatitude() == null || c.getAddressLongitude() == null) {
            throw ApiException.conflict("no_address", "This order has no delivery address");
        }
        double km = Geo.distanceKm(v.getLatitude(), v.getLongitude(), c.getAddressLatitude(), c.getAddressLongitude());
        return BigDecimal.valueOf(km).setScale(2, RoundingMode.HALF_UP);
    }

    private ShopOrder shopOrder(UUID vendorId, UUID orderId) {
        return orders.findById(orderId).filter(o -> o.getVendorId().equals(vendorId))
                .orElseThrow(() -> ApiException.notFound("Order"));
    }

    private DeliveryJob job(UUID jobId) {
        return jobs.findById(jobId).orElseThrow(() -> ApiException.notFound("Delivery job"));
    }

    private DeliveryJob mine(UUID agentId, UUID jobId, JobStatus expected, String wrongStateMessage) {
        DeliveryJob job = jobs.findById(jobId).filter(j -> agentId.equals(j.getAgentId()))
                .orElseThrow(() -> ApiException.notFound("Delivery job"));
        if (job.getStatus() != expected) {
            throw ApiException.conflict("invalid_job_state", wrongStateMessage);
        }
        return job;
    }

    private String name(UUID agentId) {
        return users.findById(agentId).map(User::getName).filter(n -> !n.isBlank()).orElse(null);
    }

    static String rupees(long minor) {
        return minor % 100 == 0 ? "₹" + minor / 100 : String.format("₹%.2f", minor / 100.0);
    }
}
