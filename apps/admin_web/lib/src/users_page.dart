import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

/// Look up a person by phone and give or take away staff roles (delivery partner, admin).
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _phone = TextEditingController();
  AppUser? _user;
  bool _notFound = false;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _notFound = false;
    });
    try {
      final user = await ref.read(apiProvider).findUser(_phone.text.trim());
      setState(() => _user = user);
    } on ApiError catch (e) {
      if (e.status == 404) {
        setState(() {
          _user = null;
          _notFound = true;
        });
      } else if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setRole(Role role, bool granted) async {
    setState(() => _busy = true);
    try {
      final user = await ref.read(apiProvider).setRole(_phone.text.trim(), role, granted: granted);
      setState(() {
        _user = user;
        _notFound = false;
      });
      if (mounted) {
        showMessage(context, granted ? 'Role granted. They need to sign in again to use it.' : 'Role removed');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Staff & roles', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Add delivery partners so they can sign in to the delivery app, or give a colleague admin access.'),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 '),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(onPressed: _busy ? null : _search, child: const Text('Find')),
          ]),
        ),
        const SizedBox(height: 24),
        if (_notFound)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('No account with this number yet. You can still add them as a delivery partner; '
                      'their account is created now and they sign in with this number.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _setRole(Role.DELIVERY_AGENT, true),
                    icon: const Icon(Icons.delivery_dining),
                    label: const Text('Add as delivery partner'),
                  ),
                ]),
              ),
            ),
          ),
        if (_user != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_user!.name ?? 'No name yet', style: theme.textTheme.titleMedium),
                  Text(_user!.phone),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [for (final r in _user!.roles) Chip(label: Text(r.name))]),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Delivery partner'),
                    subtitle: const Text('Can sign in to the delivery app'),
                    value: _user!.has(Role.DELIVERY_AGENT),
                    onChanged: _busy ? null : (on) => _setRole(Role.DELIVERY_AGENT, on),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Admin'),
                    subtitle: const Text('Full access to this website'),
                    value: _user!.has(Role.ADMIN),
                    onChanged: _busy ? null : (on) => _setRole(Role.ADMIN, on),
                  ),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}
