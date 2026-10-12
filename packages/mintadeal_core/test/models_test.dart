import 'package:flutter_test/flutter_test.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

/// Matches the shape returned by GET /api/discovery/nearby.
const sampleItem = {
  'listing': {
    'id': 'l1',
    'vendorId': 'v1',
    'listingType': 'PRODUCT',
    'title': 'Chicken curry cut 1 kg',
    'description': null,
    'category': 'MEAT_FISH',
    'imageUrl': null,
    'priceMinor': 32000,
    'offerPriceMinor': 28000,
    'discountPercent': 13,
    'stock': 25,
    'capacityPerSlot': null,
    'terms': null,
    'validFrom': null,
    'validTo': null,
    'status': 'ACTIVE',
    'removedReason': null,
    'fulfilmentModes': ['PICKUP', 'SHOP_DELIVERY'],
    'createdAt': '2026-10-12T14:13:36.123Z',
    'updatedAt': '2026-10-12T14:13:36.123Z',
  },
  'vendor': {
    'id': 'v1',
    'displayName': 'HSR Fresh Meats',
    'category': 'MEAT_FISH',
    'area': 'HSR Layout',
    'logoUrl': null,
    'mintadealOwn': false,
  },
  'distanceKm': 1.0,
  'deliverable': true,
  'pickupAvailable': true,
  'venueOffer': false,
  'deliveryFeeMinor': 3000,
  'followed': false,
};

void main() {
  test('parses a discovery item', () {
    final item = DiscoveryItem.fromJson(sampleItem);
    expect(item.listing.title, 'Chicken curry cut 1 kg');
    expect(item.listing.effectivePriceMinor, 28000);
    expect(item.listing.fulfilmentModes, [FulfilmentMode.PICKUP, FulfilmentMode.SHOP_DELIVERY]);
    expect(item.vendor.category, VendorCategory.MEAT_FISH);
    expect(item.distanceKm, 1.0);
    expect(item.deliveryFeeMinor, 3000);
  });

  test('unknown enum values fall back instead of crashing', () {
    expect(VendorCategory.parse('SOMETHING_NEW'), VendorCategory.OTHER);
    expect(ListingStatus.parse(null), ListingStatus.DRAFT);
  });

  test('page result knows whether more pages exist', () {
    final page = PageResult.fromJson(
        {'items': [sampleItem], 'page': 0, 'size': 1, 'total': 3}, DiscoveryItem.fromJson);
    expect(page.hasMore, isTrue);
  });
}
