// Lightweight Arabic date/time formatting for the visit planner.
// Self-contained (no intl locale data needed) so it works regardless of
// whether `initializeDateFormatting` has run yet.

const _weekdays = {
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};

const _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// e.g. "الأحد، 8 يونيو".
String formatVisitDateAr(DateTime d) =>
    '${_weekdays[d.weekday]}، ${d.day} ${_months[d.month - 1]}';

/// Parses a Postgres `date` string ('yyyy-MM-dd') and formats it in Arabic.
String formatVisitDateStrAr(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final d = DateTime.tryParse(raw);
  return d == null ? raw : formatVisitDateAr(d);
}

/// Parses a Postgres `time` string ('HH:mm:ss' / 'HH:mm') → "7:30 م".
String? formatVisitTimeAr(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  final period = h >= 12 ? 'م' : 'ص';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}
