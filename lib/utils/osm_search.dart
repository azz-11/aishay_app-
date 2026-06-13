import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A food place from OpenStreetMap (Nominatim).
class OsmPlace {
  final String name; // first segment of display_name
  final String neighborhood; // remainder (short), for the subtitle
  final double lat;
  final double lon;
  final String type; // restaurant / fast_food / cafe / ...
  const OsmPlace({
    required this.name,
    required this.neighborhood,
    required this.lat,
    required this.lon,
    required this.type,
  });
}

const _foodTypes = {
  'restaurant',
  'fast_food',
  'cafe',
  'bar',
  'pub',
  'food_court',
};

/// Searches Nominatim for food places, biased to [city] when given.
/// Returns [] on any error — never throws. Caller must debounce (≥1 req/sec).
Future<List<OsmPlace>> searchOsm(String query, {String? city}) async {
  final q = query.trim();
  if (q.length < 2) return [];
  final term =
      (city != null && city.trim().isNotEmpty) ? '$q ${city.trim()}' : q;

  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': term,
    'format': 'json',
    'limit': '6',
    'accept-language': 'ar',
    'countrycodes': 'sa',
  });

  try {
    final res = await http.get(uri, headers: {
      // Honored on native; browsers drop UA (forbidden header) and Nominatim
      // accepts the Referer instead — verified working from the app origin.
      'User-Agent': 'aishay-app (https://aishay-app.vercel.app)',
    }).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    if (data is! List) return [];

    final out = <OsmPlace>[];
    for (final item in data) {
      if (item is! Map) continue;
      final type = (item['type'] ?? '').toString();
      if (!_foodTypes.contains(type)) continue;
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');
      if (lat == null || lon == null) continue;
      final display = (item['display_name'] ?? '').toString();
      final parts = display.split(',').map((s) => s.trim()).toList();
      out.add(OsmPlace(
        name: parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : q,
        neighborhood:
            parts.length > 1 ? parts.sublist(1).take(2).join('، ') : '',
        lat: lat,
        lon: lon,
        type: type,
      ));
    }
    return out;
  } catch (e) {
    debugPrint('[osm] search error: $e');
    return [];
  }
}
