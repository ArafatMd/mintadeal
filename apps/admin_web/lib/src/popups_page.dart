import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dialogs.dart';

/// Pop-up stalls: what is live, what customers reported, and every past stall. Stalls go live without review,
/// so this is where they are taken down and sellers blocked.
class PopupsPage extends ConsumerStatefulWidget {
  const PopupsPage({super.key});

  @override
  ConsumerState<PopupsPage> createState() => _PopupsPageState();
}

class _PopupsPageState extends ConsumerState<PopupsPage> {
  PopupFilter _filter = PopupFilter.LIVE;
  (String, String)? _seller;
  int _reload = 0;

  Future<void> _act(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) showMessage(context, done);
      setState(() => _reload++);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Pop-up stalls', style: theme.textTheme.headlineSmall),
          const SizedBox(width: 8),
          if (_seller != null)
            InputChip(
              label: Text('All stalls of ${_seller!.$2}'),
              onDeleted: () => setState(() => _seller = null),
            )
          else
            for (final f in PopupFilter.values)
              ChoiceChip(
                label: Text(switch (f) {
                  PopupFilter.LIVE => 'Live',
                  PopupFilter.REPORTED => 'Reported',
                  PopupFilter.ENDED => 'Ended',
                  PopupFilter.REMOVED => 'Taken down',
                }),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
          IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _reload++), icon: const Icon(Icons.refresh)),
        ]),
      ),
      Expanded(
        child: PagedList<AdminPopup>(
          queryKey: (_filter, _seller?.$1, _reload),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          separator: 10,
          fetch: (page) => api.adminPopups(filter: _filter, sellerId: _seller?.$1, page: page),
          empty: const EmptyView(icon: Icons.storefront_outlined, title: 'No stalls here'),
          itemBuilder: (context, p) => _PopupTile(
            popup: p,
            onRemove: () async {
              final reason = await askReason(context, title: 'Take this stall down?', action: 'Take down');
              if (reason != null) await _act(() => api.removePopup(p.id, reason), 'Taken down');
            },
            onRestore: () => _act(() => api.restorePopup(p.id), 'Shown again'),
            onBlock: () async {
              final reason = await askReason(context, title: 'Block ${p.sellerName}?', action: 'Block');
              if (reason != null) await _act(() => api.blockPopupSeller(p.sellerId, reason), 'Seller blocked');
            },
            onUnblock: () => _act(() => api.unblockPopupSeller(p.sellerId), 'Seller unblocked'),
            onHistory: () => setState(() => _seller = (p.sellerId, p.sellerName)),
          ),
        ),
      ),
    ]);
  }
}

class _PopupTile extends StatelessWidget {
  const _PopupTile({
    required this.popup,
    required this.onRemove,
    required this.onRestore,
    required this.onBlock,
    required this.onUnblock,
    required this.onHistory,
  });

  final AdminPopup popup;
  final VoidCallback onRemove;
  final VoidCallback onRestore;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final p = popup;
    final theme = Theme.of(context);
    final date = DateFormat('d MMM, h:mm a');
    final (statusLabel, statusColor) = switch (p.status) {
      PopupStatus.LIVE => ('Live', Colors.green.shade700),
      PopupStatus.ENDED => ('Ended', theme.colorScheme.outline),
      PopupStatus.REMOVED => ('Taken down', theme.colorScheme.error),
    };
    final area = nearestArea(GeoPoint(p.latitude, p.longitude)).name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(p.sellerName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (p.reportCount > 0) ...[
              Chip(
                avatar: Icon(Icons.flag, size: 16, color: theme.colorScheme.error),
                label: Text('${p.reportCount} ${p.reportCount == 1 ? 'report' : 'reports'}'),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
            ],
            if (p.sellerBlocked) ...[
              StatusChip(label: 'Seller blocked', color: theme.colorScheme.error),
              const SizedBox(width: 6),
            ],
            StatusChip(label: statusLabel, color: statusColor),
          ]),
          const SizedBox(height: 4),
          Text(
            [
              p.phone ?? '',
              'Near $area',
              '${p.days} ${p.days == 1 ? 'day' : 'days'}',
              'Started ${date.format(p.startsAt)}',
              if (p.status == PopupStatus.LIVE) 'ends ${date.format(p.endsAt)}',
              if (p.stoppedAt != null) 'stopped ${date.format(p.stoppedAt!)}',
              if (p.movedAt != null) 'moved ${date.format(p.movedAt!)}',
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          if (p.removedReason != null)
            Text(p.removedReason!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: p.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final item = p.items[i];
                return Tooltip(
                  message: [item.title ?? 'No name', if (item.priceMinor != null) formatInr(item.priceMinor!)].join(' · '),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(item.imageUrl, width: 90, height: 90, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(width: 90, height: 90, color: Colors.black12)),
                  ),
                );
              },
            ),
          ),
          for (final r in p.reports)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${r.reason.label}${r.note == null ? '' : ': ${r.note}'} · ${date.format(r.createdAt)}',
                  style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (p.status == PopupStatus.LIVE)
              OutlinedButton.icon(onPressed: onRemove, icon: const Icon(Icons.visibility_off_outlined), label: const Text('Take down')),
            if (p.status == PopupStatus.REMOVED && p.endsAt.isAfter(DateTime.now()) && !p.sellerBlocked)
              OutlinedButton.icon(onPressed: onRestore, icon: const Icon(Icons.visibility_outlined), label: const Text('Show again')),
            if (p.sellerBlocked)
              TextButton(onPressed: onUnblock, child: const Text('Unblock seller'))
            else
              TextButton(onPressed: onBlock, child: const Text('Block seller')),
            TextButton(onPressed: onHistory, child: const Text('All stalls of this seller')),
            TextButton.icon(
              onPressed: () => launchUrl(
                  Uri.parse('https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}'),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Map'),
            ),
          ]),
        ]),
      ),
    );
  }
}
