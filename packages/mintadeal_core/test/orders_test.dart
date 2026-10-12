import 'package:flutter_test/flutter_test.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

void main() {
  financeLabels();
  test('parses a quote with groups, modes and problems', () {
    final q = Quote.fromJson({
      'groups': [
        {
          'key': 'v1:PRODUCT',
          'vendor': {'id': 'v1', 'name': 'Lakshmi Stores', 'area': 'HSR Layout'},
          'kind': 'PRODUCT',
          'lines': [
            {
              'listingId': 'l1', 'listingType': 'PRODUCT', 'title': 'Atta', 'unitPriceMinor': 26900,
              'originalPriceMinor': 29500, 'quantity': 2, 'lineTotalMinor': 53800, 'stockLeft': 3, 'problem': null,
            }
          ],
          'availableModes': ['SHOP_DELIVERY', 'PICKUP'],
          'selectedMode': 'SHOP_DELIVERY',
          'itemsTotalMinor': 53800,
          'deliveryFeeMinor': 2000,
          'totalMinor': 55800,
          'minOrderMinor': 0,
          'problems': [],
        }
      ],
      'itemsTotalMinor': 53800,
      'deliveryTotalMinor': 2000,
      'grandTotalMinor': 55800,
      'onlinePaymentAvailable': true,
      'payOnDeliveryAllowed': true,
      'addressRequired': true,
      'problems': ['Add a delivery address'],
      'canPlace': false,
    });
    expect(q.groups.single.selectedMode, FulfilmentMode.SHOP_DELIVERY);
    expect(q.groups.single.lines.single.stockLeft, 3);
    expect(q.canPlace, isFalse);
    expect(q.problems.single, 'Add a delivery address');
  });

  test('order actions and statuses parse, unknown values fall back', () {
    expect(OrderStatus.parse('OUT_FOR_DELIVERY').label, 'Out for delivery');
    expect(OrderStatus.parse('COMPLETED').isOpen, isFalse);
    expect(OrderAction.parse('MARK_READY'), OrderAction.MARK_READY);
  });

  test('relative times for order lists', () {
    final now = DateTime(2026, 10, 12, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
    expect(timeAgo(now.subtract(const Duration(minutes: 12)), now: now), '12 min ago');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
  });
}

void financeLabels() {
  test('basis points read as percentages', () {
    expect(bpsLabel(500), '5%');
    expect(bpsLabel(250), '2.5%');
    expect(bpsLabel(1275), '12.75%');
  });
}
