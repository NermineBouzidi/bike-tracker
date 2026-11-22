import '../../data/local/ride_db.dart';

/// Text helpers shared by the trips list and the trip detail.
class TripFmt {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String two(int n) => n.toString().padLeft(2, '0');

  /// Today / Yesterday / Mon 9 Nov
  static String dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  /// Mon 9 Nov 2026
  static String fullDate(DateTime d) =>
      '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';

  /// 9 Nov (for the date filters)
  static String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String clock(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

  static String timeRange(Trip t) => '${clock(t.start)} – ${clock(t.end)}';

  static String duration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${two(d.inMinutes % 60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }

  static String distance(double meters, bool mph) {
    final v = mph ? meters / 1609.344 : meters / 1000;
    return v.toStringAsFixed(v < 10 ? 2 : 1);
  }

  static String distanceUnit(bool mph) => mph ? 'mi' : 'km';

  static String speed(double kmh, bool mph) =>
      (mph ? kmh * 0.621371 : kmh).toStringAsFixed(1);

  static String speedUnit(bool mph) => mph ? 'mph' : 'km/h';
}