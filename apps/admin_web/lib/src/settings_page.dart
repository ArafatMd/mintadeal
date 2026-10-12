import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

final _settings = FutureProvider.autoDispose<List<IntegrationSettingView>>((ref) => ref.watch(apiProvider).integrationSettings());

/// Razorpay and 2Factor configuration. Secrets are write-only: the server only says whether one is set.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(_settings);
    return AsyncView(
      value: settings,
      onRetry: () => ref.invalidate(_settings),
      data: (list) => ListView(padding: const EdgeInsets.all(24), children: [
        Text('Integrations', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Keys are stored encrypted. Saved secrets are never shown again; leave a secret blank to keep it.'),
        const SizedBox(height: 16),
        for (final s in list) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _IntegrationCard(key: ValueKey(s.provider), setting: s),
          ),
          const SizedBox(height: 16),
        ],
      ]),
    );
  }
}

class _Field {
  const _Field(this.key, this.label, {this.secret = false, this.hint, this.help});

  final String key;
  final String label;
  final bool secret;
  final String? hint;
  final String? help;
}

const _fields = {
  IntegrationProvider.RAZORPAY: [
    _Field('keyId', 'Key ID', hint: 'rzp_test_… or rzp_live_…', help: 'Razorpay Dashboard → Account & Settings → API keys'),
    _Field('keySecret', 'Key secret', secret: true),
    _Field('webhookSecret', 'Webhook secret', secret: true,
        help: 'Choose any long random value and enter the same one when you add the webhook in Razorpay'),
  ],
  IntegrationProvider.RAZORPAYX: [
    _Field('accountNumber', 'RazorpayX account number',
        help: 'RazorpayX → Account details. Payouts use the Razorpay API keys above.'),
  ],
  IntegrationProvider.WHATSAPP: [
    _Field('phoneNumberId', 'Phone number ID', help: 'Meta WhatsApp Manager → API setup'),
    _Field('accessToken', 'Access token', secret: true, help: 'A permanent system user token'),
    _Field('languageCode', 'Template language', hint: 'en'),
    _Field('newOrderTemplate', 'New order template (to shops)', help: 'Body: {{1}} order, {{2}} items, {{3}} total, {{4}} fulfilment'),
    _Field('orderUpdateTemplate', 'Order update template (to customers)', help: 'Body: {{1}} order, {{2}} shop, {{3}} what happened'),
  ],
  IntegrationProvider.TWO_FACTOR: [
    _Field('apiKey', 'API key', secret: true, help: '2factor.in → API keys'),
    _Field('templateName', 'OTP template name', hint: 'Leave empty to use your account default',
        help: 'The DLT-approved OTP template registered with 2Factor'),
  ],
};

class _IntegrationCard extends ConsumerStatefulWidget {
  const _IntegrationCard({super.key, required this.setting});

  final IntegrationSettingView setting;

  @override
  ConsumerState<_IntegrationCard> createState() => _IntegrationCardState();
}

class _IntegrationCardState extends ConsumerState<_IntegrationCard> {
  late IntegrationSettingView _s = widget.setting;
  late bool _enabled = _s.enabled;
  late final Map<String, TextEditingController> _text = {
    for (final f in _fields[_s.provider]!) f.key: TextEditingController(text: f.secret ? '' : _s.config[f.key] ?? ''),
  };
  final _testPhone = TextEditingController();
  bool _busy = false;
  String? _result;
  bool _resultOk = false;

  @override
  void dispose() {
    for (final c in [..._text.values, _testPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final fields = _fields[_s.provider]!;
      final saved = await ref.read(apiProvider).saveIntegration(
            _s.provider,
            enabled: _enabled,
            config: {for (final f in fields) if (!f.secret) f.key: _text[f.key]!.text.trim()},
            secrets: {for (final f in fields) if (f.secret && _text[f.key]!.text.trim().isNotEmpty) f.key: _text[f.key]!.text.trim()},
          );
      setState(() {
        _s = saved;
        _enabled = saved.enabled;
        for (final f in fields.where((f) => f.secret)) {
          _text[f.key]!.clear();
        }
        _result = 'Saved${saved.enabled ? ' and switched on' : ''}';
        _resultOk = true;
      });
    } catch (e) {
      setState(() {
        _result = '$e';
        _resultOk = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      final (ok, message) = await ref.read(apiProvider).testIntegration(_s.provider,
          phone: _testPhone.text.trim().isEmpty ? null : _testPhone.text.trim());
      setState(() {
        _result = message;
        _resultOk = ok;
      });
    } catch (e) {
      setState(() {
        _result = '$e';
        _resultOk = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = _fields[_s.provider]!;
    final mode = _s.info['mode'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(switch (_s.provider) {
              IntegrationProvider.RAZORPAY => Icons.payments_outlined,
              IntegrationProvider.TWO_FACTOR => Icons.sms_outlined,
              IntegrationProvider.RAZORPAYX => Icons.account_balance_outlined,
              IntegrationProvider.WHATSAPP => Icons.chat_outlined,
            }),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_s.provider.label, style: theme.textTheme.titleLarge),
                Text(_s.provider.purpose, style: theme.textTheme.bodySmall),
              ]),
            ),
            if (mode != null && mode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: StatusChip(label: '$mode mode', color: mode == 'LIVE' ? Colors.red.shade700 : Colors.blueGrey),
              ),
            StatusChip(
              label: _s.enabled ? 'On' : 'Off',
              color: _s.enabled ? Colors.green.shade700 : Colors.grey.shade700,
            ),
          ]),
          if (_s.updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Last saved ${DateFormat('d MMM yyyy, h:mm a').format(_s.updatedAt!)}',
                  style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 16),
          for (final f in fields) ...[
            TextField(
              controller: _text[f.key],
              obscureText: f.secret,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: f.label,
                hintText: f.secret
                    ? (_s.secrets[f.key]?.set == true ? 'Saved ${_s.secrets[f.key]?.hint ?? ''}. Type to replace' : 'Not set')
                    : f.hint,
                helperText: f.help,
                suffixIcon: f.secret && _s.secrets[f.key]?.set == true ? const Icon(Icons.lock_outline) : null,
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final key in const ['usage'])
            if (_s.info[key] != null && _s.info[key]!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_s.info[key]!, style: theme.textTheme.bodySmall),
              ),
          if (_s.provider == IntegrationProvider.RAZORPAYX && _s.info['webhookEvents'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Also add these events to the Razorpay webhook: ${_s.info['webhookEvents']}',
                  style: theme.textTheme.bodySmall),
            ),
          if (_s.info['webhookUrl'] != null) ...[
            Text('Webhook URL to add in Razorpay', style: theme.textTheme.labelLarge),
            Row(children: [
              Expanded(child: SelectableText(_s.info['webhookUrl']!)),
              IconButton(
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _s.info['webhookUrl']!));
                  showMessage(context, 'Webhook URL copied');
                },
                icon: const Icon(Icons.copy),
              ),
            ]),
            Text('Events: ${_s.info['webhookEvents']}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
          ],
          if (_s.provider == IntegrationProvider.TWO_FACTOR) ...[
            TextField(
              controller: _testPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Send a test code to (optional)',
                prefixText: '+91 ',
                helperText: 'Test checks the key and balance; with a number it also sends one SMS',
              ),
            ),
            const SizedBox(height: 12),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(switch (_s.provider) {
              IntegrationProvider.RAZORPAY => 'Accept online payments',
              IntegrationProvider.TWO_FACTOR => 'Send sign-in codes by SMS through 2Factor',
              IntegrationProvider.RAZORPAYX => 'Send payouts automatically',
              IntegrationProvider.WHATSAPP => 'Send WhatsApp order alerts',
            }),
            subtitle: Text(switch (_s.provider) {
              IntegrationProvider.RAZORPAY => 'Customers can pay online. Venue offers need this.',
              IntegrationProvider.TWO_FACTOR => 'When off, codes are not sent and only development sign-in works',
              IntegrationProvider.RAZORPAYX => 'When off, pay shops by bank or UPI and record the reference on the Payouts page',
              IntegrationProvider.WHATSAPP => 'New orders to shops, progress to customers',
            }),
            value: _enabled,
            onChanged: _busy ? null : (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Save')),
            OutlinedButton.icon(
              onPressed: _busy ? null : _test,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Test saved settings'),
            ),
            if (_busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                Icon(_resultOk ? Icons.check_circle_outline : Icons.error_outline,
                    color: _resultOk ? Colors.green.shade700 : theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text(_result!)),
              ]),
            ),
        ]),
      ),
    );
  }
}
