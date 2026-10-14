import 'enums.dart';

typedef Json = Map<String, dynamic>;

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

int? _int(Object? v) => (v as num?)?.toInt();

double? _double(Object? v) => (v as num?)?.toDouble();

class AppUser {
  AppUser({required this.id, required this.phone, this.name, this.email, required this.roles});

  factory AppUser.fromJson(Json j) => AppUser(
        id: j['id'] as String,
        phone: j['phone'] as String,
        name: j['name'] as String?,
        email: j['email'] as String?,
        roles: [for (final r in j['roles'] as List) Role.parse(r)],
      );

  final String id;
  final String phone;
  final String? name;
  final String? email;
  final List<Role> roles;

  bool has(Role role) => roles.contains(role);

  Json toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'email': email,
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
        followed = j['followed'] as bool;

  final Listing listing;
  final VendorSummary vendor;
  final double? distanceKm;
  final bool deliverable;
  final bool pickupAvailable;
  final bool venueOffer;
  final int? deliveryFeeMinor;
  final bool followed;
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
        tag = ShopTag.parse(j['tag']);

  final VendorSummary vendor;
  final String? tagline;
  final double? distanceKm;
  final bool followed;
  final int followers;
  final int dealCount;
  final int? bestDiscountPercent;
  final String? coverImageUrl;
  final ShopTag tag;
}

class Storefront {
  Storefront.fromJson(Json j)
      : vendor = VendorPublic.fromJson(j['vendor'] as Json),
        distanceKm = _double(j['distanceKm']),
        followed = j['followed'] as bool,
        followers = _int(j['followers']) ?? 0,
        listings = [for (final i in j['listings'] as List) DiscoveryItem.fromJson(i as Json)];

  final VendorPublic vendor;
  final double? distanceKm;
  final bool followed;
  final int followers;
  final List<DiscoveryItem> listings;
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
