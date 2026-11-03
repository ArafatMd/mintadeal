package com.mintadeal.account;

import java.time.Clock;
import java.util.EnumSet;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.admin.AuditService;
import com.mintadeal.common.ApiException;
import com.mintadeal.delivery.DeliveryJobRepository;
import com.mintadeal.delivery.JobStatus;
import com.mintadeal.identity.Role;
import com.mintadeal.identity.User;
import com.mintadeal.identity.UserRepository;
import com.mintadeal.order.OrderStatus;
import com.mintadeal.order.ShopOrderRepository;
import com.mintadeal.popup.PopupService;
import com.mintadeal.support.SupportDtos.OpenRequest;
import com.mintadeal.support.SupportService;
import com.mintadeal.support.SupportTicket.Topic;
import com.mintadeal.vendor.VendorRepository;

/**
 * Deleting an account from inside the apps, as app stores require. Customers, riders and pop-up sellers are deleted
 * at once; a shop has money and orders to settle, so for its owner the request goes to Mintadeal support.
 */
@Service
public class AccountService {

    public record Result(boolean deleted, String message) {
    }

    private final UserRepository users;
    private final VendorRepository vendors;
    private final ShopOrderRepository orders;
    private final DeliveryJobRepository jobs;
    private final SupportService support;
    private final PopupService popups;
    private final DeletedAccounts deleted;
    private final AuditService audit;
    private final Clock clock;

    public AccountService(UserRepository users, VendorRepository vendors, ShopOrderRepository orders,
                          DeliveryJobRepository jobs, SupportService support, PopupService popups,
                          DeletedAccounts deleted, AuditService audit, Clock clock) {
        this.users = users;
        this.vendors = vendors;
        this.orders = orders;
        this.jobs = jobs;
        this.support = support;
        this.popups = popups;
        this.deleted = deleted;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional
    public Result delete(UUID userId) {
        User user = users.findById(userId).orElseThrow(() -> ApiException.notFound("Account"));
        if (user.hasRole(Role.ADMIN)) {
            throw ApiException.conflict("admin_account", "Admin accounts are removed by another admin.");
        }
        if (vendors.findByOwnerUserId(userId).isPresent()) {
            support.open(userId, Role.VENDOR, new OpenRequest(Topic.ACCOUNT, "Please delete my account",
                    "I asked to delete my Mintadeal account from the app. Please close my shop, settle what is owed "
                            + "and delete my account.", null));
            return new Result(false, "Your shop has orders and payouts to settle, so Mintadeal will close it and "
                    + "delete your account within 7 days. We have opened a help request and will contact you.");
        }
        if (orders.existsByCustomerIdAndStatusIn(userId, EnumSet.of(OrderStatus.PENDING_PAYMENT, OrderStatus.PLACED,
                OrderStatus.ACCEPTED, OrderStatus.READY, OrderStatus.OUT_FOR_DELIVERY))) {
            throw ApiException.conflict("open_orders",
                    "You have orders in progress. Delete your account once they are completed or cancelled.");
        }
        if (jobs.existsByAgentIdAndStatusIn(userId, EnumSet.of(JobStatus.ASSIGNED, JobStatus.PICKED_UP))) {
            throw ApiException.conflict("active_delivery", "Finish your delivery first, then delete your account.");
        }
        popups.stopAllFor(userId);
        user.anonymise(clock.instant());
        deleted.add(userId);
        audit.record("ACCOUNT_DELETED", "USER", userId, null);
        return new Result(true, "Your account has been deleted.");
    }
}
