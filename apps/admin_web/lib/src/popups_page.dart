import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dialogs.dart';

final _settingsProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).popupSettings());

String _feeText(int perDay) => perDay == 0 ? 'free' : '${formatInr(perDay)} a day';

/// The master controls: how many stalls at once and the fee per day, for shops and for other sellers.
Future<void> editPopupDefaults(BuildContext context, WidgetRef ref) async {
  final current = await ref.read(apiProvider).popupSettings();
  if (!context.mounted) return;
  final shopMax = TextEditingController(text: '${current.shopMaxLive}');
  final shopFee = TextEditingController(text: rupeesText(current.shopFeePerDayMinor));
  final sellerMax = TextEditingController(text: '${current.sellerMaxLive}');
  final sellerFee = TextEditingController(text: rupeesText(current.sellerFeePerDayMinor));
  final saved = await showDialog<PopupSettings>(
    context: context,
    builder: (context) {
      Widget pair(String title, String hint, TextEditingController max, TextEditingController fee) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(hint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(controller: max, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stalls at once', helperText: '1 to 20')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(controller: fee, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Fee per day', prefixText: '₹ ', helperText: '0 = free')),
                ),
              ]),
            ],
          );
      return AlertDialog(
        title: const Text('Pop-up stall defaults'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            pair('Shops', 'Approved shops and hotels. Fees come off the shop\'s balance.', shopMax, shopFee),
            const SizedBox(height: 20),
            pair('Other sellers', 'Hawkers, street and event stalls. They pay the fee online before going live.',
                sellerMax, sellerFee),
            const SizedBox(height: 12),
            Text('A seller with their own limits (set from their stall) keeps them.',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              PopupSettings(
                shopMaxLive: int.tryParse(shopMax.text.trim()) ?? 1,
                shopFeePerDayMinor: parseRupees(shopFee.text) ?? 0,
                sellerMaxLive: int.tryParse(sellerMax.text.trim()) ?? 1,
                sellerFeePerDayMinor: parseRupees(sellerFee.text) ?? 0,
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
  if (saved == null) return;
  try {
    await ref.read(apiProvider).updatePopupSettings(saved);
    ref.invalidate(_settingsProvider);
    if (context.mounted) showMessage(context, 'Defaults saved');
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

/// One seller's own limit and fee; empty fields use the defaults.
Future<void> editSellerLimits(BuildContext context, WidgetRef ref, String userId) async {
  final api = ref.read(apiProvider);
  final SellerLimits current;
  try {
    current = await api.sellerLimits(userId);
  } catch (e) {
    if (context.mounted) showError(context, e);
    return;
  }
  if (!context.mounted) return;
  final max = TextEditingController(text: current.maxLive?.toString() ?? '');
  final fee = TextEditingController(text: current.feePerDayMinor == null ? '' : rupeesText(current.feePerDayMinor));
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Pop-up limits: ${current.name ?? current.phone ?? ''}'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(current.shopName == null ? 'Independent seller' : 'Shop: ${current.shopName}'),
          Text('Now: ${current.effectiveMaxLive} at once, ${_feeText(current.effectiveFeePerDayMinor)}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(controller: max, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stalls at once', helperText: 'Empty = default')),
          const SizedBox(height: 8),
          TextField(controller: fee, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Fee per day', prefixText: '₹ ',
                  helperText: 'Empty = default, 0 = free for this seller')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final r = await api.setSellerLimits(userId,
        maxLive: int.tryParse(max.text.trim()), feePerDayMinor: fee.text.trim().isEmpty ? null : parseRupees(fee.text));
    if (context.mounted) {
      showMessage(context, 'Saved: ${r.effectiveMaxLive} at once, ${_feeText(r.effectiveFeePerDayMinor)}');
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

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
                  PopupFilter.SHOPS => 'From shops',
                  PopupFilter.ENDED => 'Ended',
                  PopupFilter.REMOVED => 'Taken down',
                }),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
          IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _reload++), icon: const Icon(Icons.refresh)),
          OutlinedButton.icon(
            onPressed: () => editPopupDefaults(context, ref),
            icon: const Icon(Icons.tune),
            label: const Text('Defaults'),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Consumer(builder: (context, ref, _) {
          final s = ref.watch(_settingsProvider).value;
          if (s == null) return const SizedBox.shrink();
          return Text(
            'Shops: ${s.shopMaxLive} at once, ${_feeText(s.shopFeePerDayMinor)} · '
            'Other sellers: ${s.sellerMaxLive} at once, ${_feeText(s.sellerFeePerDayMinor)}',
            style: theme.textTheme.bodySmall,
          );
        }),
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
            onLimits: () => editSellerLimits(context, ref, p.sellerId),
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
    required this.onLimits,
  });

  final AdminPopup popup;
  final VoidCallback onRemove;
  final VoidCallback onRestore;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  final VoidCallback onHistory;
  final VoidCallback onLimits;

  @override
  Widget build(BuildContext context) {
    final p = popup;
    final theme = Theme.of(context);
    final date = DateFormat('d MMM, h:mm a');
    final (statusLabel, statusColor) = switch (p.status) {
      PopupStatus.PENDING_PAYMENT => ('Waiting for fee', Colors.orange.shade800),
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
            if (p.vendorName != null) ...[
              Chip(
                avatar: const Icon(Icons.verified, size: 16, color: Color(0xFF1565C0)),
                label: Text(p.vendorName!),
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
              if (p.feeMinor > 0)
                'fee ${formatInr(p.feeMinor)} ${p.paymentProvider == 'SHOP_BALANCE' ? 'from shop balance' : p.paidAt != null ? 'paid online' : 'not paid'}',
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
            TextButton(onPressed: onLimits, child: const Text('Limits and fee')),
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
