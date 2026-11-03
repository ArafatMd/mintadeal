import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sign_in.dart';
import 'storefront_screen.dart';

/// Live pop-up stalls near a point; none when they cannot be loaded, so home never breaks because of them.
final nearbyPopupsProvider = FutureProvider.autoDispose.family<List<PublicPopup>, (double, double)>((ref, at) async {
  try {
    return await ref.watch(apiProvider).nearbyPopups(GeoPoint(at.$1, at.$2));
  } on Object {
    return const [];
  }
});

/// "Ends in 5 h", "Ends in 2 days".
String endsIn(DateTime endsAt) {
  final left = endsAt.difference(DateTime.now());
  if (left.inMinutes < 60) return 'Ends in ${left.inMinutes.clamp(1, 59)} min';
  if (left.inHours < 24) return 'Ends in ${left.inHours} h';
  final d = (left.inHours / 24).round();
  return 'Ends in $d ${d == 1 ? 'day' : 'days'}';
}

/// A row of stalls on the home screen. Hidden when there are none nearby.
class PopupRow extends ConsumerWidget {
  const PopupRow({super.key, required this.at});

  final GeoPoint at;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popups = ref.watch(nearbyPopupsProvider((at.lat, at.lng))).value ?? const [];
    if (popups.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 0, 8),
        child: Row(children: [
          Icon(Icons.storefront, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Pop-up stalls',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => PopupsScreen(at: at, startOnMap: true))),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary, visualDensity: VisualDensity.compact),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Map', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PopupsScreen(at: at))),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary, visualDensity: VisualDensity.compact),
            child: Text('All ${popups.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      SizedBox(
        height: 196,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: popups.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) => _PopupCard(popup: popups[i], at: at),
        ),
      ),
    ]);
  }
}

class _PopupCard extends StatelessWidget {
  const _PopupCard({required this.popup, required this.at});

  final PublicPopup popup;
  final GeoPoint at;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = popup.items.first;
    final prices = popup.items.map((i) => i.priceMinor).whereType<int>().toList()..sort();
    return SizedBox(
      width: 150,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => PopupScreen(popupId: popup.id, at: at))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              Image.network(first.imageUrl, height: 110, width: 150, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(height: 110, color: theme.colorScheme.surfaceContainerHighest)),
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF1B7F3B), borderRadius: BorderRadius.circular(6)),
                  child: const Text('HERE NOW',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(popup.sellerName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  if (popup.vendorId != null) ...[
                    const SizedBox(width: 3),
                    Tooltip(
                      message: 'Run by ${popup.vendorName}, a shop checked by Mintadeal',
                      child: const Icon(Icons.verified, size: 16, color: Color(0xFF1565C0)),
                    ),
                  ],
                ]),
                Text(
                  [
                    if (popup.distanceKm != null) formatDistance(popup.distanceKm!),
                    if (prices.isNotEmpty) 'from ${formatInr(prices.first)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
                Text(endsIn(popup.endsAt), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// One stall: its photos and prices, and ways to reach it. No ordering: customers pay the seller there.
class PopupScreen extends ConsumerWidget {
  const PopupScreen({super.key, required this.popupId, this.at});

  final String popupId;
  final GeoPoint? at;

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    if (!await ensureSignedIn(context, ref) || !context.mounted) return;
    final note = TextEditingController();
    final reason = await showModalBottomSheet<PopupReportReason>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const ListTile(title: Text('What is wrong?', style: TextStyle(fontWeight: FontWeight.w700))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(controller: note, maxLength: 300,
                  decoration: const InputDecoration(labelText: 'Tell us more (optional)')),
            ),
            for (final r in PopupReportReason.values)
              ListTile(title: Text(r.label), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pop(context, r)),
          ]),
        ),
      ),
    );
    if (reason == null) return;
    try {
      await ref.read(apiProvider).reportPopup(popupId, reason, note: note.text.trim().isEmpty ? null : note.text.trim());
      if (context.mounted) showMessage(context, 'Thanks. Mintadeal will check this stall.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.watch(_popupProvider((popupId, at?.lat, at?.lng)));
    return Scaffold(
      appBar: AppBar(
        title: Text(future.value?.sellerName ?? 'Pop-up stall'),
        actions: [
          IconButton(tooltip: 'Report this stall', icon: const Icon(Icons.flag_outlined), onPressed: () => _report(context, ref)),
        ],
      ),
      body: AsyncView(
        value: future,
        onRetry: () => ref.invalidate(_popupProvider((popupId, at?.lat, at?.lng))),
        data: (p) => _body(context, ref, p),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, PublicPopup p) {
    void tapped(PopupReaction r) => ref.read(apiProvider).popupEvent(p.id, r);
    final theme = Theme.of(context);
    final phone = p.phone;
    final digits = phone?.replaceAll(RegExp(r'[^0-9]'), '');
    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Chip(
          avatar: const Icon(Icons.wifi_tethering, size: 18, color: Colors.white),
          label: const Text('Here now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF1B7F3B),
          side: BorderSide.none,
        ),
        Text([
          if (p.distanceKm != null) '${formatDistance(p.distanceKm!)} away',
          endsIn(p.endsAt),
        ].join(' · '), style: theme.textTheme.titleSmall),
      ]),
      const SizedBox(height: 8),
      if (p.vendorId != null)
        Card(
          margin: EdgeInsets.zero,
          color: const Color(0xFFE3F2FD),
          child: ListTile(
            leading: const Icon(Icons.verified, color: Color(0xFF1565C0)),
            title: Text('From ${p.vendorName}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Verified shop on Mintadeal. Pay at the stall when you buy.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => StorefrontScreen(vendorId: p.vendorId!, at: at))),
          ),
        )
      else
        Row(children: [
          Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Pop-up stall, not checked by Mintadeal. Pay the seller directly when you buy.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ]),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
          onPressed: () {
            tapped(PopupReaction.DIRECTIONS);
            launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}'),
                mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.directions),
          label: const Text('Directions'),
        ),
        if (phone != null)
          OutlinedButton.icon(
            onPressed: () {
              tapped(PopupReaction.CALL);
              launchUrl(Uri(scheme: 'tel', path: phone));
            },
            icon: const Icon(Icons.call),
            label: const Text('Call'),
          ),
        if (digits != null)
          OutlinedButton.icon(
            onPressed: () {
              tapped(PopupReaction.WHATSAPP);
              launchUrl(Uri.parse('https://wa.me/$digits'), mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.chat_outlined),
            label: const Text('WhatsApp'),
          ),
      ]),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final columns = c.maxWidth >= 600 ? 3 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
          children: [
            for (final item in p.items)
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(
                    child: Image.network(item.imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: theme.colorScheme.surfaceContainerHighest)),
                  ),
                  if (item.title != null || item.priceMinor != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (item.title != null)
                          Text(item.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                        if (item.priceMinor != null)
                          Text(formatInr(item.priceMinor!),
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ]),
                    ),
                ]),
              ),
          ],
        );
      }),
      const SizedBox(height: 16),
      PinMap(point: GeoPoint(p.latitude, p.longitude), height: 200, zoom: 16),
    ]);
  }
}

final _popupProvider = FutureProvider.autoDispose.family<PublicPopup, (String, double?, double?)>((ref, k) async {
  final api = ref.watch(apiProvider);
  final p = await api.popup(k.$1, at: k.$2 == null ? null : GeoPoint(k.$2!, k.$3!));
  // Counted once each time the page opens, for the admin's report to the seller.
  api.popupEvent(p.id, PopupReaction.VIEW);
  return p;
});

/// Every stall near the customer, as a list or on a map.
class PopupsScreen extends ConsumerStatefulWidget {
  const PopupsScreen({super.key, required this.at, this.startOnMap = false});

  final GeoPoint at;
  final bool startOnMap;

  @override
  ConsumerState<PopupsScreen> createState() => _PopupsScreenState();
}

class _PopupsScreenState extends ConsumerState<PopupsScreen> {
  late bool _map = widget.startOnMap;
  PublicPopup? _selected;

  void _open(PublicPopup p) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PopupScreen(popupId: p.id, at: widget.at)));

  @override
  Widget build(BuildContext context) {
    final key = (widget.at.lat, widget.at.lng);
    final popups = ref.watch(nearbyPopupsProvider(key));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pop-up stalls'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.view_list), label: Text('List')),
                ButtonSegment(value: true, icon: Icon(Icons.map_outlined), label: Text('Map')),
              ],
              selected: {_map},
              onSelectionChanged: (v) => setState(() => _map = v.first),
            ),
          ),
        ],
      ),
      body: AsyncView(
        value: popups,
        onRetry: () => ref.invalidate(nearbyPopupsProvider(key)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(icon: Icons.storefront_outlined, title: 'No pop-up stalls near you right now',
                message: 'Street, market and event stalls appear here while they are open.');
          }
          return _map ? _mapView(list) : _listView(list);
        },
      ),
    );
  }

  Widget _listView(List<PublicPopup> list) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(nearbyPopupsProvider((widget.at.lat, widget.at.lng)).future),
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final p = list[i];
          final prices = p.items.map((x) => x.priceMinor).whereType<int>().toList()..sort();
          return Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(p),
              child: Row(children: [
                Image.network(p.items.first.imageUrl, width: 96, height: 96, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(width: 96, height: 96, color: Colors.black12)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _NameLine(popup: p, style: theme.textTheme.titleMedium),
                    Text([
                      if (p.distanceKm != null) formatDistance(p.distanceKm!),
                      if (prices.isNotEmpty) 'from ${formatInr(prices.first)}',
                    ].join(' · '), style: theme.textTheme.bodyMedium),
                    Text(endsIn(p.endsAt), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                  ]),
                ),
                const Icon(Icons.chevron_right),
                const SizedBox(width: 8),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _mapView(List<PublicPopup> list) {
    final theme = Theme.of(context);
    final you = LatLng(widget.at.lat, widget.at.lng);
    final points = [you, for (final p in list) LatLng(p.latitude, p.longitude)];
    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          initialCenter: you,
          initialZoom: 15,
          initialCameraFit: CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(56), maxZoom: 17),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onTap: (_, _) => setState(() => _selected = null),
        ),
        children: [
          ...mapBaseLayers(),
          MarkerLayer(markers: [
            Marker(
              point: you,
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
              ),
            ),
            for (final p in list)
              Marker(
                point: LatLng(p.latitude, p.longitude),
                width: 52,
                height: 52,
                child: Semantics(
                  button: true,
                  label: p.sellerName,
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = p),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _selected?.id == p.id ? theme.colorScheme.primary : const Color(0xFF1B7F3B),
                            width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: ClipOval(
                        child: Image.network(p.items.first.imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(color: Colors.white,
                                child: const Icon(Icons.storefront, color: Color(0xFF1B7F3B)))),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ],
      ),
      if (_selected != null)
        Positioned(
          left: 12,
          right: 12,
          bottom: 16,
          child: Card(
            elevation: 6,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(_selected!),
              child: Row(children: [
                Image.network(_selected!.items.first.imageUrl, width: 88, height: 88, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(width: 88, height: 88, color: Colors.black12)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _NameLine(popup: _selected!, style: theme.textTheme.titleMedium),
                    Text([
                      if (_selected!.distanceKm != null) formatDistance(_selected!.distanceKm!),
                      endsIn(_selected!.endsAt),
                    ].join(' · '), style: theme.textTheme.bodyMedium),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: FilledButton(onPressed: () => _open(_selected!), child: const Text('Open')),
                ),
              ]),
            ),
          ),
        )
      else
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
              child: Text('${list.length} ${list.length == 1 ? 'stall' : 'stalls'} here now · tap a photo',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
    ]);
  }
}

class _NameLine extends StatelessWidget {
  const _NameLine({required this.popup, this.style});

  final PublicPopup popup;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(children: [
        Flexible(
          child: Text(popup.sellerName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: style?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (popup.vendorId != null) ...[
          const SizedBox(width: 4),
          const Icon(Icons.verified, size: 18, color: Color(0xFF1565C0)),
        ],
      ]);
}
