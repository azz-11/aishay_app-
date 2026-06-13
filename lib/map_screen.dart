import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n/app_strings.dart';
import 'search_screen.dart';
import 'utils/map_utils.dart';
import 'utils/osm_search.dart';
import 'utils/osrm_route.dart';

const _kDark = Color(0xFF0F1923);
const _kDark2 = Color(0xFF1A2340);
const _kOrange = Color(0xFFF26500);
const _kCardBg = Color(0xFF1E2D45);
const _kGold = Color(0xFFC8931A);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size,
        {FontWeight weight = FontWeight.w400,
        Color color = Colors.white,
        double? height}) =>
    GoogleFonts.tajawal(
        fontSize: size, fontWeight: weight, color: color, height: height);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final _client = Supabase.instance.client;
  final _mapController = MapController();

  bool _loading = true;
  LatLng _center = kFallbackCenter;
  List<Map<String, dynamic>> _restaurants = [];
  LatLng? _userPosition;
  String? _selectedRestaurantId; // pin whose name label is shown
  String _userCity = ''; // for biasing the search

  // ── Search bar ──
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<OsmPlace> _osmResults = [];
  List<Map<String, dynamic>> _dbMatches = [];
  LatLng? _tempPin; // highlighted pin dropped on a searched location
  List<LatLng> _routePoints = []; // driving route line (user → restaurant)

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await Future.wait([_loadCenter(), _loadRestaurants()]);
    if (mounted) setState(() => _loading = false);
    // After the map paints at the city fallback, try to zoom onto the user.
    _centerOnUserOrCity();
  }

  /// Snapchat-style open: zoom onto the user's actual location if we can get
  /// it; otherwise stay on the city center (the FlutterMap fallback).
  Future<void> _centerOnUserOrCity() async {
    try {
      final Position pos;
      if (kIsWeb) {
        // iOS Safari: request directly so the call isn't blocked by pre-checks.
        pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
      } else {
        if (!await Geolocator.isLocationServiceEnabled()) return;
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          return; // keep city fallback
        }
        pos = await Geolocator.getCurrentPosition();
      }
      final here = LatLng(pos.latitude, pos.longitude);
      if (mounted) setState(() => _userPosition = here);
      _animatedMove(here, 15.5); // close zoom on nearby places
    } catch (e) {
      debugPrint('[map] center-on-user skipped: $e'); // stay on city center
    }
  }

  // ── Search (OSM + our restaurants) ──────────────────────────────────────────
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _osmResults = [];
        _dbMatches = [];
      });
      return;
    }
    _searchDebounce =
        Timer(const Duration(milliseconds: 400), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    // Our own restaurants by name.
    try {
      final safe = q.replaceAll(RegExp(r'[,()]'), ' ').trim();
      final res = await _client
          .from('restaurants')
          .select('id, name_ar, city, avg_rating, latitude, longitude')
          .or('name_ar.ilike.%$safe%,name_en.ilike.%$safe%')
          .limit(5);
      if (mounted) {
        setState(() => _dbMatches = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      debugPrint('[map] db search error: $e');
    }
    // OpenStreetMap food places (biased to the user's city).
    final osm = await searchOsm(q, city: _userCity.isNotEmpty ? _userCity : null);
    if (mounted) setState(() => _osmResults = osm);
  }

  void _goToOsmPlace(OsmPlace p) {
    final dest = LatLng(p.lat, p.lon);
    setState(() {
      _tempPin = dest;
      _osmResults = [];
      _dbMatches = [];
      _searchCtrl.text = p.name;
      FocusScope.of(context).unfocus();
    });
    _animatedMove(dest, 16);
  }

  void _goToDbRestaurant(Map<String, dynamic> rest) {
    setState(() {
      _osmResults = [];
      _dbMatches = [];
      _searchCtrl.text = rest['name_ar']?.toString() ?? '';
      FocusScope.of(context).unfocus();
    });
    final lat = (rest['latitude'] as num?)?.toDouble();
    final lng = (rest['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) _animatedMove(LatLng(lat, lng), 16);
    _showRestaurantSheet(rest);
  }

  Future<void> _loadCenter() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    try {
      final row =
          await _client.from('users').select('city').eq('id', me).maybeSingle();
      final city = row?['city']?.toString();
      if (city != null) {
        _userCity = city.trim();
        if (kCityCoords.containsKey(city)) _center = kCityCoords[city]!;
      }
    } catch (e) {
      debugPrint('[map] center error: $e');
    }
  }

  Future<void> _loadRestaurants() async {
    try {
      final res = await _client
          .from('restaurants')
          .select('id, name_ar, city, avg_rating, latitude, longitude')
          .not('latitude', 'is', null);
      _restaurants = List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('[map] restaurants error: $e');
    }
  }

  // Smoothly fly the camera to [dest].
  void _animatedMove(LatLng dest, double zoom) {
    final cam = _mapController.camera;
    final latT = Tween(begin: cam.center.latitude, end: dest.latitude);
    final lngT = Tween(begin: cam.center.longitude, end: dest.longitude);
    final zoomT = Tween(begin: cam.zoom, end: zoom);
    final ctrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeInOut);
    ctrl.addListener(() => _mapController.move(
        LatLng(latT.evaluate(anim), lngT.evaluate(anim)), zoomT.evaluate(anim)));
    ctrl.forward().whenComplete(ctrl.dispose);
  }

  Future<void> _goToMyLocation() async {
    try {
      if (kIsWeb) {
        // iOS Safari: call getCurrentPosition directly inside the tap handler,
        // with no awaits before it, so the user-gesture activation isn't lost.
        // checkPermission via the Permissions API is unreliable on Safari.
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        final here = LatLng(pos.latitude, pos.longitude);
        if (mounted) setState(() => _userPosition = here);
        _animatedMove(here, 14);
        return;
      }
      // Native path (unchanged).
      if (!await Geolocator.isLocationServiceEnabled()) {
        _denied();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _denied();
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      if (mounted) setState(() => _userPosition = here);
      _animatedMove(here, 14);
    } catch (e) {
      debugPrint('[map] location error: $e');
      _denied();
    }
  }

  void _denied() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('يرجى السماح بالوصول للموقع', style: GoogleFonts.tajawal())),
    );
  }

  String? _distanceLabel(Map<String, dynamic> rest) {
    if (_userPosition == null) return null;
    final lat = (rest['latitude'] as num?)?.toDouble();
    final lng = (rest['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    final m = Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude, lat, lng);
    return m < 1000 ? '${m.round()} م' : '${(m / 1000).toStringAsFixed(1)} كم';
  }

  Future<void> _openDirections(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[map] directions launch error: $e');
    }
  }

  void _showRestaurantSheet(Map<String, dynamic> rest) {
    final name = rest['name_ar']?.toString() ?? 'مطعم';
    final city = rest['city']?.toString() ?? '';
    final rating = (rest['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final lat = (rest['latitude'] as num?)?.toDouble();
    final lng = (rest['longitude'] as num?)?.toDouble();
    final ar = AppStrings.isArabic;
    final raw = _distanceLabel(rest); // straight-line placeholder
    final straightLine = raw == null ? null : (ar ? toArabicDigits(raw) : raw);

    // Clear any previous route line before drawing this one.
    setState(() => _routePoints = []);

    RouteResult? route;
    var routeLoading = _userPosition != null && lat != null && lng != null;
    void Function(void Function())? sheetSetState;

    if (routeLoading) {
      getRoute(_userPosition!, LatLng(lat, lng)).then((r) {
        route = r;
        routeLoading = false;
        if (r != null && mounted) setState(() => _routePoints = r.points);
        sheetSetState?.call(() {});
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          sheetSetState = setModalState;

          // Distance/ETA line: hint → placeholder → driving result.
          Widget infoLine;
          if (_userPosition == null) {
            infoLine = Text('فعّل موقعك لمعرفة المسافة',
                style: _tj(13, color: _kTextSec));
          } else if (routeLoading) {
            infoLine = Text(
                straightLine != null ? 'يبعد $straightLine' : '...',
                style: _tj(13, color: _kTextSec));
          } else if (route != null) {
            final d = formatDistance(route!.distanceMeters, arabicDigits: ar);
            final t = formatDuration(route!.durationSeconds, arabicDigits: ar);
            infoLine = Text('يبعد $d · $t بالسيارة',
                style: _tj(13, weight: FontWeight.w700, color: _kOrange));
          } else {
            // OSRM failed → fall back to the straight-line distance.
            infoLine = Text(
                straightLine != null ? 'يبعد $straightLine' : '—',
                style: _tj(13, color: _kTextSec));
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 16 + MediaQuery.of(ctx).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  Text(name, style: _tj(18, weight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                          size: 14, color: _kTextSec),
                      const SizedBox(width: 5),
                      Text(city, style: _tj(13, color: _kTextSec)),
                      const Spacer(),
                      if (rating > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kGold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                                  size: 12, color: _kGold),
                              const SizedBox(width: 4),
                              Text(rating.toStringAsFixed(1),
                                  style: _tj(12,
                                      weight: FontWeight.w700, color: _kGold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(PhosphorIcons.navigationArrow(),
                          size: 14, color: _kTextSec),
                      const SizedBox(width: 5),
                      Flexible(child: infoLine),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SearchScreen(
                                  initialRestaurantId: rest['id']?.toString(),
                                  initialQuery: name,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_kOrange, Color(0xFFFF7A1A)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text('عرض التجارب',
                                style: _tj(15, weight: FontWeight.w800)),
                          ),
                        ),
                      ),
                      if (lat != null && lng != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openDirections(lat, lng),
                            child: Container(
                              height: 50,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _kOrange, width: 1.4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      PhosphorIcons.navigationArrow(
                                          PhosphorIconsStyle.fill),
                                      size: 16,
                                      color: _kOrange),
                                  const SizedBox(width: 6),
                                  Text('الاتجاهات',
                                      style: _tj(15,
                                          weight: FontWeight.w800,
                                          color: _kOrange)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      sheetSetState = null;
      if (mounted) setState(() => _routePoints = []); // clear line on close
    });
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(PhosphorIcons.magnifyingGlass(), size: 18, color: _kTextSec),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              style: _tj(13),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'ابحث عن مطعم...',
                hintStyle: _tj(13, color: _kTextSec),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchDebounce?.cancel();
                setState(() {
                  _searchCtrl.clear();
                  _osmResults = [];
                  _dbMatches = [];
                });
                FocusScope.of(context).unfocus();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.close, size: 16, color: _kTextSec),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          // Our own restaurants first.
          for (final rest in _dbMatches)
            ListTile(
              dense: true,
              leading: Icon(PhosphorIcons.storefront(PhosphorIconsStyle.fill),
                  size: 18, color: _kOrange),
              title: Text(rest['name_ar']?.toString() ?? '',
                  style: _tj(12), overflow: TextOverflow.ellipsis),
              subtitle: Text((rest['city'] ?? '').toString(),
                  style: _tj(10, color: _kTextSec)),
              onTap: () => _goToDbRestaurant(rest),
            ),
          // Then OpenStreetMap places.
          for (final p in _osmResults)
            ListTile(
              dense: true,
              leading: Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                  size: 18, color: _kTextSec),
              title: Text(p.name,
                  style: _tj(12), overflow: TextOverflow.ellipsis),
              subtitle: p.neighborhood.isEmpty
                  ? null
                  : Text(p.neighborhood,
                      style: _tj(10, color: _kTextSec),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              onTap: () => _goToOsmPlace(p),
            ),
        ],
      ),
    );
  }

  List<Marker> _markers() {
    final markers = <Marker>[];
    for (final rest in _restaurants) {
      if (rest['latitude'] == null || rest['longitude'] == null) continue;
      final id = rest['id']?.toString();
      final isSelected = id != null && id == _selectedRestaurantId;
      markers.add(Marker(
        point: LatLng((rest['latitude'] as num).toDouble(),
            (rest['longitude'] as num).toDouble()),
        width: 130,
        height: isSelected ? 72 : 56,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          // Opaque + full-size hitbox so the tap reliably wins the gesture
          // arena against the map's pan (was getting swallowed on web).
          behavior: HitTestBehavior.opaque,
          onTap: () {
            debugPrint('[map] pin tapped: ${rest['name_ar']}');
            setState(() => _selectedRestaurantId = id);
            _showRestaurantSheet(rest);
          },
          child: SizedBox.expand(
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _kOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4)
                      ],
                    ),
                    child: Icon(
                        PhosphorIcons.forkKnife(PhosphorIconsStyle.fill),
                        size: 15,
                        color: Colors.white),
                  ),
                  // Name label only for the selected pin (keeps the map clean).
                  if (isSelected) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kDark2.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(rest['name_ar']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _tj(10, weight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ));
    }
    if (_userPosition != null) {
      markers.add(Marker(
        point: _userPosition!,
        width: 22,
        height: 22,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2D9CDB),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF2D9CDB).withValues(alpha: 0.6),
                  blurRadius: 8)
            ],
          ),
        ),
      ));
    }
    // Temporary highlighted pin for a searched location.
    if (_tempPin != null) {
      markers.add(Marker(
        point: _tempPin!,
        width: 40,
        height: 40,
        child: Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
            size: 40, color: _kOrange),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kDark,
        floatingActionButton: _loading
            ? null
            : FloatingActionButton.extended(
                backgroundColor: _kOrange,
                onPressed: _goToMyLocation,
                icon: Icon(
                    PhosphorIcons.navigationArrow(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 18),
                label:
                    Text('موقعي الحالي', style: _tj(13, weight: FontWeight.w800)),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _kOrange))
            : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 13, // city fallback; user GPS zooms to 15.5
                      minZoom: 4,
                      maxZoom: 18,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c'],
                        retinaMode: RetinaMode.isHighDensity(context),
                        userAgentPackageName: 'com.aishay.app',
                      ),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: _kOrange,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      MarkerLayer(markers: _markers()),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 12,
                        bottom: 12,
                        left: 16,
                        right: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _kDark.withValues(alpha: 0.95),
                            _kDark.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text('الخريطة',
                                  style: _tj(18, weight: FontWeight.w900)),
                              const Spacer(),
                              Text('${_restaurants.length} مطعم',
                                  style: _tj(12, color: _kTextSec)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _searchBar(),
                          if (_dbMatches.isNotEmpty || _osmResults.isNotEmpty)
                            _searchDropdown(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
