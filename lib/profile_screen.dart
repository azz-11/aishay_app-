import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _experiences = [];
  List<Map<String, dynamic>> _saved = [];
  bool _loading = true;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() => _tabIndex = _tabController.index));
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
debugPrint('Current user id: ${user.id}');
debugPrint('Current user email: ${user.email}');

      final profile = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      final experiences = await Supabase.instance.client
          .from('experiences')
          .select('*, restaurant:restaurants(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final savedRes = await Supabase.instance.client
    .from('saves')
    .select('*, experience:experiences(*, restaurant:restaurants(*))')
    .eq('user_id', user.id);

      setState(() {
        _profile = profile;
        _experiences = List<Map<String, dynamic>>.from(experiences);
        _saved = List<Map<String, dynamic>>.from(savedRes);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Profile error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  double _avgRating(Map<String, dynamic> exp) {
    final fields = ['rating_food', 'rating_service', 'rating_ambiance', 'rating_clean', 'rating_value'];
    final vals = fields.map((f) => (exp[f] as num?)?.toDouble() ?? 0.0).where((v) => v > 0).toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  String _stars(double r) {
    final full = r.round();
    return '${'★' * full}${'☆' * (5 - full)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF5EE),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF26500))),
      );
    }

    final displayName = _profile?['display_name'] ?? _profile?['username'] ?? 'مستخدم';
    final username = _profile?['username'] ?? '';
    final bio = _profile?['bio'] ?? '';
    final city = _profile?['city'] ?? '';
    final avatar = _profile?['avatar_url'];

    // إحصائيات
    final expCount = _experiences.length;
    final restaurants = _experiences.map((e) => e['restaurant_id']).toSet().length;
    final cities = _experiences
        .map((e) => e['restaurant']?['city'])
        .where((c) => c != null && c.toString().isNotEmpty)
        .toSet()
        .length;
    final totalLikes = _experiences.fold<int>(0, (sum, e) => sum + ((e['likes_count'] as int?) ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EE),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // HEADER
                Container(
                  color: const Color(0xFF1A2340),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 12,
                    bottom: 20,
                    left: 16,
                    right: 16,
                  ),
                  child: Column(
                    children: [
                      // Top row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('حسابي',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                          Row(
                            children: [
                              _iconBtn(Icons.share_outlined, () {}),
                              const SizedBox(width: 8),
                              _iconBtn(Icons.logout_rounded, _signOut),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Avatar + info
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF26500), width: 2.5),
                              color: const Color(0xFF243058),
                            ),
                            child: avatar != null
                                ? ClipOval(child: Image.network(avatar, fit: BoxFit.cover))
                                : Center(
                                    child: Text(
                                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'م',
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFF26500)),
                                    ),
                                  ),
                          ),

                          const SizedBox(width: 16),

                          // Name + bio
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                                if (username.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text('@$username',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                ],
                                if (city.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, color: Color(0xFF94A3B8), size: 12),
                                      const SizedBox(width: 3),
                                      Text(city, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                ],
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(bio,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), height: 1.5),
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // تعديل الملف
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('✏️ تعديل الملف الشخصي',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // STATS
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      _stat('$expCount', 'تجربة'),
                      _divider(),
                      _stat('$restaurants', 'مطعم'),
                      _divider(),
                      _stat('$cities', 'مدينة'),
                      _divider(),
                      _stat('$totalLikes', '🔥 يستاهل'),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),

          // TABS
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFF26500),
                indicatorWeight: 2.5,
                labelColor: const Color(0xFFF26500),
                unselectedLabelColor: const Color(0xFF94A3B8),
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                tabs: const [
                  Tab(text: '🍽️ تجاربي'),
                  Tab(text: '📍 أود زيارته'),
                  Tab(text: '📊 إحصائيات'),
                ],
              ),
            ),
          ),
        ],

        body: TabBarView(
          controller: _tabController,
          children: [
            _buildExperiences(),
            _buildSaved(),
            _buildStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildExperiences() {
    if (_experiences.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🍽️', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('لا توجد تجارب بعد',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
            SizedBox(height: 6),
            Text('شارك أول تجربة لك!',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _experiences.length,
      itemBuilder: (context, i) {
        final exp = _experiences[i];
        final restName = exp['restaurant']?['name_ar'] ?? 'مطعم';
        final city = exp['restaurant']?['city'] ?? '';
        final photos = exp['photos'] as List? ?? [];
        final rating = _avgRating(exp);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              // صورة
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                child: SizedBox(
                  width: 90, height: 90,
                  child: photos.isNotEmpty
                      ? Image.network(photos[0], fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderSmall())
                      : _placeholderSmall(),
                ),
              ),

              // معلومات
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E))),
                      if (city.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('📍 $city', style: const TextStyle(fontSize: 10, color: Color(0xFF7A6655))),
                      ],
                      if (rating > 0) ...[
                        const SizedBox(height: 6),
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
                        const SizedBox(height: 4),
                        Text(
                          exp['description'].toString().length > 60
                              ? '${exp['description'].toString().substring(0, 60)}...'
                              : exp['description'].toString(),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF7A6655), height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSaved() {
    if (_saved.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📍', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('لا توجد مطاعم محفوظة',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
            SizedBox(height: 6),
            Text('اضغط أود زيارته في أي تجربة',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _saved.length,
      itemBuilder: (context, i) {
        final exp = _saved[i]['experience'];
        if (exp == null) return const SizedBox();
        final restName = exp['restaurant']?['name_ar'] ?? 'مطعم';
        final photos = exp['photos'] as List? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                child: SizedBox(
                  width: 90, height: 90,
                  child: photos.isNotEmpty
                      ? Image.network(photos[0], fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderSmall())
                      : _placeholderSmall(),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 4),
                      const Text('📍 أود زيارته',
                          style: TextStyle(fontSize: 10, color: Color(0xFFF26500), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStats() {
    if (_experiences.isEmpty) {
      return const Center(
        child: Text('لا توجد بيانات كافية',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
      );
    }

    // حساب متوسط كل تقييم
    final ratingFields = [
      ['🍽️ الطعام', 'rating_food'],
      ['🤝 الخدمة', 'rating_service'],
      ['🌅 الأجواء', 'rating_ambiance'],
      ['✨ النظافة', 'rating_clean'],
      ['💰 القيمة', 'rating_value'],
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // متوسط التقييمات
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⭐ متوسط تقييماتك',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 16),
                ...ratingFields.map((r) {
                  final vals = _experiences
                      .map((e) => (e[r[1]] as num?)?.toDouble() ?? 0.0)
                      .where((v) => v > 0)
                      .toList();
                  if (vals.isEmpty) return const SizedBox();
                  final avg = vals.reduce((a, b) => a + b) / vals.length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(width: 90,
                            child: Text(r[0], style: const TextStyle(fontSize: 11, color: Color(0xFF7A6655)))),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: avg / 5,
                              backgroundColor: const Color(0xFFE4D9CE),
                              valueColor: const AlwaysStoppedAnimation(Color(0xFFC8931A)),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(avg.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ملخص
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2340),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📊 ملخصك',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 12),
                _summaryRow('إجمالي التجارب', '${_experiences.length} تجربة'),
                _summaryRow('مطاعم مختلفة', '${_experiences.map((e) => e['restaurant_id']).toSet().length} مطعم'),
                _summaryRow('أعلى تقييم أعطيته', '5.0 ⭐'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
      ],
    ),
  );

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _divider() => Container(width: 1, height: 30, color: const Color(0xFFE4D9CE));

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );

  Widget _placeholderSmall() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF1A2340), Color(0xFF2A3A5C)]),
    ),
    child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 24))),
  );
}

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}