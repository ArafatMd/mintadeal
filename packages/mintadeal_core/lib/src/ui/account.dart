import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import 'widgets.dart';

/// "Delete my account", as app stores require. Asks first, then signs out once the account is gone.
class DeleteAccountTile extends ConsumerWidget {
  const DeleteAccountTile({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Delete your account?'),
        content: const Text(
          'Your name, photo and saved details are removed and you are signed out. '
          'Records of past orders and payments are kept because the law requires it.\n\n'
          'You can sign up again later with the same number, as a new account.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep my account')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final (deleted, message) = await ref.read(apiProvider).deleteAccount();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(deleted ? 'Account deleted' : 'Request received'),
          content: Text(message),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      if (deleted) await ref.read(sessionProvider.notifier).signOut();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    return ListTile(
      leading: Icon(Icons.person_remove_outlined, color: error),
      title: Text('Delete my account', style: TextStyle(color: error)),
      onTap: () => _delete(context, ref),
    );
  }
}
