import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inrPaise = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

/// Formats an amount held in paise, e.g. 26900 -> "₹269".
String formatInr(int minor) {
  return minor % 100 == 0 ? _inr.format(minor / 100) : _inrPaise.format(minor / 100);
}

/// Parses rupees typed by a user ("269", "269.50") into paise. Returns null if invalid.
int? parseRupees(String text) {
  final cleaned = text.replaceAll(RegExp(r'[₹,\s]'), '');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}

/// Paise to an editable rupee string ("26900" -> "269", "26950" -> "269.50").
String rupeesText(int? minor) {
  if (minor == null) return '';
  return minor % 100 == 0 ? '${minor ~/ 100}' : (minor / 100).toStringAsFixed(2);
}

/// "0.4 km", or "Under 100 m" for shops right next door.
String formatDistance(double km) => km < 0.1 ? 'Under 100 m' : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
