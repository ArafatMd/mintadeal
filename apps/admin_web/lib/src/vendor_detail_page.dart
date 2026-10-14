import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dialogs.dart';

final _vendorDetail = FutureProvider.autoDispose.family<VendorDetail, String>(
    (ref, id) => ref.watch(apiProvider).adminVendor(id));

final _vendorCharges = FutureProvider.autoDispose.family<ShopCharges, String>(
    (ref, id) => ref.watch(apiProvider).adminVendorCharges(id));

class VendorDetailPage extends ConsumerStatefulWidget {
  const VendorDetailPage({super.key, required this.vendorId});

  final String vendorId;

  @override
  ConsumerState<VendorDetailPage> createState() => _VendorDetailPageState();
}

class _VendorDetailPageState extends ConsumerState<VendorDetailPage> {
  bool _busy = false;

  Future<void> _act(Future<Object?> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(_vendorDetail(widget.vendorId));
      if (mounted) showMessage(context, done);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(_vendorDetail(widget.vendorId));
    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.vendor.displayName ?? 'Vendor')),
      body: AsyncView(
        value: detail,
        onRetry: () => ref.invalidate(_vendorDetail(widget.vendorId)),
        data: (d) => _body(context, d),
      ),
    );
  }

  Widget _body(BuildContext context, VendorDetail d) {
    final v = d.vendor;
    final j = v.json;
    final api = ref.read(apiProvider);
    final theme = Theme.of(context);
    final date = DateFormat('d MMM yyyy, h:mm a');
    String yesNo(String key) => j[key] == true ? 'Yes' : 'No';

    final actions = <Widget>[
      if (v.status == VendorStatus.PENDING || v.status == VendorStatus.REJECTED || v.status == VendorStatus.SUSPENDED)
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  final note = await askReason(context,
                      title: v.status == VendorStatus.SUSPENDED ? 'Reinstate shop' : 'Approve shop',
                      action: 'Approve', required: false);
                  if (note != null) {
                    await _act(() => api.approveVendor(v.id, note: note.isEmpty ? null : note), 'Approved');
                  }
                },
          icon: const Icon(Icons.check),
          label: Text(v.status == VendorStatus.SUSPENDED ? 'Reinstate' : 'Approve'),
        ),
      if (v.status == VendorStatus.PENDING)
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  final note = await askReason(context, title: 'Reject application', action: 'Reject');
                  if (note != null) await _act(() => api.rejectVendor(v.id, note), 'Rejected');
                },
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
        ),
      if (v.status == VendorStatus.APPROVED)
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  final note = await askReason(context, title: 'Suspend shop', action: 'Suspend');
                  if (note != null) await _act(() => api.suspendVendor(v.id, note), 'Suspended');
                },
          icon: const Icon(Icons.block),
          label: const Text('Suspend'),
        ),
      PopupMenuButton<VendorType>(
        tooltip: 'Vendor type',
        enabled: !_busy,
        onSelected: (t) => _act(() => api.setVendorType(v.id, t), 'Type set to ${t.label}'),
        itemBuilder: (_) => [
          for (final t in VendorType.values)
            CheckedPopupMenuItem(value: t, checked: v.vendorType == t, child: Text(t.label)),
        ],
        child: Chip(avatar: const Icon(Icons.tune, size: 18), label: Text(v.vendorType.label)),
      ),
    ];

    final info = <(String, String?)>[
      ('Category', v.category.label),
      ('Phone', v.phone),
      ('Address', '${j['addressLine']}, ${j['area']}, ${j['city']} ${j['pincode']}'),
      ('Opening hours', j['openingHours'] as String?),
      ('Description', j['description'] as String?),
      ('Legal name', j['legalName'] as String?),
      ('GSTIN', j['gstNumber'] as String?),
      ('Payout UPI', j['payoutUpiId'] as String?),
      ('Bank account', j['payoutAccountNumber'] as String?),
      ('IFSC', j['payoutIfsc'] as String?),
      ('Shop delivery', yesNo('selfDelivery')),
      ('Partner delivery', yesNo('partnerDelivery')),
      ('Pickup', yesNo('pickup')),
      ('Delivers across Bangalore', yesNo('citywideDelivery')),
      ('Delivery radius', '${j['deliveryRadiusKm']} km'),
      ('Delivery fee', formatInr((j['deliveryFeeMinor'] as num).toInt())),
      ('Minimum order', formatInr((j['minOrderMinor'] as num).toInt())),
      ('Applied', date.format(v.createdAt)),
      ('Review note', v.reviewNote),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          CatalogueImage(url: j['logoUrl'] as String?, category: v.category, size: 72),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.displayName, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              StatusChip(label: v.status.label, color: vendorStatusColor(v.status)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              for (final (label, value) in info)
                if (value != null && value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 200, child: Text(label, style: theme.textTheme.bodySmall)),
                      Expanded(child: SelectableText(value)),
                    ]),
                  ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _ShopOnMap(json: j),
        const SizedBox(height: 16),
        Consumer(builder: (context, ref, _) {
          final charges = ref.watch(_vendorCharges(v.id)).value;
          if (charges == null || charges.charges.isEmpty) return const SizedBox.shrink();
          return Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_outlined),
              title: Text('Unpaid delivery charges: ${formatInr(charges.outstandingMinor)}'),
              subtitle: Text('${charges.charges.length} partner ${charges.charges.length == 1 ? 'delivery' : 'deliveries'} · limit ${formatInr(charges.limitMinor)}'),
            ),
          );
        }),
        const SizedBox(height: 24),
        Text('Listings (${d.listings.length})', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (d.listings.isEmpty) const Text('No listings yet'),
        for (final l in d.listings)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CatalogueImage(url: l.imageUrl, category: l.category, size: 40),
            title: Text(l.title),
            subtitle: Text('${l.listingType.label} · ${formatInr(l.effectivePriceMinor)}'),
            trailing: StatusChip(label: l.status.label, color: listingStatusColor(l.status)),
          ),
        const SizedBox(height: 24),
        Text('History', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (d.history.isEmpty) const Text('No admin actions yet'),
        for (final h in d.history)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(h.action.replaceAll('_', ' ').toLowerCase()),
            subtitle: Text([date.format(h.createdAt), if (h.detail != null) h.detail!].join(' · ')),
          ),
      ],
    );
  }
}

/// Where the shop says it is, so the team can check the pin before approving.
class _ShopOnMap extends StatelessWidget {
  const _ShopOnMap({required this.json});

  final Map<String, dynamic> json;

  @override
  Widget build(BuildContext context) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final pinned = json['locationPinned'] == true;
    final point = GeoPoint(lat, lng);
    final area = bengaluruAreas.where((a) => a.name == json['area']).firstOrNull;
    final fromArea = area == null ? null : distanceKm(point, area.point);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Shop on the map', style: theme.textTheme.titleMedium)),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open in Google Maps'),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(pinned ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 18, color: pinned ? Colors.green.shade700 : theme.colorScheme.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                pinned
                    ? 'Pinned by the shop'
                    : 'Not pinned: this is the centre of ${json['area']}, so distances to this shop are rough',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ]),
          if (pinned && fromArea != null && fromArea > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'The pin is ${formatDistance(fromArea).replaceFirst('~', '')} from the centre of ${json['area']}. '
                'Check the area or the pin.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          PinMap(point: point, height: 260, zoom: pinned ? 17 : 14),
          const SizedBox(height: 6),
          SelectableText('${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}', style: theme.textTheme.bodySmall),
        ]),
      ),
    );
  }
}
