import 'enums.dart';
import 'models.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

class StatementLine {
  StatementLine.fromJson(Json j)
      : type = j['type'] as String,
        description = j['description'] as String,
        amountMinor = _int(j['amountMinor']),
        createdAt = _date(j['createdAt'])!;

  final String type;
  final String description;

  /// From the shop's side: positive is money to the shop.
  final int amountMinor;
  final DateTime createdAt;
}

class PayoutView {
  PayoutView.fromJson(Json j)
      : id = j['id'] as String,
        vendorId = j['vendorId'] as String,
        vendorName = j['vendorName'] as String,
        amountMinor = _int(j['amountMinor']),
        status = PayoutStatus.parse(j['status']),
        method = j['method'] as String?,
        destination = j['destination'] as String,
        utr = j['utr'] as String?,
        failureReason = j['failureReason'] as String?,
        createdAt = _date(j['createdAt'])!,
        paidAt = _date(j['paidAt']);

  final String id;
  final String vendorId;
  final String vendorName;
  final int amountMinor;
  final PayoutStatus status;
  final String? method;
  final String destination;
  final String? utr;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? paidAt;
}

class Earnings {
  Earnings.fromJson(Json j)
      : balanceMinor = _int(j['balanceMinor']),
        inPayoutMinor = _int(j['inPayoutMinor']),
        payoutDestination = j['payoutDestination'] as String?,
        commissionBps = _int(j['commissionBps']),
        statement = [for (final s in j['statement'] as List) StatementLine.fromJson(s as Json)],
        payouts = [for (final p in j['payouts'] as List) PayoutView.fromJson(p as Json)];

  /// What Mintadeal owes the shop now; negative when the shop owes Mintadeal.
  final int balanceMinor;
  final int inPayoutMinor;
  final String? payoutDestination;
  final int commissionBps;
  final List<StatementLine> statement;
  final List<PayoutView> payouts;
}

class FinanceSummary {
  FinanceSummary.fromJson(Json j)
      : gatewayMinor = _int(j['gatewayMinor']),
        customerPrepaidMinor = _int(j['customerPrepaidMinor']),
        owedToShopsMinor = _int(j['owedToShopsMinor']),
        owedByShopsMinor = _int(j['owedByShopsMinor']),
        payoutsInTransitMinor = _int(j['payoutsInTransitMinor']),
        commissionRevenueMinor = _int(j['commissionRevenueMinor']),
        deliveryRecoveryMinor = _int(j['deliveryRecoveryMinor']),
        balanced = j['balanced'] as bool,
        pendingPayoutsMinor = _int(j['pendingPayoutsMinor']),
        pendingPayouts = _int(j['pendingPayouts']),
        failedRefunds = _int(j['failedRefunds']);

  final int gatewayMinor;
  final int customerPrepaidMinor;
  final int owedToShopsMinor;
  final int owedByShopsMinor;
  final int payoutsInTransitMinor;
  final int commissionRevenueMinor;
  final int deliveryRecoveryMinor;
  final bool balanced;
  final int pendingPayoutsMinor;
  final int pendingPayouts;
  final int failedRefunds;
}

class VendorBalance {
  VendorBalance.fromJson(Json j)
      : vendorId = j['vendorId'] as String,
        vendorName = j['vendorName'] as String,
        balanceMinor = _int(j['balanceMinor']),
        payoutDestination = j['payoutDestination'] as String?;

  final String vendorId;
  final String vendorName;
  final int balanceMinor;
  final String? payoutDestination;
}

class CommissionRates {
  CommissionRates(this.defaultBps, this.categoryBps);

  CommissionRates.fromJson(Json j)
      : defaultBps = _int(j['defaultBps']),
        categoryBps = {
          for (final e in (j['categoryBps'] as Json? ?? const {}).entries) VendorCategory.parse(e.key): _int(e.value),
        };

  final int defaultBps;
  final Map<VendorCategory, int> categoryBps;

  Json toJson() => {
        'defaultBps': defaultBps,
        'categoryBps': {for (final e in categoryBps.entries) e.key.name: e.value},
      };
}

class PayoutBatchResult {
  PayoutBatchResult.fromJson(Json j)
      : payoutCount = _int(j['payoutCount']),
        totalMinor = _int(j['totalMinor']),
        skipped = [for (final s in j['skipped'] as List) '$s'];

  final int payoutCount;
  final int totalMinor;
  final List<String> skipped;
}

class RefundRow {
  RefundRow.fromJson(Json j)
      : id = j['id'] as String,
        orderCode = j['orderCode'] as String,
        amountMinor = _int(j['amountMinor']),
        status = j['status'] as String,
        error = j['error'] as String?,
        createdAt = _date(j['createdAt'])!;

  final String id;
  final String orderCode;
  final int amountMinor;
  final String status;
  final String? error;
  final DateTime createdAt;
}

class NotificationRow {
  NotificationRow.fromJson(Json j)
      : event = j['event'] as String,
        channel = j['channel'] as String,
        recipient = j['recipient'] as String,
        status = j['status'] as String,
        error = j['error'] as String?,
        createdAt = _date(j['createdAt'])!;

  final String event;
  final String channel;
  final String recipient;
  final String status;
  final String? error;
  final DateTime createdAt;
}

/// Basis points as a percentage label: 500 -> "5%", 250 -> "2.5%".
String bpsLabel(int bps) => bps % 100 == 0 ? '${bps ~/ 100}%' : '${(bps / 100).toStringAsFixed(bps % 10 == 0 ? 1 : 2)}%';
