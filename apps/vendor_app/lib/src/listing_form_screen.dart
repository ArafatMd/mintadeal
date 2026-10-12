import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'image_field.dart';
import 'providers.dart';

/// Create or edit a product or a venue offer.
class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key, required this.shop, required this.existing});

  final Vendor shop;
  final Listing? existing;

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _offerPrice = TextEditingController();
  final _stock = TextEditingController();
  final _capacity = TextEditingController();
  final _terms = TextEditingController();
  late ListingType _type;
  late VendorCategory _category;
  late Set<FulfilmentMode> _modes;
  String? _imageUrl;
  DateTime? _validFrom;
  DateTime? _validTo;
  bool _trackStock = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final l = widget.existing;
    _type = l?.listingType ?? ListingType.PRODUCT;
    _category = l?.category ?? widget.shop.category;
    _title.text = l?.title ?? '';
    _description.text = l?.description ?? '';
    _price.text = rupeesText(l?.priceMinor);
    _offerPrice.text = rupeesText(l?.offerPriceMinor);
    _trackStock = l?.stock != null;
    _stock.text = l?.stock?.toString() ?? '';
    _capacity.text = l?.capacityPerSlot?.toString() ?? '';
    _terms.text = l?.terms ?? '';
    _imageUrl = l?.imageUrl;
    _validFrom = l?.validFrom;
    _validTo = l?.validTo;
    _modes = l?.fulfilmentModes.toSet() ?? _defaultModes(_type);
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _price, _offerPrice, _stock, _capacity, _terms]) {
      c.dispose();
    }
    super.dispose();
  }

  Set<FulfilmentMode> _defaultModes(ListingType type) {
    if (type == ListingType.OFFER) return {FulfilmentMode.VENUE_QR};
    return {for (final m in _allowedProductModes) m};
  }

  List<FulfilmentMode> get _allowedProductModes => [
        if (widget.shop.selfDelivery) FulfilmentMode.SHOP_DELIVERY,
        if (widget.shop.partnerDelivery) FulfilmentMode.PARTNER_DELIVERY,
        if (widget.shop.pickup) FulfilmentMode.PICKUP,
      ];

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final initial = (start ? _validFrom : _validTo) ?? now.add(Duration(days: start ? 0 : 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 366)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _validFrom = picked;
      } else {
        // The offer stays valid for the whole of its last day.
        _validTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Future<void> _save({required bool publish}) async {
    if (!_form.currentState!.validate()) return;
    if (_modes.isEmpty) {
      showMessage(context, 'Choose at least one way for customers to get this');
      return;
    }
    if (_type == ListingType.OFFER && _validTo == null) {
      showMessage(context, 'Choose until when the offer is valid');
      return;
    }
    final body = {
      'listingType': _type.name,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'category': _category.name,
      'imageUrl': _imageUrl,
      'priceMinor': parseRupees(_price.text),
      'offerPriceMinor': parseRupees(_offerPrice.text),
      'stock': _type == ListingType.PRODUCT && _trackStock ? int.tryParse(_stock.text.trim()) : null,
      'capacityPerSlot': _type == ListingType.OFFER ? int.tryParse(_capacity.text.trim()) : null,
      'terms': _terms.text.trim(),
      'validFrom': _validFrom?.toUtc().toIso8601String(),
      'validTo': _validTo?.toUtc().toIso8601String(),
      'fulfilmentModes': [for (final m in _modes) m.name],
    };
    setState(() => _saving = true);
    try {
      final api = ref.read(apiProvider);
      var saved = widget.existing == null
          ? await api.createListing(body)
          : await api.updateListing(widget.existing!.id, body);
      if (publish && saved.status != ListingStatus.ACTIVE) saved = await api.publishListing(saved.id);
      ref.invalidate(myListingsProvider);
      if (mounted) {
        showMessage(context, saved.status == ListingStatus.ACTIVE ? 'Live for customers' : 'Saved as draft');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final dates = DateFormat('d MMM yyyy');
    final productModes = _allowedProductModes;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit listing' : 'New listing')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (!editing) ...[
              SegmentedButton<ListingType>(
                segments: const [
                  ButtonSegment(value: ListingType.PRODUCT, icon: Icon(Icons.inventory_2_outlined), label: Text('Product')),
                  ButtonSegment(value: ListingType.OFFER, icon: Icon(Icons.qr_code_2), label: Text('Offer at venue')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _modes = _defaultModes(_type);
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _type == ListingType.PRODUCT
                    ? 'Something customers get delivered or pick up.'
                    : 'A deal customers buy online and use at your shop, hotel or event by showing a QR code.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ],
            ImageField(url: _imageUrl, category: _category, onChanged: (u) => setState(() => _imageUrl = u)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: _type == ListingType.PRODUCT ? 'e.g. Basmati rice 5 kg' : 'e.g. Weekend buffet for 2',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price', prefixText: '₹ '),
                  validator: (v) => (parseRupees(v ?? '') ?? 0) > 0 ? null : 'Enter a price',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _offerPrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Offer price', prefixText: '₹ ', helperText: 'Optional'),
                  validator: (v) {
                    final offer = parseRupees(v ?? '');
                    final price = parseRupees(_price.text);
                    if (offer == null || price == null) return null;
                    return offer < price ? null : 'Must be lower';
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<VendorCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in VendorCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
              onChanged: (c) => setState(() => _category = c!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            if (_type == ListingType.PRODUCT) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Track stock'),
                subtitle: const Text('Hide automatically when it runs out'),
                value: _trackStock,
                onChanged: (v) => setState(() => _trackStock = v),
              ),
              if (_trackStock)
                TextFormField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Units in stock'),
                  validator: (v) => int.tryParse(v ?? '') == null ? 'Enter a number' : null,
                ),
              const SizedBox(height: 16),
              Text('How customers get it', style: Theme.of(context).textTheme.titleSmall),
              if (productModes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Turn on delivery or pickup in My shop settings to list products.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              for (final m in productModes)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(m.icon),
                  title: Text(m.label),
                  value: _modes.contains(m),
                  onChanged: (on) => setState(() => on! ? _modes.add(m) : _modes.remove(m)),
                ),
            ] else ...[
              const SizedBox(height: 16),
              Text('Valid', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(_validFrom == null ? 'From today' : 'From ${dates.format(_validFrom!)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.event_busy_outlined),
                    label: Text(_validTo == null ? 'Until…' : 'Until ${dates.format(_validTo!)}'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'How many can you honour per day? (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _terms,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Terms',
                  hintText: 'e.g. Valid Mon-Thu. Call to book a slot. Not valid on public holidays.',
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _save(publish: false),
                  child: Text(widget.existing?.status == ListingStatus.ACTIVE ? 'Save' : 'Save draft'),
                ),
              ),
              const SizedBox(width: 12),
              if (widget.existing?.status != ListingStatus.ACTIVE)
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(publish: true),
                    child: const Text('Save and publish'),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
