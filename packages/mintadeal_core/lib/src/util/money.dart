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
/// Straight-line distance, so marked as approximate: "~350 m", "~1.2 km", "~13 km".
String formatDistance(double km) {
  if (km < 0.1) return 'Under 100 m';
  if (km < 1) return '~${(km * 1000 / 50).round() * 50} m';
  return '~${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

/// Short relative time for order lists: "just now", "12 min ago", "3 h ago", or a date.
String timeAgo(DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return DateFormat('d MMM, h:mm a').format(when);
}

/// A trip by road ("1.8 km · 10 min") when the server knows one, else the approximate straight-line distance.
String? formatTrip(double? straightKm, double? roadKm, int? roadMinutes) {
  if (roadKm != null && roadMinutes != null) {
    final km = roadKm < 1 ? '${(roadKm * 1000 / 50).round() * 50} m' : '${roadKm.toStringAsFixed(roadKm < 10 ? 1 : 0)} km';
    return '$km · $roadMinutes min';
  }
  return straightKm == null ? null : formatDistance(straightKm);
}
