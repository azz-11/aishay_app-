import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> points;
  const RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });
}

/// Driving route from [from] to [to] via OSRM (free, no key).
/// Returns null on any error — never throws.
Future<RouteResult?> getRoute(LatLng from, LatLng to) async {
  // Build the URL by hand so the ',' and ';' separators aren't percent-encoded.
  final url = 'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson';
  try {
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    if (data is! Map) return null;
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final r = routes.first as Map;
    final dist = (r['distance'] as num?)?.toDouble();
    final dur = (r['duration'] as num?)?.toDouble();
    final coords = (r['geometry'] is Map) ? r['geometry']['coordinates'] : null;
    if (dist == null || dur == null || coords is! List) return null;
    final points = <LatLng>[];
    for (final c in coords) {
      if (c is List && c.length >= 2) {
        points.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
      }
    }
    return RouteResult(
        distanceMeters: dist, durationSeconds: dur, points: points);
  } catch (e) {
    debugPrint('[osrm] route error: $e');
    return null;
  }
}

// ── Formatting ──────────────────────────────────────────────────────────────
String formatDistance(double meters, {bool arabicDigits = false}) {
  final s = meters < 1000
      ? '${meters.round()} م'
      : '${(meters / 1000).toStringAsFixed(1)} كم';
  return arabicDigits ? toArabicDigits(s) : s;
}

String formatDuration(double seconds, {bool arabicDigits = false}) {
  final mins = (seconds / 60).round();
  final String s;
  if (mins < 1) {
    s = 'أقل من دقيقة';
  } else if (mins < 60) {
    s = '$mins ${_arMinutes(mins)}';
  } else {
    final h = mins ~/ 60;
    final m = mins % 60;
    final hPart = h == 1 ? 'ساعة' : (h == 2 ? 'ساعتان' : '$h ${_arHours(h)}');
    s = m == 0 ? hPart : '$hPart و$m ${_arMinutes(m)}';
  }
  return arabicDigits ? toArabicDigits(s) : s;
}

// Arabic number agreement (simplified): 3–10 → plural, else singular form.
String _arMinutes(int n) => (n >= 3 && n <= 10) ? 'دقائق' : 'دقيقة';
String _arHours(int n) => (n >= 3 && n <= 10) ? 'ساعات' : 'ساعة';

String toArabicDigits(String s) {
  const w = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const a = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var out = s;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(w[i], a[i]);
  }
  return out;
}
