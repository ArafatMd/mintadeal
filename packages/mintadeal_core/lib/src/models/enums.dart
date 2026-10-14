// Enum values mirror the API exactly.
// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

enum Role {
  CUSTOMER,
  VENDOR,
  DELIVERY_AGENT,
  ADMIN;

  static Role parse(Object? s) => _byName(values, s, CUSTOMER);
}

enum VendorCategory {
  GROCERY('Grocery', Icons.local_grocery_store_outlined),
  MEAT_FISH('Meat & fish', Icons.set_meal_outlined),
  BAKERY('Bakery', Icons.bakery_dining_outlined),
  CLOTHING('Clothing', Icons.checkroom_outlined),
  ELECTRONICS('Electronics', Icons.devices_other_outlined),
  FURNITURE('Furniture', Icons.chair_outlined),
  HARDWARE('Hardware', Icons.hardware_outlined),
  RESTAURANT('Restaurant', Icons.restaurant_outlined),
  HOTEL('Hotel', Icons.hotel_outlined),
  SALON_SPA('Salon & spa', Icons.content_cut_outlined),
  FITNESS('Fitness', Icons.fitness_center_outlined),
  SERVICES('Services', Icons.handyman_outlined),
  EVENTS('Events', Icons.event_outlined),
  OTHER('Other', Icons.storefront_outlined);

  const VendorCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  static VendorCategory parse(Object? s) => _byName(values, s, OTHER);
}

enum VendorStatus {
  PENDING('Pending review'),
  APPROVED('Approved'),
  REJECTED('Rejected'),
  SUSPENDED('Suspended');

  const VendorStatus(this.label);

  final String label;

  static VendorStatus parse(Object? s) => _byName(values, s, PENDING);
}

enum VendorType {
  EXTERNAL('External shop'),
  INTERNAL('Mintadeal own catalogue');

  const VendorType(this.label);

  final String label;

  static VendorType parse(Object? s) => _byName(values, s, EXTERNAL);
}

enum ListingType {
  PRODUCT('Product'),
  OFFER('Offer at venue');

  const ListingType(this.label);

  final String label;

  static ListingType parse(Object? s) => _byName(values, s, PRODUCT);
}

enum ListingStatus {
  DRAFT('Draft'),
  ACTIVE('Live'),
  PAUSED('Paused'),
  REMOVED('Removed by Mintadeal');

  const ListingStatus(this.label);

  final String label;

  static ListingStatus parse(Object? s) => _byName(values, s, DRAFT);
}

enum FulfilmentMode {
  SHOP_DELIVERY('Shop delivers', Icons.delivery_dining_outlined),
  PARTNER_DELIVERY('Delivery partner', Icons.local_shipping_outlined),
  PICKUP('Pickup at shop', Icons.storefront_outlined),
  VENUE_QR('Use at venue (QR)', Icons.qr_code_2);

  const FulfilmentMode(this.label, this.icon);

  final String label;
  final IconData icon;

  bool get isDelivery => this == SHOP_DELIVERY || this == PARTNER_DELIVERY;

  static FulfilmentMode parse(Object? s) => _byName(values, s, PICKUP);
}

enum PaymentMethod {
  ONLINE('Pay online (UPI, card)'),
  PAY_ON_DELIVERY('Pay on delivery or pickup');

  const PaymentMethod(this.label);

  final String label;

  static PaymentMethod parse(Object? s) => _byName(values, s, PAY_ON_DELIVERY);
}

enum PaymentStatus {
  NOT_REQUIRED('Pay on delivery'),
  PENDING('Waiting for payment'),
  PAID('Paid'),
  EXPIRED('Payment expired'),
  CANCELLED('Cancelled');

  const PaymentStatus(this.label);

  final String label;

  static PaymentStatus parse(Object? s) => _byName(values, s, NOT_REQUIRED);
}

enum OrderStatus {
  PENDING_PAYMENT('Waiting for payment'),
  PLACED('Waiting for the shop'),
  ACCEPTED('Accepted'),
  READY('Ready for pickup'),
  OUT_FOR_DELIVERY('Out for delivery'),
  COMPLETED('Completed'),
  CANCELLED('Cancelled');

  const OrderStatus(this.label);

  final String label;

  bool get isOpen => this != COMPLETED && this != CANCELLED;

  static OrderStatus parse(Object? s) => _byName(values, s, PLACED);
}

enum OrderAction {
  PAY('Pay now'),
  CANCEL('Cancel order'),
  ACCEPT('Accept'),
  REJECT('Reject'),
  MARK_READY('Mark ready for pickup'),
  OUT_FOR_DELIVERY('Out for delivery'),
  COMPLETE('Complete'),
  REDEEM('Scan QR code'),
  REQUEST_DELIVERY('Book delivery partner'),
  CANCEL_DELIVERY('Cancel delivery partner');

  const OrderAction(this.label);

  final String label;

  static OrderAction parse(Object? s) => _byName(values, s, CANCEL);
}

enum RefundStatus {
  PENDING('Refund pending'),
  PROCESSED('Refunded'),
  FAILED('Refund failed, Mintadeal will retry');

  const RefundStatus(this.label);

  final String label;

  static RefundStatus parse(Object? s) => _byName(values, s, PENDING);
}

enum IntegrationProvider {
  RAZORPAY('Razorpay', 'Online payments'),
  TWO_FACTOR('2Factor', 'SMS sign-in codes'),
  RAZORPAYX('RazorpayX', 'Automatic payouts to shops'),
  WHATSAPP('WhatsApp', 'Order alerts to shops and customers');

  const IntegrationProvider(this.label, this.purpose);

  final String label;
  final String purpose;

  static IntegrationProvider parse(Object? s) => _byName(values, s, RAZORPAY);
}

enum JobStatus {
  REQUESTED('Waiting for a rider'),
  ASSIGNED('Rider on the way to the shop'),
  PICKED_UP('Out for delivery'),
  DELIVERED('Delivered'),
  FAILED('Delivery failed'),
  CANCELLED('Cancelled');

  const JobStatus(this.label);

  final String label;

  bool get isActive => this == REQUESTED || this == ASSIGNED || this == PICKED_UP;

  static JobStatus parse(Object? s) => _byName(values, s, REQUESTED);
}

enum PayoutStatus {
  PENDING('Ready to send'),
  PROCESSING('On its way'),
  PAID('Paid'),
  FAILED('Failed'),
  CANCELLED('Cancelled');

  const PayoutStatus(this.label);

  final String label;

  static PayoutStatus parse(Object? s) => _byName(values, s, PENDING);
}

/// Why a shop card stands out; shown as a small coloured pill.
enum ShopTag {
  ENDS_TODAY('Ends today'),
  NEW('New deals'),
  FREE_DELIVERY('Free delivery'),
  VENUE_OFFER('Venue offer'),
  DELIVERY('Delivers to you'),
  PICKUP('Pickup');

  const ShopTag(this.label);

  final String label;

  static ShopTag parse(Object? s) => ShopTag.values.firstWhere((t) => t.name == s, orElse: () => PICKUP);
}

/// What tapping a home banner opens.
enum BannerTarget {
  NONE('Nothing'),
  CATEGORY('A category'),
  SHOP('A shop'),
  LISTING('A product or offer');

  const BannerTarget(this.label);

  final String label;

  static BannerTarget parse(Object? s) => _byName(values, s, NONE);
}

/// Which home view shows a banner.
enum BannerScope {
  NEARBY('Nearby'),
  CITYWIDE('All Bengaluru'),
  BOTH('Both');

  const BannerScope(this.label);

  final String label;

  static BannerScope parse(Object? s) => _byName(values, s, BOTH);
}

enum TicketTopic {
  ORDER('An order'),
  PAYMENT_REFUND('Payment or refund'),
  DELIVERY('Delivery'),
  ACCOUNT('My account'),
  SHOP_LISTING('My shop or listings'),
  PAYOUT('Payouts'),
  OTHER('Something else');

  const TicketTopic(this.label);

  final String label;

  static TicketTopic parse(Object? s) => _byName(values, s, OTHER);
}

enum TicketStatus {
  OPEN('Waiting for us'),
  ANSWERED('Replied'),
  CLOSED('Closed');

  const TicketStatus(this.label);

  final String label;

  static TicketStatus parse(Object? s) => _byName(values, s, OPEN);
}
