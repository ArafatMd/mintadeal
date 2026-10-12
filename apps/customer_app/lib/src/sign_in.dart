import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

/// Returns true if the customer is signed in, asking them to sign in first if needed.
Future<bool> ensureSignedIn(BuildContext context, WidgetRef ref) async {
  if (ref.read(sessionProvider).value != null) return true;
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _SignInPage()),
  );
  return ok ?? false;
}

class _SignInPage extends ConsumerWidget {
  const _SignInPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sessionProvider, (_, next) {
      if (next.value != null) Navigator.of(context).pop(true);
    });
    return Scaffold(
      appBar: AppBar(),
      body: const PhoneLoginScreen(
        appTitle: 'Sign in',
        tagline: 'Follow your favourite local shops and order from them.',
      ),
    );
  }
}
