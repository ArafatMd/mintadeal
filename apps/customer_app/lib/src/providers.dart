import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

typedef PlaceKey = (String id, double? lat, double? lng);

GeoPoint? _at(PlaceKey k) => k.$2 == null ? null : GeoPoint(k.$2!, k.$3!);

final listingProvider = FutureProvider.autoDispose.family<DiscoveryItem, PlaceKey>(
    (ref, key) => ref.watch(apiProvider).listing(key.$1, at: _at(key)));

final storefrontProvider = FutureProvider.autoDispose.family<Storefront, PlaceKey>(
    (ref, key) => ref.watch(apiProvider).storefront(key.$1, at: _at(key)));

final followsProvider = FutureProvider.autoDispose<List<VendorPublic>>((ref) {
  if (ref.watch(sessionProvider).value == null) return const [];
  return ref.watch(apiProvider).follows();
});

PlaceKey placeKey(String id, GeoPoint? at) => (id, at?.lat, at?.lng);
