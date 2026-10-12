import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'orders_screen.dart';

/// Hands the customer to the payment page and waits for Mintadeal's server to confirm the payment.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.checkoutId, this.openNow = false});

  final String checkoutId;
  final bool openNow;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  CheckoutResult? _checkout;
  Object? _error;
  bool _checking = false;
  Timer? _poll;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back from the payment page or another app: check straight away.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await ref.read(apiProvider).checkout(widget.checkoutId);
      setState(() => _checkout = c);
      if (widget.openNow && c.paymentUrl != null) _open();
    } catch (e) {
      setState(() => _error = e);
    }
  }

  Future<void> _open() async {
    final url = _checkout?.paymentUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _refresh() async {
    if (_checking || _checkout?.paymentStatus != PaymentStatus.PENDING) return;
    _checking = true;
    try {
      final c = await ref.read(apiProvider).refreshPayment(widget.checkoutId);
      if (!mounted) return;
      setState(() => _checkout = c);
      if (c.paymentStatus != PaymentStatus.PENDING) {
        _poll?.cancel();
        ref.invalidate(myOrdersRefreshProvider);
      }
    } catch (_) {
      // Keep waiting; a temporary network problem must not look like a failed payment.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _checkout;
    final theme = Theme.of(context);
    Widget body;
    if (_error != null) {
      body = ErrorView(message: '$_error', onRetry: _load);
    } else if (c == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = switch (c.paymentStatus) {
        PaymentStatus.PAID => EmptyView(
            icon: Icons.check_circle_outline,
            title: 'Payment received',
            message: 'Order ${c.code} is confirmed. The shop has been told.',
            action: FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => OrderPlacedScreen(result: c))),
              child: const Text('See my order'),
            ),
          ),
        PaymentStatus.PENDING => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Pay ${formatInr(c.grandTotalMinor)}', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Order ${c.code}', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Complete the payment on the payment page. This screen updates by itself when it goes through.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open payment page'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _refresh, child: const Text('I have paid, check now')),
              const SizedBox(height: 24),
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
          ),
        _ => EmptyView(
            icon: Icons.timer_off_outlined,
            title: c.paymentStatus == PaymentStatus.EXPIRED ? 'Payment time ran out' : 'Order cancelled',
            message: 'Nothing was charged for order ${c.code}. You can order again from the shop.',
          ),
      };
    }
    return Scaffold(appBar: AppBar(title: const Text('Payment')), body: body);
  }
}
