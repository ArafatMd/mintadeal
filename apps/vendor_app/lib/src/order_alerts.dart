import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

/// Polls the shop's order counts so a new order shows up within seconds, even on the Listings tab.
/// WhatsApp/SMS alerts come in a later stage; this covers the app being open.
class OrderCountsController extends Notifier<VendorOrderCounts?> {
  static const interval = Duration(seconds: 20);
  Timer? _timer;

  @override
  VendorOrderCounts? build() {
    _timer = Timer.periodic(interval, (_) => refresh());
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    try {
      final next = await ref.read(apiProvider).shopOrderCounts();
      final before = state?.newOrders ?? 0;
      state = next;
      if (next.newOrders > before) {
        newOrderTick.value++;
        SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {
      // Offline for a moment; try again on the next tick.
    }
  }
}

final orderCountsProvider = NotifierProvider.autoDispose<OrderCountsController, VendorOrderCounts?>(OrderCountsController.new);

/// Incremented whenever more new orders arrive, so screens can show an alert and reload.
final newOrderTick = ValueNotifier<int>(0);
