package com.mintadeal.order;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mintadeal.catalogue.FulfilmentMode;
import com.mintadeal.catalogue.Listing;
import com.mintadeal.catalogue.ListingRepository;
import com.mintadeal.catalogue.ListingStatus;
import com.mintadeal.catalogue.ListingType;
import com.mintadeal.common.ApiException;
import com.mintadeal.common.Geo;
import com.mintadeal.finance.CommissionService;
import com.mintadeal.identity.User;
import com.mintadeal.identity.UserRepository;
import com.mintadeal.order.CheckoutDtos.Address;
import com.mintadeal.order.CheckoutDtos.CartItem;
import com.mintadeal.order.CheckoutDtos.CheckoutDto;
import com.mintadeal.order.CheckoutDtos.PlaceRequest;
import com.mintadeal.order.CheckoutDtos.Quote;
import com.mintadeal.order.CheckoutDtos.QuoteGroup;
import com.mintadeal.order.CheckoutDtos.QuoteLine;
import com.mintadeal.order.CheckoutDtos.QuoteRequest;
import com.mintadeal.order.CheckoutDtos.VendorRef;
import com.mintadeal.vendor.Vendor;
import com.mintadeal.vendor.VendorRepository;

/**
 * Turns a cart into shop orders. The same rules produce the quote the customer sees and the orders that are
 * placed, so the cart screen never promises something checkout would refuse.
 */
@Service
public class CheckoutService {

    private record PlannedLine(Listing listing, int quantity, String problem) {
    }

    private record PlannedGroup(String key, Vendor vendor, ListingType kind, List<PlannedLine> lines,
                                List<FulfilmentMode> available, FulfilmentMode selected, long itemsTotal,
                                long deliveryFee, List<String> problems) {
    }

    private record Plan(List<PlannedGroup> groups, List<String> problems, boolean addressRequired,
                        boolean onlineAvailable, boolean payOnDeliveryAllowed) {

        boolean canPlace() {
            return problems.isEmpty() && groups.stream().allMatch(g -> g.problems().isEmpty());
        }

        String firstProblem() {
            return problems.isEmpty()
                    ? groups.stream().flatMap(g -> g.problems().stream()).findFirst().orElse("")
                    : problems.getFirst();
        }
    }

    private final ListingRepository listings;
    private final VendorRepository vendors;
    private final UserRepository users;
    private final CheckoutRepository checkouts;
    private final ShopOrderRepository orders;
    private final OrderEventRepository events;
    private final PaymentGateways gateways;
    private final OrderViews views;
    private final OrderProperties props;
    private final CommissionService commission;
    private final ApplicationEventPublisher publisher;
    private final Clock clock;

    public CheckoutService(ListingRepository listings, VendorRepository vendors, UserRepository users,
                           CheckoutRepository checkouts, ShopOrderRepository orders, OrderEventRepository events,
                           PaymentGateways gateways, OrderViews views, OrderProperties props,
                           CommissionService commission, ApplicationEventPublisher publisher, Clock clock) {
        this.commission = commission;
        this.publisher = publisher;
        this.listings = listings;
        this.vendors = vendors;
        this.users = users;
        this.checkouts = checkouts;
        this.orders = orders;
        this.events = events;
        this.gateways = gateways;
        this.views = views;
        this.props = props;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public Quote quote(QuoteRequest req) {
        Plan plan = plan(req);
        List<QuoteGroup> groups = plan.groups().stream().map(CheckoutService::toQuoteGroup).toList();
        long items = groups.stream().mapToLong(QuoteGroup::itemsTotalMinor).sum();
        long delivery = groups.stream().mapToLong(QuoteGroup::deliveryFeeMinor).sum();
        return new Quote(groups, items, delivery, items + delivery, plan.onlineAvailable(),
                plan.payOnDeliveryAllowed(), plan.addressRequired(), plan.problems(), plan.canPlace());
    }

    @Transactional
    public CheckoutDto place(UUID customerId, PlaceRequest req) {
        var existing = checkouts.findByCustomerIdAndClientRequestId(customerId, req.clientRequestId());
        if (existing.isPresent()) {
            // The app retried a request that already went through: return the same checkout, place nothing twice.
            return views.checkout(existing.get());
        }
        Plan plan = plan(req.quote());
        if (!plan.canPlace()) {
            throw ApiException.badRequest("cannot_place", plan.firstProblem());
        }
        User customer = users.findById(customerId).orElseThrow(() -> ApiException.notFound("User"));
        Instant now = clock.instant();

        String code;
        do {
            code = OrderCodes.next();
        } while (checkouts.existsByCode(code));
        Checkout checkout = new Checkout(code, customerId, req.clientRequestId(), req.paymentMethod(), now);
        String name = req.contactName() != null && !req.contactName().isBlank()
                ? req.contactName().trim() : customer.getName();
        checkout.setContact(name, customer.getPhone());
        if (plan.addressRequired()) {
            Address a = req.address();
            checkout.setAddress(a.line().trim(), a.area().trim(), blankToNull(a.landmark()), a.latitude(),
                    a.longitude());
        }
        checkout.setNote(blankToNull(req.note()));
        long items = plan.groups().stream().mapToLong(PlannedGroup::itemsTotal).sum();
        long delivery = plan.groups().stream().mapToLong(PlannedGroup::deliveryFee).sum();
        checkout.setTotals(items, delivery);
        checkouts.save(checkout);

        boolean online = req.paymentMethod() == PaymentMethod.ONLINE;
        int index = 1;
        for (PlannedGroup g : plan.groups()) {
            OrderStatus initial = online ? OrderStatus.PENDING_PAYMENT : OrderStatus.PLACED;
            ShopOrder order = new ShopOrder(checkout, index++, g.vendor().getId(), g.vendor().getDisplayName(),
                    g.selected(), initial, now);
            for (PlannedLine line : g.lines()) {
                Listing l = line.listing();
                order.addLine(l.getId(), l.getListingType(), l.getTitle(), l.getImageUrl(), l.effectivePriceMinor(),
                        l.getPriceMinor(), line.quantity());
                // Reserve stock now; it is put back if the order is cancelled or never paid.
                if (l.getStock() != null) {
                    l.setStock(l.getStock() - line.quantity());
                }
            }
            order.setDeliveryFeeMinor(g.deliveryFee());
            order.setCommissionBps(commission.rateFor(g.vendor()));
            if (!online) {
                order.awaitAcceptance(now.plus(props.acceptTimeout()));
            }
            orders.save(order);
            events.save(new OrderEvent(order.getId(), initial, ActorType.CUSTOMER, customerId,
                    online ? "Waiting for online payment" : "Order placed, pay on " + payOnWhat(g.selected()), now));
            publisher.publishEvent(new OrderStatusEvent(order.getId(), initial, ActorType.CUSTOMER));
        }

        if (online) {
            PaymentGateway gateway = gateways.require();
            Instant deadline = now.plus(props.paymentTimeout());
            PaymentGateway.Link link = gateway.create(checkout, deadline);
            checkout.attachPaymentLink(gateway.name(), link.reference(), link.url(), deadline);
        }
        return views.checkout(checkout);
    }

    private static String payOnWhat(FulfilmentMode mode) {
        return mode == FulfilmentMode.PICKUP ? "pickup" : "delivery";
    }

    private Plan plan(QuoteRequest req) {
        Instant now = clock.instant();
        // Merge repeated items so stock and quantity limits apply to the total.
        Map<UUID, Integer> quantities = new LinkedHashMap<>();
        for (CartItem item : req.items()) {
            quantities.merge(item.listingId(), item.quantity(), Integer::sum);
        }
        Map<UUID, Listing> byId = listings.findAllById(quantities.keySet()).stream()
                .collect(Collectors.toMap(Listing::getId, Function.identity()));
        Map<UUID, Vendor> vendorsById = vendors.findAllById(
                        byId.values().stream().map(Listing::getVendorId).collect(Collectors.toSet())).stream()
                .collect(Collectors.toMap(Vendor::getId, Function.identity()));

        List<String> problems = new ArrayList<>();
        Map<String, List<PlannedLine>> grouped = new LinkedHashMap<>();
        for (var entry : quantities.entrySet()) {
            Listing l = byId.get(entry.getKey());
            Vendor v = l == null ? null : vendorsById.get(l.getVendorId());
            if (l == null || v == null) {
                problems.add("An item in your cart no longer exists. Remove it to continue.");
                continue;
            }
            grouped.computeIfAbsent(v.getId() + ":" + l.getListingType(), k -> new ArrayList<>())
                    .add(new PlannedLine(l, entry.getValue(), lineProblem(l, v, entry.getValue(), now)));
        }

        Address address = req.address();
        List<PlannedGroup> groups = new ArrayList<>();
        for (var entry : grouped.entrySet()) {
            List<PlannedLine> lines = entry.getValue();
            Listing first = lines.getFirst().listing();
            Vendor vendor = vendorsById.get(first.getVendorId());
            groups.add(group(entry.getKey(), vendor, first.getListingType(), lines, address,
                    req.modes() == null ? null : req.modes().get(entry.getKey())));
        }

        boolean addressRequired = groups.stream().anyMatch(g -> g.selected() != null && g.selected().isDelivery());
        if (addressRequired && address == null) {
            problems.add("Add a delivery address");
        }
        boolean onlineAvailable = gateways.active().isPresent();
        boolean podAllowed = groups.stream().noneMatch(g -> g.kind() == ListingType.OFFER);
        if (req.paymentMethod() == PaymentMethod.ONLINE && !onlineAvailable) {
            problems.add("Online payment is not available yet. Choose pay on delivery or pickup.");
        }
        if (req.paymentMethod() == PaymentMethod.PAY_ON_DELIVERY && !podAllowed) {
            problems.add("Venue offers must be paid online");
        }
        return new Plan(groups, problems, addressRequired, onlineAvailable, podAllowed);
    }

    private String lineProblem(Listing l, Vendor v, int quantity, Instant now) {
        if (!v.isApproved() || l.getStatus() != ListingStatus.ACTIVE) {
            return "No longer available";
        }
        if (l.getValidTo() != null && !l.getValidTo().isAfter(now)) {
            return "This offer has ended";
        }
        if (l.getValidFrom() != null && l.getValidFrom().isAfter(now)) {
            return "This offer has not started yet";
        }
        if (l.getStock() != null && l.getStock() <= 0) {
            return "Out of stock";
        }
        if (quantity > props.maxQuantity()) {
            return "You can order at most " + props.maxQuantity();
        }
        if (l.getStock() != null && quantity > l.getStock()) {
            return "Only " + l.getStock() + " left";
        }
        return null;
    }

    private PlannedGroup group(String key, Vendor vendor, ListingType kind, List<PlannedLine> lines,
                               Address address, FulfilmentMode requested) {
        List<String> problems = new ArrayList<>();
        lines.stream().filter(l -> l.problem() != null)
                .forEach(l -> problems.add(l.listing().getTitle() + ": " + l.problem()));

        // Ways every item in the group can be fulfilled, limited by what the shop offers.
        Set<FulfilmentMode> modes = EnumSet.allOf(FulfilmentMode.class);
        lines.forEach(l -> modes.retainAll(l.listing().getFulfilmentModes()));
        if (!vendor.isSelfDelivery()) {
            modes.remove(FulfilmentMode.SHOP_DELIVERY);
        }
        if (!vendor.isPartnerDelivery()) {
            modes.remove(FulfilmentMode.PARTNER_DELIVERY);
        }
        if (!vendor.isPickup()) {
            modes.remove(FulfilmentMode.PICKUP);
        }
        boolean hadDelivery = modes.stream().anyMatch(FulfilmentMode::isDelivery);
        if (address != null && hadDelivery) {
            double km = Geo.distanceKm(address.latitude(), address.longitude(), vendor.getLatitude(),
                    vendor.getLongitude());
            if (!vendor.deliversTo(km)) {
                modes.removeIf(FulfilmentMode::isDelivery);
            }
        }
        List<FulfilmentMode> available = List.copyOf(modes);
        FulfilmentMode selected = requested != null && modes.contains(requested) ? requested
                : available.isEmpty() ? null : available.getFirst();
        if (selected == null) {
            problems.add(hadDelivery
                    ? vendor.getDisplayName() + " does not deliver to your address"
                    : "These items from " + vendor.getDisplayName() + " cannot be ordered together. "
                            + "Order them separately.");
        }

        long itemsTotal = lines.stream().mapToLong(l -> l.listing().effectivePriceMinor() * l.quantity()).sum();
        long fee = selected != null && selected.isDelivery() ? vendor.getDeliveryFeeMinor() : 0;
        if (selected != null && selected.isDelivery() && itemsTotal < vendor.getMinOrderMinor()) {
            problems.add("Minimum order for delivery from " + vendor.getDisplayName() + " is "
                    + OrderCodes.rupees(vendor.getMinOrderMinor()));
        }
        return new PlannedGroup(key, vendor, kind, lines, available, selected, itemsTotal, fee, problems);
    }

    private static QuoteGroup toQuoteGroup(PlannedGroup g) {
        Vendor v = g.vendor();
        List<QuoteLine> lines = g.lines().stream().map(pl -> {
            Listing l = pl.listing();
            return new QuoteLine(l.getId(), l.getListingType(), l.getTitle(), l.getImageUrl(), l.effectivePriceMinor(),
                    l.getPriceMinor(), pl.quantity(), l.effectivePriceMinor() * pl.quantity(), l.getStock(),
                    pl.problem());
        }).toList();
        return new QuoteGroup(g.key(), new VendorRef(v.getId(), v.getDisplayName(), v.getArea(), v.getLogoUrl(),
                v.getPhone()), g.kind(), lines, g.available(), g.selected(), g.itemsTotal(), g.deliveryFee(),
                g.itemsTotal() + g.deliveryFee(), v.getMinOrderMinor(), g.problems());
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
