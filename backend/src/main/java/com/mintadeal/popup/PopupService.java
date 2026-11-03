package com.mintadeal.popup;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;

import com.mintadeal.admin.AuditService;
import com.mintadeal.common.ApiException;
import com.mintadeal.common.Geo;
import com.mintadeal.common.PageResponse;
import com.mintadeal.files.FileProperties;
import com.mintadeal.finance.Bookkeeping;
import com.mintadeal.order.PaymentGateway;
import com.mintadeal.order.PaymentGateways;
import com.mintadeal.order.PaymentLinkPaidEvent;
import com.mintadeal.popup.PopupDtos.LimitsRequest;
import com.mintadeal.popup.PopupDtos.SellerLimits;
import com.mintadeal.popup.PopupDtos.SettingsDto;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorRepository;
import com.mintadeal.identity.User;
import com.mintadeal.identity.UserRepository;
import com.mintadeal.popup.Popup.Status;
import com.mintadeal.popup.PopupDtos.AdminPopup;
import com.mintadeal.popup.PopupDtos.ItemDto;
import com.mintadeal.popup.PopupDtos.Me;
import com.mintadeal.popup.PopupDtos.MyPopup;
import com.mintadeal.popup.PopupDtos.PublicPopup;
import com.mintadeal.popup.PopupDtos.ReportDto;
import com.mintadeal.popup.PopupDtos.ReportRequest;
import com.mintadeal.popup.PopupDtos.StartRequest;

/**
 * Pop-up stalls. A seller runs as many stalls at once as their limit allows (one by default), each at one place for
 * the days they chose; when a stall ends customers stop seeing it and it stays as history. Stalls go live straight
 * away, so the rules are checked up front and customers' reports hide a stall until an admin looks at it.
 *
 * <p>Approved shops can run stalls too: the stall shows the shop, and any listing fee comes off the shop's balance.
 * Other sellers pay the fee online before the stall goes live.
 */
@Service
public class PopupService {

    private static final Logger log = LoggerFactory.getLogger(PopupService.class);
    /** How long a seller has to pay the fee before the stall is dropped. Razorpay needs at least 15 minutes. */
    private static final Duration PAYMENT_WINDOW = Duration.ofMinutes(30);

    private final PopupSellerRepository sellers;
    private final PopupRepository popups;
    private final PopupReportRepository reports;
    private final UserRepository users;
    private final PopupProperties props;
    private final AuditService audit;
    private final String filesBase;
    private final PopupSettingsRepository settings;
    private final VendorRepository vendors;
    private final PaymentGateways gateways;
    private final Bookkeeping bookkeeping;
    private final Clock clock;

    public PopupService(PopupSellerRepository sellers, PopupRepository popups, PopupReportRepository reports,
                        UserRepository users, PopupProperties props, AuditService audit, FileProperties files,
                        PopupSettingsRepository settings, VendorRepository vendors, PaymentGateways gateways,
                        Bookkeeping bookkeeping, Clock clock) {
        this.settings = settings;
        this.vendors = vendors;
        this.gateways = gateways;
        this.bookkeeping = bookkeeping;
        this.filesBase = files.publicBaseUrl() + "/files/";
        this.sellers = sellers;
        this.popups = popups;
        this.reports = reports;
        this.users = users;
        this.props = props;
        this.audit = audit;
        this.clock = clock;
    }

    // --- Seller ---

    @Transactional(readOnly = true)
    public Me me(UUID userId) {
        Instant now = clock.instant();
        PopupSeller seller = sellers.findById(userId).orElse(null);
        List<Popup> recent = popups.findTop20BySellerIdOrderByCreatedAtDesc(userId);
        List<MyPopup> active = recent.stream().filter(p -> isActive(p, now)).map(p -> MyPopup.of(p, now)).toList();
        List<MyPopup> history = recent.stream().filter(p -> !isActive(p, now))
                .filter(p -> p.getFeeMinor() == 0 || p.getPaidAt() != null)
                .map(p -> MyPopup.of(p, now)).toList();
        Vendor shop = shopOf(userId);
        return new Me(seller == null ? null : seller.getName(), seller != null && seller.isBlocked(),
                seller == null ? null : seller.getBlockedReason(), active, history, props.allowedDays(),
                props.defaultDays(), props.maxItems(), maxLive(seller, shop), feePerDay(seller, shop),
                shop == null ? null : shop.getDisplayName());
    }

    @Transactional
    public Me rename(UUID userId, String name) {
        PopupSeller seller = sellers.findById(userId).orElseThrow(() -> ApiException.notFound("Stall"));
        seller.setName(checkedName(name));
        return me(userId);
    }

    @Transactional
    public Me start(UUID userId, StartRequest r) {
        Instant now = clock.instant();
        PopupSeller seller = sellers.findById(userId).orElse(null);
        Vendor shop = shopOf(userId);
        if (seller == null) {
            String name = r.name() != null && !r.name().isBlank() ? r.name()
                    : shop != null ? shop.getDisplayName() : null;
            if (name == null) {
                throw ApiException.badRequest("name_required", "Tell customers your name or your stall's name");
            }
            seller = sellers.save(new PopupSeller(userId, checkedName(name), now));
        } else if (r.name() != null && !r.name().isBlank()) {
            seller.setName(checkedName(r.name()));
        }
        List<PopupItem> items = checkedItems(r.items());
        open(seller, shop, stallName(r.stallName(), seller), items, r.latitude(), r.longitude(), r.days(), now);
        return me(userId);
    }

    @Transactional
    public Me again(UUID userId, UUID fromId, double lat, double lng, int days, String stallName) {
        Popup from = own(userId, fromId);
        if (from.getRemovedAt() != null) {
            throw ApiException.conflict("popup_removed", "Mintadeal took this stall down. Start a new one.");
        }
        PopupSeller seller = sellers.findById(userId).orElseThrow();
        String name = stallName != null && !stallName.isBlank() ? checkedName(stallName) : from.getSellerName();
        open(seller, shopOf(userId), name, List.copyOf(from.getItems()), lat, lng, days, clock.instant());
        return me(userId);
    }

    /** Asks the payment provider whether the stall's fee was paid, for when the seller comes back from paying. */
    @Transactional
    public Me checkPayment(UUID userId, UUID popupId) {
        Popup p = own(userId, popupId);
        if (p.status(clock.instant()) == Status.PENDING_PAYMENT) {
            PaymentGateway.Status st = gateways.named(p.getPaymentProvider()).fetch(p.getPaymentReference());
            if (st.paid()) {
                markPaid(p, st.paymentId());
            }
        }
        return me(userId);
    }

    @EventListener
    @Transactional
    public void onLinkPaid(PaymentLinkPaidEvent e) {
        popups.findByPaymentReference(e.reference()).ifPresent(p -> markPaid(p, e.paymentId()));
    }

    private void markPaid(Popup p, String paymentId) {
        if (p.getPaidAt() != null || p.getRemovedAt() != null) {
            return;
        }
        p.paid(paymentId, clock.instant());
        bookkeeping.popupFeePaid(p.getId(), "Pop-up stall fee: " + p.getSellerName(), p.getFeeMinor());
        log.info("Pop-up stall {} paid; live for {} days", p.getId(), p.getDays());
    }

    @Transactional
    public Me move(UUID userId, UUID popupId, double lat, double lng) {
        Popup p = ownLive(userId, popupId);
        checkPlace(lat, lng);
        p.moveTo(lat, lng, clock.instant());
        return me(userId);
    }

    /** Stops a live stall, or drops one still waiting for its fee. */
    @Transactional
    public Me stop(UUID userId, UUID popupId) {
        Popup p = own(userId, popupId);
        Status status = p.status(clock.instant());
        if (status != Status.LIVE && status != Status.PENDING_PAYMENT) {
            throw ApiException.conflict("popup_not_live", "This stall has already ended");
        }
        if (status == Status.PENDING_PAYMENT) {
            try {
                gateways.named(p.getPaymentProvider()).cancel(p.getPaymentReference());
            } catch (RuntimeException e) {
                log.warn("Could not cancel the payment link of stall {}: {}", p.getId(), e.getMessage());
            }
        }
        p.stop(clock.instant());
        return me(userId);
    }

    /** Ends the stalls of a person deleting their account. */
    @Transactional
    public void stopAllFor(UUID userId) {
        Instant now = clock.instant();
        popups.findTop20BySellerIdOrderByCreatedAtDesc(userId).stream().filter(p -> isActive(p, now))
                .forEach(p -> p.stop(now));
    }

    private static boolean isActive(Popup p, Instant now) {
        Status s = p.status(now);
        return s == Status.LIVE || s == Status.PENDING_PAYMENT;
    }

    private void open(PopupSeller seller, Vendor shop, String stallName, List<PopupItem> items, Double lat,
                      Double lng, Integer days, Instant now) {
        if (seller.isBlocked()) {
            throw ApiException.forbidden("seller_blocked",
                    "You cannot open stalls on Mintadeal. Contact Mintadeal support if you think this is a mistake.");
        }
        int max = maxLive(seller, shop);
        if (popups.findLive(seller.getUserId(), now).size() + popups.countAwaitingPayment(seller.getUserId(), now)
                >= max) {
            throw ApiException.conflict("popup_live", max == 1
                    ? "You are already selling. Stop that stall first."
                    : "You can run " + max + " stalls at a time. Stop one first.");
        }
        if (popups.countBySellerIdAndCreatedAtAfter(seller.getUserId(), now.minus(Duration.ofDays(1)))
                >= props.maxPerDay()) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "popup_limit",
                    "You started " + props.maxPerDay() + " stalls today. Try again tomorrow.");
        }
        if (days == null || !props.allowedDays().contains(days)) {
            throw ApiException.badRequest("invalid_days", "Choose " + props.allowedDays().stream()
                    .map(String::valueOf).collect(Collectors.joining(", ")) + " days");
        }
        checkPlace(lat, lng);
        Popup p = new Popup(seller.getUserId(), stallName, lat, lng, days, items, now);
        if (shop != null) {
            p.fromShop(shop.getId(), shop.getDisplayName());
        }
        long fee = feePerDay(seller, shop) * days;
        String what = "Pop-up stall " + stallName + ", " + days + (days == 1 ? " day" : " days");
        if (fee > 0 && shop != null) {
            p.chargedToShop(fee, now);
            popups.save(p);
            bookkeeping.popupFeeChargedToShop(p.getId(), shop.getId(), what, fee);
        } else if (fee > 0) {
            PaymentGateway gateway = gateways.active().orElseThrow(() -> ApiException.conflict("payment_unavailable",
                    "Online payment is not set up yet, so paid stalls cannot be opened. Contact Mintadeal."));
            Instant deadline = now.plus(PAYMENT_WINDOW);
            String phone = users.findById(seller.getUserId()).map(u -> u.getPhone()).orElse(null);
            PaymentGateway.Link link = gateway.createLink(fee, "popup_" + p.getId().toString().replace("-", ""),
                    "Mintadeal " + what, seller.getName(), phone, deadline, Map.of("popup_id", p.getId().toString()));
            p.awaitPayment(fee, gateway.name(), link.reference(), link.url(), deadline);
            popups.save(p);
        } else {
            popups.save(p);
        }
    }

    private String stallName(String requested, PopupSeller seller) {
        return requested == null || requested.isBlank() ? seller.getName() : checkedName(requested);
    }

    /** The person's approved shop, if they have one. */
    private Vendor shopOf(UUID userId) {
        return vendors.findByOwnerUserId(userId).filter(Vendor::isApproved).orElse(null);
    }

    private PopupSettings settings() {
        return settings.findById(1).orElseThrow();
    }

    private int maxLive(PopupSeller seller, Vendor shop) {
        if (seller != null && seller.getMaxLive() != null) {
            return seller.getMaxLive();
        }
        return shop != null ? settings().getShopMaxLive() : settings().getSellerMaxLive();
    }

    private long feePerDay(PopupSeller seller, Vendor shop) {
        if (seller != null && seller.getFeePerDayMinor() != null) {
            return seller.getFeePerDayMinor();
        }
        return shop != null ? settings().getShopFeePerDayMinor() : settings().getSellerFeePerDayMinor();
    }

    private static void checkPlace(Double lat, Double lng) {
        if (lat == null || lng == null || !PopupRules.inBengaluru(lat, lng)) {
            throw ApiException.badRequest("outside_city", "Mintadeal is only in Bengaluru for now");
        }
    }

    private static String checkedName(String name) {
        String n = name == null ? "" : name.strip();
        if (n.isEmpty()) {
            throw ApiException.badRequest("name_required", "Tell customers your name or your stall's name");
        }
        String bad = PopupRules.notAllowed(n);
        if (bad != null) {
            throw notAllowed(bad);
        }
        return n;
    }

    private List<PopupItem> checkedItems(List<ItemDto> items) {
        if (items.isEmpty() || items.size() > props.maxItems()) {
            throw ApiException.badRequest("invalid_items", "Add 1 to " + props.maxItems() + " photos");
        }
        return items.stream().map(i -> {
            String title = i.title() == null || i.title().isBlank() ? null : i.title().strip();
            String bad = PopupRules.notAllowed(title);
            if (bad != null) {
                throw notAllowed(bad);
            }
            // Only photos uploaded to Mintadeal, never links to other sites.
            if (!i.imageUrl().startsWith(filesBase)) {
                throw ApiException.badRequest("invalid_photo", "Take or choose the photo in the app");
            }
            return new PopupItem(i.imageUrl(), title, i.priceMinor());
        }).toList();
    }

    private static ApiException notAllowed(String word) {
        return ApiException.badRequest("not_allowed",
                "\"" + word + "\" cannot be sold on Mintadeal stalls. Remove it and try again.");
    }

    private Popup own(UUID userId, UUID popupId) {
        return popups.findById(popupId).filter(p -> p.getSellerId().equals(userId))
                .orElseThrow(() -> ApiException.notFound("Stall"));
    }

    private Popup ownLive(UUID userId, UUID popupId) {
        Popup p = own(userId, popupId);
        if (p.status(clock.instant()) != Status.LIVE) {
            throw ApiException.conflict("popup_not_live", "This stall has already ended");
        }
        return p;
    }

    // --- Customers ---

    @Transactional(readOnly = true)
    public List<PublicPopup> nearby(double lat, double lng) {
        double r = props.nearbyRadiusKm();
        double dLat = r / 111.0;
        double dLng = r / (111.0 * Math.cos(Math.toRadians(lat)));
        List<Popup> found = popups.findLiveIn(lat - dLat, lat + dLat, lng - dLng, lng + dLng, clock.instant());
        Map<UUID, String> phones = phones(found);
        return found.stream()
                .map(p -> toPublic(p, phones.get(p.getSellerId()), Geo.distanceKm(lat, lng, p.getLatitude(),
                        p.getLongitude())))
                .filter(p -> p.distanceKm() <= r)
                .sorted(Comparator.comparing(PublicPopup::distanceKm))
                .limit(50)
                .toList();
    }

    @Transactional(readOnly = true)
    public PublicPopup one(UUID id, Double lat, Double lng) {
        Popup p = popups.findById(id).filter(x -> x.status(clock.instant()) == Status.LIVE)
                .orElseThrow(() -> ApiException.notFound("Stall"));
        Double km = lat == null || lng == null ? null : Geo.distanceKm(lat, lng, p.getLatitude(), p.getLongitude());
        return toPublic(p, phones(List.of(p)).get(p.getSellerId()), km);
    }

    @Transactional
    public void report(UUID popupId, UUID reporterId, ReportRequest r) {
        Instant now = clock.instant();
        Popup p = popups.findById(popupId).orElseThrow(() -> ApiException.notFound("Stall"));
        if (p.getSellerId().equals(reporterId)) {
            throw ApiException.badRequest("own_popup", "You cannot report your own stall");
        }
        if (reports.existsByPopupIdAndReporterId(popupId, reporterId)) {
            return;
        }
        reports.save(new PopupReport(popupId, reporterId, r.reason(),
                r.note() == null || r.note().isBlank() ? null : r.note().strip(), now));
        if (p.status(now) == Status.LIVE && reports.countByPopupId(popupId) >= props.hideAfterReports()) {
            p.remove("Hidden after " + props.hideAfterReports() + " customer reports. Waiting for Mintadeal to check.",
                    now);
            audit.record("POPUP_AUTO_HIDDEN", "POPUP", popupId, null);
        }
    }

    private static PublicPopup toPublic(Popup p, String phone, Double km) {
        return new PublicPopup(p.getId(), p.getSellerName(), phone, p.getItems().stream().map(ItemDto::of).toList(),
                p.getLatitude(), p.getLongitude(), km == null ? null : Math.round(km * 10) / 10.0, p.getStartsAt(),
                p.getEndsAt(), p.getVendorId(), p.getVendorName());
    }

    private Map<UUID, String> phones(List<Popup> list) {
        Set<UUID> ids = list.stream().map(Popup::getSellerId).collect(Collectors.toSet());
        Map<UUID, String> out = new HashMap<>();
        users.findAllById(ids).forEach(u -> out.put(u.getId(), u.getPhone()));
        return out;
    }

    // --- Admin ---

    public enum AdminFilter { LIVE, REPORTED, SHOPS, ENDED, REMOVED }

    @Transactional(readOnly = true)
    public PageResponse<AdminPopup> adminList(AdminFilter filter, UUID sellerId, int page) {
        Instant now = clock.instant();
        PageRequest pr = PageRequest.of(Math.max(page, 0), 30);
        Page<Popup> found = sellerId != null ? popups.findBySellerIdOrderByCreatedAtDesc(sellerId, pr)
                : switch (filter == null ? AdminFilter.LIVE : filter) {
                    case LIVE -> popups.findAllLive(now, pr);
                    case REPORTED -> popups.findReported(pr);
                    case SHOPS -> popups.findFromShops(pr);
                    case ENDED -> popups.findAllEnded(now, pr);
                    case REMOVED -> popups.findByRemovedAtIsNotNullOrderByRemovedAtDesc(pr);
                };
        return PageResponse.of(found, adminView(found.getContent(), now));
    }

    @Transactional
    public AdminPopup remove(UUID id, String reason) {
        Popup p = popups.findById(id).orElseThrow(() -> ApiException.notFound("Stall"));
        String why = reason == null || reason.isBlank() ? "Removed by Mintadeal" : reason.strip();
        p.remove(why, clock.instant());
        audit.record("POPUP_REMOVED", "POPUP", id, why);
        return adminView(List.of(p), clock.instant()).apply(p);
    }

    @Transactional
    public AdminPopup restore(UUID id) {
        Popup p = popups.findById(id).orElseThrow(() -> ApiException.notFound("Stall"));
        PopupSeller seller = sellers.findById(p.getSellerId()).orElseThrow();
        if (seller.isBlocked()) {
            throw ApiException.conflict("seller_blocked", "Unblock the seller first");
        }
        if (popups.findLive(p.getSellerId(), clock.instant()).size()
                >= maxLive(seller, shopOf(p.getSellerId()))) {
            throw ApiException.conflict("popup_live", "The seller already runs as many stalls as allowed");
        }
        p.restore();
        audit.record("POPUP_RESTORED", "POPUP", id, null);
        return adminView(List.of(p), clock.instant()).apply(p);
    }

    /** Blocks a seller: their live stall is taken down and they cannot open new ones. */
    @Transactional
    public void block(UUID sellerId, String reason) {
        PopupSeller seller = sellers.findById(sellerId).orElseThrow(() -> ApiException.notFound("Seller"));
        String why = reason == null || reason.isBlank() ? "Blocked by Mintadeal" : reason.strip();
        seller.block(why);
        popups.findLive(sellerId, clock.instant()).forEach(p -> p.remove(why, clock.instant()));
        audit.record("POPUP_SELLER_BLOCKED", "POPUP_SELLER", sellerId, why);
    }

    @Transactional
    public void unblock(UUID sellerId) {
        sellers.findById(sellerId).orElseThrow(() -> ApiException.notFound("Seller")).unblock();
        audit.record("POPUP_SELLER_UNBLOCKED", "POPUP_SELLER", sellerId, null);
    }

    /** Counts a customer's reaction to a live stall; anything else is ignored, never an error for the customer. */
    @Transactional
    public void react(UUID popupId, PopupDtos.Reaction type) {
        Popup p = popups.findById(popupId).orElse(null);
        if (p == null || p.status(clock.instant()) != Status.LIVE) {
            return;
        }
        switch (type) {
            case VIEW -> popups.countView(popupId);
            case CALL -> popups.countCall(popupId);
            case WHATSAPP -> popups.countWhatsapp(popupId);
            case DIRECTIONS -> popups.countDirections(popupId);
        }
    }

    /** A seller's stalls with their counts, newest first, for an admin to share on request. */
    @Transactional(readOnly = true)
    public PopupDtos.SellerReport report(UUID userId) {
        User user = users.findById(userId).orElseThrow(() -> ApiException.notFound("Person"));
        PopupSeller seller = sellers.findById(userId).orElse(null);
        Vendor shop = shopOf(userId);
        Instant now = clock.instant();
        List<PopupDtos.ReportLine> lines = popups.findTop100BySellerIdOrderByCreatedAtDesc(userId).stream()
                .filter(p -> p.getFeeMinor() == 0 || p.getPaidAt() != null)
                .map(p -> new PopupDtos.ReportLine(p.getId(), p.getSellerName(), p.getLatitude(), p.getLongitude(),
                        p.getDays(), p.getStartsAt(), p.getStoppedAt() != null ? p.getStoppedAt()
                        : p.getRemovedAt() != null ? p.getRemovedAt() : p.getEndsAt(), p.status(now),
                        PopupDtos.Counts.of(p)))
                .toList();
        PopupDtos.Counts total = lines.stream().map(PopupDtos.ReportLine::counts)
                .reduce(new PopupDtos.Counts(0, 0, 0, 0), PopupDtos.Counts::plus);
        return new PopupDtos.SellerReport(userId, seller != null ? seller.getName() : user.getName(), user.getPhone(),
                shop == null ? null : shop.getDisplayName(), lines.size(), total, lines);
    }

    @Transactional(readOnly = true)
    public SettingsDto settingsView() {
        return SettingsDto.of(settings());
    }

    @Transactional
    public SettingsDto updateSettings(SettingsDto r) {
        settings().update(r.shopMaxLive(), r.shopFeePerDayMinor(), r.sellerMaxLive(), r.sellerFeePerDayMinor(),
                clock.instant());
        audit.record("POPUP_SETTINGS_CHANGED", "POPUP_SETTINGS", new UUID(0, 1), r.toString());
        return settingsView();
    }

    @Transactional(readOnly = true)
    public SellerLimits limits(UUID userId) {
        User user = users.findById(userId).orElseThrow(() -> ApiException.notFound("Person"));
        PopupSeller seller = sellers.findById(userId).orElse(null);
        Vendor shop = shopOf(userId);
        return new SellerLimits(userId, seller != null ? seller.getName()
                : shop != null ? shop.getDisplayName() : user.getName(), user.getPhone(),
                shop == null ? null : shop.getDisplayName(), seller == null ? null : seller.getMaxLive(),
                seller == null ? null : seller.getFeePerDayMinor(), maxLive(seller, shop), feePerDay(seller, shop));
    }

    /** Sets one seller's limits; a shop owner who never opened a stall gets a seller record named after the shop. */
    @Transactional
    public SellerLimits setLimits(UUID userId, LimitsRequest r) {
        User user = users.findById(userId).orElseThrow(() -> ApiException.notFound("Person"));
        PopupSeller seller = sellers.findById(userId).orElseGet(() -> {
            Vendor shop = vendors.findByOwnerUserId(userId).orElse(null);
            String name = shop != null ? shop.getDisplayName() : user.getName() != null ? user.getName() : user.getPhone();
            return sellers.save(new PopupSeller(userId, name, clock.instant()));
        });
        seller.setLimits(r.maxLive(), r.feePerDayMinor());
        audit.record("POPUP_LIMITS_CHANGED", "POPUP_SELLER", userId, r.toString());
        return limits(userId);
    }

    @Transactional(readOnly = true)
    public long liveReportedCount() {
        return reports.countLiveReported(clock.instant());
    }

    private Function<Popup, AdminPopup> adminView(List<Popup> list, Instant now) {
        Map<UUID, Long> counts = new HashMap<>();
        if (!list.isEmpty()) {
            for (Object[] row : reports.countByPopupIds(list.stream().map(Popup::getId).toList())) {
                counts.put((UUID) row[0], (Long) row[1]);
            }
        }
        Map<UUID, String> phones = phones(list);
        Map<UUID, Boolean> blocked = new HashMap<>();
        sellers.findAllById(list.stream().map(Popup::getSellerId).collect(Collectors.toSet()))
                .forEach(s -> blocked.put(s.getUserId(), s.isBlocked()));
        return p -> {
            long n = counts.getOrDefault(p.getId(), 0L);
            List<ReportDto> rs = n == 0 ? List.of()
                    : reports.findByPopupIdOrderByCreatedAtDesc(p.getId()).stream().map(ReportDto::of).toList();
            return new AdminPopup(p.getId(), p.getSellerId(), p.getSellerName(), phones.get(p.getSellerId()),
                    blocked.getOrDefault(p.getSellerId(), false), p.status(now),
                    p.getItems().stream().map(ItemDto::of).toList(), p.getLatitude(), p.getLongitude(), p.getDays(),
                    p.getStartsAt(), p.getEndsAt(), p.getStoppedAt(), p.getRemovedAt(), p.getRemovedReason(),
                    p.getMovedAt(), n, rs, p.getVendorId(), p.getVendorName(), p.getFeeMinor(),
                    p.getPaymentProvider(), p.getPaidAt(), PopupDtos.Counts.of(p));
        };
    }
}
