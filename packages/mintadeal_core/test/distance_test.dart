import 'package:flutter_test/flutter_test.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

void main() {
  test('formats distances for people', () {
    expect(formatDistance(0.04), 'Under 100 m');
    expect(formatDistance(0.33), '~350 m');
    expect(formatDistance(1.0), '~1.0 km');
    expect(formatDistance(3.66), '~3.7 km');
    expect(formatDistance(12.7), '~13 km');
  });

  test('names a position after the nearest area and knows the city limits', () {
    expect(nearestArea(const GeoPoint(12.9130, 77.6450)).name, 'HSR Layout');
    expect(nearestArea(const GeoPoint(12.9700, 77.7480)).name, 'Whitefield');
    expect(inBengaluru(const GeoPoint(12.9116, 77.6474)), isTrue);
    expect(inBengaluru(const GeoPoint(13.0827, 80.2707)), isFalse); // Chennai
    expect(distanceKm(const GeoPoint(12.9116, 77.6474), const GeoPoint(12.9352, 77.6245)), closeTo(3.6, 0.2));
  });

  test('a road trip shows distance and time, without the approximate mark', () {
    expect(formatTrip(1.3, 1.8, 10), '1.8 km · 10 min');
    expect(formatTrip(0.3, 0.45, 3), '450 m · 3 min');
    expect(formatTrip(1.3, null, null), '~1.3 km');
    expect(formatTrip(null, null, null), isNull);
  });
}
