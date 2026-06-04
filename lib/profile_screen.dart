import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_screen.dart';
import 'experience_detail_screen.dart';
import 'settings_screen.dart';
import 'user_profile_screen.dart';
import 'l10n/app_strings.dart';
import 'widgets/app_placeholder.dart';
import 'widgets/app_avatar.dart';

// ── Design tokens (match home & detail screens)
const _kDark    = Color(0xFF0F1923);
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

class ProfileScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;
  const ProfileScreen({super.key, this.refreshNotifier});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  // Static cache — survives tab switches without re-fetching
  static Map<String, dynamic>? _cachedProfile;
  static List<Map<String, dynamic>> _cachedExperiences = [];
  static List<Map<String, dynamic>> _cachedSaved = [];

  late TabController _tabController;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _experiences = [];
  List<Map<String, dynamic>> _saved = [];
  bool _loading = true;
  int _avatarVersion = 0;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    widget.refreshNotifier?.addListener(_onRefreshTriggered);
    _loadFollowCounts();
    // Show cached data instantly, then refresh in background
    if (_cachedProfile != null) {
      _profile      = _cachedProfile;
      _experiences  = _cachedExperiences;
      _saved        = _cachedSaved;
      _loading      = false;
      _loadProfile(silent: true);
    } else {
      _loadProfile();
    }
  }

  void _onRefreshTriggered() {
    if (mounted) _loadProfile(silent: true);
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshTriggered);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      final experiences = await Supabase.instance.client
          .from('experiences')
          .select('*, restaurant:restaurants(*), user:users!experiences_user_id_fkey(display_name, username, avatar_url)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final savedRes = await Supabase.instance.client
          .from('saves')
          .select('*, experience:experiences(*, restaurant:restaurants(*), user:users!experiences_user_id_fkey(display_name, username, avatar_url))')
          .eq('user_id', user.id);

      final expList   = List<Map<String, dynamic>>.from(experiences);
      final savedList = List<Map<String, dynamic>>.from(savedRes);
      // Update static cache
      _cachedProfile     = profile;
      _cachedExperiences = expList;
      _cachedSaved       = savedList;
      setState(() {
        _profile     = profile;
        _experiences = expList;
        _saved       = savedList;
        _loading     = false;
        _avatarVersion++;
      });
      await _loadFollowCounts();
    } catch (e) {
      debugPrint('Profile error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadFollowCounts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final followersRes = await Supabase.instance.client
          .from('follows')
          .select('follower_id')
          .eq('following_id', user.id);
      final followingRes = await Supabase.instance.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', user.id);
      if (mounted) {
        setState(() {
          _followersCount = (followersRes as List).length;
          _followingCount = (followingRes as List).length;
        });
        debugPrint('Follow counts — followers: $_followersCount, following: $_followingCount');
      }
    } catch (e) {
      debugPrint('Follow counts error: $e');
    }
  }

  Future<void> _shareProfile() async {
    final text = 'ألقِ نظرة على تجاربي 👀\nhttps://aishay-app.vercel.app';
    try {
      await Share.share(text);
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نسخ الرابط',
                style: GoogleFonts.tajawal(color: Colors.white)),
            backgroundColor: const Color(0xFFF26500),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: _profile ?? {})),
    );
    if (result == true && mounted) {
      _loadProfile(silent: true);
    }
  }

  Future<void> _openExperienceDetail(Map<String, dynamic> exp) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => ExperienceDetailScreen(
          experience: exp,
          onClose: () => Navigator.pop(context),
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
    if (mounted) _loadProfile();
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(profile: _profile),
      ),
    );
    if (mounted) _loadProfile(silent: true);
  }

  Future<void> _showFollowList({required bool isFollowers}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: _kDark2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FollowListSheet(
        title: isFollowers ? AppStrings.followers : AppStrings.following,
        userId: user.id,
        currentUserId: user.id,
        isFollowers: isFollowers,
        onRefreshCounts: _loadFollowCounts,
      ),
    );
    if (mounted) _loadFollowCounts();
  }

  double _avgRating(Map<String, dynamic> exp) {
    final fields = ['rating_food', 'rating_service', 'rating_ambiance', 'rating_clean', 'rating_value'];
    final vals = fields.map((f) => (exp[f] as num?)?.toDouble() ?? 0.0).where((v) => v > 0).toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _kDark,
        body: const Center(child: CircularProgressIndicator(color: _kOrange)),
      );
    }

    final displayName = _profile?['display_name'] ?? _profile?['username'] ?? 'مستخدم';
    final username = _profile?['username'] ?? '';
    final bio = _profile?['bio'] ?? '';
    final city = _profile?['city'] ?? '';
    final avatar = _profile?['avatar_url'];

    final expCount = _experiences.length;

    return Scaffold(
      backgroundColor: _kDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── CINEMATIC HEADER
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1F2E4A), _kDark],
                    ),
                  ),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 14,
                    bottom: 26,
                    left: 16,
                    right: 16,
                  ),
                  child: Column(
                    children: [
                      // Top bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('حسابي', style: _tj(20, weight: FontWeight.w900)),
                          Row(
                            children: [
                              _iconBtn(PhosphorIcons.shareNetwork(), _shareProfile),
                              const SizedBox(width: 8),
                              _iconBtn(PhosphorIcons.gear(), _openSettings),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Header row: avatar on the right (forced RTL), info left
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AppAvatar(
                              displayName: displayName,
                              username: username,
                              avatarUrl:
                                  avatar != null ? '$avatar?v=$_avatarVersion' : null,
                              size: 72,
                              showGlow: true,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(displayName,
                                      style: _tj(16, weight: FontWeight.w900),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (username.isNotEmpty || city.toString().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (username.isNotEmpty)
                                          Flexible(
                                            child: Text('@$username',
                                                style: _tj(12, color: _kTextSec),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        if (username.isNotEmpty && city.toString().isNotEmpty)
                                          Text('  ·  ', style: _tj(12, color: _kTextSec)),
                                        if (city.toString().isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                                                  size: 11, color: _kTextSec),
                                              const SizedBox(width: 3),
                                              Text(city, style: _tj(12, color: _kTextSec)),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  // Inline stats: followers · following · experiences
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _headerStat(_followersCount, AppStrings.followers,
                                          onTap: () => _showFollowList(isFollowers: true)),
                                      _headerStatDivider(),
                                      _headerStat(_followingCount, AppStrings.following,
                                          onTap: () => _showFollowList(isFollowers: false)),
                                      _headerStatDivider(),
                                      _headerStat(expCount, AppStrings.experiences),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bio (optional, start-aligned)
                      if (bio.toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              bio,
                              style: _tj(12, color: const Color(0xFFCBD5E1), height: 1.5),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Edit profile button
                      GestureDetector(
                        onTap: _openEditProfile,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          child: Center(
                            child: Text(AppStrings.editProfile,
                                style: _tj(13, weight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 2),
              ],
            ),
          ),

          // ── PINNED TABS
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: _kOrange,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: _kOrange,
                unselectedLabelColor: _kTextSec,
                labelStyle: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w800),
                unselectedLabelStyle: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: AppStrings.myExperiences),
                  Tab(text: AppStrings.saved),
                  Tab(text: AppStrings.statistics),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.forkKnife(), size: 52, color: _kTextSec.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text('لا توجد تجارب بعد', style: _tj(14, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('شارك أول تجربة لك!', style: _tj(12, color: _kTextSec)),
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

        return GestureDetector(
          onTap: () => _openExperienceDetail(exp),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Photo
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                  child: SizedBox(
                    width: 96, height: 96,
                    child: photos.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: photos[0].toString(),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ColoredBox(color: _kDark2),
                            errorWidget: (_, __, ___) => AppPlaceholder(
                              name: (exp['restaurant']?['name_ar'] ?? exp['title'] ?? '').toString(),
                              borderRadius: 0,
                            ),
                          )
                        : AppPlaceholder(
                            name: (exp['restaurant']?['name_ar'] ?? exp['title'] ?? '').toString(),
                            borderRadius: 0,
                          ),
                  ),
                ),

                // Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(restName, style: _tj(13, weight: FontWeight.w900)),
                        if (city.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(city, style: _tj(10, color: _kTextSec)),
                        ],
                        if (rating > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _kGold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('★', style: TextStyle(fontSize: 11, color: _kGold)),
                                const SizedBox(width: 3),
                                Text(rating.toStringAsFixed(1),
                                    style: _tj(11, weight: FontWeight.w800, color: _kGold)),
                              ],
                            ),
                          ),
                        ],
                        if (exp['description'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            exp['description'].toString().length > 65
                                ? '${exp['description'].toString().substring(0, 65)}...'
                                : exp['description'].toString(),
                            style: _tj(10, color: _kTextSec, height: 1.55),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaved() {
    if (_saved.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), size: 52, color: _kTextSec.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text('لا توجد مطاعم محفوظة', style: _tj(14, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('اضغط أود زيارته في أي تجربة', style: _tj(12, color: _kTextSec)),
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

        return GestureDetector(
          onTap: () => _openExperienceDetail(exp),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10)],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                  child: SizedBox(
                    width: 96, height: 96,
                    child: photos.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: photos[0].toString(),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ColoredBox(color: _kDark2),
                            errorWidget: (_, __, ___) => AppPlaceholder(
                              name: (exp['restaurant']?['name_ar'] ?? exp['title'] ?? '').toString(),
                              borderRadius: 0,
                            ),
                          )
                        : AppPlaceholder(
                            name: (exp['restaurant']?['name_ar'] ?? exp['title'] ?? '').toString(),
                            borderRadius: 0,
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(restName, style: _tj(13, weight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(AppStrings.wantToVisit,
                              style: _tj(10, weight: FontWeight.w700, color: _kOrange)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStats() {
    if (_experiences.isEmpty) {
      return Center(
        child: Text('لا توجد بيانات كافية', style: _tj(13, color: _kTextSec)),
      );
    }

    final ratingFields = [
      ['الطعام', 'rating_food'],
      ['الخدمة', 'rating_service'],
      ['الأجواء', 'rating_ambiance'],
      ['النظافة', 'rating_clean'],
      ['القيمة', 'rating_value'],
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating averages
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('متوسط تقييماتك', style: _tj(13, weight: FontWeight.w800)),
                const SizedBox(height: 18),
                ...ratingFields.map((r) {
                  final vals = _experiences
                      .map((e) => (e[r[1]] as num?)?.toDouble() ?? 0.0)
                      .where((v) => v > 0)
                      .toList();
                  if (vals.isEmpty) return const SizedBox();
                  final avg = vals.reduce((a, b) => a + b) / vals.length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(r[0], style: _tj(11, color: _kTextSec)),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: avg / 5,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFB8860B), Color(0xFFF5C542)],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(avg.toStringAsFixed(1),
                            style: _tj(11, weight: FontWeight.w800, color: _kGold)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Summary
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kDark2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ملخصك', style: _tj(13, weight: FontWeight.w800)),
                const SizedBox(height: 14),
                _summaryRow('إجمالي التجارب', '${_experiences.length} تجربة'),
                _summaryRow('مطاعم مختلفة',
                    '${_experiences.map((e) => e['restaurant_id']).toSet().length} مطعم'),
                _summaryRow('أعلى تقييم أعطيته', '5.0'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: _tj(11, color: _kTextSec)),
        Text(value, style: _tj(11, weight: FontWeight.w800, color: _kGold)),
      ],
    ),
  );

  // Compact inline stat for the header row (orange number + muted label).
  Widget _headerStat(num value, String label, {VoidCallback? onTap}) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${value.round()}',
                style: _tj(14, weight: FontWeight.w900, color: _kOrange)),
            const SizedBox(height: 1),
            Text(label, style: _tj(10, color: _kTextSec)),
          ],
        ),
      );

  Widget _headerStatDivider() => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.08),
      );

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );

}

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _kDark,
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

// ── Followers / Following bottom-sheet ────────────────────────────────────────

class _FollowListSheet extends StatefulWidget {
  final String title;
  final String userId;
  final String currentUserId;
  final bool isFollowers;
  final VoidCallback? onRefreshCounts;

  const _FollowListSheet({
    required this.title,
    required this.userId,
    required this.currentUserId,
    required this.isFollowers,
    this.onRefreshCounts,
  });

  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  List<Map<String, dynamic>> _users = [];
  Set<String> _myFollowing = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final List<String> userIds;
      if (widget.isFollowers) {
        final res = await Supabase.instance.client
            .from('follows')
            .select('follower_id')
            .eq('following_id', widget.userId);
        userIds = (res as List).map((r) => r['follower_id'].toString()).toList();
      } else {
        final res = await Supabase.instance.client
            .from('follows')
            .select('following_id')
            .eq('follower_id', widget.userId);
        userIds = (res as List).map((r) => r['following_id'].toString()).toList();
      }

      if (userIds.isEmpty) {
        if (mounted) setState(() { _users = []; _loading = false; });
        return;
      }

      final usersRes = await Supabase.instance.client
          .from('users')
          .select('id, display_name, username, avatar_url')
          .inFilter('id', userIds);

      final followingRes = await Supabase.instance.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', widget.currentUserId)
          .inFilter('following_id', userIds);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(usersRes);
          _myFollowing = (followingRes as List)
              .map((r) => r['following_id'].toString())
              .toSet();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(String targetId) async {
    final wasFollowing = _myFollowing.contains(targetId);
    setState(() {
      if (wasFollowing) {
        _myFollowing.remove(targetId);
      } else {
        _myFollowing.add(targetId);
      }
    });
    try {
      if (!wasFollowing) {
        await Supabase.instance.client.from('follows').upsert({
          'follower_id': widget.currentUserId,
          'following_id': targetId,
        }, onConflict: 'follower_id,following_id');
      } else {
        await Supabase.instance.client
            .from('follows')
            .delete()
            .eq('follower_id', widget.currentUserId)
            .eq('following_id', targetId);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (wasFollowing) {
            _myFollowing.add(targetId);
          } else {
            _myFollowing.remove(targetId);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title, style: _tj(16, weight: FontWeight.w900)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kOrange))
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline_rounded,
                                color: _kTextSec, size: 42),
                            const SizedBox(height: 12),
                            Text('لا يوجد بعد',
                                style: _tj(13, color: _kTextSec)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: _users.length,
                        itemBuilder: (_, i) => _buildUserItem(_users[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> u) {
    final uid = u['id'].toString();
    final name = u['display_name'] as String? ?? 'مستخدم';
    final username = u['username'] as String? ?? '';
    final avatar = u['avatar_url'] as String?;
    final isMe = uid == widget.currentUserId;
    final following = _myFollowing.contains(uid);

    return GestureDetector(
      onTap: () async {
        final nav = Navigator.of(context);
        nav.pop();
        await nav.push(
          MaterialPageRoute(builder: (_) => UserProfileScreen(userId: uid)),
        );
        widget.onRefreshCounts?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            AppAvatar(
              displayName: name,
              username: username,
              avatarUrl: avatar,
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: _tj(13, weight: FontWeight.w700)),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('@$username', style: _tj(11, color: _kTextSec)),
                  ],
                ],
              ),
            ),
            if (!isMe)
              GestureDetector(
                onTap: () => _toggleFollow(uid),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: following
                        ? Colors.white.withValues(alpha: 0.08)
                        : _kOrange,
                    borderRadius: BorderRadius.circular(18),
                    border: following
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.25))
                        : null,
                  ),
                  child: Text(
                    following ? 'تتابعه' : '+ متابعة',
                    style: _tj(11, weight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}
