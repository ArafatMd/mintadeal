import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'image_field.dart';
import 'providers.dart';

/// Registers a new shop, or edits an existing shop's details and fulfilment settings.
class ShopFormScreen extends ConsumerStatefulWidget {
  const ShopFormScreen({super.key, required this.existing});

  final Vendor? existing;

  @override
  ConsumerState<ShopFormScreen> createState() => _ShopFormScreenState();
}

class _ShopFormScreenState extends ConsumerState<ShopFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _text;
  late VendorCategory _category;
  late Area _area;
  String? _logoUrl;
  bool _selfDelivery = false;
  bool _partnerDelivery = false;
  bool _pickup = true;
  bool _citywide = false;
  bool _saving = false;

  static const _fields = [
    'displayName', 'legalName', 'phone', 'description', 'addressLine', 'pincode', 'latitude', 'longitude',
    'gstNumber', 'openingHours', 'payoutUpiId', 'payoutAccountNumber', 'payoutIfsc', 'deliveryRadiusKm',
    'deliveryFee', 'minOrder',
  ];

  @override
  void initState() {
    super.initState();
    final j = widget.existing?.json ?? const <String, dynamic>{};
    String s(String k) => j[k] == null ? '' : '${j[k]}';
    _text = {for (final f in _fields) f: TextEditingController(text: s(f))};
    _text['deliveryFee']!.text = rupeesText((j['deliveryFeeMinor'] as num?)?.toInt());
    _text['minOrder']!.text = rupeesText((j['minOrderMinor'] as num?)?.toInt());
    if (widget.existing == null) {
      _text['phone']!.text = ref.read(sessionProvider).value?.user.phone.replaceFirst('+91', '') ?? '';
      _text['deliveryRadiusKm']!.text = '3';
    }
    _category = widget.existing?.category ?? VendorCategory.GROCERY;
    _area = bengaluruAreas.firstWhere((a) => a.name == j['area'], orElse: () => bengaluruAreas.first);
    if (widget.existing == null) _setAreaCoordinates(_area);
    _logoUrl = j['logoUrl'] as String?;
    _selfDelivery = j['selfDelivery'] as bool? ?? false;
    _partnerDelivery = j['partnerDelivery'] as bool? ?? false;
    _pickup = j['pickup'] as bool? ?? true;
    _citywide = j['citywideDelivery'] as bool? ?? false;
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setAreaCoordinates(Area a) {
    _text['latitude']!.text = a.lat.toStringAsFixed(6);
    _text['longitude']!.text = a.lng.toStringAsFixed(6);
  }

  Map<String, dynamic> _payload() {
    String? t(String k) => _text[k]!.text.trim().isEmpty ? null : _text[k]!.text.trim();
    return {
      'displayName': t('displayName'),
      'legalName': t('legalName'),
      'category': _category.name,
      'phone': t('phone'),
      'description': t('description'),
      'addressLine': t('addressLine'),
      'area': _area.name,
      'pincode': t('pincode'),
      'latitude': double.tryParse(_text['latitude']!.text),
      'longitude': double.tryParse(_text['longitude']!.text),
      'gstNumber': t('gstNumber')?.toUpperCase(),
      'openingHours': t('openingHours'),
      'logoUrl': _logoUrl,
      'payoutUpiId': t('payoutUpiId'),
      'payoutAccountNumber': t('payoutAccountNumber'),
      'payoutIfsc': t('payoutIfsc')?.toUpperCase(),
      'selfDelivery': _selfDelivery,
      'partnerDelivery': _partnerDelivery,
      'pickup': _pickup,
      'citywideDelivery': _citywide,
      'deliveryRadiusKm': double.tryParse(_text['deliveryRadiusKm']!.text) ?? 0,
      'deliveryFeeMinor': parseRupees(_text['deliveryFee']!.text) ?? 0,
      'minOrderMinor': parseRupees(_text['minOrder']!.text) ?? 0,
    };
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiProvider);
      if (widget.existing == null) {
        await api.registerShop(_payload());
        // Registering grants the VENDOR role; pick it up in a fresh token.
        await ref.read(sessionProvider.notifier).refresh();
      } else {
        await api.updateShop(_payload());
      }
      ref.invalidate(myShopProvider);
      if (mounted) {
        showMessage(context, widget.existing == null ? 'Submitted for review' : 'Saved');
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) => v == null || v.trim().isEmpty ? 'Required' : null;

  Widget _field(String key, String label,
      {String? Function(String?)? validator, TextInputType? keyboard, String? hint, int maxLines = 1,
      String? prefix, List<TextInputFormatter>? formatters, TextCapitalization caps = TextCapitalization.sentences}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _text[key],
        validator: validator,
        keyboardType: keyboard,
        maxLines: maxLines,
        inputFormatters: formatters,
        textCapitalization: caps,
        decoration: InputDecoration(labelText: label, hintText: hint, prefixText: prefix),
      ),
    );
  }

  Widget _section(String title, [String? subtitle]) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final registering = widget.existing == null;
    final anyDelivery = _selfDelivery || _partnerDelivery;
    return Scaffold(
      appBar: AppBar(
        title: Text(registering ? 'Register your shop' : 'Shop settings'),
        actions: [
          if (registering)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(sessionProvider.notifier).signOut(),
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (registering)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Tell customers about your shop. Mintadeal reviews every shop before it goes live.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ImageField(url: _logoUrl, category: _category, label: 'Shop photo or logo',
                onChanged: (u) => setState(() => _logoUrl = u)),
            _section('Shop'),
            _field('displayName', 'Shop name', validator: _required, caps: TextCapitalization.words),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<VendorCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in VendorCategory.values)
                    DropdownMenuItem(value: c, child: Row(children: [Icon(c.icon, size: 20), const SizedBox(width: 8), Text(c.label)])),
                ],
                onChanged: (c) => setState(() => _category = c!),
              ),
            ),
            _field('description', 'What you sell (optional)', maxLines: 3),
            _field('phone', 'Shop phone', validator: _required, keyboard: TextInputType.phone, prefix: '+91 '),
            _field('openingHours', 'Opening hours (optional)', hint: 'e.g. 9 am - 9 pm, closed Sunday'),
            _section('Location'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<Area>(
                initialValue: _area,
                decoration: const InputDecoration(labelText: 'Area'),
                items: [for (final a in bengaluruAreas) DropdownMenuItem(value: a, child: Text(a.name))],
                onChanged: (a) => setState(() {
                  _area = a!;
                  _setAreaCoordinates(a);
                }),
              ),
            ),
            _field('addressLine', 'Street address', validator: _required),
            _field('pincode', 'Pincode', keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                validator: (v) => v != null && RegExp(r'^\d{6}$').hasMatch(v) ? null : '6-digit pincode'),
            Row(children: [
              Expanded(child: _field('latitude', 'Latitude', keyboard: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => double.tryParse(v ?? '') == null ? 'Number' : null)),
              const SizedBox(width: 12),
              Expanded(child: _field('longitude', 'Longitude', keyboard: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => double.tryParse(v ?? '') == null ? 'Number' : null)),
            ]),
            Text('Filled from your area. Fine-tune it to your exact shop location so distances are right.',
                style: Theme.of(context).textTheme.bodySmall),
            _section('How customers get your products',
                'Venue offers (hotels, salons, events) are always used at your shop with a QR code.'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('We deliver ourselves'),
              value: _selfDelivery,
              onChanged: (v) => setState(() => _selfDelivery = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mintadeal delivery partner on request'),
              subtitle: const Text('Mintadeal books and pays the partner; the cost is deducted from your payout'),
              value: _partnerDelivery,
              onChanged: (v) => setState(() => _partnerDelivery = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Customers can pick up from the shop'),
              value: _pickup,
              onChanged: (v) => setState(() => _pickup = v),
            ),
            if (anyDelivery) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Deliver across all of Bangalore'),
                subtitle: const Text('Your products also appear in Deals in Bangalore'),
                value: _citywide,
                onChanged: (v) => setState(() => _citywide = v),
              ),
              if (!_citywide)
                _field('deliveryRadiusKm', 'Delivery distance (km)',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'How far do you deliver?'),
              Row(children: [
                Expanded(child: _field('deliveryFee', 'Delivery fee', prefix: '₹ ', keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _field('minOrder', 'Minimum order', prefix: '₹ ', keyboard: TextInputType.number)),
              ]),
            ],
            _section('Business and payouts', 'Used for verification and to pay you. Only Mintadeal sees these.'),
            _field('legalName', 'Registered business name (optional)', caps: TextCapitalization.words),
            _field('gstNumber', 'GSTIN (if registered)', caps: TextCapitalization.characters),
            _field('payoutUpiId', 'UPI ID for payouts', hint: 'shopname@okbank'),
            _field('payoutAccountNumber', 'Bank account number (optional)', keyboard: TextInputType.number),
            _field('payoutIfsc', 'IFSC (optional)', caps: TextCapitalization.characters),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(registering ? 'Submit for review' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
