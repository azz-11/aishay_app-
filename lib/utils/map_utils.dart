import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

/// City → coordinates (the 9 onboarding cities). Used to center maps on the
/// user's city. Fallback = Riyadh.
const kCityCoords = <String, LatLng>{
  'جدة': LatLng(21.4858, 39.1925),
  'الرياض': LatLng(24.7136, 46.6753),
  'مكة': LatLng(21.3891, 39.8579),
  'المدينة': LatLng(24.5247, 39.5692),
  'الدمام': LatLng(26.4207, 50.0888),
  'الخبر': LatLng(26.2172, 50.1971),
  'أبها': LatLng(18.2164, 42.5053),
  'تبوك': LatLng(28.3998, 36.5700),
  'القصيم': LatLng(26.3260, 43.9750),
};

const kFallbackCenter = LatLng(24.7136, 46.6753); // Riyadh

LatLng cityCenter(String? city) =>
    (city != null && kCityCoords.containsKey(city))
        ? kCityCoords[city]!
        : kFallbackCenter;

/// Uniformly darken OSM tiles so orange pins pop (keeps the map legible).
const kDarkenTiles = ColorFilter.matrix(<double>[
  0.6, 0, 0, 0, 0,
  0, 0.6, 0, 0, 0,
  0, 0, 0.6, 0, 0,
  0, 0, 0, 1, 0,
]);
