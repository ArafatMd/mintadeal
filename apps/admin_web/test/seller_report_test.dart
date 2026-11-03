import 'package:flutter_test/flutter_test.dart';
import 'package:mintadeal_admin/src/popups_page.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

void main() {
  test('the seller report reads well when pasted into WhatsApp', () {
    final r = SellerReport.fromJson({
      'name': 'Meena Bangles',
      'phone': '+919811166600',
      'shopName': null,
      'stalls': 2,
      'total': {'views': 31, 'calls': 4, 'whatsapp': 1, 'directions': 9},
      'lines': [
        {
          'name': 'Meena Bangles', 'latitude': 12.9125, 'longitude': 77.6440, 'days': 2,
          'startsAt': '2026-11-03T06:30:00Z', 'endedAt': '2026-11-05T06:30:00Z', 'status': 'ENDED',
          'counts': {'views': 30, 'calls': 4, 'whatsapp': 1, 'directions': 9},
        },
        {
          'name': 'Meena Bangles', 'latitude': 12.9352, 'longitude': 77.6245, 'days': 1,
          'startsAt': '2026-11-01T06:30:00Z', 'endedAt': '2026-11-02T06:30:00Z', 'status': 'ENDED',
          'counts': {'views': 1, 'calls': 0, 'whatsapp': 0, 'directions': 0},
        },
      ],
    });
    final text = sellerReportText(r);
    expect(text, contains('Mintadeal pop-up stall report: Meena Bangles'));
    expect(text, contains('2 stalls, 1 Nov to 5 Nov'));
    expect(text, contains('Customers opened your stall 31 times.'));
    expect(text, contains('Calls: 4 · WhatsApp: 1 · Directions: 9'));
    expect(text, contains('• 3 Nov, 2 days, near HSR Layout: 30 opens, 4 calls, 1 WhatsApp, 9 directions'));
    expect(text, contains('• 1 Nov, 1 day, near Koramangala: 1 open, 0 calls'));
  });
}
