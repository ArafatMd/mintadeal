import 'package:flutter_test/flutter_test.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

void main() {
  test('formats paise as Indian rupees', () {
    expect(formatInr(26900), '₹269');
    expect(formatInr(12345678), '₹1,23,456.78');
    expect(formatInr(10000000), '₹1,00,000');
  });

  test('parses typed rupees into paise', () {
    expect(parseRupees('269'), 26900);
    expect(parseRupees('₹1,299.50'), 129950);
    expect(parseRupees(''), isNull);
    expect(parseRupees('abc'), isNull);
    expect(rupeesText(26950), '269.50');
    expect(rupeesText(26900), '269');
  });
}
