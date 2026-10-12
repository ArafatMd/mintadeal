import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'area.dart';
import 'sign_in.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final area = ref.watch(areaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        children: [
          if (session == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign in'),
              subtitle: const Text('Follow shops and order from them'),
              onTap: () => ensureSignedIn(context, ref),
            )
          else ...[
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(session.user.name ?? 'Add your name'),
              subtitle: Text(session.user.phone),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editName(context, ref, session.user.name),
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text('Your area'),
            subtitle: Text(area.name),
            onTap: () => pickArea(context, ref),
          ),
          const ListTile(
            leading: Icon(Icons.receipt_long_outlined),
            title: Text('My orders'),
            subtitle: Text('Coming with ordering in the next update'),
            enabled: false,
          ),
          if (session != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () => ref.read(sessionProvider.notifier).signOut(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String? current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null) return;
    try {
      await ref.read(apiProvider).updateMe(name: name);
      await ref.read(sessionProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
