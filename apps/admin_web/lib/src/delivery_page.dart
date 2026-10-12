import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'dialogs.dart';

/// Delivery partner jobs: assign riders to waiting jobs, follow active ones, cancel when needed.
class DeliveryPage extends ConsumerStatefulWidget {
  const DeliveryPage({super.key});

  @override
  ConsumerState<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends ConsumerState<DeliveryPage> {
  String _status = 'ACTIVE';
  int _reload = 0;

  Future<void> _assign(DeliveryJobView j) async {
    final phone = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign ${j.orderCode}'),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: phone,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: "Delivery partner's mobile number", prefixText: '+91 '),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, phone.text.trim()), child: const Text('Assign')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    try {
      await ref.read(apiProvider).adminAssignJob(j.id, value);
      setState(() => _reload++);
      if (mounted) showMessage(context, 'Assigned');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _cancel(DeliveryJobView j) async {
    final reason = await askReason(context, title: 'Cancel delivery ${j.orderCode}', action: 'Cancel job');
    if (reason == null) return;
    try {
      await ref.read(apiProvider).adminCancelJob(j.id, reason);
      setState(() => _reload++);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final time = DateFormat('d MMM, h:mm a');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Delivery', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(width: 16),
          for (final (value, label) in const [
            ('ACTIVE', 'On the road'),
            ('REQUESTED', 'Waiting for a rider'),
            ('DELIVERED', 'Delivered'),
            ('FAILED', 'Failed'),
            ('CANCELLED', 'Cancelled'),
            ('ALL', 'All'),
          ])
            ChoiceChip(label: Text(label), selected: _status == value, onSelected: (_) => setState(() => _status = value)),
          IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _reload++), icon: const Icon(Icons.refresh)),
        ]),
      ),
      Expanded(
        child: PagedList<DeliveryJobView>(
          queryKey: (_status, _reload),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          separator: 8,
          fetch: (page) => api.adminJobs(status: _status, page: page),
          empty: const EmptyView(icon: Icons.delivery_dining_outlined, title: 'No delivery jobs'),
          itemBuilder: (context, j) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
              title: Text('${j.orderCode} · ${j.pickup.name ?? j.pickup.area} → ${j.drop.area}'),
              subtitle: Text([
                j.status.label,
                j.agentName != null || j.agentPhone != null ? 'rider ${j.agentName ?? ''} ${j.agentPhone ?? ''}'.trim() : 'no rider yet',
                '${j.distanceKm.toStringAsFixed(1)} km',
                if (j.costMinor != null) 'shop pays ${formatInr(j.costMinor!)}',
                if (j.cashToCollectMinor > 0) 'collect ${formatInr(j.cashToCollectMinor)}',
                'requested ${time.format(j.requestedAt)}',
                if (j.failureReason != null) j.failureReason!,
              ].join(' · ')),
              trailing: !j.status.isActive
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (j.status != JobStatus.PICKED_UP)
                        TextButton(onPressed: () => _assign(j), child: Text(j.agentPhone == null ? 'Assign rider' : 'Reassign')),
                      IconButton(tooltip: 'Cancel job', onPressed: () => _cancel(j), icon: const Icon(Icons.cancel_outlined)),
                    ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
