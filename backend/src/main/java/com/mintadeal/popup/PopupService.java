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

import com.mintadeal.admin.AuditService;
import com.mintadeal.common.ApiException;
import com.mintadeal.common.Geo;
import com.mintadeal.common.PageResponse;
import com.mintadeal.files.FileProperties;
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
 * Pop-up stalls. A seller has at most one live stall, at one place, for the days they chose; when it ends customers
 * stop seeing it and it stays as history. Stalls go live straight away, so the rules are checked up front and
 * customers' reports hide a stall until an admin looks at it.
 */
@Service
public class PopupService {

    private final PopupSellerRepository sellers;
    private final PopupRepository popups;
    private final PopupReportRepository reports;
    private final UserRepository users;
    private final PopupProperties props;
    private final AuditService audit;
    private final String filesBase;
    private final Clock clock;

    public PopupService(PopupSellerRepository sellers, PopupRepository popups, PopupReportRepository reports,
                        UserRepository users, PopupProperties props, AuditService audit, FileProperties files,
                        Clock clock) {
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
        MyPopup live = recent.stream().filter(p -> p.status(now) == Status.LIVE).findFirst()
                .map(p -> MyPopup.of(p, now)).orElse(null);
        List<MyPopup> history = recent.stream().filter(p -> p.status(now) != Status.LIVE)
                .map(p -> MyPopup.of(p, now)).toList();
        return new Me(seller == null ? null : seller.getName(), seller != null && seller.isBlocked(),
                seller == null ? null : seller.getBlockedReason(), live, history, props.allowedDays(),
                props.defaultDays(), props.maxItems());
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
        if (seller == null) {
            if (r.name() == null || r.name().isBlank()) {
                throw ApiException.badRequest("name_required", "Tell customers your name or your stall's name");
            }
            seller = sellers.save(new PopupSeller(userId, checkedName(r.name()), now));
        } else if (r.name() != null && !r.name().isBlank()) {
            seller.setName(checkedName(r.name()));
        }
        List<PopupItem> items = checkedItems(r.items());
        open(seller, items, r.latitude(), r.longitude(), r.days(), now);
        return me(userId);
    }

    @Transactional
    public Me again(UUID userId, UUID fromId, double lat, double lng, int days) {
        Popup from = own(userId, fromId);
        if (from.getRemovedAt() != null) {
            throw ApiException.conflict("popup_removed", "Mintadeal took this stall down. Start a new one.");
        }
        PopupSeller seller = sellers.findById(userId).orElseThrow();
        open(seller, List.copyOf(from.getItems()), lat, lng, days, clock.instant());
        return me(userId);
    }

    @Transactional
    public Me move(UUID userId, UUID popupId, double lat, double lng) {
        Popup p = ownLive(userId, popupId);
        checkPlace(lat, lng);
        p.moveTo(lat, lng, clock.instant());
        return me(userId);
    }

    @Transactional
    public Me stop(UUID userId, UUID popupId) {
        ownLive(userId, popupId).stop(clock.instant());
        return me(userId);
    }

    /** Ends the stall of a person deleting their account. */
    @Transactional
    public void stopAllFor(UUID userId) {
        popups.findLive(userId, clock.instant()).ifPresent(p -> p.stop(clock.instant()));
    }

    private void open(PopupSeller seller, List<PopupItem> items, Double lat, Double lng, Integer days, Instant now) {
        if (seller.isBlocked()) {
            throw ApiException.forbidden("seller_blocked",
                    "You cannot open stalls on Mintadeal. Contact Mintadeal support if you think this is a mistake.");
        }
        if (popups.findLive(seller.getUserId(), now).isPresent()) {
            throw ApiException.conflict("popup_live", "You are already selling. Stop that stall first.");
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
        popups.save(new Popup(seller.getUserId(), seller.getName(), lat, lng, days, items, now));
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
                p.getEndsAt());
    }

    private Map<UUID, String> phones(List<Popup> list) {
        Set<UUID> ids = list.stream().map(Popup::getSellerId).collect(Collectors.toSet());
        Map<UUID, String> out = new HashMap<>();
        users.findAllById(ids).forEach(u -> out.put(u.getId(), u.getPhone()));
        return out;
    }

    // --- Admin ---

    public enum AdminFilter { LIVE, REPORTED, ENDED, REMOVED }

    @Transactional(readOnly = true)
    public PageResponse<AdminPopup> adminList(AdminFilter filter, UUID sellerId, int page) {
        Instant now = clock.instant();
        PageRequest pr = PageRequest.of(Math.max(page, 0), 30);
        Page<Popup> found = sellerId != null ? popups.findBySellerIdOrderByCreatedAtDesc(sellerId, pr)
                : switch (filter == null ? AdminFilter.LIVE : filter) {
                    case LIVE -> popups.findAllLive(now, pr);
                    case REPORTED -> popups.findReported(pr);
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
        if (popups.findLive(p.getSellerId(), clock.instant()).filter(x -> !x.getId().equals(id)).isPresent()) {
            throw ApiException.conflict("popup_live", "The seller already has another live stall");
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
        popups.findLive(sellerId, clock.instant()).ifPresent(p -> p.remove(why, clock.instant()));
        audit.record("POPUP_SELLER_BLOCKED", "POPUP_SELLER", sellerId, why);
    }

    @Transactional
    public void unblock(UUID sellerId) {
        sellers.findById(sellerId).orElseThrow(() -> ApiException.notFound("Seller")).unblock();
        audit.record("POPUP_SELLER_UNBLOCKED", "POPUP_SELLER", sellerId, null);
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
                    p.getMovedAt(), n, rs);
        };
    }
}
