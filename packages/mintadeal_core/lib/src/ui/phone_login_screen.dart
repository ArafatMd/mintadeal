import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../models/enums.dart';
import 'theme.dart';
import 'widgets.dart';

/// Phone number + one-time code sign-in, shared by all Mintadeal apps.
class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key, required this.appTitle, required this.tagline, this.requiredRole});

  final String appTitle;
  final String tagline;

  /// If set, accounts without this role are signed straight out again with an explanation.
  final Role? requiredRole;

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  /// Whether the code went on WhatsApp, and whether WhatsApp can be offered when the SMS does not arrive.
  bool _sentOnWhatsApp = false;
  bool _whatsAppAvailable = false;

  /// Seconds before another code can be asked for (the server allows one every 30 seconds).
  static const _wait = 30;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _wait);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool onWhatsApp = false}) async {
    if (_phone.text.trim().length < 10) {
      showMessage(context, 'Enter your 10-digit mobile number');
      return;
    }
    await _run(() async {
      final sent = await ref.read(sessionProvider.notifier).requestOtp(_phone.text.trim(), onWhatsApp: onWhatsApp);
      setState(() {
        _codeSent = true;
        _sentOnWhatsApp = onWhatsApp;
        _whatsAppAvailable = sent.whatsApp;
        _code.clear();
      });
      _startCountdown();
    });
  }

  Future<void> _verify() async {
    await _run(() async {
      final user = await ref.read(sessionProvider.notifier).verifyOtp(_phone.text.trim(), _code.text.trim());
      final role = widget.requiredRole;
      if (role != null && !user.has(role)) {
        await ref.read(sessionProvider.notifier).signOut();
        if (mounted) {
          showMessage(context, role == Role.ADMIN
              ? 'This number does not have admin access.'
              : 'This number is not registered as a Mintadeal delivery partner. Ask Mintadeal to add you.');
          setState(() {
            _codeSent = false;
            _code.clear();
          });
        }
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: MintadealLogo(height: 88)),
                  const SizedBox(height: 12),
                  const SizedBox(height: 4),
                  Text(widget.appTitle, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(widget.tagline, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _phone,
                    enabled: !_codeSent && !_busy,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                      LengthLimitingTextInputFormatter(14)],
                    decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 '),
                    onSubmitted: (_) => _sendCode(),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _code,
                      enabled: !_busy,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      decoration: const InputDecoration(labelText: '6-digit code'),
                      onSubmitted: (_) => _verify(),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(_sentOnWhatsApp ? Icons.chat : Icons.sms_outlined, size: 18,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _sentOnWhatsApp
                              ? 'Code sent on WhatsApp to +91 ${_phone.text.trim()}'
                              : 'Code sent by SMS to +91 ${_phone.text.trim()}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_codeSent ? 'Verify and continue' : 'Send code'),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 12),
                    if (_secondsLeft > 0)
                      Text('Didn\'t get it? You can ask again in $_secondsLeft s',
                          textAlign: TextAlign.center, style: theme.textTheme.bodySmall)
                    else ...[
                      if (_whatsAppAvailable && !_sentOnWhatsApp)
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _sendCode(onWhatsApp: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF128C3E),
                            side: const BorderSide(color: Color(0xFF128C3E)),
                          ),
                          icon: const Icon(Icons.chat),
                          label: const Text('Get the code on WhatsApp'),
                        ),
                      TextButton(
                        onPressed: _busy ? null : () => _sendCode(),
                        child: const Text('Send the code by SMS again'),
                      ),
                    ],
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              _timer?.cancel();
                              setState(() {
                                _codeSent = false;
                                _secondsLeft = 0;
                                _code.clear();
                              });
                            },
                      child: const Text('Change number'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [signedIn] when there is a session, otherwise [signedOut].
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.signedIn, required this.signedOut});

  final Widget Function(Session session) signedIn;
  final Widget signedOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return session.when(
      data: (s) => s == null ? signedOut : signedIn(s),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => signedOut,
    );
  }
}
