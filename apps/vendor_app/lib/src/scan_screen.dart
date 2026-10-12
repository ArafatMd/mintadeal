import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scans a customer's venue offer QR, shows what it is, and uses it up on confirmation.
/// When scanning fails, the order number plus the last 4 digits of the customer's phone works too.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _orderCode = TextEditingController();
  final _last4 = TextEditingController();
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  RedemptionCheck? _check;
  String? _code;
  bool _busy = false;
  bool _manual = false;

  @override
  void dispose() {
    _orderCode.dispose();
    _last4.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final value = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (value == null || _busy || _check != null) return;
    HapticFeedback.mediumImpact();
    await _lookup(code: value);
  }

  Future<void> _lookup({String? code}) async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      final check = code != null
          ? await api.checkRedemption(code: code)
          : await api.checkRedemption(orderCode: _orderCode.text.trim(), phoneLast4: _last4.text.trim());
      setState(() {
        _check = check;
        _code = code;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeem() async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      final result = _code != null
          ? await api.redeem(code: _code)
          : await api.redeem(orderCode: _orderCode.text.trim(), phoneLast4: _last4.text.trim());
      setState(() => _check = result);
      if (mounted) showMessage(context, 'Offer used. Order ${result.orderCode} is complete.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() => setState(() {
        _check = null;
        _code = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan offer QR')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_check != null)
          _Result(check: _check!, busy: _busy, onRedeem: _redeem, onNext: _reset)
        else ...[
          if (!_manual)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => Container(
                    color: Colors.black87,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text('The camera is not available (${error.errorCode.name}). Enter the order number below.',
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          TextButton.icon(
            onPressed: () => setState(() => _manual = !_manual),
            icon: Icon(_manual ? Icons.qr_code_scanner : Icons.keyboard),
            label: Text(_manual ? 'Use the camera' : 'Cannot scan? Enter the order number'),
          ),
          if (_manual) ...[
            TextField(
              controller: _orderCode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Order number', hintText: 'MD-7K3Q9P'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _last4,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: "Last 4 digits of the customer's phone"),
            ),
            FilledButton(onPressed: _busy ? null : () => _lookup(), child: const Text('Check')),
          ],
        ],
      ]),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.check, required this.busy, required this.onRedeem, required this.onNext});

  final RedemptionCheck check;
  final bool busy;
  final VoidCallback onRedeem;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final used = check.usedAt != null;
    final ok = check.valid && !used;
    final color = used ? Colors.green.shade700 : ok ? theme.colorScheme.primary : theme.colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(used ? Icons.check_circle : ok ? Icons.local_offer : Icons.block, size: 56, color: color),
          const SizedBox(height: 12),
          Text(used ? 'Used' : ok ? 'Valid offer' : check.problem ?? 'Cannot be used',
              style: theme.textTheme.headlineSmall?.copyWith(color: color)),
          if (check.title != null) ...[
            const SizedBox(height: 12),
            Text(check.title!, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            Text('For ${check.quantity} ${check.quantity == 1 ? 'person' : 'people'}'
                '${check.customerName == null ? '' : ' · ${check.customerName}'}'),
            Text('Order ${check.orderCode}', style: theme.textTheme.bodySmall),
            if (check.validTo != null)
              Text('Valid until ${DateFormat('d MMM yyyy').format(check.validTo!)}', style: theme.textTheme.bodySmall),
            if (used)
              Text('Used ${DateFormat('d MMM, h:mm a').format(check.usedAt!)}', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 20),
          if (ok)
            FilledButton.icon(
              onPressed: busy ? null : onRedeem,
              icon: const Icon(Icons.done),
              label: const Text('Use offer now'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: busy ? null : onNext, child: const Text('Scan another')),
        ]),
      ),
    );
  }
}
