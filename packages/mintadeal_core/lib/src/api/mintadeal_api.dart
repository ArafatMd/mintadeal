import 'dart:typed_data';

import '../models/enums.dart';
import '../models/models.dart';
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
}
