import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

final _bannersProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).adminBanners());

final _dates = DateFormat('d MMM yyyy');

/// Banners on the customer home screen. Without any live banner, the app shows banners made from real discounts.
class BannersPage extends ConsumerWidget {
  const BannersPage({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [AdminBanner? banner]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => BannerEditor(existing: banner),
    ));
    if (saved == true) ref.invalidate(_bannersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(_bannersProvider);
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
        child: Row(children: [
          Expanded(child: Text('Home banners', style: theme.textTheme.headlineSmall)),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_bannersProvider),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _edit(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('New banner'),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Text(
          'Shown in the carousel at the top of the customer app, lowest order number first. '
          'When none is live, the app shows banners made from the best discounts near the customer.',
          style: theme.textTheme.bodySmall,
        ),
      ),
      Expanded(
        child: AsyncView(
          value: banners,
          onRetry: () => ref.invalidate(_bannersProvider),
          data: (list) => list.isEmpty
              ? const EmptyView(
                  icon: Icons.view_carousel_outlined,
                  title: 'No banners yet',
                  message: 'Add one to promote a category, a shop or a product.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _BannerRow(banner: list[i], onTap: () => _edit(context, ref, list[i])),
                ),
        ),
      ),
    ]);
  }
}

class _BannerRow extends StatelessWidget {
  const _BannerRow({required this.banner, required this.onTap});

  final AdminBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = banner;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final (label, color) = b.live
        ? ('Live', Colors.green.shade700)
        : !b.active
            ? ('Off', Colors.grey.shade700)
            : b.startsAt != null && b.startsAt!.isAfter(now)
                ? ('Scheduled', Colors.blue.shade700)
                : b.endsAt != null && !b.endsAt!.isAfter(now)
                    ? ('Ended', Colors.grey.shade700)
                    : ('Not shown: link is not live', Colors.orange.shade800);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(children: [
          SizedBox(
            width: 220,
            height: 90,
            child: Image.network(b.imageUrl, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.title, style: theme.textTheme.titleMedium),
                if (b.subtitle != null) Text(b.subtitle!, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  [
                    'Opens: ${_targetText(b)}',
                    b.scope.label,
                    'Order ${b.position}',
                    if (b.startsAt != null) 'from ${_dates.format(b.startsAt!)}',
                    if (b.endsAt != null) 'until ${_dates.format(b.endsAt!.subtract(const Duration(seconds: 1)))}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ]),
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: StatusChip(label: label, color: color)),
        ]),
      ),
    );
  }

  static String _targetText(AdminBanner b) => switch (b.targetType) {
        BannerTarget.NONE => 'nothing',
        BannerTarget.CATEGORY => b.targetCategory?.label ?? 'a category',
        BannerTarget.SHOP => b.targetName ?? 'a shop',
        BannerTarget.LISTING => b.targetName ?? 'a product',
      };
}

/// Create or edit a banner.
class BannerEditor extends ConsumerStatefulWidget {
  const BannerEditor({super.key, this.existing});

  final AdminBanner? existing;

  @override
  ConsumerState<BannerEditor> createState() => _BannerEditorState();
}

class _BannerEditorState extends ConsumerState<BannerEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _subtitle = TextEditingController(text: widget.existing?.subtitle);
  late final _kicker = TextEditingController(text: widget.existing?.kicker);
  late final _position = TextEditingController(text: '${widget.existing?.position ?? 0}');
  late String? _imageUrl = widget.existing?.imageUrl;
  late BannerTarget _target = widget.existing?.targetType ?? BannerTarget.CATEGORY;
  late VendorCategory? _category = widget.existing?.targetCategory ?? VendorCategory.GROCERY;
  late String? _targetId = widget.existing?.targetId;
  late String? _targetName = widget.existing?.targetName;
  late BannerScope _scope = widget.existing?.scope ?? BannerScope.BOTH;
  late DateTime? _start = widget.existing?.startsAt;
  // Stored as the moment it ends (midnight after the last day); shown as the last day.
  late DateTime? _end = widget.existing?.endsAt;
  late bool _active = widget.existing?.active ?? true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _subtitle, _kicker, _position]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_imageUrl == null) {
      showMessage(context, 'Add a banner image');
      return;
    }
    if ((_target == BannerTarget.SHOP || _target == BannerTarget.LISTING) && _targetId == null) {
      showMessage(context, _target == BannerTarget.SHOP ? 'Choose a shop' : 'Choose a product');
      return;
    }
    setState(() => _saving = true);
    try {
      String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      await ref.read(apiProvider).saveBanner(widget.existing?.id, {
        'title': _title.text.trim(),
        'subtitle': t(_subtitle),
        'kicker': t(_kicker),
        'imageUrl': _imageUrl,
        'targetType': _target.name,
        'targetCategory': _target == BannerTarget.CATEGORY ? _category?.name : null,
        'targetId': _target == BannerTarget.SHOP || _target == BannerTarget.LISTING ? _targetId : null,
        'scope': _scope.name,
        'startsAt': _start?.toUtc().toIso8601String(),
        'endsAt': _end?.toUtc().toIso8601String(),
        'position': int.tryParse(_position.text) ?? 0,
        'active': _active,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this banner?'),
        content: const Text('Customers stop seeing it straight away.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).deleteBanner(widget.existing!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _pickTarget() async {
    final picked = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _TargetPicker(shops: _target == BannerTarget.SHOP),
    );
    if (picked != null) {
      setState(() {
        _targetId = picked.$1;
        _targetName = picked.$2;
      });
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final current = start ? _start : _end?.subtract(const Duration(days: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (day == null) return;
    setState(() {
      if (start) {
        _start = DateTime(day.year, day.month, day.day);
      } else {
        _end = DateTime(day.year, day.month, day.day + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New banner' : 'Edit banner'),
        actions: [
          if (widget.existing != null)
            TextButton.icon(onPressed: _delete, icon: const Icon(Icons.delete_outline), label: const Text('Delete')),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _form,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              ImageField(
                url: _imageUrl,
                category: _category ?? VendorCategory.OTHER,
                label: 'Banner image',
                hint: 'A wide photo, about 1200 × 460. The text goes on the left, so keep the subject on the right.',
                aspectRatio: 2.6,
                onChanged: (u) => setState(() => _imageUrl = u),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _kicker,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Small line above the headline (optional)',
                    hintText: 'FRESH SAVINGS NEAR YOU'),
              ),
              TextFormField(
                controller: _title,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Headline', hintText: 'Up to 50% Off'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _subtitle,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Second line (optional)',
                    hintText: 'On Fresh Fruits & Vegetables'),
              ),
              const SizedBox(height: 8),
              Text('When tapped, open', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in BannerTarget.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _target == t,
                    onSelected: (_) => setState(() {
                      if (t != _target) {
                        _targetId = null;
                        _targetName = null;
                      }
                      _target = t;
                    }),
                  ),
              ]),
              const SizedBox(height: 12),
              if (_target == BannerTarget.CATEGORY)
                DropdownButtonFormField<VendorCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in VendorCategory.values) DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (c) => setState(() => _category = c),
                ),
              if (_target == BannerTarget.SHOP || _target == BannerTarget.LISTING)
                OutlinedButton.icon(
                  onPressed: _pickTarget,
                  icon: Icon(_target == BannerTarget.SHOP ? Icons.storefront_outlined : Icons.sell_outlined),
                  label: Text(_targetName ?? (_target == BannerTarget.SHOP ? 'Choose a shop' : 'Choose a product')),
                ),
              const SizedBox(height: 20),
              Text('Show on', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<BannerScope>(
                segments: [for (final s in BannerScope.values) ButtonSegment(value: s, label: Text(s.label))],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: _DateButton(
                    label: 'Starts',
                    value: _start,
                    empty: 'Straight away',
                    onPick: () => _pickDate(start: true),
                    onClear: () => setState(() => _start = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    label: 'Last day',
                    value: _end?.subtract(const Duration(days: 1)),
                    empty: 'No end date',
                    onPick: () => _pickDate(start: false),
                    onClear: () => setState(() => _end = null),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: _position,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Order', helperText: 'Lower shows first'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 0 || n > 999 ? '0 to 999' : null;
                    },
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Switched on'),
                    subtitle: const Text('Turn off to hide it without deleting'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save banner'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.empty,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final String empty;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.event_outlined)
              : IconButton(tooltip: 'Clear', onPressed: onClear, icon: const Icon(Icons.close)),
        ),
        child: Text(value == null ? empty : _dates.format(value!)),
      ),
    );
  }
}

/// Picks an approved shop or a live product; returns (id, name).
class _TargetPicker extends ConsumerWidget {
  const _TargetPicker({required this.shops});

  final bool shops;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return AlertDialog(
      title: Text(shops ? 'Choose a shop' : 'Choose a product or offer'),
      content: SizedBox(
        width: 480,
        height: 480,
        child: shops
            ? PagedList<Vendor>(
                queryKey: 'shops',
                padding: EdgeInsets.zero,
                separator: 0,
                fetch: (page) => api.adminVendors(status: VendorStatus.APPROVED, page: page),
                empty: const EmptyView(icon: Icons.storefront_outlined, title: 'No approved shops'),
                itemBuilder: (context, v) => ListTile(
                  leading: CatalogueImage(url: v.json['logoUrl'] as String?, category: v.category, size: 36),
                  title: Text(v.displayName),
                  subtitle: Text('${v.category.label} · ${v.area}'),
                  onTap: () => Navigator.pop(context, (v.id, v.displayName)),
                ),
              )
            : PagedList<(Listing, String?)>(
                queryKey: 'listings',
                padding: EdgeInsets.zero,
                separator: 0,
                fetch: (page) => api.adminListings(status: ListingStatus.ACTIVE, page: page),
                empty: const EmptyView(icon: Icons.sell_outlined, title: 'No live products or offers'),
                itemBuilder: (context, row) => ListTile(
                  leading: CatalogueImage(url: row.$1.imageUrl, category: row.$1.category, size: 36),
                  title: Text(row.$1.title),
                  subtitle: Text(row.$2 ?? ''),
                  onTap: () => Navigator.pop(context, (row.$1.id, row.$1.title)),
                ),
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}
