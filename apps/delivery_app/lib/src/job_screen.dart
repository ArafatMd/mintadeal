import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:url_launcher/url_launcher.dart';

final _job = FutureProvider.autoDispose.family<DeliveryJobView, String>((ref, id) => ref.watch(apiProvider).job(id));

class JobScreen extends ConsumerStatefulWidget {
  const JobScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends ConsumerState<JobScreen> {
  bool _busy = false;

  Future<void> _act(String action, {String? code, String? reason, String? done}) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).jobAction(widget.jobId, action, code: code, reason: reason);
      ref.invalidate(_job(widget.jobId));
      if (mounted && done != null) showMessage(context, done);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deliver() async {
    final code = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ask the customer for the 4-digit code in their Mintadeal app.'),
          const SizedBox(height: 12),
          TextField(
            controller: code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 8),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, code.text.trim()), child: const Text('Confirm delivery')),
        ],
      ),
    );
    if (entered == null || entered.isEmpty) return;
    await _act('delivered', code: entered, done: 'Delivered. Thank you!');
  }

  Future<void> _fail() async {
    String? chosen;
    final other = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Could not deliver?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('The order goes back to the shop. Return the items to the shop.'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final r in ['Customer not reachable', 'Wrong address', 'Customer refused the order'])
                ChoiceChip(label: Text(r), selected: chosen == r, onSelected: (_) => setState(() => chosen = r)),
            ]),
            TextField(
              controller: other,
              decoration: const InputDecoration(labelText: 'Or write what happened'),
              onChanged: (_) => setState(() => chosen = null),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
            FilledButton(
              onPressed: (chosen ?? other.text.trim()).isEmpty ? null : () => Navigator.pop(context, chosen ?? other.text.trim()),
              child: const Text('Mark as failed'),
            ),
          ],
        ),
      ),
    );
    if (reason != null) await _act('failed', reason: reason, done: 'Marked as not delivered');
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(_job(widget.jobId));
    return Scaffold(
      appBar: AppBar(title: Text(job.value?.orderCode ?? 'Job')),
      body: AsyncView(
        value: job,
        onRetry: () => ref.invalidate(_job(widget.jobId)),
        data: (j) => RefreshIndicator(onRefresh: () => ref.refresh(_job(widget.jobId).future), child: _body(context, j)),
      ),
      bottomNavigationBar: job.value == null ? null : _actions(job.value!),
    );
  }

  Widget? _actions(DeliveryJobView j) {
    final buttons = <Widget>[
      if (j.status == JobStatus.REQUESTED && !j.mine)
        FilledButton.icon(
          onPressed: _busy ? null : () => _act('claim', done: 'Job is yours. Head to the shop.'),
          icon: const Icon(Icons.check),
          label: const Text('Take this job'),
        ),
      if (j.status == JobStatus.ASSIGNED && j.mine) ...[
        OutlinedButton(onPressed: _busy ? null : () => _act('release', done: 'Job handed back'), child: const Text('Hand back')),
        FilledButton.icon(
          onPressed: _busy ? null : () => _act('picked-up', done: 'Picked up. Deliver to the customer.'),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Picked up from shop'),
        ),
      ],
      if (j.status == JobStatus.PICKED_UP && j.mine) ...[
        OutlinedButton(onPressed: _busy ? null : _fail, child: const Text('Could not deliver')),
        FilledButton.icon(onPressed: _busy ? null : _deliver, icon: const Icon(Icons.done_all), label: const Text('Delivered')),
      ],
    ];
    if (buttons.isEmpty) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          for (final (i, b) in buttons.indexed) ...[if (i > 0) const SizedBox(width: 12), Expanded(flex: i == buttons.length - 1 ? 2 : 1, child: b)],
        ]),
      ),
    );
  }

  Widget _body(BuildContext context, DeliveryJobView j) {
    final theme = Theme.of(context);
    final time = DateFormat('d MMM, h:mm a');
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        StatusChip(label: j.status.label, color: j.status.isActive ? theme.colorScheme.primary : Colors.grey.shade700),
        const Spacer(),
        Text('${j.distanceKm.toStringAsFixed(1)} km · ${j.itemCount} ${j.itemCount == 1 ? 'item' : 'items'}'),
      ]),
      const SizedBox(height: 12),
      Card(
        color: j.cashToCollectMinor > 0 ? theme.colorScheme.secondaryContainer : null,
        child: ListTile(
          leading: Icon(j.cashToCollectMinor > 0 ? Icons.payments_outlined : Icons.verified_outlined),
          title: Text(j.cashToCollectMinor > 0 ? 'Collect ${formatInr(j.cashToCollectMinor)} from the customer' : 'Already paid online'),
          subtitle: Text(j.cashToCollectMinor > 0 ? 'Cash or UPI, then hand it to the shop' : 'Do not collect any money'),
        ),
      ),
      const SizedBox(height: 12),
      _StopCard(title: '1. Pick up', icon: Icons.storefront_outlined, stop: j.pickup),
      const SizedBox(height: 8),
      _StopCard(title: '2. Deliver to', icon: Icons.home_outlined, stop: j.drop, hiddenUntilTaken: !j.mine),
      if (j.failureReason != null) ...[
        const SizedBox(height: 12),
        Text(j.failureReason!, style: TextStyle(color: theme.colorScheme.error)),
      ],
      const SizedBox(height: 16),
      Text('Requested ${time.format(j.requestedAt)}', style: theme.textTheme.bodySmall),
      if (j.pickedUpAt != null) Text('Picked up ${time.format(j.pickedUpAt!)}', style: theme.textTheme.bodySmall),
      if (j.deliveredAt != null) Text('Delivered ${time.format(j.deliveredAt!)}', style: theme.textTheme.bodySmall),
    ]);
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.title, required this.icon, required this.stop, this.hiddenUntilTaken = false});

  final String title;
  final IconData icon;
  final JobStop stop;
  final bool hiddenUntilTaken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: theme.textTheme.titleSmall)]),
          const SizedBox(height: 8),
          if (stop.name != null) Text(stop.name!, style: theme.textTheme.titleMedium),
          Text([stop.address, stop.area].whereType<String>().join(', ')),
          if (hiddenUntilTaken)
            Text('Full address and phone appear when you take the job', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${stop.lat},${stop.lng}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.directions),
              label: const Text('Directions'),
            ),
            if (stop.phone != null)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: stop.phone)),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call'),
              ),
          ]),
        ]),
      ),
    );
  }
}
