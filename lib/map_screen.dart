import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'search_screen.dart';
import 'utils/map_utils.dart';

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

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
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

  Future<void> _loadCenter() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    try {
      final row =
          await _client.from('users').select('city').eq('id', me).maybeSingle();
      final city = row?['city']?.toString();
      if (city != null && kCityCoords.containsKey(city)) {
        _center = kCityCoords[city]!;
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

  void _showRestaurantSheet(Map<String, dynamic> rest) {
    debugPrint('[map] sheet opening');
    final name = rest['name_ar']?.toString() ?? 'مطعم';
    final city = rest['city']?.toString() ?? '';
    final rating = (rest['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final distance = _distanceLabel(rest) ?? '—';

    showModalBottomSheet(
      context: context,
      backgroundColor: _kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
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
                  const SizedBox(width: 14),
                  Icon(PhosphorIcons.navigationArrow(),
                      size: 14, color: _kTextSec),
                  const SizedBox(width: 5),
                  Text(distance, style: _tj(13, color: _kTextSec)),
                  const Spacer(),
                  if (rating > 0)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
              const SizedBox(height: 18),
              GestureDetector(
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
                  child:
                      Text('عرض التجارب', style: _tj(15, weight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
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
                      child: Row(
                        children: [
                          Text('الخريطة',
                              style: _tj(18, weight: FontWeight.w900)),
                          const Spacer(),
                          Text('${_restaurants.length} مطعم',
                              style: _tj(12, color: _kTextSec)),
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
