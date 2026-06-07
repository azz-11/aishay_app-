import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'security_utils.dart';
import 'l10n/app_strings.dart';
import 'services/gamification_service.dart';
import 'utils/map_utils.dart';

const _kSaudiCitiesAdd = [
  'الرياض', 'جدة', 'مكة', 'المدينة',
  'الدمام', 'الخبر', 'الطائف', 'أبها', 'تبوك', 'القصيم',
];

// ── Design tokens
const _kDark2   = Color(0xFF1A2340);
const _kOrange  = Color(0xFFF26500);
const _kGold    = Color(0xFFC8931A);
const _kCardBg  = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size,
    {FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
    double? height}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color, height: height);

class AddExperienceScreen extends StatefulWidget {
  const AddExperienceScreen({super.key});

  @override
  State<AddExperienceScreen> createState() => _AddExperienceScreenState();
}

class _AddExperienceScreenState extends State<AddExperienceScreen>
    with TickerProviderStateMixin {

  // Image
  final _picker = ImagePicker();
  List<Uint8List> _imageBytes = [];
  List<String> _imageUrls = [];

  // Controllers
  final _restController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dishNameCtrl = TextEditingController();
  final _dishPriceCtrl = TextEditingController();

  // State
  int _step = 1;
  bool _loading = false;
  String? _error;

  // Ratings
  final List<double> _ratings = [0, 0, 0, 0, 0];
  // Display-only labels (the numeric ratings are what get stored). Getter so it
  // re-localizes on language toggle instead of caching at construction.
  List<String> get _ratingLabels => [
    AppStrings.food,
    AppStrings.service,
    AppStrings.ambiance,
    AppStrings.cleanliness,
    AppStrings.value,
  ];

  // Atmosphere & Price
  String _atmosphere = '';
  String _priceRange = '';

  // Tags
  final List<String> _tags = [];
  final _tagOptions = [
    '👨‍👩‍👧 عائلي',
    '💻 للعمل',
    '🌿 للدراسة',
    '🌳 خارجي',
    '🕯️ رومانسي',
    '👥 شبابي',
  ];

  // Visit time
  String _visitTime = '';

  // Dishes
  final List<Map<String, dynamic>> _dishes = [];
  List<String> _selectedCategories = [];
  bool _showOtherCategory = false;
  final _otherCategoryCtrl = TextEditingController();

  // Restaurant
  String? _restaurantId;
  String? _restaurantName;
  String _restaurantCity = '';
  List<Map<String, dynamic>> _searchResults = [];

  // Location (NEW restaurants only) — captured from the mini-map center.
  final _miniMapController = MapController();
  double? _lat;
  double? _lng;

  // Dish photos
  Uint8List? _pendingDishPhoto;
  String? _pendingDishPhotoUrl;
  bool _dishPhotoUploading = false;

  // Animation
  late AnimationController _slideCtrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _restController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _dishNameCtrl.dispose();
    _dishPriceCtrl.dispose();
    _otherCategoryCtrl.dispose();
    _miniMapController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationDenied();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _locationDenied();
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _miniMapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (e) {
      debugPrint('[add_exp] location error: $e');
      _locationDenied();
    }
  }

  void _locationDenied() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('يرجى السماح بالوصول للموقع', style: GoogleFonts.tajawal())),
    );
  }

  double get _avgRating {
    final filled = _ratings.where((r) => r > 0).toList();
    if (filled.isEmpty) return 0;
    return filled.reduce((a, b) => a + b) / filled.length;
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 70);
    for (final img in picked) {
      final bytes = await img.readAsBytes();
      setState(() => _imageBytes.add(bytes));
    }
  }

  Future<void> _uploadImages(String expId) async {
    for (int i = 0; i < _imageBytes.length; i++) {
      final path = 'experiences/$expId/photo_$i.jpg';
      await Supabase.instance.client.storage
          .from('photos')
          .uploadBinary(path, _imageBytes[i]);
      final url = Supabase.instance.client.storage
          .from('photos')
          .getPublicUrl(path);
      _imageUrls.add(url);
    }
  }

  Future<void> _searchRestaurant(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('restaurants')
          .select()
          .ilike('name_ar', '%$query%')
          .limit(5);
      setState(() => _searchResults = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  void _nextStep() {
    setState(() {
      _error = null;
      _slideCtrl.forward(from: 0);
      _step++;
    });
  }

  // Title must be at most 6 words (whitespace-separated).
  int _titleWordCount(String title) =>
      title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  bool _isTitleValid(String title) => _titleWordCount(title) <= 6;

  Future<void> _submit() async {
    if (_restaurantName == null || _restaurantName!.isEmpty) {
      setState(() => _error = AppStrings.enterRestaurantName);
      return;
    }

    // Sanitize + length-validate text inputs (defense-in-depth; the DB is the
    // authoritative gate — see supabase/security/rls_and_storage.sql).
    final title = sanitizeInput(_titleController.text);
    final desc = sanitizeInput(_descController.text);

    if (title.isEmpty) {
      setState(() => _error = AppStrings.enterTitle);
      return;
    }
    if (desc.isEmpty) {
      setState(() => _error = AppStrings.enterDescription);
      return;
    }
    if (title.length > kMaxTitleLength) {
      setState(() => _error = AppStrings.titleTooLong(kMaxTitleLength));
      return;
    }
    if (!_isTitleValid(title)) {
      setState(() => _error = AppStrings.titleMaxWords);
      return;
    }
    if (desc.length > kMaxDescriptionLength) {
      setState(() => _error = AppStrings.descTooLong(kMaxDescriptionLength));
      return;
    }
    if (containsProfanity(title) || containsProfanity(desc)) {
      setState(() => _error = AppStrings.inappropriateContent);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser!;

      if (_restaurantId == null) {
        final rest = await Supabase.instance.client
            .from('restaurants')
            .insert({
              'name_ar': _restaurantName,
              'created_by': user.id,
              if (_selectedCategories.isNotEmpty)
                'category': _selectedCategories.join(','),
              if (_restaurantCity.isNotEmpty) 'city': _restaurantCity,
              if (_lat != null) 'latitude': _lat,
              if (_lng != null) 'longitude': _lng,
            })
            .select()
            .single();
        _restaurantId = rest['id'];
      }

      final exp = await Supabase.instance.client
          .from('experiences')
          .insert({
            'user_id': user.id,
            'restaurant_id': _restaurantId,
            'title': title,
            'description': desc,
            'rating_food': _ratings[0] > 0 ? _ratings[0] : null,
            'rating_service': _ratings[1] > 0 ? _ratings[1] : null,
            'rating_ambiance': _ratings[2] > 0 ? _ratings[2] : null,
            'rating_clean': _ratings[3] > 0 ? _ratings[3] : null,
            'rating_value': _ratings[4] > 0 ? _ratings[4] : null,
            'atmosphere': _atmosphere.isNotEmpty ? _atmosphere : null,
            'price_range': _priceRange.isNotEmpty ? _priceRange : null,
            'visit_time': _visitTime.isNotEmpty ? _visitTime : null,
            if (_tags.isNotEmpty) 'tags': _tags,
          })
          .select()
          .single();

      if (_imageBytes.isNotEmpty) {
        await _uploadImages(exp['id']);
        await Supabase.instance.client
            .from('experiences')
            .update({'photos': _imageUrls})
            .eq('id', exp['id']);

        // Set the restaurant cover from the first photo if it has none yet.
        if (_imageUrls.isNotEmpty && _restaurantId != null) {
          try {
            await Supabase.instance.client
                .from('restaurants')
                .update({'cover_image': _imageUrls.first})
                .eq('id', _restaurantId!)
                .isFilter('cover_image', null);
          } catch (e) {
            debugPrint('cover_image update error: $e');
          }
        }
      }

      if (_dishes.isNotEmpty) {
        await Supabase.instance.client.from('dishes').insert(
          _dishes.map((d) => {
            'experience_id': exp['id'],
            'name': sanitizeAndCap((d['name'] as String?) ?? '', kMaxDishNameLength),
            'price_sar': double.tryParse((d['price'] as String?) ?? '0'),
            'photo_url': d['photo_url'],
          }).toList(),
        );
      }

      if (mounted) setState(() => _step = 99);

      // Award cheap (experience-derived) badges; celebrate any new ones.
      try {
        final newBadges = await GamificationService()
            .checkAndAwardBadges(user.id, full: false);
        if (newBadges.isNotEmpty && mounted) {
          final msg = newBadges.length == 1
              ? 'حصلت على شارة جديدة: ${newBadges.first.name}'
              : 'حصلت على ${newBadges.length} شارات جديدة!';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _kOrange,
              duration: const Duration(seconds: 3),
              content: Row(
                children: [
                  Icon(PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(msg, style: _tj(13, weight: FontWeight.w700))),
                ],
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Badge award error: $e');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark2,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_step < 99) _buildProgressBar(),
            Expanded(
              child: SlideTransition(
                position: _slide,
                child: _step == 99
                    ? _buildSuccess()
                    : _step == 1
                        ? _buildStep1()
                        : _step == 2
                            ? _buildStep2()
                            : _step == 3
                                ? _buildStep3()
                                : _buildStep4(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _step > 1 && _step < 99
                ? setState(() => _step--)
                : Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(PhosphorIcons.caretRight(), color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _step == 99 ? AppStrings.published
                : _step == 1 ? AppStrings.stepPhotosRestaurant
                : _step == 2 ? AppStrings.ratings
                : _step == 3 ? AppStrings.stepAtmospherePrice
                : AppStrings.stepDishesDescription,
            style: _tj(15, weight: FontWeight.w800),
          ),
          const Spacer(),
          if (_step < 99)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$_step / 4',
                  style: _tj(11, weight: FontWeight.w700, color: _kOrange)),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 5,
      color: Colors.white.withValues(alpha: 0.07),
      child: FractionallySizedBox(
        alignment: Alignment.centerRight,
        widthFactor: _step / 4,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF26500), Color(0xFFFF8C33)],
            ),
          ),
        ),
      ),
    );
  }

  // ── City picker sheet
  void _showCityPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kDark2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(AppStrings.chooseCity, style: _tj(16, weight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: _kSaudiCitiesAdd.length,
              itemBuilder: (_, i) {
                final city = _kSaudiCitiesAdd[i];
                final selected = _restaurantCity == city;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _restaurantCity = city);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: selected ? _kOrange.withValues(alpha: 0.15) : _kCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? _kOrange : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                            color: selected ? _kOrange : _kTextSec, size: 16),
                        const SizedBox(width: 10),
                        Text(city,
                            style: _tj(13,
                                weight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? _kOrange : Colors.white)),
                        if (selected) ...[
                          const Spacer(),
                          Icon(Icons.check_rounded, color: _kOrange, size: 16),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Dish photo pickers
  Future<ImageSource?> _showDishPhotoSourceDialog() => showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: _kCardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(PhosphorIcons.camera(), color: _kOrange),
          title: Text(AppStrings.camera, style: _tj(13)),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        ListTile(
          leading: Icon(PhosphorIcons.images(), color: _kOrange),
          title: Text(AppStrings.gallery, style: _tj(13)),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );

  Future<void> _pickDishPhotoForPending() async {
    final source = await _showDishPhotoSourceDialog();
    if (source == null) return;
    final photo = await _picker.pickImage(source: source, imageQuality: 70);
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    setState(() {
      _pendingDishPhoto = bytes;
      _pendingDishPhotoUrl = null;
      _dishPhotoUploading = true;
    });
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = 'dishes/${ts}_${_dishes.length}.jpg';
      await Supabase.instance.client.storage
          .from('photos')
          .uploadBinary(path, bytes);
      final url = Supabase.instance.client.storage
          .from('photos')
          .getPublicUrl(path);
      if (mounted) setState(() => _pendingDishPhotoUrl = url);
    } catch (e) {
      debugPrint('Dish photo upload error: $e');
    } finally {
      if (mounted) setState(() => _dishPhotoUploading = false);
    }
  }

  Future<void> _pickDishPhotoForIndex(int index) async {
    final source = await _showDishPhotoSourceDialog();
    if (source == null) return;
    final photo = await _picker.pickImage(source: source, imageQuality: 70);
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    // Show local preview immediately
    setState(() => _dishes[index]['preview_bytes'] = bytes);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = 'dishes/${ts}_$index.jpg';
      await Supabase.instance.client.storage
          .from('photos')
          .uploadBinary(path, bytes);
      final url = Supabase.instance.client.storage
          .from('photos')
          .getPublicUrl(path);
      if (mounted) {
        setState(() {
          _dishes[index]['photo_url'] = url;
          _dishes[index].remove('preview_bytes');
        });
      }
    } catch (e) {
      debugPrint('Dish photo upload error: $e');
      if (mounted) setState(() => _dishes[index].remove('preview_bytes'));
    }
  }

  // ── STEP 1: الصور والمطعم
  Widget _buildStep1() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(AppStrings.photos),
                const SizedBox(height: 10),
                SizedBox(
                  height: 92,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 82, height: 82,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: _kOrange, width: 1.5),
                            borderRadius: BorderRadius.circular(14),
                            color: _kOrange.withValues(alpha: 0.1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIcons.image(),
                                  color: _kOrange, size: 26),
                              const SizedBox(height: 4),
                              Text(AppStrings.addPhoto,
                                  style: _tj(8, weight: FontWeight.w700, color: _kOrange)),
                            ],
                          ),
                        ),
                      ),
                      ..._imageBytes.map((bytes) => Stack(
                        children: [
                          Container(
                            width: 82, height: 82,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              image: DecorationImage(
                                  image: MemoryImage(bytes), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 2, left: 10,
                            child: GestureDetector(
                              onTap: () => setState(() => _imageBytes.remove(bytes)),
                              child: Container(
                                width: 20, height: 20,
                                decoration: const BoxDecoration(
                                    color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),

                const SizedBox(height: 22),
                _label('${AppStrings.restaurantName} *'),
                const SizedBox(height: 8),
                _input(
                  controller: _restController,
                  hint: AppStrings.searchOrEnterRestaurant,
                  onChanged: (v) {
                    setState(() {
                      _restaurantName = v;
                      _restaurantId = null;
                    });
                    _searchRestaurant(v);
                  },
                ),

                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: _searchResults.map((r) => ListTile(
                        dense: true,
                        title: Text(r['name_ar'] ?? '',
                            style: _tj(12)),
                        subtitle: Text(r['city'] ?? '',
                            style: _tj(10, color: _kTextSec)),
                        onTap: () {
                          setState(() {
                            _restaurantId = r['id'];
                            _restaurantName = r['name_ar'];
                            _restController.text = r['name_ar'];
                            _searchResults = [];
                          });
                        },
                      )).toList(),
                    ),
                  ),

                if (_restaurantId != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF065F46).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Color(0xFF34D399), size: 16),
                        const SizedBox(width: 8),
                        Text(AppStrings.restaurantLinked,
                            style: _tj(11, weight: FontWeight.w700,
                                color: const Color(0xFF34D399))),
                      ],
                    ),
                  ),

                // Location picker — only when creating a NEW restaurant.
                if (_restaurantId == null &&
                    (_restaurantName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _label('📍 موقع المطعم (اختياري)'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _useCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              PhosphorIcons.navigationArrow(
                                  PhosphorIconsStyle.fill),
                              size: 16,
                              color: _kOrange),
                          const SizedBox(width: 8),
                          Text('موقعي الحالي',
                              style: _tj(13,
                                  weight: FontWeight.w800, color: _kOrange)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 180,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _miniMapController,
                            options: MapOptions(
                              initialCenter: cityCenter(_restaurantCity.isNotEmpty
                                  ? _restaurantCity
                                  : null),
                              initialZoom: 13,
                              interactionOptions: const InteractionOptions(
                                flags:
                                    InteractiveFlag.all & ~InteractiveFlag.rotate,
                              ),
                              onPositionChanged: (camera, hasGesture) {
                                if (hasGesture) {
                                  _lat = camera.center.latitude;
                                  _lng = camera.center.longitude;
                                }
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.aishay.app',
                                tileBuilder: (context, tileWidget, tile) =>
                                    ColorFiltered(
                                        colorFilter: kDarkenTiles,
                                        child: tileWidget),
                              ),
                            ],
                          ),
                          // Fixed center pin — move the map under it to position.
                          IgnorePointer(
                            child: Center(
                              child: Transform.translate(
                                offset: const Offset(0, -16),
                                child: Icon(
                                    PhosphorIcons.mapPin(
                                        PhosphorIconsStyle.fill),
                                    size: 34,
                                    color: _kOrange),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('حرّك الخريطة لضبط الموقع، أو اتركه فارغًا للتخطّي',
                      style: _tj(10, color: _kTextSec)),
                ],

                const SizedBox(height: 22),
                _label('⏱️ ${AppStrings.visitTime}'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: AppStrings.visitTimeOptions.map((time) {
                      final active = _visitTime == time;
                      return GestureDetector(
                        onTap: () => setState(() => _visitTime = active ? '' : time),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? _kOrange : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active ? _kOrange : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            AppStrings.localizeVisitTime(time),
                            style: _tj(12,
                                weight: active ? FontWeight.w700 : FontWeight.w500,
                                color: active ? Colors.white : _kTextSec),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 22),
                _label('✏️ ${AppStrings.experienceTitle} *'),
                const SizedBox(height: 8),
                _input(
                  controller: _titleController,
                  hint: AppStrings.titleHintExample,
                  maxLength: 80,
                ),
                // Live word counter + over-limit error (max 6 words).
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _titleController,
                  builder: (_, value, __) {
                    final count = _titleWordCount(value.text);
                    final over = count > 6;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
                      child: Row(
                        children: [
                          if (over)
                            Expanded(
                              child: Text(
                                AppStrings.titleMaxWords,
                                style: _tj(11, color: Colors.redAccent),
                              ),
                            )
                          else
                            const Spacer(),
                          Text(
                            AppStrings.wordsCount(count),
                            style: _tj(11,
                                color: over ? Colors.redAccent : _kTextSec),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 22),
                _label('🏷️ ${AppStrings.restaurantCategory}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '☕ كافيه',
                    '🥩 مشويات',
                    '🍣 سوشي',
                    '🍔 برغر',
                    '🥗 صحي',
                    '🍕 بيتزا',
                    '🍜 مطبخ آسيوي',
                    '🍗 دجاج',
                    '🥪 ساندويتش',
                    '🍚 رز',
                    '🥩 لحم',
                  ].map((cat) {
                    final active = _selectedCategories.contains(cat);
                    return GestureDetector(
                      onTap: () => setState(() =>
                          active ? _selectedCategories.remove(cat) : _selectedCategories.add(cat)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: active
                              ? _kOrange.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? _kOrange.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (active)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: const Icon(Icons.check, color: _kOrange, size: 12),
                              ),
                            Text(cat,
                                style: _tj(11, weight: FontWeight.w600,
                                    color: active ? _kOrange : _kTextSec)),
                          ],
                        ),
                      ),
                    );
                  }).toList()
                    ..add(GestureDetector(
                      onTap: () => setState(() => _showOtherCategory = !_showOtherCategory),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _showOtherCategory
                              ? _kOrange.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _showOtherCategory
                                ? _kOrange.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_showOtherCategory)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.check, color: _kOrange, size: 12),
                              ),
                            Text(AppStrings.otherCategory,
                                style: _tj(11, weight: FontWeight.w600,
                                    color: _showOtherCategory ? _kOrange : _kTextSec)),
                          ],
                        ),
                      ),
                    )),
                ),

                if (_showOtherCategory) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _input(controller: _otherCategoryCtrl, hint: AppStrings.writeCategory)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final val = _otherCategoryCtrl.text.trim();
                          if (val.isNotEmpty && !_selectedCategories.contains(val)) {
                            setState(() {
                              _selectedCategories.add(val);
                              _otherCategoryCtrl.clear();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: _kOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],

                if (_selectedCategories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedCategories.map((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kCardBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c, style: _tj(10)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _selectedCategories.remove(c)),
                            child: const Icon(Icons.close, color: Colors.white54, size: 12),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ],

                const SizedBox(height: 22),
                _label('📍 ${AppStrings.city}'),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _showCityPickerSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _restaurantCity.isNotEmpty
                            ? _kOrange.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                            color: _restaurantCity.isNotEmpty ? _kOrange : _kTextSec,
                            size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _restaurantCity.isNotEmpty ? _restaurantCity : AppStrings.chooseCity,
                            style: _tj(12,
                                color: _restaurantCity.isNotEmpty
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3)),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            color: _kTextSec, size: 18),
                      ],
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  _errorBox(_error!),
                ],
              ],
            ),
          ),
        ),
        _nextBtn(AppStrings.next, () {
          if (_titleController.text.trim().isEmpty) {
            setState(() => _error = AppStrings.enterTitle);
            return;
          }
          setState(() => _error = null);
          _nextStep();
        }),
      ],
    );
  }

  // ── STEP 2: التقييمات
  Widget _buildStep2() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ...List.generate(_ratingLabels.length, (i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_ratingLabels[i],
                                style: _tj(12, weight: FontWeight.w700)),
                            if (_ratings[i] > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _kGold.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${_ratings[i].toInt()}.0',
                                    style: _tj(11, weight: FontWeight.w800, color: _kGold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (j) {
                            final active = j < _ratings[i];
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _ratings[i] = (j + 1).toDouble()),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 150),
                                  style: TextStyle(
                                    fontSize: active ? 34 : 30,
                                    color: active
                                        ? _kGold
                                        : Colors.white.withValues(alpha: 0.2),
                                  ),
                                  child: const Text('★'),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                }),

                if (_avgRating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppStrings.overallRating,
                            style: _tj(12, color: _kTextSec)),
                        Row(
                          children: [
                            Text(
                              '${'★' * _avgRating.round()}${'☆' * (5 - _avgRating.round())}',
                              style: const TextStyle(fontSize: 16, color: _kGold),
                            ),
                            const SizedBox(width: 8),
                            Text(_avgRating.toStringAsFixed(1),
                                style: _tj(16, weight: FontWeight.w900, color: _kGold)),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        _nextBtn(AppStrings.next, _nextStep),
      ],
    );
  }

  // ── STEP 3: الأجواء والسعر
  Widget _buildStep3() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(AppStrings.ambiance),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ['🌿', 'هادي'],
                    ['🔉', 'متوسط'],
                    ['🔊', 'صاخب'],
                  ].map((a) {
                    final active = _atmosphere == a[1];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _atmosphere = a[1]),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: active
                                ? _kOrange.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: active
                                  ? _kOrange.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(a[0], style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 5),
                              Text(a[1],
                                  style: _tj(11, weight: FontWeight.w700,
                                      color: active ? _kOrange : _kTextSec)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 22),
                _label('🏷️ ${AppStrings.additionalDetails}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tagOptions.map((t) {
                    final active = _tags.contains(t);
                    return GestureDetector(
                      onTap: () => setState(() =>
                          active ? _tags.remove(t) : _tags.add(t)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: active
                              ? _kOrange.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? _kOrange.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(t,
                            style: _tj(11, weight: FontWeight.w600,
                                color: active ? _kOrange : _kTextSec)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 22),
                _label('💰 ${AppStrings.costPerPerson}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'أقل من 50 ر.س',
                    '50-100 ر.س',
                    '100-200 ر.س',
                    '200+ ر.س',
                  ].map((p) {
                    final active = _priceRange == p;
                    return GestureDetector(
                      onTap: () => setState(() => _priceRange = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: active
                              ? _kOrange.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active
                                ? _kOrange.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(p,
                            style: _tj(12, weight: FontWeight.w600,
                                color: active ? _kOrange : _kTextSec)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        _nextBtn(AppStrings.next, _nextStep),
      ],
    );
  }

  // ── STEP 4: الأطباق والوصف
  Widget _buildStep4() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(AppStrings.dishes),
                const SizedBox(height: 10),

                ..._dishes.asMap().entries.map((entry) {
                  final i = entry.key;
                  final d = entry.value;
                  final photoUrl = d['photo_url'] as String?;
                  final previewBytes = d['preview_bytes'] as Uint8List?;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _pickDishPhotoForIndex(i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: previewBytes != null
                                ? Image.memory(previewBytes,
                                    width: 38, height: 38, fit: BoxFit.cover)
                                : (photoUrl != null && photoUrl.isNotEmpty)
                                    ? Image.network(photoUrl,
                                        width: 38, height: 38, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 38, height: 38,
                                          color: _kDark2,
                                          child: Icon(PhosphorIcons.camera(),
                                              color: _kTextSec, size: 16),
                                        ))
                                    : Container(
                                        width: 38, height: 38,
                                        color: _kDark2,
                                        child: Icon(PhosphorIcons.camera(),
                                            color: _kTextSec, size: 16),
                                      ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text((d['name'] as String?) ?? '', style: _tj(12))),
                        Text('${d['price']} ${AppStrings.sar}',
                            style: _tj(12, weight: FontWeight.w700, color: _kOrange)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _dishes.removeAt(i)),
                          child: const Icon(Icons.close, color: _kTextSec, size: 16),
                        ),
                      ],
                    ),
                  );
                }),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      _input(controller: _dishNameCtrl, hint: AppStrings.dishName),
                      const SizedBox(height: 8),
                      // Dish photo picker
                      GestureDetector(
                        onTap: _dishPhotoUploading ? null : _pickDishPhotoForPending,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _pendingDishPhotoUrl != null
                                  ? _kOrange.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_dishPhotoUploading)
                                const SizedBox(
                                  width: 32, height: 32,
                                  child: Center(
                                    child: SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                          color: _kOrange, strokeWidth: 2),
                                    ),
                                  ),
                                )
                              else if (_pendingDishPhoto != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(_pendingDishPhoto!,
                                      width: 32, height: 32, fit: BoxFit.cover),
                                )
                              else
                                Icon(PhosphorIcons.camera(),
                                    color: _kTextSec, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _dishPhotoUploading
                                      ? AppStrings.uploadingImage
                                      : _pendingDishPhotoUrl != null
                                          ? AppStrings.imageUploaded
                                          : AppStrings.addDishPhotoOptional,
                                  style: _tj(11,
                                      color: _pendingDishPhotoUrl != null
                                          ? _kOrange
                                          : _kTextSec),
                                ),
                              ),
                              if (_pendingDishPhoto != null && !_dishPhotoUploading)
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _pendingDishPhoto = null;
                                    _pendingDishPhotoUrl = null;
                                  }),
                                  child: const Icon(Icons.close,
                                      color: _kTextSec, size: 14),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _input(
                                  controller: _dishPriceCtrl,
                                  hint: AppStrings.price,
                                  keyboardType: TextInputType.number)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (_dishNameCtrl.text.isNotEmpty && !_dishPhotoUploading) {
                                setState(() {
                                  _dishes.add({
                                    'name': _dishNameCtrl.text.trim(),
                                    'price': _dishPriceCtrl.text.trim(),
                                    'photo_url': _pendingDishPhotoUrl,
                                  });
                                  _pendingDishPhoto = null;
                                  _pendingDishPhotoUrl = null;
                                  _dishNameCtrl.clear();
                                  _dishPriceCtrl.clear();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: _kOrange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),
                _label('✍️ ${AppStrings.description} *'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: TextField(
                    controller: _descController,
                    maxLines: 4,
                    maxLength: 500,
                    style: _tj(13),
                    decoration: InputDecoration(
                      hintText: AppStrings.descHint,
                      hintStyle: _tj(12, color: Colors.white.withValues(alpha: 0.3)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                      counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  _errorBox(_error!),
                ],
              ],
            ),
          ),
        ),
        _nextBtn(_loading ? '...' : AppStrings.publishExperienceCta,
            _loading ? () {} : _submit),
      ],
    );
  }

  // ── SUCCESS
  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kOrange.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: _kOrange.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 24),
            Text(AppStrings.experienceShared,
                style: _tj(26, weight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(
              AppStrings.thanksMessage,
              textAlign: TextAlign.center,
              style: _tj(13, color: _kTextSec, height: 1.7),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kOrange, Color(0xFFFF8C33)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(AppStrings.backToFeed,
                      style: _tj(16, weight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPERS
  Widget _label(String text) => Row(
    children: [
      Container(width: 3, height: 16, color: _kOrange,
          margin: const EdgeInsets.only(left: 8)),
      Text(text, style: _tj(13, weight: FontWeight.w700, color: _kTextSec)),
    ],
  );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    Function(String)? onChanged,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: _tj(13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _tj(12, color: Colors.white.withValues(alpha: 0.3)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFCA5A5)),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFF991B1B), size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: _tj(11, color: const Color(0xFF991B1B)))),
      ],
    ),
  );

  Widget _nextBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kOrange, Color(0xFFFF8C33)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _kOrange.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(label, style: _tj(16, weight: FontWeight.w800)),
        ),
      ),
    );
  }
}
