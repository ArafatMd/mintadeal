import 'package:flutter_test/flutter_test.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

void main() {
  test('formats distances for people', () {
    expect(formatDistance(0.04), 'Under 100 m');
    expect(formatDistance(1.0), '1.0 km');
    expect(formatDistance(3.66), '3.7 km');
    expect(formatDistance(12.7), '13 km');
  });
}
