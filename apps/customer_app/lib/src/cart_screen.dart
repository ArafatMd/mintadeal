import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'area.dart';
import 'cart.dart';
import 'orders_screen.dart';
import 'payment_screen.dart';
import 'sign_in.dart';

/// Cart and checkout in one screen: the server quote decides what can be ordered, how, and for how much.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final Map<String, FulfilmentMode> _modes = {};
  PaymentMethod? _payment;
  Quote? _quote;
  Object? _quoteError;
  bool _quoting = false;
  bool _placing = false;
  Timer? _debounce;
  int _quoteGeneration = 0;
  late String _requestId = _newRequestId();
  late final TextEditingController _line;
  late final TextEditingController _landmark;
  late final TextEditingController _name;
  final _note = TextEditingController();

  // Stays within 2^30: on the web, ints are JavaScript numbers and `1 << 32` would be 0.
  static String _newRequestId() {
    final r = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}-${r.nextInt(1 << 30).toRadixString(36)}${r.nextInt(1 << 30).toRadixString(36)}';
  }

  @override
  void initState() {
    super.initState();
    final saved = ref.read(addressProvider);
    _line = TextEditingController(text: saved.line);
    _landmark = TextEditingController(text: saved.landmark);
    _name = TextEditingController(text: saved.contactName);
    WidgetsBinding.instance.addPostFrameCallback((_) => _requote());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_line, _landmark, _name, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  DeliveryAddress? get _address {
    final area = ref.read(areaProvider);
    if (_line.text.trim().isEmpty) return null;
    return DeliveryAddress(
      line: _line.text.trim(),
      area: area.name,
      landmark: _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
      lat: area.lat,
      lng: area.lng,
    );
  }

  List<(String, int)> get _items => [for (final e in ref.read(cartProvider)) (e.listingId, e.quantity)];

  void _requote({bool soon = false}) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: soon ? 0 : 400), _runQuote);
  }

  Future<void> _runQuote() async {
    final items = _items;
    if (items.isEmpty) {
      setState(() => _quote = null);
      return;
    }
    final generation = ++_quoteGeneration;
    setState(() => _quoting = true);
    try {
      final q = await ref.read(apiProvider).quote(items, modes: _modes, payment: _payment, address: _address);
      if (!mounted || generation != _quoteGeneration) return;
      setState(() {
        _quote = q;
        _quoteError = null;
        // Venue offers can only be paid online; pick the first method that is allowed.
        if (_payment == null || (_payment == PaymentMethod.PAY_ON_DELIVERY && !q.payOnDeliveryAllowed)) {
          _payment = q.payOnDeliveryAllowed ? PaymentMethod.PAY_ON_DELIVERY : PaymentMethod.ONLINE;
          _requote(soon: true);
        }
      });
    } catch (e) {
      if (mounted && generation == _quoteGeneration) setState(() => _quoteError = e);
    } finally {
      if (mounted && generation == _quoteGeneration) setState(() => _quoting = false);
    }
  }

  Future<void> _place() async {
    final quote = _quote;
    if (quote == null || !quote.canPlace || _payment == null) return;
    if (!await ensureSignedIn(context, ref)) return;
    setState(() => _placing = true);
    try {
      await ref.read(addressProvider.notifier).save(
          SavedAddress(line: _line.text.trim(), landmark: _landmark.text.trim(), contactName: _name.text.trim()));
      final result = await ref.read(apiProvider).placeOrder(
            _requestId,
            _items,
            modes: {for (final g in quote.groups) if (g.selectedMode != null) g.key: g.selectedMode!},
            payment: _payment!,
            address: quote.addressRequired ? _address : null,
            contactName: _name.text.trim().isEmpty ? null : _name.text.trim(),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      ref.read(cartProvider.notifier).clear();
      _requestId = _newRequestId();
      ref.invalidate(myOrdersRefreshProvider);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (result.paymentStatus == PaymentStatus.PENDING) {
        navigator.pushReplacement(MaterialPageRoute(builder: (_) => PaymentScreen(checkoutId: result.id, openNow: true)));
      } else {
        navigator.pushReplacement(MaterialPageRoute(builder: (_) => OrderPlacedScreen(result: result)));
      }
    } catch (e) {
      if (mounted) showError(context, e);
      _requote(soon: true);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    ref.listen(cartProvider, (_, _) => _requote());
    ref.listen(areaProvider, (_, _) => _requote(soon: true));
    final quote = _quote;
    final theme = Theme.of(context);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: const EmptyView(
          icon: Icons.shopping_bag_outlined,
          title: 'Your cart is empty',
          message: 'Add products or offers from shops near you.',
        ),
      );
    }

    final byListing = {for (final e in cart) e.listingId: e};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        bottom: _quoting ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator()) : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_quoteError != null && quote == null) ErrorView(message: '$_quoteError', onRetry: () => _requote(soon: true)),
          if (quote == null && _quoteError == null) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          if (quote != null) ...[
            for (final g in quote.groups) ...[
              _GroupCard(
                group: g,
                entries: byListing,
                onMode: (m) {
                  setState(() => _modes[g.key] = m);
                  _requote(soon: true);
                },
              ),
              const SizedBox(height: 12),
            ],
            if (quote.addressRequired) ...[
              Text('Delivery address', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => pickArea(context, ref),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Area'),
                  child: Row(children: [
                    Expanded(child: Text(ref.watch(areaProvider).name)),
                    const Icon(Icons.expand_more),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _line,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'House / flat, street'),
                onChanged: (_) => _requote(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _landmark,
                decoration: const InputDecoration(labelText: 'Landmark (optional)'),
              ),
              const SizedBox(height: 16),
            ],
            Text('Your details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name for the shop'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Note for the shop (optional)', counterText: ''),
            ),
            const SizedBox(height: 16),
            Text('Payment', style: theme.textTheme.titleMedium),
            RadioGroup<PaymentMethod>(
              groupValue: _payment,
              onChanged: (m) {
                setState(() => _payment = m);
                _requote(soon: true);
              },
              child: Column(children: [
                RadioListTile<PaymentMethod>(
                  contentPadding: EdgeInsets.zero,
                  value: PaymentMethod.ONLINE,
                  enabled: quote.onlinePaymentAvailable,
                  title: const Text('Pay online'),
                  subtitle: Text(quote.onlinePaymentAvailable ? 'UPI, cards and wallets' : 'Not available yet'),
                ),
                RadioListTile<PaymentMethod>(
                  contentPadding: EdgeInsets.zero,
                  value: PaymentMethod.PAY_ON_DELIVERY,
                  enabled: quote.payOnDeliveryAllowed,
                  title: const Text('Pay the shop on delivery or pickup'),
                  subtitle: Text(quote.payOnDeliveryAllowed ? 'Cash or UPI to the shop' : 'Venue offers are paid online'),
                ),
              ]),
            ),
            const Divider(height: 24),
            _TotalRow('Items', quote.itemsTotalMinor),
            if (quote.deliveryTotalMinor > 0) _TotalRow('Delivery', quote.deliveryTotalMinor),
            _TotalRow('Total', quote.grandTotalMinor, bold: true),
            for (final p in quote.problems)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(p, style: TextStyle(color: theme.colorScheme.error)),
              ),
          ],
        ],
      ),
      bottomNavigationBar: quote == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: quote.canPlace && !_placing && !_quoting ? _place : null,
                  child: _placing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_payment == PaymentMethod.ONLINE
                          ? 'Pay ${formatInr(quote.grandTotalMinor)}'
                          : 'Place order · ${formatInr(quote.grandTotalMinor)}'),
                ),
              ),
            ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group, required this.entries, required this.onMode});

  final QuoteGroup group;
  final Map<String, CartEntry> entries;
  final ValueChanged<FulfilmentMode> onMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cart = ref.read(cartProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.storefront_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(group.vendor.name, style: theme.textTheme.titleSmall)),
            if (group.kind == ListingType.OFFER) const DealBadge(text: 'Venue offer'),
          ]),
          const Divider(),
          for (final line in group.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CatalogueImage(
                    url: line.imageUrl,
                    category: entries[line.listingId]?.category ?? VendorCategory.OTHER,
                    size: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(line.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('${formatInr(line.unitPriceMinor)} each', style: theme.textTheme.bodySmall),
                    if (line.problem != null)
                      Text(line.problem!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                  ]),
                ),
                _QuantityStepper(
                  quantity: line.quantity,
                  onChanged: (q) => cart.setQuantity(line.listingId, q),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          if (group.availableModes.isNotEmpty && group.kind == ListingType.PRODUCT) ...[
            Text('How do you want it?', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final m in group.availableModes)
                ChoiceChip(
                  avatar: Icon(m.icon, size: 18),
                  label: Text(m == FulfilmentMode.PICKUP ? 'Pickup' : 'Delivery'
                      '${m == FulfilmentMode.PARTNER_DELIVERY ? ' (partner)' : ''}'),
                  selected: group.selectedMode == m,
                  onSelected: (_) => onMode(m),
                ),
            ]),
          ],
          if (group.kind == ListingType.OFFER)
            Row(children: [
              const Icon(Icons.qr_code_2, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text('Show your order at the venue to use it', style: theme.textTheme.bodySmall)),
            ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(
                group.deliveryFeeMinor > 0 ? 'Delivery ${formatInr(group.deliveryFeeMinor)}' : '',
                style: theme.textTheme.bodySmall,
              ),
            ),
            Text(formatInr(group.totalMinor), style: theme.textTheme.titleSmall),
          ]),
          for (final p in group.problems.where((p) => !group.lines.any((l) => l.problem != null && p.endsWith(l.problem!))))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(p, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ),
        ]),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: quantity == 1 ? 'Remove' : 'Less',
        onPressed: () => onChanged(quantity - 1),
        icon: Icon(quantity == 1 ? Icons.delete_outline : Icons.remove),
      ),
      Text('$quantity', style: Theme.of(context).textTheme.titleSmall),
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'More',
        onPressed: quantity >= CartController.maxQuantity ? null : () => onChanged(quantity + 1),
        icon: const Icon(Icons.add),
      ),
    ]);
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.amountMinor, {this.bold = false});

  final String label;
  final int amountMinor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(formatInr(amountMinor), style: style)]),
    );
  }
}
