import 'dart:typed_data';

import '../models/enums.dart';
import '../models/finance.dart';
import '../models/models.dart';
import '../models/orders.dart';
import 'api_client.dart';

/// A customer's location, used for Nearby and distances.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;
}

class AuthResult {
  AuthResult(this.accessToken, this.user);

  final String accessToken;
  final AppUser user;
}

/// Typed access to every Mintadeal endpoint used by the apps.
class MintadealApi {
  MintadealApi(this.client);

  final ApiClient client;

  // --- Auth & profile ---

  Future<void> requestOtp(String phone) => client.post('/api/auth/otp/request', {'phone': phone});

  Future<AuthResult> verifyOtp(String phone, String code) async {
    final j = await client.post('/api/auth/otp/verify', {'phone': phone, 'code': code}) as Json;
    return AuthResult(j['accessToken'] as String, AppUser.fromJson(j['user'] as Json));
  }

  Future<AuthResult> refreshToken() async {
    final j = await client.post('/api/me/token') as Json;
    return AuthResult(j['accessToken'] as String, AppUser.fromJson(j['user'] as Json));
  }

  Future<AppUser> me() async => AppUser.fromJson(await client.get('/api/me') as Json);

  Future<AppUser> updateMe({String? name, String? email}) async =>
      AppUser.fromJson(await client.patch('/api/me', {'name': name, 'email': email}) as Json);

  Future<String> uploadImage(Uint8List bytes, String filename) => client.uploadImage(bytes, filename);

  // --- Discovery (customer) ---

  Future<PageResult<DiscoveryItem>> nearby(GeoPoint at,
      {VendorCategory? category, ListingType? type, String? q, bool followedOnly = false, int page = 0}) async {
    final j = await client.get('/api/discovery/nearby', query: {
      'lat': at.lat,
      'lng': at.lng,
      'category': category?.name,
      'type': type?.name,
      'q': q,
      'followedOnly': followedOnly,
      'page': page,
    }) as Json;
    return PageResult.fromJson(j, DiscoveryItem.fromJson);
  }

  Future<PageResult<DiscoveryItem>> bangalore(
      {GeoPoint? at, VendorCategory? category, ListingType? type, String? q, int page = 0}) async {
    final j = await client.get('/api/discovery/bangalore', query: {
      'lat': at?.lat,
      'lng': at?.lng,
      'category': category?.name,
      'type': type?.name,
      'q': q,
      'page': page,
    }) as Json;
    return PageResult.fromJson(j, DiscoveryItem.fromJson);
  }

  Future<DiscoveryItem> listing(String id, {GeoPoint? at}) async => DiscoveryItem.fromJson(
      await client.get('/api/discovery/listings/$id', query: {'lat': at?.lat, 'lng': at?.lng}) as Json);

  Future<Storefront> storefront(String vendorId, {GeoPoint? at}) async => Storefront.fromJson(
      await client.get('/api/discovery/vendors/$vendorId', query: {'lat': at?.lat, 'lng': at?.lng}) as Json);

  Future<List<VendorPublic>> follows() async =>
      [for (final v in await client.get('/api/customer/follows') as List) VendorPublic.fromJson(v as Json)];

  Future<void> follow(String vendorId) => client.put('/api/customer/follows/$vendorId');

  Future<void> unfollow(String vendorId) => client.delete('/api/customer/follows/$vendorId');

  // --- Vendor ---

  /// The signed-in user's shop, or null if they have not registered one.
  Future<Vendor?> myShop() async {
    try {
      return Vendor(await client.get('/api/vendor/shop') as Json);
    } on ApiError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<Vendor> registerShop(Json profile) async => Vendor(await client.post('/api/vendor/shop', profile) as Json);

  Future<Vendor> updateShop(Json profile) async => Vendor(await client.put('/api/vendor/shop', profile) as Json);

  Future<List<Listing>> myListings() async =>
      [for (final l in await client.get('/api/vendor/listings') as List) Listing.fromJson(l as Json)];

  Future<Listing> createListing(Json listing) async =>
      Listing.fromJson(await client.post('/api/vendor/listings', listing) as Json);

  Future<Listing> updateListing(String id, Json listing) async =>
      Listing.fromJson(await client.put('/api/vendor/listings/$id', listing) as Json);

  Future<Listing> publishListing(String id) async =>
      Listing.fromJson(await client.post('/api/vendor/listings/$id/publish') as Json);

  Future<Listing> pauseListing(String id) async =>
      Listing.fromJson(await client.post('/api/vendor/listings/$id/pause') as Json);

  Future<Listing> updateStock(String id, int? stock) async =>
      Listing.fromJson(await client.put('/api/vendor/listings/$id/stock', {'stock': stock}) as Json);

  // --- Admin ---

  Future<PageResult<Vendor>> adminVendors({VendorStatus? status, int page = 0}) async {
    final j = await client.get('/api/admin/vendors', query: {'status': status?.name, 'page': page}) as Json;
    return PageResult.fromJson(j, Vendor.new);
  }

  Future<VendorDetail> adminVendor(String id) async =>
      VendorDetail.fromJson(await client.get('/api/admin/vendors/$id') as Json);

  Future<Vendor> approveVendor(String id, {String? note}) async =>
      Vendor(await client.post('/api/admin/vendors/$id/approve', {'note': note}) as Json);

  Future<Vendor> rejectVendor(String id, String note) async =>
      Vendor(await client.post('/api/admin/vendors/$id/reject', {'note': note}) as Json);

  Future<Vendor> suspendVendor(String id, String note) async =>
      Vendor(await client.post('/api/admin/vendors/$id/suspend', {'note': note}) as Json);

  Future<Vendor> setVendorType(String id, VendorType type) async =>
      Vendor(await client.put('/api/admin/vendors/$id/type', {'vendorType': type.name}) as Json);

  Future<PageResult<(Listing, String?)>> adminListings({ListingStatus? status, int page = 0}) async {
    final j = await client.get('/api/admin/listings', query: {'status': status?.name, 'page': page}) as Json;
    return PageResult.fromJson(
        j, (i) => (Listing.fromJson(i['listing'] as Json), i['vendorName'] as String?));
  }

  Future<Listing> removeListing(String id, String reason) async =>
      Listing.fromJson(await client.post('/api/admin/listings/$id/remove', {'reason': reason}) as Json);

  Future<AppUser> findUser(String phone) async =>
      AppUser.fromJson(await client.get('/api/admin/users', query: {'phone': phone}) as Json);

  Future<AppUser> setRole(String phone, Role role, {required bool granted}) async => AppUser.fromJson(
      await client.post('/api/admin/users/roles', {'phone': phone, 'role': role.name, 'granted': granted}) as Json);

  // --- Customer orders ---

  Json _cartBody(List<(String, int)> items, Map<String, FulfilmentMode> modes, PaymentMethod? payment,
          DeliveryAddress? address) =>
      {
        'items': [for (final (id, q) in items) {'listingId': id, 'quantity': q}],
        'modes': {for (final e in modes.entries) e.key: e.value.name},
        'paymentMethod': payment?.name,
        'address': address?.toJson(),
      };

  Future<Quote> quote(List<(String, int)> items,
          {Map<String, FulfilmentMode> modes = const {}, PaymentMethod? payment, DeliveryAddress? address}) async =>
      Quote.fromJson(await client.post('/api/customer/checkout/quote', _cartBody(items, modes, payment, address)) as Json);

  Future<CheckoutResult> placeOrder(String clientRequestId, List<(String, int)> items,
          {required Map<String, FulfilmentMode> modes,
          required PaymentMethod payment,
          DeliveryAddress? address,
          String? contactName,
          String? note}) async =>
      CheckoutResult.fromJson(await client.post('/api/customer/checkout', {
        ..._cartBody(items, modes, payment, address),
        'clientRequestId': clientRequestId,
        'contactName': contactName,
        'note': note,
      }) as Json);

  Future<CheckoutResult> checkout(String id) async =>
      CheckoutResult.fromJson(await client.get('/api/customer/checkouts/$id') as Json);

  Future<CheckoutResult> refreshPayment(String checkoutId) async =>
      CheckoutResult.fromJson(await client.post('/api/customer/checkouts/$checkoutId/refresh-payment') as Json);

  Future<PageResult<OrderSummary>> myOrders({int page = 0}) async =>
      PageResult.fromJson(await client.get('/api/customer/orders', query: {'page': page}) as Json, OrderSummary.fromJson);

  Future<OrderDetail> myOrder(String id) async =>
      OrderDetail.fromJson(await client.get('/api/customer/orders/$id') as Json);

  Future<OrderDetail> cancelMyOrder(String id) async =>
      OrderDetail.fromJson(await client.post('/api/customer/orders/$id/cancel') as Json);

  // --- Vendor orders ---

  /// [filter] is one of NEW, ACTIVE, DONE, ALL.
  Future<PageResult<OrderSummary>> shopOrders(String filter, {int page = 0}) async => PageResult.fromJson(
      await client.get('/api/vendor/orders', query: {'filter': filter, 'page': page}) as Json, OrderSummary.fromJson);

  Future<VendorOrderCounts> shopOrderCounts() async =>
      VendorOrderCounts.fromJson(await client.get('/api/vendor/orders/summary') as Json);

  Future<OrderDetail> shopOrder(String id) async =>
      OrderDetail.fromJson(await client.get('/api/vendor/orders/$id') as Json);

  Future<OrderDetail> shopOrderAction(String id, OrderAction action, {String? reason}) async {
    final path = switch (action) {
      OrderAction.ACCEPT => 'accept',
      OrderAction.REJECT => 'reject',
      OrderAction.MARK_READY => 'ready',
      OrderAction.OUT_FOR_DELIVERY => 'out-for-delivery',
      OrderAction.COMPLETE => 'complete',
      _ => throw ArgumentError('Not a shop action: $action'),
    };
    return OrderDetail.fromJson(
        await client.post('/api/vendor/orders/$id/$path', action == OrderAction.REJECT ? {'reason': reason} : null)
            as Json);
  }

  // --- Admin orders and settings ---

  Future<PageResult<OrderSummary>> adminOrders({OrderStatus? status, String? q, int page = 0}) async =>
      PageResult.fromJson(
          await client.get('/api/admin/orders', query: {'status': status?.name, 'q': q, 'page': page}) as Json,
          OrderSummary.fromJson);

  Future<OrderDetail> adminOrder(String id) async =>
      OrderDetail.fromJson(await client.get('/api/admin/orders/$id') as Json);

  Future<OrderDetail> adminCancelOrder(String id, String reason) async =>
      OrderDetail.fromJson(await client.post('/api/admin/orders/$id/cancel', {'reason': reason}) as Json);

  Future<List<IntegrationSettingView>> integrationSettings() async =>
      [for (final s in await client.get('/api/admin/settings') as List) IntegrationSettingView.fromJson(s as Json)];

  /// Blank secret values keep what is stored.
  Future<IntegrationSettingView> saveIntegration(IntegrationProvider provider,
          {required bool enabled, required Map<String, String> config, required Map<String, String> secrets}) async =>
      IntegrationSettingView.fromJson(await client.put('/api/admin/settings/${provider.name}',
          {'enabled': enabled, 'config': config, 'secrets': secrets}) as Json);

  Future<(bool, String)> testIntegration(IntegrationProvider provider, {String? phone}) async {
    final j = await client.post('/api/admin/settings/${provider.name}/test', {'phone': phone}) as Json;
    return (j['ok'] as bool, j['message'] as String);
  }

  // --- Venue offer QR (shop) ---

  Json _codeBody(String? code, String? orderCode, String? phoneLast4) =>
      {'code': code, 'orderCode': orderCode, 'phoneLast4': phoneLast4};

  Future<RedemptionCheck> checkRedemption({String? code, String? orderCode, String? phoneLast4}) async =>
      RedemptionCheck.fromJson(
          await client.post('/api/vendor/redemptions/check', _codeBody(code, orderCode, phoneLast4)) as Json);

  Future<RedemptionCheck> redeem({String? code, String? orderCode, String? phoneLast4}) async =>
      RedemptionCheck.fromJson(
          await client.post('/api/vendor/redemptions/redeem', _codeBody(code, orderCode, phoneLast4)) as Json);

  // --- Partner delivery (shop) ---

  Future<DeliveryCostQuote> deliveryQuote(String orderId) async =>
      DeliveryCostQuote.fromJson(await client.get('/api/vendor/orders/$orderId/delivery/quote') as Json);

  Future<DeliveryCostQuote> requestDelivery(String orderId) async =>
      DeliveryCostQuote.fromJson(await client.post('/api/vendor/orders/$orderId/delivery') as Json);

  Future<void> cancelDelivery(String orderId) => client.post('/api/vendor/orders/$orderId/delivery/cancel');

  Future<ShopCharges> shopCharges() async => ShopCharges.fromJson(await client.get('/api/vendor/charges') as Json);

  // --- Delivery partner app ---

  Future<List<DeliveryJobView>> availableJobs({GeoPoint? at}) async => [
        for (final j in await client.get('/api/delivery/jobs/available', query: {'lat': at?.lat, 'lng': at?.lng}) as List)
          DeliveryJobView.fromJson(j as Json)
      ];

  /// [scope] is ACTIVE or HISTORY.
  Future<List<DeliveryJobView>> myJobs(String scope) async => [
        for (final j in await client.get('/api/delivery/jobs', query: {'scope': scope}) as List)
          DeliveryJobView.fromJson(j as Json)
      ];

  Future<DeliveryJobView> job(String id) async =>
      DeliveryJobView.fromJson(await client.get('/api/delivery/jobs/$id') as Json);

  Future<DeliveryJobView> jobAction(String id, String action, {String? code, String? reason}) async =>
      DeliveryJobView.fromJson(await client.post('/api/delivery/jobs/$id/$action',
          code != null ? {'code': code} : reason != null ? {'reason': reason} : null) as Json);

  // --- Admin delivery ---

  Future<PageResult<DeliveryJobView>> adminJobs({String status = 'ACTIVE', int page = 0}) async => PageResult.fromJson(
      await client.get('/api/admin/delivery/jobs', query: {'status': status, 'page': page}) as Json,
      DeliveryJobView.fromJson);

  Future<DeliveryJobView> adminAssignJob(String id, String phone) async =>
      DeliveryJobView.fromJson(await client.post('/api/admin/delivery/jobs/$id/assign', {'phone': phone}) as Json);

  Future<DeliveryJobView> adminCancelJob(String id, String reason) async =>
      DeliveryJobView.fromJson(await client.post('/api/admin/delivery/jobs/$id/cancel', {'reason': reason}) as Json);

  Future<ShopCharges> adminVendorCharges(String vendorId) async =>
      ShopCharges.fromJson(await client.get('/api/admin/delivery/charges', query: {'vendorId': vendorId}) as Json);

  // --- Money: shop ---

  Future<Earnings> earnings() async => Earnings.fromJson(await client.get('/api/vendor/earnings') as Json);

  // --- Money: admin ---

  Future<FinanceSummary> financeSummary() async =>
      FinanceSummary.fromJson(await client.get('/api/admin/finance/summary') as Json);

  Future<List<VendorBalance>> vendorBalances() async => [
        for (final v in await client.get('/api/admin/finance/vendor-balances') as List) VendorBalance.fromJson(v as Json)
      ];

  Future<CommissionRates> commissionRates() async =>
      CommissionRates.fromJson(await client.get('/api/admin/finance/commission') as Json);

  Future<CommissionRates> saveCommissionRates(CommissionRates rates) async =>
      CommissionRates.fromJson(await client.put('/api/admin/finance/commission', rates.toJson()) as Json);

  Future<PayoutBatchResult> createPayoutBatch() async =>
      PayoutBatchResult.fromJson(await client.post('/api/admin/finance/payouts/batches') as Json);

  /// [status] is OPEN, ALL or a payout status.
  Future<PageResult<PayoutView>> payouts({String status = 'OPEN', int page = 0}) async => PageResult.fromJson(
      await client.get('/api/admin/finance/payouts', query: {'status': status, 'page': page}) as Json,
      PayoutView.fromJson);

  Future<List<PayoutView>> sendPendingPayouts() async => [
        for (final p in await client.post('/api/admin/finance/payouts/send-pending') as List) PayoutView.fromJson(p as Json)
      ];

  Future<PayoutView> payoutAction(String id, String action, {String? utr, String? reason}) async =>
      PayoutView.fromJson(await client.post('/api/admin/finance/payouts/$id/$action',
          utr != null ? {'utr': utr} : reason != null ? {'reason': reason} : null) as Json);

  Future<List<RefundRow>> failedRefunds() async =>
      [for (final r in await client.get('/api/admin/finance/refunds') as List) RefundRow.fromJson(r as Json)];

  Future<RefundRow> retryRefund(String id) async =>
      RefundRow.fromJson(await client.post('/api/admin/finance/refunds/$id/retry') as Json);

  Future<PageResult<NotificationRow>> notificationLog({int page = 0}) async => PageResult.fromJson(
      await client.get('/api/admin/finance/notifications', query: {'page': page}) as Json, NotificationRow.fromJson);
}
