import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/session.dart';
import '../models/enums.dart';
import '../models/stage6.dart';
import 'async_view.dart';
import 'paged_list.dart';
import 'widgets.dart';

final _time = DateFormat('d MMM, h:mm a');

Color ticketStatusColor(TicketStatus s) => switch (s) {
      TicketStatus.OPEN => Colors.orange.shade800,
      TicketStatus.ANSWERED => Colors.green.shade700,
      TicketStatus.CLOSED => Colors.grey.shade700,
    };

/// The person's help requests, newest activity first, with a button to start one.
///
/// [as] keeps each app's requests apart: a shop owner's customer questions are not mixed with shop ones.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key, required this.as, this.topics = TicketTopic.values});

  final Role as;
  final List<TicketTopic> topics;

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  int _reload = 0;

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    setState(() => _reload++);
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(NewTicketScreen(as: widget.as, topics: widget.topics)),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Ask for help'),
      ),
      body: PagedList<TicketSummary>(
        queryKey: (widget.as, _reload),
        fetch: (page) => api.myTickets(widget.as, page: page),
        separator: 8,
        header: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('We usually reply within a few hours, 9 am to 9 pm.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
        empty: const EmptyView(
          icon: Icons.support_agent_outlined,
          title: 'No help requests yet',
          message: 'Tap "Ask for help" and tell us what happened. We reply here.',
        ),
        itemBuilder: (context, t) => Card(
          child: ListTile(
            title: Text(t.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text([t.code, t.topic.label, if (t.orderCode != null) t.orderCode!, _time.format(t.lastMessageAt)]
                .join(' · ')),
            trailing: StatusChip(label: t.status.label, color: ticketStatusColor(t.status)),
            onTap: () => _open(TicketScreen(ticketId: t.id)),
          ),
        ),
      ),
    );
  }
}

/// Start a help request, optionally about one order.
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({
    super.key,
    required this.as,
    this.orderId,
    this.orderCode,
    this.topics = TicketTopic.values,
    this.topic,
  });

  final Role as;
  final String? orderId;
  final String? orderCode;
  final List<TicketTopic> topics;
  final TicketTopic? topic;

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  late TicketTopic _topic = widget.topic ?? (widget.orderId != null ? TicketTopic.ORDER : widget.topics.first);
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final t = await ref.read(apiProvider).openTicket(widget.as,
          topic: _topic, subject: _subject.text.trim(), message: _message.text.trim(), orderId: widget.orderId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TicketScreen(ticketId: t.ticket.id)));
      showMessage(context, 'Sent. Your request number is ${t.ticket.code}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask for help')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (widget.orderCode != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('About order ${widget.orderCode}'),
                subtitle: const Text('We can see the order details, so no need to repeat them.'),
              ),
            ),
          const SizedBox(height: 12),
          Text('What is it about?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in widget.topics)
              ChoiceChip(
                showCheckmark: false,
                label: Text(t.label),
                selected: _topic == t,
                onSelected: (_) => setState(() => _topic = t),
              ),
          ]),
          const SizedBox(height: 16),
          TextFormField(
            controller: _subject,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'In a few words', hintText: 'e.g. Wrong item delivered'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _message,
            maxLength: 2000,
            minLines: 5,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'What happened?', alignLabelWithHint: true),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send'),
          ),
        ]),
      ),
    );
  }
}

final _ticketProvider = FutureProvider.autoDispose.family<TicketDetail, (String, bool)>((ref, key) {
  final api = ref.watch(apiProvider);
  return key.$2 ? api.staffTicket(key.$1) : api.ticket(key.$1);
});

/// One help request as a conversation, with a reply box. [staff] shows the admin's side.
class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.ticketId, this.staff = false, this.embedded = false, this.onChanged});

  final String ticketId;
  final bool staff;

  /// Called after a reply or a status change, e.g. so a list beside it can refresh.
  final VoidCallback? onChanged;

  /// Inside the admin's two-pane layout: no app bar.
  final bool embedded;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  (String, bool) get _key => (widget.ticketId, widget.staff);

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _run(Future<TicketDetail> Function() action) async {
    setState(() => _sending = true);
    try {
      await action();
      _reply.clear();
      ref.invalidate(_ticketProvider(_key));
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(_ticketProvider(_key));
    final api = ref.read(apiProvider);
    final theme = Theme.of(context);
    final body = AsyncView(
      value: detail,
      onRetry: () => ref.invalidate(_ticketProvider(_key)),
      data: (d) {
        final t = d.ticket;
        final closed = t.status == TicketStatus.CLOSED;
        return Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Expanded(child: Text(t.subject, style: theme.textTheme.titleMedium)),
                StatusChip(label: t.status.label, color: ticketStatusColor(t.status)),
              ]),
              const SizedBox(height: 4),
              Text(
                [
                  t.code,
                  t.topic.label,
                  if (t.orderCode != null) 'Order ${t.orderCode}',
                  if (widget.staff) '${t.openerName ?? 'No name'} · ${t.openerPhone ?? ''} · ${t.openerRole.name.toLowerCase()}',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              for (final m in d.messages) _Bubble(message: m, mineIsStaff: widget.staff),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: closed
                  ? Row(children: [
                      Expanded(child: Text('This request is closed.', style: theme.textTheme.bodySmall)),
                      if (widget.staff)
                        TextButton(
                          onPressed: _sending ? null : () => _run(() => api.staffSetTicketOpen(t.id, true)),
                          child: const Text('Reopen'),
                        ),
                    ])
                  : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 2000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: widget.staff ? 'Reply to ${t.openerName ?? 'them'}' : 'Write a reply',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send',
                        onPressed: _sending
                            ? null
                            : () {
                                final text = _reply.text.trim();
                                if (text.isEmpty) return;
                                _run(() => widget.staff ? api.staffReply(t.id, text) : api.replyToTicket(t.id, text));
                              },
                        icon: const Icon(Icons.send),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'More',
                        onSelected: (_) => _run(() => widget.staff ? api.staffSetTicketOpen(t.id, false) : api.closeTicket(t.id)),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'close', child: Text(widget.staff ? 'Close request' : 'Mark as solved')),
                        ],
                      ),
                    ]),
            ),
          ),
        ]);
      },
    );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: Text(detail.value?.ticket.code ?? 'Help request')), body: body);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mineIsStaff});

  final TicketMessage message;

  /// The staff view puts staff messages on the right; everyone else sees their own on the right.
  final bool mineIsStaff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = message.staff == mineIsStaff;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: mine ? scheme.primaryContainer : scheme.surface,
          border: mine ? null : Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message.staff ? 'Mintadeal support' : (message.authorName ?? 'You'),
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(message.body),
          const SizedBox(height: 2),
          Text(_time.format(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
