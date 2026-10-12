import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

/// Every WhatsApp message Mintadeal tried to send, with failures and their reasons.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final date = DateFormat('d MMM, h:mm:ss a');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(children: [
          Text('Messages', style: Theme.of(context).textTheme.headlineSmall),
          IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _reload++), icon: const Icon(Icons.refresh)),
        ]),
      ),
      Expanded(
        child: PagedList<NotificationRow>(
          queryKey: _reload,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          separator: 4,
          fetch: (page) => api.notificationLog(page: page),
          empty: const EmptyView(
            icon: Icons.chat_outlined,
            title: 'No messages sent yet',
            message: 'Turn on WhatsApp under Integrations to alert shops and customers.',
          ),
          itemBuilder: (context, n) => ListTile(
            leading: Icon(n.status == 'SENT' ? Icons.check_circle_outline : Icons.error_outline,
                color: n.status == 'SENT' ? Colors.green.shade700 : Theme.of(context).colorScheme.error),
            title: Text('${n.event.replaceAll('_', ' ').toLowerCase()} → ${n.recipient}'),
            subtitle: Text([n.channel, date.format(n.createdAt), if (n.error != null) n.error!].join(' · ')),
          ),
        ),
      ),
    ]);
  }
}
