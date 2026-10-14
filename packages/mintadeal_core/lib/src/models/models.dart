import 'enums.dart';
import '../util/money.dart';

typedef Json = Map<String, dynamic>;

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

int? _int(Object? v) => (v as num?)?.toInt();

double? _double(Object? v) => (v as num?)?.toDouble();

class AppUser {
  AppUser({required this.id, required this.phone, this.name, this.email, this.avatarUrl, required this.roles});

  factory AppUser.fromJson(Json j) => AppUser(
        id: j['id'] as String,
        phone: j['phone'] as String,
        name: j['name'] as String?,
        email: j['email'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        roles: [for (final r in j['roles'] as List) Role.parse(r)],
      );

  final String id;
  final String phone;
  final String? name;
  final String? email;

  /// Profile photo, or null to show initials.
  final String? avatarUrl;
  final List<Role> roles;

  bool has(Role role) => roles.contains(role);

  Json toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'roles': [for (final r in roles) r.name],
      };
}

class PageResult<T> {
  PageResult({required this.items, required this.page, required this.size, required this.total});

  factory PageResult.fromJson(Json j, T Function(Json) item) => PageResult(
        items: [for (final i in j['items'] as List) item(i as Json)],
        page: j['page'] as int,
        size: j['size'] as int,
        total: _int(j['total'])!,
      );

  final List<T> items;
  final int page;
  final int size;
  final int total;

  bool get hasMore => (page + 1) * size < total;
}

/// A shop as its owner and admins see it.
class Vendor {
  Vendor(this.json)
      : id = json['id'] as String,
        displayName = json['displayName'] as String,
        category = VendorCategory.parse(json['category']),
        vendorType = VendorType.parse(json['vendorType']),
        status = VendorStatus.parse(json['status']),
        phone = json['phone'] as String,
        area = json['area'] as String,
        addressLine = json['addressLine'] as String,
        reviewNote = json['reviewNote'] as String?,
        createdAt = _date(json['createdAt'])!;

  /// The raw fields, used to pre-fill the shop settings form.
  final Json json;
  final String id;
  final String displayName;
  final VendorCategory category;
  final VendorType vendorType;
  final VendorStatus status;
  final String phone;
  final String area;
  final String addressLine;
  final String? reviewNote;
  final DateTime createdAt;

  bool get selfDelivery => json['selfDelivery'] as bool;
  bool get partnerDelivery => json['partnerDelivery'] as bool;
  bool get pickup => json['pickup'] as bool;
  bool get citywideDelivery => json['citywideDelivery'] as bool;
}

/// A shop as customers see it on a storefront.
class VendorPublic {
  VendorPublic.fromJson(Json j)
      : id = j['id'] as String,
        displayName = j['displayName'] as String,
        category = VendorCategory.parse(j['category']),
        description = j['description'] as String?,
        phone = j['phone'] as String,
        addressLine = j['addressLine'] as String,
        area = j['area'] as String,
        openingHours = j['openingHours'] as String?,
        logoUrl = j['logoUrl'] as String?,
        coverUrl = j['coverUrl'] as String?,
        selfDelivery = j['selfDelivery'] as bool,
        partnerDelivery = j['partnerDelivery'] as bool,
        pickup = j['pickup'] as bool,
        citywideDelivery = j['citywideDelivery'] as bool,
        deliveryRadiusKm = _double(j['deliveryRadiusKm']) ?? 0,
        deliveryFeeMinor = _int(j['deliveryFeeMinor']) ?? 0,
        minOrderMinor = _int(j['minOrderMinor']) ?? 0,
        mintadealOwn = j['mintadealOwn'] as bool? ?? false;

  final String id;
  final String displayName;
  final VendorCategory category;
  final String? description;
  final String phone;
  final String addressLine;
  final String area;
  final String? openingHours;
  final String? logoUrl;

  /// The shop's banner photo for its card and storefront.
  final String? coverUrl;
  final bool selfDelivery;
  final bool partnerDelivery;
  final bool pickup;
  final bool citywideDelivery;
  final double deliveryRadiusKm;
  final int deliveryFeeMinor;
  final int minOrderMinor;
  final bool mintadealOwn;
}

class VendorSummary {
  VendorSummary.fromJson(Json j)
      : id = j['id'] as String,
        displayName = j['displayName'] as String,
        category = VendorCategory.parse(j['category']),
        area = j['area'] as String,
        logoUrl = j['logoUrl'] as String?,
        mintadealOwn = j['mintadealOwn'] as bool? ?? false;

  final String id;
  final String displayName;
  final VendorCategory category;
  final String area;
  final String? logoUrl;
  final bool mintadealOwn;
}

class Listing {
  Listing.fromJson(Json j)
      : id = j['id'] as String,
        vendorId = j['vendorId'] as String,
        listingType = ListingType.parse(j['listingType']),
        title = j['title'] as String,
        description = j['description'] as String?,
        category = VendorCategory.parse(j['category']),
        imageUrl = j['imageUrl'] as String?,
        priceMinor = _int(j['priceMinor'])!,
        offerPriceMinor = _int(j['offerPriceMinor']),
        discountPercent = _int(j['discountPercent']),
        stock = _int(j['stock']),
        capacityPerSlot = _int(j['capacityPerSlot']),
        terms = j['terms'] as String?,
        validFrom = _date(j['validFrom']),
        validTo = _date(j['validTo']),
        status = ListingStatus.parse(j['status']),
        removedReason = j['removedReason'] as String?,
        fulfilmentModes = [for (final m in j['fulfilmentModes'] as List) FulfilmentMode.parse(m)],
        updatedAt = _date(j['updatedAt'])!;

  final String id;
  final String vendorId;
  final ListingType listingType;
  final String title;
  final String? description;
  final VendorCategory category;
  final String? imageUrl;
  final int priceMinor;
  final int? offerPriceMinor;
  final int? discountPercent;
  final int? stock;
  final int? capacityPerSlot;
  final String? terms;
  final DateTime? validFrom;
  final DateTime? validTo;
  final ListingStatus status;
  final String? removedReason;
  final List<FulfilmentMode> fulfilmentModes;
  final DateTime updatedAt;

  int get effectivePriceMinor => offerPriceMinor ?? priceMinor;
}

/// A listing as seen by a particular customer: how it can reach them and how far away it is.
class DiscoveryItem {
  DiscoveryItem.fromJson(Json j)
      : listing = Listing.fromJson(j['listing'] as Json),
        vendor = VendorSummary.fromJson(j['vendor'] as Json),
        distanceKm = _double(j['distanceKm']),
        deliverable = j['deliverable'] as bool,
        pickupAvailable = j['pickupAvailable'] as bool,
        venueOffer = j['venueOffer'] as bool,
        deliveryFeeMinor = _int(j['deliveryFeeMinor']),
        followed = j['followed'] as bool,
        roadKm = _double(j['roadKm']),
        roadMinutes = _int(j['roadMinutes']);

  final Listing listing;
  final VendorSummary vendor;
  final double? distanceKm;
  final bool deliverable;
  final bool pickupAvailable;
  final bool venueOffer;
  final int? deliveryFeeMinor;
  final bool followed;

  /// By road, when the server has road routing switched on.
  final double? roadKm;
  final int? roadMinutes;

  /// "1.8 km · 10 min" by road, else "~1.3 km"; null without a location.
  String? get distanceText => formatTrip(distanceKm, roadKm, roadMinutes);
}

/// A shop on the home screen with a summary of its deals that this customer can get.
class ShopCard {
  ShopCard.fromJson(Json j)
      : vendor = VendorSummary.fromJson(j['vendor'] as Json),
        tagline = j['tagline'] as String?,
        distanceKm = _double(j['distanceKm']),
        followed = j['followed'] as bool? ?? false,
        followers = _int(j['followers']) ?? 0,
        dealCount = _int(j['dealCount']) ?? 0,
        bestDiscountPercent = _int(j['bestDiscountPercent']),
        coverImageUrl = j['coverImageUrl'] as String?,
        tag = ShopTag.parse(j['tag']),
        rating = _double(j['rating']),
        ratingCount = _int(j['ratingCount']) ?? 0,
        roadKm = _double(j['roadKm']),
        roadMinutes = _int(j['roadMinutes']);

  final VendorSummary vendor;
  final String? tagline;
  final double? distanceKm;
  final bool followed;
  final int followers;
  final int dealCount;
  final int? bestDiscountPercent;
  final String? coverImageUrl;
  final ShopTag tag;
  final double? rating;
  final int ratingCount;
  final double? roadKm;
  final int? roadMinutes;

  String? get distanceText => formatTrip(distanceKm, roadKm, roadMinutes);
}

class Storefront {
  Storefront.fromJson(Json j)
      : vendor = VendorPublic.fromJson(j['vendor'] as Json),
        distanceKm = _double(j['distanceKm']),
        followed = j['followed'] as bool,
        followers = _int(j['followers']) ?? 0,
        listings = [for (final i in j['listings'] as List) DiscoveryItem.fromJson(i as Json)],
        rating = _double(j['rating']),
        ratingCount = _int(j['ratingCount']) ?? 0,
        roadKm = _double(j['roadKm']),
        roadMinutes = _int(j['roadMinutes']);

  final VendorPublic vendor;
  final double? distanceKm;
  final bool followed;
  final int followers;
  final List<DiscoveryItem> listings;

  /// Average of visible reviews, or null when there are none.
  final double? rating;
  final int ratingCount;
  final double? roadKm;
  final int? roadMinutes;

  String? get distanceText => formatTrip(distanceKm, roadKm, roadMinutes);
}

class AuditEntry {
  AuditEntry.fromJson(Json j)
      : action = j['action'] as String,
        detail = j['detail'] as String?,
        createdAt = _date(j['createdAt'])!;

  final String action;
  final String? detail;
  final DateTime createdAt;
}

class VendorDetail {
  VendorDetail.fromJson(Json j)
      : vendor = Vendor(j['vendor'] as Json),
        listings = [for (final l in j['listings'] as List) Listing.fromJson(l as Json)],
        history = [for (final h in j['history'] as List) AuditEntry.fromJson(h as Json)];

  final Vendor vendor;
  final List<Listing> listings;
  final List<AuditEntry> history;
}

/// A home screen banner, as customers see it.
class HomeBanner {
  HomeBanner.fromJson(Json j)
      : id = j['id'] as String,
        title = j['title'] as String,
        subtitle = j['subtitle'] as String?,
        kicker = j['kicker'] as String?,
        imageUrl = j['imageUrl'] as String,
        targetType = BannerTarget.parse(j['targetType']),
        targetCategory = j['targetCategory'] == null ? null : VendorCategory.parse(j['targetCategory']),
        targetId = j['targetId'] as String?;

  final String id;
  final String title;
  final String? subtitle;
  final String? kicker;
  final String imageUrl;
  final BannerTarget targetType;
  final VendorCategory? targetCategory;
  final String? targetId;
}

/// A banner as admins manage it.
class AdminBanner extends HomeBanner {
  AdminBanner.fromJson(super.j)
      : targetName = j['targetName'] as String?,
        scope = BannerScope.parse(j['scope']),
        startsAt = _date(j['startsAt']),
        endsAt = _date(j['endsAt']),
        position = _int(j['position']) ?? 0,
        active = j['active'] as bool? ?? false,
        live = j['live'] as bool? ?? false,
        super.fromJson();

  final String? targetName;
  final BannerScope scope;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int position;
  final bool active;

  /// Customers can see it right now: active, within its dates, and its shop or product is live.
  final bool live;
}
