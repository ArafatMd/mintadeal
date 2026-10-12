import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

final myShopProvider = FutureProvider.autoDispose<Vendor?>((ref) => ref.watch(apiProvider).myShop());

final myListingsProvider = FutureProvider.autoDispose<List<Listing>>((ref) => ref.watch(apiProvider).myListings());
