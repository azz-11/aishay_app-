import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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
  final _descController = TextEditingController();
  final _dishNameCtrl = TextEditingController();
  final _dishPriceCtrl = TextEditingController();

  // State
  int _step = 1;
  bool _loading = false;
  String? _error;

  // Ratings
  final List<double> _ratings = [0, 0, 0, 0, 0];
  final _ratingLabels = [
    '🍽️ الطعام',
    '🤝 الخدمة',
    '🌅 الأجواء',
    '✨ النظافة',
    '💰 القيمة'
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
    '👥 شبابي'
  ];

  // Dishes
  final List<Map<String, String>> _dishes = [];
List<String> _selectedCategories = [];
bool _showOtherCategory = false;
final _otherCategoryCtrl = TextEditingController();

  // Restaurant
  String? _restaurantId;
  String? _restaurantName;
  List<Map<String, dynamic>> _searchResults = [];

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
  _descController.dispose();
  _dishNameCtrl.dispose();
  _dishPriceCtrl.dispose();
  _otherCategoryCtrl.dispose();
  super.dispose();
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

  Future<void> _submit() async {
    if (_restaurantName == null || _restaurantName!.isEmpty) {
      setState(() => _error = 'أدخل اسم المطعم');
      return;
    }
    if (_descController.text.trim().isEmpty) {
      setState(() => _error = 'أدخل وصف التجربة');
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
            .insert({'name_ar': _restaurantName, 'created_by': user.id})
            .select()
            .single();
        _restaurantId = rest['id'];
      }

      final exp = await Supabase.instance.client
          .from('experiences')
          .insert({
            'user_id': user.id,
            'restaurant_id': _restaurantId,
            'description': _descController.text.trim(),
            'rating_food': _ratings[0] > 0 ? _ratings[0] : null,
            'rating_service': _ratings[1] > 0 ? _ratings[1] : null,
            'rating_ambiance': _ratings[2] > 0 ? _ratings[2] : null,
            'rating_clean': _ratings[3] > 0 ? _ratings[3] : null,
            'rating_value': _ratings[4] > 0 ? _ratings[4] : null,
            'atmosphere': _atmosphere.isNotEmpty ? _atmosphere : null,
            'price_range': _priceRange.isNotEmpty ? _priceRange : null,
          })
          .select()
          .single();

      if (_imageBytes.isNotEmpty) {
        await _uploadImages(exp['id']);
        await Supabase.instance.client
            .from('experiences')
            .update({'photos': _imageUrls})
            .eq('id', exp['id']);
      }

      if (_dishes.isNotEmpty) {
        await Supabase.instance.client.from('dishes').insert(
          _dishes.map((d) => {
            'experience_id': exp['id'],
            'name': d['name'],
            'price_sar': double.tryParse(d['price'] ?? '0'),
          }).toList(),
        );
      }

      if (mounted) setState(() => _step = 99);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2340),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _step > 1 && _step < 99
                ? setState(() => _step--)
                : Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _step == 99 ? 'تم النشر 🎉'
                : _step == 1 ? 'الصور والمطعم'
                : _step == 2 ? 'التقييمات'
                : _step == 3 ? 'الأجواء والسعر'
                : 'الأطباق والوصف',
            style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const Spacer(),
          if (_step < 99)
            Text('$_step / 4',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 3,
      color: Colors.white.withOpacity(0.1),
      child: FractionallySizedBox(
        alignment: Alignment.centerRight,
        widthFactor: _step / 4,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF26500), Color(0xFFFF7A1A)],
            ),
          ),
        ),
      ),
    );
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
              _label('📷 الصور'),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 80, height: 80,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFF26500), width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFF26500).withOpacity(0.1),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: Color(0xFFF26500), size: 26),
                            SizedBox(height: 4),
                            Text('أضف صورة',
                                style: TextStyle(color: Color(0xFFF26500),
                                    fontSize: 8, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    ..._imageBytes.map((bytes) => Stack(
                      children: [
                        Container(
                          width: 80, height: 80,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: MemoryImage(bytes), fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 2, left: 10,
                          child: GestureDetector(
                            onTap: () => setState(() => _imageBytes.remove(bytes)),
                            child: Container(
                              width: 18, height: 18,
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

              const SizedBox(height: 20),
              _label('🍽️ اسم المطعم *'),
              const SizedBox(height: 8),
              _input(
                controller: _restController,
                hint: 'ابحث أو أدخل اسم المطعم',
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
                    color: const Color(0xFF243058),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: _searchResults.map((r) => ListTile(
                      dense: true,
                      title: Text(r['name_ar'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                      subtitle: Text(r['city'] ?? '',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
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
                    color: const Color(0xFF065F46).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF34D399).withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Color(0xFF34D399), size: 16),
                      SizedBox(width: 8),
                      Text('تم ربط المطعم ✓',
                          style: TextStyle(color: Color(0xFF34D399),
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              _label('🏷️ تصنيف المطعم'),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFF26500).withOpacity(0.15)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? const Color(0xFFF26500).withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (active)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.check, color: Color(0xFFF26500), size: 12),
                            ),
                          Text(cat,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? const Color(0xFFF26500)
                                      : const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  );
                }).toList()
                  ..add(GestureDetector(
                    onTap: () => setState(() => _showOtherCategory = !_showOtherCategory),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _showOtherCategory
                            ? const Color(0xFFF26500).withOpacity(0.15)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _showOtherCategory
                              ? const Color(0xFFF26500).withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_showOtherCategory)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.check, color: Color(0xFFF26500), size: 12),
                            ),
                          Text('✏️ تصنيف آخر',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _showOtherCategory
                                      ? const Color(0xFFF26500)
                                      : const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  )),
              ),

              if (_showOtherCategory) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _input(controller: _otherCategoryCtrl, hint: 'اكتب التصنيف...')),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF26500),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
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
                      color: const Color(0xFF1A2340),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c, style: const TextStyle(color: Colors.white, fontSize: 10)),
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

              if (_error != null) ...[
                const SizedBox(height: 10),
                _errorBox(_error!),
              ],
            ],
          ),
        ),
      ),
      _nextBtn('التالي ←', _nextStep),
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
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_ratingLabels[i],
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            if (_ratings[i] > 0)
                              Text('${_ratings[i].toInt()}.0',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFC8931A))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (j) {
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _ratings[i] = (j + 1).toDouble()),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text('★',
                                    style: TextStyle(
                                      fontSize: 28,
                                      color: j < _ratings[i]
                                          ? const Color(0xFFC8931A)
                                          : Colors.white.withOpacity(0.2),
                                    )),
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
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF243058),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('التقييم الكلي',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8))),
                        Row(
                          children: [
                            Text(
                              '${'★' * _avgRating.round()}${'☆' * (5 - _avgRating.round())}',
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFFF5D485)),
                            ),
                            const SizedBox(width: 6),
                            Text(_avgRating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFF5D485))),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        _nextBtn('التالي ←', _nextStep),
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
                _label('🌅 الأجواء'),
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
                        onTap: () =>
                            setState(() => _atmosphere = a[1] as String),
                        child: Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white.withOpacity(0.15)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active
                                  ? Colors.white.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(a[0] as String,
                                  style:
                                      const TextStyle(fontSize: 22)),
                              const SizedBox(height: 4),
                              Text(a[1] as String,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: active
                                          ? Colors.white
                                          : const Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),
                _label('🏷️ تفاصيل إضافية'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tagOptions.map((t) {
                    final active = _tags.contains(t);
                    return GestureDetector(
                      onTap: () => setState(() =>
                          active ? _tags.remove(t) : _tags.add(t)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFF26500).withOpacity(0.15)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? const Color(0xFFF26500).withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? const Color(0xFFF26500)
                                    : const Color(0xFF94A3B8))),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),
                _label('💰 التكلفة للفرد'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'أقل من 50 ر.س',
                    '50-100 ر.س',
                    '100-200 ر.س',
                    '200+ ر.س'
                  ].map((p) {
                    final active = _priceRange == p;
                    return GestureDetector(
                      onTap: () => setState(() => _priceRange = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFF26500).withOpacity(0.15)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? const Color(0xFFF26500).withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Text(p,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? const Color(0xFFF26500)
                                    : const Color(0xFF94A3B8))),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        _nextBtn('التالي ←', _nextStep),
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
                _label('🍽️ الأطباق'),
                const SizedBox(height: 10),

                ..._dishes.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text('🍽️', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(d['name'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11))),
                      Text('${d['price']} ر.س',
                          style: const TextStyle(
                              color: Color(0xFFF26500),
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _dishes.remove(d)),
                        child: const Icon(Icons.close,
                            color: Color(0xFF94A3B8), size: 16),
                      ),
                    ],
                  ),
                )),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      _input(
                          controller: _dishNameCtrl,
                          hint: 'اسم الطبق'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _input(
                                  controller: _dishPriceCtrl,
                                  hint: 'السعر',
                                  keyboardType: TextInputType.number)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (_dishNameCtrl.text.isNotEmpty) {
                                setState(() {
                                  _dishes.add({
                                    'name': _dishNameCtrl.text.trim(),
                                    'price': _dishPriceCtrl.text.trim(),
                                  });
                                  _dishNameCtrl.clear();
                                  _dishPriceCtrl.clear();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF26500),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                _label('✍️ وصف التجربة *'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12)),
                  ),
                  child: TextField(
                    controller: _descController,
                    maxLines: 4,
                    maxLength: 500,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'شاركنا تجربتك... كيف كان الطعام؟ الخدمة؟ الأجواء؟',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                      counterStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3)),
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
        _nextBtn(_loading ? '...' : '🔥 نشر التجربة',
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
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('تجربتك انتشرت!',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
              'شكراً — تجربتك ستساعد أصدقاءك يختارون صح 🔥',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  height: 1.6),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF26500), Color(0xFFFF7A1A)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF26500).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: const Center(
                  child: Text('العودة للفيد',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPERS
  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8)));

  Widget _input({
    required TextEditingController controller,
    required String hint,
    Function(String)? onChanged,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.white.withOpacity(0.3)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
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
        const Icon(Icons.warning_amber_rounded,
            color: Color(0xFF991B1B), size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF991B1B)))),
      ],
    ),
  );

  Widget _nextBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF26500), Color(0xFFFF7A1A)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF26500).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
      ),
    );
  }
}