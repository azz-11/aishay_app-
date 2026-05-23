import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_experience_screen.dart';
import 'experience_detail_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _experiences = [];
  Map<String, dynamic>? _topExperience;
  bool _loading = true;
  String _selectedCategory = 'الكل';
  Map<String, dynamic>? _selectedExp; // التجربة المفتوحة

  final _categories = ['الكل', 'كافيهات', 'مشويات', 'سوشي', 'برغر', 'صحي'];
  final _catIcons = ['🍽️', '☕', '🥩', '🍣', '🍔', '🥗'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('experiences')
          .select('*, restaurant:restaurants(*), user:users!experiences_user_id_fkey(*)')
          .order('created_at', ascending: false)
          .limit(20);

      final list = List<Map<String, dynamic>>.from(res);

      for (int i = 0; i < list.length; i++) {
        try {
          final likes = await Supabase.instance.client
              .from('likes')
              .select('id')
              .eq('experience_id', list[i]['id']);
          list[i]['likes_count'] = likes.length;
        } catch (_) {
          list[i]['likes_count'] = 0;
        }
      }

      setState(() {
        _experiences = list;
        _topExperience = list.isNotEmpty ? list.first : null;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _loading = false);
    }
  }

  void _openExp(Map<String, dynamic> exp) {
    setState(() => _selectedExp = exp);
  }

  void _closeExp() {
    setState(() => _selectedExp = null);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == 'الكل') return _experiences;
    return _experiences.where((e) {
      final cat = e['restaurant']?['category'] ?? '';
      return cat.contains(_selectedCategory);
    }).toList();
  }

  double _avgRating(Map<String, dynamic> exp) {
    final fields = ['rating_food', 'rating_service', 'rating_ambiance', 'rating_clean', 'rating_value'];
    final vals = fields.map((f) => (exp[f] as num?)?.toDouble() ?? 0.0).where((v) => v > 0).toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  String _stars(double rating) {
    final full = rating.round();
    return '${'★' * full}${'☆' * (5 - full)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EE),
      body: Stack(
        children: [
          // الصفحة الرئيسية
          SafeArea(
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF1A2340),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Text('أي شيء',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFF26500))),
                      const Spacer(),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.search, color: Colors.white, size: 22)),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22)),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFF26500)))
                      : _experiences.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              color: const Color(0xFFF26500),
                              onRefresh: _loadData,
                              child: ListView(
                                children: [
                                  if (_topExperience != null) _buildBanner(_topExperience!),
                                  _buildCategories(),
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('🕐 أحدث التجارب',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                                        Text('شاهد الكل',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF26500))),
                                      ],
                                    ),
                                  ),
                                  ..._filtered.map((exp) => _buildExpCard(exp)),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),

          // صفحة التفاصيل فوق كل شيء
          if (_selectedExp != null)
            Positioned.fill(
              child: ExperienceDetailScreen(
                experience: _selectedExp!,
                onClose: _closeExp,
              ),
            ),
        ],
      ),
      bottomNavigationBar: _selectedExp != null ? null : _buildBottomNav(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text('لا توجد تجارب بعد',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A2340))),
          const SizedBox(height: 6),
          const Text('كن أول من يشارك تجربته 🔥',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddExperienceScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF26500), Color(0xFFFF7A1A)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('+ أضف تجربة',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(Map<String, dynamic> exp) {
    final rating = _avgRating(exp);
    final restName = exp['restaurant']?['name_ar'] ?? 'مطعم';
    final city = exp['restaurant']?['city'] ?? '';
    final likes = exp['likes_count'] ?? 0;
    final photos = exp['photos'] as List? ?? [];

    return GestureDetector(
      onTap: () => _openExp(exp),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            Positioned.fill(
              child: photos.isNotEmpty
                  ? Image.network(photos[0], fit: BoxFit.cover, errorBuilder: (_, __, ___) => _gradientBg())
                  : _gradientBg(),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFC8931A), Color(0xFFE8A820)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('⭐ الأعلى تقييماً',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF1A2340))),
              ),
            ),
            Positioned(
              bottom: 12, right: 14, left: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('📍 $city', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(_stars(rating), style: const TextStyle(fontSize: 12, color: Color(0xFFF5D485))),
                      const SizedBox(width: 6),
                      Text(rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFF5D485))),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 12, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 8),
                      Text('🔥 $likes يستاهل',
                          style: const TextStyle(fontSize: 10, color: Color(0xFFFFB347), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2D1508), Color(0xFF8B3010), Color(0xFFD4521A)],
      ),
    ),
    child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 60, color: Colors.white24))),
  );

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('التصنيفات',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
        ),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categories.length,
            itemBuilder: (context, i) {
              final cat = _categories[i];
              final active = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF1A2340) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: active ? const Color(0xFF1A2340) : const Color(0xFFE4D9CE)),
                          boxShadow: active
                              ? [BoxShadow(color: const Color(0xFF1A2340).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                              : [],
                        ),
                        child: Center(child: Text(_catIcons[i], style: const TextStyle(fontSize: 20))),
                      ),
                      const SizedBox(height: 4),
                      Text(cat,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                              color: active ? const Color(0xFF1A2340) : const Color(0xFF7A6655))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpCard(Map<String, dynamic> exp) {
    final rating = _avgRating(exp);
    final restName = exp['restaurant']?['name_ar'] ?? 'مطعم';
    final city = exp['restaurant']?['city'] ?? '';
    final userName = exp['user']?['display_name'] ?? 'مستخدم';
    final likes = exp['likes_count'] ?? 0;
    final photos = exp['photos'] as List? ?? [];

    return GestureDetector(
      onTap: () => _openExp(exp),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: photos.isNotEmpty
                    ? Image.network(photos[0], fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderImg())
                    : _placeholderImg(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFFF26500),
                        child: Text(userName.isNotEmpty ? userName[0] : 'م',
                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                      Text(userName,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                      const Spacer(),
                      Text(_timeAgo(exp['created_at']),
                          style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(restName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E))),
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('📍 $city', style: const TextStyle(fontSize: 9, color: Color(0xFF7A6655))),
                  ],
                  if (rating > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(_stars(rating), style: const TextStyle(fontSize: 11, color: Color(0xFFC8931A))),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                      ],
                    ),
                  ],
                  if (exp['description'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      exp['description'].toString().length > 80
                          ? '${exp['description'].toString().substring(0, 80)}...'
                          : exp['description'].toString(),
                      style: const TextStyle(fontSize: 10, color: Color(0xFF7A6655), height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _actionBtn('🔥 يستاهل · $likes', true),
                      const SizedBox(width: 8),
                      _actionBtn('💬 تعليق', false),
                      const Spacer(),
                      _actionBtn('📍 أود زيارته', false),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImg() => Container(
    height: 120,
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF1A2340), Color(0xFF2A3A5C)]),
    ),
    child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 40))),
  );

  Widget _actionBtn(String label, bool primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primary ? const Color(0xFFFEF0E6) : const Color(0xFFFAF5EE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primary ? const Color(0xFFF26500).withOpacity(0.3) : const Color(0xFFE4D9CE)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: primary ? const Color(0xFFF26500) : const Color(0xFF7A6655))),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      [Icons.home_rounded, 'الرئيسية'],
      [Icons.search_rounded, 'بحث'],
      [null, ''],
      [Icons.notifications_outlined, 'إشعارات'],
      [Icons.person_outline_rounded, 'حسابي'],
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE4D9CE))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              if (i == 2) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddExperienceScreen()),
                      );
                      _loadData();
                    },
                    child: Center(
                      child: Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFF26500), Color(0xFFFF7A1A)]),
                          borderRadius: BorderRadius.circular(23),
                          boxShadow: [BoxShadow(color: const Color(0xFFF26500).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                );
              }
              final active = _currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
  if (i == 4) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  } else {
    setState(() => _currentIndex = i);
  }
},
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i][0] as IconData, size: 22,
                          color: active ? const Color(0xFFF26500) : const Color(0xFF94A3B8)),
                      const SizedBox(height: 2),
                      Text(items[i][1] as String,
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                              color: active ? const Color(0xFFF26500) : const Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}