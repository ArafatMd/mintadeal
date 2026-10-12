import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One listing in the cart. Prices here are for display only; checkout always uses the server's current prices.
class CartEntry {
  const CartEntry({
    required this.listingId,
    required this.vendorId,
    required this.vendorName,
    required this.title,
    required this.category,
    required this.type,
    required this.priceMinor,
    this.offerPriceMinor,
    this.imageUrl,
    required this.quantity,
  });

  factory CartEntry.fromItem(DiscoveryItem item, {int quantity = 1}) => CartEntry(
        listingId: item.listing.id,
        vendorId: item.vendor.id,
        vendorName: item.vendor.displayName,
        title: item.listing.title,
        category: item.listing.category,
        type: item.listing.listingType,
        priceMinor: item.listing.priceMinor,
        offerPriceMinor: item.listing.offerPriceMinor,
        imageUrl: item.listing.imageUrl,
        quantity: quantity,
      );

  factory CartEntry.fromJson(Map<String, dynamic> j) => CartEntry(
        listingId: j['listingId'] as String,
        vendorId: j['vendorId'] as String,
        vendorName: j['vendorName'] as String,
        title: j['title'] as String,
        category: VendorCategory.parse(j['category']),
        type: ListingType.parse(j['type']),
        priceMinor: j['priceMinor'] as int,
        offerPriceMinor: j['offerPriceMinor'] as int?,
        imageUrl: j['imageUrl'] as String?,
        quantity: j['quantity'] as int,
      );

  final String listingId;
  final String vendorId;
  final String vendorName;
  final String title;
  final VendorCategory category;
  final ListingType type;
  final int priceMinor;
  final int? offerPriceMinor;
  final String? imageUrl;
  final int quantity;

  CartEntry withQuantity(int q) => CartEntry(
        listingId: listingId,
        vendorId: vendorId,
        vendorName: vendorName,
        title: title,
        category: category,
        type: type,
        priceMinor: priceMinor,
        offerPriceMinor: offerPriceMinor,
        imageUrl: imageUrl,
        quantity: q,
      );

  Map<String, dynamic> toJson() => {
        'listingId': listingId,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'title': title,
        'category': category.name,
        'type': type.name,
        'priceMinor': priceMinor,
        'offerPriceMinor': offerPriceMinor,
        'imageUrl': imageUrl,
        'quantity': quantity,
      };
}

class CartController extends Notifier<List<CartEntry>> {
  static const _key = 'mintadeal.cart';
  static const maxQuantity = 20;

  @override
  List<CartEntry> build() {
    _restore();
    return const [];
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      state = [for (final e in jsonDecode(raw) as List) CartEntry.fromJson(e as Map<String, dynamic>)];
    } on Object {
      await prefs.remove(_key);
    }
  }

  void add(DiscoveryItem item) {
    final i = state.indexWhere((e) => e.listingId == item.listing.id);
    if (i >= 0) {
      setQuantity(item.listing.id, state[i].quantity + 1);
    } else {
      _set([...state, CartEntry.fromItem(item)]);
    }
  }

  void setQuantity(String listingId, int quantity) {
    if (quantity <= 0) {
      remove(listingId);
      return;
    }
    _set([
      for (final e in state) e.listingId == listingId ? e.withQuantity(quantity.clamp(1, maxQuantity)) : e,
    ]);
  }

  void remove(String listingId) => _set([for (final e in state) if (e.listingId != listingId) e]);

  void clear() => _set(const []);

  int quantityOf(String listingId) =>
      state.where((e) => e.listingId == listingId).fold(0, (sum, e) => sum + e.quantity);

  void _set(List<CartEntry> next) {
    state = next;
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_key, jsonEncode([for (final e in next) e.toJson()])));
  }
}

final cartProvider = NotifierProvider<CartController, List<CartEntry>>(CartController.new);

final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).fold(0, (sum, e) => sum + e.quantity));

/// The customer's delivery address details, remembered on the device. Area and coordinates come from the area picker.
class SavedAddress {
  const SavedAddress({this.line = '', this.landmark = '', this.contactName = ''});

  final String line;
  final String landmark;
  final String contactName;
}

class AddressController extends Notifier<SavedAddress> {
  static const _key = 'mintadeal.address';

  @override
  SavedAddress build() {
    _restore();
    return const SavedAddress();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    state = SavedAddress(
      line: j['line'] as String? ?? '',
      landmark: j['landmark'] as String? ?? '',
      contactName: j['contactName'] as String? ?? '',
    );
  }

  Future<void> save(SavedAddress a) async {
    state = a;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({'line': a.line, 'landmark': a.landmark, 'contactName': a.contactName}));
  }
}

final addressProvider = NotifierProvider<AddressController, SavedAddress>(AddressController.new);
