import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'experience_detail_screen.dart';
import 'user_profile_screen.dart';
import 'l10n/app_strings.dart';
import 'widgets/app_placeholder.dart';
import 'widgets/app_avatar.dart';
import 'widgets/restaurant_card.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kDark    = Color(0xFF0F1923);
const _kDark2   = Color(0xFF1A2340);
const _kOrange  = Color(0xFFF26500);
const _kGold    = Color(0xFFC8931A);
const _kCardBg  = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size, FontWeight weight, Color color, {double height = 1.0}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color, height: height);

// Shared select string for the experiences tab.
const _kExpSelect =
    'id, title, description, photos, rating_food, rating_service, '
    'rating_ambiance, rating_clean, rating_value, '
    'restaurant:restaurants(name_ar, city), '
    'user:users!experiences_user_id_fkey(display_name, username, avatar_url)';

class SearchScreen extends StatefulWidget {
  /// When set, the screen opens pre-filtered by this query on the التجارب tab.
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  int _activeTab = 0; // 0=التجارب  1=المطاعم  2=الأشخاص
  String _searchQuery = '';

  List<Map<String, dynamic>> _experiences = [];
  List<Map<String, dynamic>> _restaurants = [];
  List<Map<String, dynamic>> _users = [];

  Set<String> _myFollowing = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() { if (mounted) setState(() {}); });
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _ctrl.text = initial;
      _searchQuery = initial;
      _activeTab = 0; // التجارب
    }
    _loadMyFollowing();
    _loadData(); // first load → all results for the default tab
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Following set (for follow buttons) ───────────────────────────────────────

  Future<void> _loadMyFollowing() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;
    try {
      final res = await Supabase.instance.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', me.id);
      if (mounted) {
        setState(() {
          _myFollowing = (res as List).map((r) => r['following_id'].toString()).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow(String targetId) async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;
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
          'follower_id': me.id,
          'following_id': targetId,
        }, onConflict: 'follower_id,following_id');
        try {
          await Supabase.instance.client.from('notifications').insert({
            'user_id': targetId,
            'from_user_id': me.id,
            'type': 'follow',
            'is_read': false,
          });
        } catch (e) {
          debugPrint('Follow notification error: $e');
        }
      } else {
        await Supabase.instance.client
            .from('follows')
            .delete()
            .eq('follower_id', me.id)
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

  // ── Search input → debounced load ───────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final q = value.trim();
      if (q == _searchQuery) return;
      _searchQuery = q;
      _loadData();
    });
  }

  void _onTabChanged(int index) {
    if (_activeTab == index) return;
    setState(() => _activeTab = index);
    _loadData();
  }

  // ── Data loading per tab ─────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final q = _searchQuery;
    final tab = _activeTab;
    try {
      switch (tab) {
        case 0:
          await _loadExperiences(q);
          break;
        case 1:
          await _loadRestaurants(q);
          break;
        default:
          await _loadUsers(q);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.searchError}: $e')),
        );
      }
    }
  }

  Future<void> _loadExperiences(String q) async {
    final client = Supabase.instance.client;

    if (q.isEmpty) {
      final res = await client
          .from('experiences')
          .select(_kExpSelect)
          .order('created_at', ascending: false)
          .limit(20);
      if (mounted && _activeTab == 0) {
        setState(() { _experiences = List<Map<String, dynamic>>.from(res); _loading = false; });
      }
      return;
    }

    // Match by restaurant name (two-step) OR by title/description, then merge.
    final restRes = await client
        .from('restaurants')
        .select('id')
        .ilike('name_ar', '%$q%');
    final restIds = (restRes as List).map((r) => r['id'].toString()).toList();

    List<Map<String, dynamic>> byRestaurant = [];
    if (restIds.isNotEmpty) {
      final res = await client
          .from('experiences')
          .select(_kExpSelect)
          .inFilter('restaurant_id', restIds)
          .order('created_at', ascending: false)
          .limit(20);
      byRestaurant = List<Map<String, dynamic>>.from(res);
    }

    final byContent = await client
        .from('experiences')
        .select(_kExpSelect)
        .or('description.ilike.%$q%,title.ilike.%$q%')
        .order('created_at', ascending: false)
        .limit(20);

    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final e in [...byRestaurant, ...List<Map<String, dynamic>>.from(byContent)]) {
      final id = e['id']?.toString() ?? '';
      if (id.isNotEmpty && seen.add(id)) merged.add(e);
    }
    if (mounted && _activeTab == 0) {
      setState(() { _experiences = merged; _loading = false; });
    }
  }

  Future<void> _loadRestaurants(String q) async {
    final base = Supabase.instance.client.from('restaurants').select(
        'id, name_ar, city, category, avg_rating, cover_image, experiences(photos)');
    final res = q.isEmpty
        ? await base.limit(20)
        : await base.ilike('name_ar', '%$q%').limit(20);
    if (mounted && _activeTab == 1) {
      setState(() { _restaurants = List<Map<String, dynamic>>.from(res); _loading = false; });
    }
  }

  Future<void> _loadUsers(String q) async {
    final base = Supabase.instance.client
        .from('users')
        .select('id, display_name, username, avatar_url, bio, city');
    final res = q.isEmpty
        ? await base.limit(20)
        : await base.or('display_name.ilike.%$q%,username.ilike.%$q%').limit(20);
    if (mounted && _activeTab == 2) {
      setState(() { _users = List<Map<String, dynamic>>.from(res); _loading = false; });
    }
  }

  double _avgRating(Map<String, dynamic> exp) {
    const fields = ['rating_food', 'rating_service', 'rating_ambiance', 'rating_clean', 'rating_value'];
    final vals = fields
        .map((f) => (exp[f] as num?)?.toDouble() ?? 0.0)
        .where((v) => v > 0)
        .toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  List<Map<String, dynamic>> get _activeList {
    switch (_activeTab) {
      case 0:  return _experiences;
      case 1:  return _restaurants;
      default: return _users;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      body: Column(
        children: [
          // ── HEADER ────────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A2A40), _kDark],
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 14,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.exploreRestaurants,
                    style: _tj(20, FontWeight.w900, Colors.white)),
                const SizedBox(height: 2),
                Text(AppStrings.searchSubtitle,
                    style: _tj(12, FontWeight.w400, _kTextSec)),
                const SizedBox(height: 14),
                // Search input
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _searchFocus.hasFocus
                          ? _kOrange.withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.1),
                      width: _searchFocus.hasFocus ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _searchFocus.hasFocus
                            ? _kOrange.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.2),
                        blurRadius: _searchFocus.hasFocus ? 18 : 10,
                        spreadRadius: _searchFocus.hasFocus ? 2 : 0,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _searchFocus,
                    textDirection: TextDirection.rtl,
                    style: _tj(13, FontWeight.w400, Colors.white),
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: AppStrings.searchHint,
                      hintStyle: _tj(12, FontWeight.w400, _kTextSec),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2),
                              ),
                            )
                          : _ctrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded, color: _kTextSec, size: 20),
                                  onPressed: () {
                                    _ctrl.clear();
                                    _debounce?.cancel();
                                    _searchQuery = '';
                                    _loadData();
                                    setState(() {});
                                  },
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Icon(PhosphorIcons.magnifyingGlass(), color: _kOrange, size: 22),
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── TABS (orange underline) ─────────────────────────────────────────
          Container(
            color: _kDark2,
            child: Row(
              children: [
                _TabSpec(0, AppStrings.experiencesTab),
                _TabSpec(1, AppStrings.restaurantsTab),
                _TabSpec(2, AppStrings.peopleTab),
              ].map(_buildTab).toList(),
            ),
          ),

          // ── RESULTS ───────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kOrange))
                : _activeList.isEmpty
                    ? _buildEmpty()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                        children: [
                          if (_activeTab == 0)
                            ..._experiences.asMap().entries.map((e) => _SearchFadeIn(
                              delay: Duration(milliseconds: e.key * 60),
                              child: _buildExpCard(e.value),
                            )),
                          if (_activeTab == 1)
                            ..._restaurants.asMap().entries.map((e) => _SearchFadeIn(
                              delay: Duration(milliseconds: e.key * 60),
                              child: _buildRestaurantCard(e.value),
                            )),
                          if (_activeTab == 2)
                            ..._users.asMap().entries.map((e) => _SearchFadeIn(
                              delay: Duration(milliseconds: e.key * 60),
                              child: _buildUserCard(e.value),
                            )),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(_TabSpec spec) {
    final active = _activeTab == spec.index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabChanged(spec.index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                spec.label,
                textAlign: TextAlign.center,
                style: _tj(
                  13,
                  active ? FontWeight.w800 : FontWeight.w500,
                  active ? Colors.white : _kTextSec,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 2.5,
              width: active ? 42 : 0,
              decoration: BoxDecoration(
                color: _kOrange,
                borderRadius: BorderRadius.circular(2),
                boxShadow: active
                    ? [BoxShadow(color: _kOrange.withValues(alpha: 0.5), blurRadius: 6)]
                    : [],
              ),
            ),
            const SizedBox(height: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('😕', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 14),
          Text(AppStrings.noResults, style: _tj(15, FontWeight.w800, Colors.white)),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isEmpty ? AppStrings.noContentYet : AppStrings.tryDifferentSearch,
            style: _tj(12, FontWeight.w400, _kTextSec),
          ),
        ],
      ),
    );
  }

  // ── PEOPLE CARD ──────────────────────────────────────────────────────────────

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name      = user['display_name'] as String? ?? 'مستخدم';
    final username  = user['username'] as String? ?? '';
    final bio       = user['bio'] as String? ?? '';
    final avatar    = user['avatar_url'] as String?;
    final city      = user['city'] as String? ?? '';
    final userId    = user['id']?.toString() ?? '';
    final me        = Supabase.instance.client.auth.currentUser;
    final isMe      = me != null && me.id == userId;
    final following = _myFollowing.contains(userId);

    return GestureDetector(
      onTap: () => userId.isNotEmpty
          ? Navigator.push(context,
              MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)))
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
        ),
        child: Row(
          children: [
            AppAvatar(
              displayName: name,
              username: (user['username'] ?? '').toString(),
              avatarUrl: avatar,
              size: 50,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: _tj(13, FontWeight.w900, Colors.white)),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('@$username', style: _tj(10, FontWeight.w400, _kTextSec)),
                  ],
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), size: 10, color: _kTextSec),
                        const SizedBox(width: 3),
                        Text(city, style: _tj(10, FontWeight.w400, _kTextSec)),
                      ],
                    ),
                  ],
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      bio.length > 50 ? '${bio.substring(0, 50)}...' : bio,
                      style: _tj(10, FontWeight.w400, _kTextSec),
                    ),
                  ],
                ],
              ),
            ),
            if (!isMe && userId.isNotEmpty) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _toggleFollow(userId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: following ? Colors.white.withValues(alpha: 0.08) : _kOrange,
                    borderRadius: BorderRadius.circular(18),
                    border: following
                        ? Border.all(color: Colors.white.withValues(alpha: 0.25))
                        : null,
                  ),
                  child: Text(
                    following ? AppStrings.followingState : AppStrings.followAction,
                    style: _tj(11, FontWeight.w700, Colors.white),
                  ),
                ),
              ),
            ] else
              Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 18),
          ],
        ),
      ),
    );
  }

  // ── RESTAURANT CARD ────────────────────────────────────────────────────────

  Widget _buildRestaurantCard(Map<String, dynamic> rest) {
    return RestaurantCard(
      restaurant: rest,
      photos: _restaurantPhotos(rest),
      onTap: () {
        // Jump to the التجارب tab filtered by this restaurant.
        final name = rest['name_ar'] as String? ?? '';
        _ctrl.text = name;
        _debounce?.cancel();
        _searchQuery = name;
        setState(() => _activeTab = 0);
        _loadData();
      },
    );
  }

  /// Flatten experiences[].photos → dedupe → first 4 (for the collage).
  List<String> _restaurantPhotos(Map<String, dynamic> rest) {
    final seen = <String>{};
    final out = <String>[];
    final exps = rest['experiences'];
    if (exps is List) {
      for (final e in exps) {
        final photos = (e is Map) ? e['photos'] : null;
        if (photos is List) {
          for (final ph in photos) {
            final url = ph?.toString();
            if (url != null && url.isNotEmpty && seen.add(url)) {
              out.add(url);
              if (out.length >= 4) return out;
            }
          }
        }
      }
    }
    return out;
  }

  // ── EXPERIENCE CARD ──────────────────────────────────────────────────────────

  Widget _buildExpCard(Map<String, dynamic> exp) {
    final restName  = exp['restaurant']?['name_ar'] ?? 'مطعم';
    final city      = exp['restaurant']?['city'] as String? ?? '';
    final rating    = _avgRating(exp);
    final photos    = exp['photos'] as List? ?? [];
    final userName  = exp['user']?['display_name'] as String? ?? 'مستخدم';
    final userAvatar = exp['user']?['avatar_url'] as String?;
    final desc      = exp['description']?.toString() ?? '';
    final title     = (exp['title'] as String? ?? '').trim();
    final quoteText = title.isNotEmpty
        ? title
        : (desc.length > 70 ? '${desc.substring(0, 70)}...' : desc);
    final full      = rating.round();
    final stars     = '${'★' * full}${'☆' * (5 - full)}';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ExperienceDetailScreen(experience: exp)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo (180px) with overlaid info
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Photo
                    photos.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: photos[0].toString(),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ColoredBox(color: _kCardBg),
                            errorWidget: (_, __, ___) =>
                                AppPlaceholder(name: restName, borderRadius: 0),
                          )
                        : AppPlaceholder(name: restName, borderRadius: 0),

                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                              Colors.black.withValues(alpha: 0.90),
                            ],
                            stops: const [0.22, 0.52, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Rating badge top-right
                    if (rating > 0)
                      Positioned(
                        top: 12, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kGold,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: _kGold.withValues(alpha: 0.4), blurRadius: 8)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('★', style: TextStyle(fontSize: 10, color: Colors.white)),
                              const SizedBox(width: 3),
                              Text(rating.toStringAsFixed(1),
                                  style: _tj(10, FontWeight.w800, Colors.white)),
                            ],
                          ),
                        ),
                      ),

                    // Restaurant name + city + title at bottom of photo
                    Positioned(
                      bottom: 12, left: 12, right: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(restName,
                              style: GoogleFonts.tajawal(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 8)],
                              )),
                          if (city.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(city,
                                style: _tj(10, FontWeight.w400, Colors.white70)),
                          ],
                          if (quoteText.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: 40, height: 3,
                              decoration: BoxDecoration(
                                color: _kOrange,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _styledTitle(quoteText, fontSize: 13),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Below photo
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stars row
                  if (rating > 0) ...[
                    Row(
                      children: [
                        Text(stars, style: const TextStyle(fontSize: 12, color: _kGold)),
                        const SizedBox(width: 5),
                        Text(rating.toStringAsFixed(1),
                            style: _tj(11, FontWeight.w700, _kGold)),
                      ],
                    ),
                    const SizedBox(height: 7),
                  ],
                  // User avatar + name
                  Row(
                    children: [
                      AppAvatar(
                        displayName: userName,
                        username: (exp['user']?['username'] ?? '').toString(),
                        avatarUrl: userAvatar,
                        size: 22,
                      ),
                      const SizedBox(width: 7),
                      Text('${AppStrings.by} $userName',
                          style: _tj(10, FontWeight.w500, _kTextSec)),
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

  Widget _styledTitle(String text, {double fontSize = 11.0}) {
    final words = text.trim().split(' ');
    final firstWord = words.isNotEmpty ? words.first : '';
    final rest = words.length > 1 ? words.sublist(1).join(' ') : '';
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textDirection: TextDirection.rtl,
      text: TextSpan(
        style: GoogleFonts.tajawal(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        children: [
          const TextSpan(text: '❝ ', style: TextStyle(color: _kOrange)),
          TextSpan(text: firstWord, style: const TextStyle(color: _kOrange)),
          if (rest.isNotEmpty)
            TextSpan(text: ' $rest', style: const TextStyle(color: Colors.white)),
          const TextSpan(text: ' ❞', style: TextStyle(color: _kOrange)),
        ],
      ),
    );
  }


}

class _TabSpec {
  final int index;
  final String label;
  const _TabSpec(this.index, this.label);
}

class _SearchFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _SearchFadeIn({required this.child, required this.delay});

  @override
  State<_SearchFadeIn> createState() => _SearchFadeInState();
}

class _SearchFadeInState extends State<_SearchFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _offset, child: widget.child),
      );
}
