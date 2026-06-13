import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_experience_screen.dart' deferred as add_exp;
import 'app_locale.dart';
import 'l10n/app_strings.dart';
import 'experience_detail_screen.dart';
import 'notifications_screen.dart' deferred as notif;
import 'profile_screen.dart' deferred as profile;
import 'map_screen.dart' deferred as map;
import 'search_screen.dart';
import 'following_feed_screen.dart';
import 'widgets/experience_card.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kDark    = Color(0xFF0F1923);
const _kDark2   = Color(0xFF1A2340);
const _kOrange  = Color(0xFFF26500);
const _kCardBg  = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size, FontWeight weight, Color color, {double height = 1.0}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color, height: height);

// Same 9 cities as onboarding (onboarding_preferences_screen.dart). No "الكل".
const _kSaudiCities = [
  'جدة', 'الرياض', 'مكة', 'المدينة',
  'الدمام', 'الخبر', 'أبها', 'تبوك', 'القصيم',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Warm-starts the feed network request (called from SplashScreen so it runs
  /// in parallel with the splash). Forwards to the State's static prefetch.
  static void prefetchFeed() => _HomeScreenState.prefetchFeed();

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _experiences = [];
  // Latest experiences from people the user follows ("تثق بتجاربهم" strip).
  List<Map<String, dynamic>> _followingExperiences = [];
  Map<String, dynamic>? _topExperience;
  bool _loading = true;
  String _selectedCategory = 'الكل';
  String _selectedCity = 'جدة'; // last-resort default; replaced by _loadCity()
  String? _selectedMood;
  Map<String, dynamic>? _selectedExp;
  final _profileRefreshNotifier = ValueNotifier<int>(0);

  // Deferred-library readiness for the lazily-loaded tabs.
  bool _profileReady = false;
  bool _mapReady = false;
  bool _shouldAnimateList = true;
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  late AnimationController _shimmerController;
  late AnimationController _ambientCtrl;
  late AnimationController _notifPulseCtrl;
  late Animation<double> _notifPulse;
  final ScrollController _scrollController = ScrollController();
  int _unreadCount = 0;
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _notifChannel;

  final _categories = [
    'الكل',
    'مشويات',
    'برغر',
    'آسيوي',
    'كافيهات',
    'سوشي',
    'بيتزا',
    'صحي',
    'دجاج',
    'أرز',
    'مأكولات بحرية',
    'شاورما',
    'حلويات',
    'ستيك',
    'مكسيكي',
    'هندي',
    'إيطالي',
    'أكلات شعبية',
    'عصائر',
  ];
  // Category → icon map, so adding categories never breaks a positional index.
  static const _catIcon = <String, PhosphorIconData>{
    'الكل':           PhosphorIconsRegular.squaresFour,
    'مشويات':         PhosphorIconsRegular.flame,
    'برغر':           PhosphorIconsRegular.hamburger,
    'آسيوي':          PhosphorIconsRegular.bowlFood,
    'كافيهات':        PhosphorIconsRegular.coffee,
    'سوشي':           PhosphorIconsRegular.fish,
    'بيتزا':          PhosphorIconsRegular.pizza,
    'صحي':            PhosphorIconsRegular.leaf,
    'دجاج':           PhosphorIconsRegular.bird,
    'أرز':            PhosphorIconsRegular.grains,
    'مأكولات بحرية':  PhosphorIconsRegular.fish,
    'شاورما':         PhosphorIconsRegular.bread,
    'حلويات':         PhosphorIconsRegular.cake,
    'ستيك':           PhosphorIconsRegular.knife,
    'مكسيكي':         PhosphorIconsRegular.pepper,
    'هندي':           PhosphorIconsRegular.bowlFood,
    'إيطالي':         PhosphorIconsRegular.wine,
    'أكلات شعبية':    PhosphorIconsRegular.cookingPot,
    'عصائر':          PhosphorIconsRegular.drop,
  };

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _notifPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _notifPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 40),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
    ]).animate(_notifPulseCtrl);
    _scrollController.addListener(_onScroll);
    AppLocale.notifier.addListener(_onLocaleChange);
    // Fire independent initial work in parallel — _loadCity only feeds a
    // client-side filter, so the feed query no longer waits on it.
    _loadCity();
    _loadData();
    _subscribeRealtime();
    _checkUnread();
    _subscribeNotifRealtime();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('home_experiences_feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'experiences',
          callback: (payload) {
            if (mounted && !_loading) _loadData();
          },
        )
        .subscribe();
  }

  Future<void> _checkUnread() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      if (mounted) {
        setState(() => _unreadCount = (res as List).length);
      }
    } catch (e) {
      debugPrint('Check unread error: $e');
    }
  }

  void _subscribeNotifRealtime() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _notifChannel = Supabase.instance.client
        .channel('home_notif_badge_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (mounted) _checkUnread();
          },
        )
        .subscribe();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _ambientCtrl.dispose();
    _notifPulseCtrl.dispose();
    _scrollController.dispose();
    AppLocale.notifier.removeListener(_onLocaleChange);
    _profileRefreshNotifier.dispose();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _loadCity() async {
    final prefs = await SharedPreferences.getInstance();
    String? city;

    // Source of truth: users.city (this is where onboarding saved it).
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me != null) {
      try {
        final row = await Supabase.instance.client
            .from('users')
            .select('city')
            .eq('id', me)
            .maybeSingle();
        final dbCity = (row?['city'] ?? '').toString().trim();
        if (dbCity.isNotEmpty) {
          city = dbCity;
          await prefs.setString('selected_city', dbCity); // keep local cache fresh
        }
      } catch (e) {
        debugPrint('[home] load city (db) error: $e');
      }
    }

    city ??= prefs.getString('selected_city'); // local cache fallback
    final resolved = (city == null || city.trim().isEmpty) ? 'جدة' : city.trim();
    if (mounted) setState(() => _selectedCity = resolved);
  }

  Future<void> _saveCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_city', city); // fast local cache
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me != null) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'city': city})
            .eq('id', me); // durable, source of truth
      } catch (e) {
        debugPrint('[home] save city (db) error: $e');
      }
    }
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      _loadData(loadMore: true);
    }
  }

  static const _kPageSize = 10;
  static const _kSelectFields =
      'id, title, description, photos, rating_food, rating_service, '
      'rating_ambiance, rating_clean, rating_value, atmosphere, price_range, '
      'visit_time, tags, created_at, user_id, restaurant_id, '
      'restaurant:restaurants(id, name_ar, city, category), '
      'user:users!experiences_user_id_fkey(display_name, username, avatar_url)';

  // ── Warm-start prefetch (kicked off by SplashScreen) ────────────────────────
  static Future<List<Map<String, dynamic>>>? _prefetchFuture;

  /// Begins loading the first page of the feed. Called from SplashScreen so the
  /// network request runs in parallel with the splash animation instead of only
  /// after the user reaches the home screen.
  static void prefetchFeed() {
    _prefetchFuture ??= _fetchFeed(0);
  }

  /// Fetches one page of experiences, then merges per-experience like counts.
  /// Static so it can run without a mounted State (during the splash).
  static Future<List<Map<String, dynamic>>> _fetchFeed(int page) async {
    final from = page * _kPageSize;
    final res = await Supabase.instance.client
        .from('experiences')
        .select(_kSelectFields)
        .order('created_at', ascending: false)
        .range(from, from + _kPageSize - 1);

    final list = List<Map<String, dynamic>>.from(res);
    if (list.isNotEmpty) {
      // likes depends on the experience ids, so it stays a second round-trip.
      try {
        final expIds = list.map((e) => e['id'].toString()).toList();
        final allLikes = await Supabase.instance.client
            .from('likes')
            .select('experience_id')
            .inFilter('experience_id', expIds);
        final counts = <String, int>{};
        for (final l in allLikes as List) {
          final id = l['experience_id'].toString();
          counts[id] = (counts[id] ?? 0) + 1;
        }
        for (int i = 0; i < list.length; i++) {
          list[i]['likes_count'] = counts[list[i]['id'].toString()] ?? 0;
        }
      } catch (e) {
        debugPrint('Likes count error: $e');
        for (int i = 0; i < list.length; i++) {
          list[i]['likes_count'] = 0;
        }
      }
    }
    return list;
  }

  Future<void> _loadData({bool loadMore = false}) async {
    if (loadMore) {
      if (!_hasMore || _loadingMore || _loading) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() { _loading = true; _page = 0; _hasMore = true; });
    }
    try {
      final List<Map<String, dynamic>> list;
      if (!loadMore && _prefetchFuture != null) {
        // Consume the prefetch begun during the splash screen (runs in parallel).
        list = await _prefetchFuture!;
        _prefetchFuture = null;
      } else {
        list = await _fetchFeed(_page);
      }

      if (mounted) {
        setState(() {
          if (loadMore) {
            _experiences.addAll(list);
            _loadingMore = false;
          } else {
            _experiences   = list;
            _topExperience = list.isNotEmpty ? list.first : null;
            _loading       = false;
          }
          _hasMore = list.length == _kPageSize;
          _page++;
        });
        if (!loadMore && _shouldAnimateList) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) setState(() => _shouldAnimateList = false);
          });
        }
      }
      if (!loadMore) _loadFollowing(); // refresh the "تثق بتجاربهم" strip too
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  /// Latest 3 experiences from people the current user follows. Hidden entirely
  /// when the user follows no one or none of them have posted.
  Future<void> _loadFollowing() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return;
    try {
      final follows = await Supabase.instance.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', me);
      final ids = (follows as List)
          .map((f) => f['following_id']?.toString())
          .whereType<String>()
          .toList();
      if (ids.isEmpty) {
        if (mounted) setState(() => _followingExperiences = []);
        return;
      }
      final res = await Supabase.instance.client
          .from('experiences')
          .select(_kSelectFields)
          .inFilter('user_id', ids)
          .order('created_at', ascending: false)
          .limit(3);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) {
        final expIds = list.map((e) => e['id'].toString()).toList();
        final likes = await Supabase.instance.client
            .from('likes')
            .select('experience_id')
            .inFilter('experience_id', expIds);
        final counts = <String, int>{};
        for (final l in likes as List) {
          final id = l['experience_id'].toString();
          counts[id] = (counts[id] ?? 0) + 1;
        }
        for (final e in list) {
          e['likes_count'] = counts[e['id'].toString()] ?? 0;
        }
      }
      if (mounted) setState(() => _followingExperiences = list);
    } catch (e) {
      debugPrint('[home] following feed error: $e');
    }
  }

  void _openExp(Map<String, dynamic> exp) => setState(() => _selectedExp = exp);

  void _closeExp() {
    setState(() => _selectedExp = null);
    _loadData();
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  // Remove emojis, keep Arabic, ASCII, spaces and commas
  String _stripEmojis(String s) => s.replaceAll(
        RegExp(r'[^ -؀-ۿ\s,]'),
        '',
      ).trim();

  List<Map<String, dynamic>> get _filtered {
    var list = _experiences;
    final myId = Supabase.instance.client.auth.currentUser?.id;

    // City filter — but never hide the user's OWN posts, and treat a
    // missing/empty restaurant city as visible everywhere (not black-holed).
    list = list.where((e) {
      final city = (e['restaurant']?['city'] ?? '').toString().trim();
      final mine = e['user_id']?.toString() == myId;
      return mine ||
          city.isEmpty ||
          city == _selectedCity ||
          city.contains(_selectedCity);
    }).toList();

    // Category filter — strip emojis from stored value, handle both String and List
    if (_selectedCategory != 'الكل') {
      final keywords = _catKeywords(_selectedCategory);
      list = list.where((e) {
        final rawCat = e['restaurant']?['category'];
        if (rawCat == null) return false;
        final catStr = rawCat is List
            ? rawCat.map((c) => c.toString()).join(',')
            : rawCat.toString();
        final cat = _stripEmojis(catStr).toLowerCase().trim();
        if (cat.isEmpty) return false;
        return keywords.any((kw) => cat.contains(_stripEmojis(kw).toLowerCase()));
      }).toList();
    }

    // Mood filter
    if (_selectedMood != null) {
      list = list.where((e) {
        final atmosphere = (e['atmosphere'] as String? ?? '').toLowerCase();

        // tags is a Postgres array → List<dynamic>; handle String fallback for legacy data
        final rawTags = e['tags'];
        final List<String> tagList = rawTags == null
            ? []
            : rawTags is List
                ? rawTags.map((t) => t.toString().toLowerCase()).toList()
                : [rawTags.toString().toLowerCase()];

        bool hasTag(String keyword) => tagList.any((t) => t.contains(keyword));

        switch (_selectedMood) {
          case 'هادئ':
            return atmosphere.contains('هادي') || hasTag('هادي');
          case 'جلسات خارجية':
            return hasTag('خارجي');
          case 'شبابي':
            return hasTag('شبابي');
          case 'رومانسي':
            return hasTag('رومانسي');
          case 'عائلي':
            return hasTag('عائلي');
          case 'للعمل':
            return hasTag('للعمل') || hasTag('للدراسة');
          default:
            return true;
        }
      }).toList();
    }

    return list;
  }

  List<String> _catKeywords(String cat) {
    const map = <String, List<String>>{
      'مشويات':        ['مشوي', 'مشويات', 'مشاوي', 'grill', 'bbq', 'شواء'],
      'برغر':          ['برغر', 'برجر', 'burger'],
      'آسيوي':         ['آسيوي', 'اسيوي', 'asian', 'نودلز', 'noodle', 'تايلندي', 'صيني', 'chinese', 'thai'],
      'كافيهات':       ['كافيه', 'كافيهات', 'كوفي', 'cafe', 'coffee', 'كيف'],
      'سوشي':          ['سوشي', 'sushi', 'ياباني', 'japanese'],
      'بيتزا':         ['بيتزا', 'pizza'],
      'صحي':           ['صحي', 'healthy', 'salad', 'سلطة', 'دايت'],
      'دجاج':          ['دجاج', 'chicken', 'بروست', 'broast'],
      'أرز':           ['رز', 'أرز', 'rice', 'كبسة', 'مندي', 'برياني', 'biryani'],
      'مأكولات بحرية': ['بحري', 'بحرية', 'مأكولات بحرية', 'seafood', 'سمك', 'fish', 'جمبري', 'shrimp', 'روبيان'],
      'شاورما':        ['شاورما', 'shawarma'],
      'حلويات':        ['حلو', 'حلويات', 'حلا', 'sweet', 'dessert', 'كيك', 'cake'],
      'ستيك':          ['ستيك', 'steak', 'لحم', 'لحوم', 'meat'],
      'مكسيكي':        ['مكسيك', 'mexican', 'تاكو', 'taco'],
      'هندي':          ['هندي', 'هند', 'indian'],
      'إيطالي':        ['إيطالي', 'ايطالي', 'italian', 'باستا', 'pasta'],
      'أكلات شعبية':   ['شعبي', 'تقليدي', 'أصيل', 'اصيل', 'بلدي', 'أكلات شعبية', 'traditional', 'authentic'],
      'عصائر':         ['عصائر', 'عصير', 'juice', 'smoothie'],
    };
    return map[cat] ?? [cat];
  }

  // ── City picker bottom sheet ───────────────────────────────────────────────

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kDark2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Column(
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
              child: Row(
                children: [
                  Text('اختر مدينة', style: _tj(16, FontWeight.w900, Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: _kSaudiCities.length,
                itemBuilder: (_, i) {
                  final city = _kSaudiCities[i];
                  final selected = _selectedCity == city;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      setState(() => _selectedCity = city);
                      await _saveCity(city);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: selected ? _kOrange.withValues(alpha: 0.15) : _kCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? _kOrange : Colors.white.withValues(alpha: 0.06),
                          width: selected ? 1.2 : 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                            color: selected ? _kOrange : _kTextSec,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            city,
                            style: _tj(13, selected ? FontWeight.w700 : FontWeight.w500,
                                selected ? _kOrange : Colors.white),
                          ),
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
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  // Switches bottom-nav tabs, lazily loading deferred tab libraries on first
  // visit so their code isn't in the initial main.dart.js payload.
  Future<void> _selectTab(int i) async {
    if (i == 3 && !_mapReady) {
      await map.loadLibrary();
      if (mounted) setState(() => _mapReady = true);
    } else if (i == 4 && !_profileReady) {
      await profile.loadLibrary();
      if (mounted) setState(() => _profileReady = true);
    }
    if (!mounted) return;
    setState(() => _currentIndex = i);
    if (i == 4) _profileRefreshNotifier.value++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kDark, Color(0xFF0D1720), Color(0xFF0A1118)],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          IndexedStack(
            index: _currentIndex,
            children: [
              // 0 — Home feed
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: _loading
                          ? _buildShimmerGrid()
                          : _experiences.isEmpty
                              ? _buildEmpty()
                              : RefreshIndicator(
                                  color: _kOrange,
                                  backgroundColor: _kCardBg,
                                  onRefresh: _loadData,
                                  child: CustomScrollView(
                                    controller: _scrollController,
                                    physics: const BouncingScrollPhysics(),
                                    slivers: [
                                      SliverToBoxAdapter(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (_topExperience != null) _buildBanner(_topExperience!),
                                            _buildMoodSection(),
                                            _buildCategories(),
                                            _buildTrustedSection(),
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(AppStrings.latestExperiences,
                                                      style: _tj(15, FontWeight.w800, Colors.white)),
                                                  if (_filtered.isEmpty && _selectedCategory != 'الكل')
                                                    Text(AppStrings.noResults,
                                                        style: _tj(11, FontWeight.w500, _kTextSec))
                                                  else
                                                    Text(AppStrings.seeAll,
                                                        style: _tj(12, FontWeight.w600, _kOrange)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 2-column grid
                                      if (_filtered.isNotEmpty)
                                        SliverPadding(
                                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                                          sliver: SliverGrid(
                                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              crossAxisSpacing: 10,
                                              mainAxisSpacing: 10,
                                              childAspectRatio: 0.62,
                                            ),
                                            delegate: SliverChildBuilderDelegate(
                                              (context, i) {
                                                final exp = _filtered[i];
                                                final gridCard = ExperienceCard(
                                                  experience: exp,
                                                  onTap: () => _openExp(exp),
                                                  scrollController: _scrollController,
                                                );
                                                final card = _shouldAnimateList
                                                    ? _AnimatedCard(
                                                        delay: Duration(milliseconds: i * 80),
                                                        child: gridCard,
                                                      )
                                                    : gridCard;
                                                return RepaintBoundary(child: card);
                                              },
                                              childCount: _filtered.length,
                                            ),
                                          ),
                                        ),
                                      SliverToBoxAdapter(
                                        child: _loadingMore
                                            ? const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 24),
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                      color: _kOrange, strokeWidth: 2),
                                                ),
                                              )
                                            : const SizedBox(height: 100),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
              // 1 — Search
              const SearchScreen(),
              // 2 — Add button slot
              const SizedBox(),
              // 3 — Map (deferred lib; built after first visit)
              _mapReady ? map.MapScreen() : const SizedBox(),
              // 4 — Profile (deferred lib; built after first visit)
              _profileReady
                  ? profile.ProfileScreen(refreshNotifier: _profileRefreshNotifier)
                  : const SizedBox(),
            ],
          ),

          // Detail screen overlay
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

  // ── TOP BAR ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        color: _kDark,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 0.8),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo image with orange circle fallback
          SizedBox(
            height: 38,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: _kOrange, shape: BoxShape.circle),
                child: Center(child: Text('A', style: _tj(18, FontWeight.w900, Colors.white))),
              ),
            ),
          ),
          const Spacer(),
          // Tappable city chip
          GestureDetector(
            onTap: _showCityPicker,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: _kOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kOrange),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                      color: _kOrange, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    _selectedCity,
                    style: _tj(12, FontWeight.w600, Colors.white),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.5), size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Language toggle
          GestureDetector(
            onTap: () async {
              await AppLocale.toggle();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocale.isArabic ? 'تم التبديل إلى العربية' : 'Switched to English',
                      style: GoogleFonts.tajawal(),
                    ),
                    backgroundColor: _kOrange,
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: AppLocale.isArabic ? _kOrange : _kDark2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppLocale.isArabic ? _kOrange : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Text(AppLocale.isArabic ? 'AR' : 'EN',
                  style: _tj(11, FontWeight.w800, Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          // Notifications bell
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              await notif.loadLibrary();
              if (!mounted) return;
              setState(() => _unreadCount = 0);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => notif.NotificationsScreen()),
              );
              _checkUnread();
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(PhosphorIcons.bell(), color: Colors.white, size: 22),
                  if (_unreadCount > 0)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: AnimatedBuilder(
                        animation: _notifPulse,
                        builder: (_, __) => Transform.scale(
                          scale: _notifPulse.value,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: _kOrange,
                              shape: BoxShape.circle,
                              border: Border.all(color: _kDark, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: _kOrange.withValues(alpha: 0.2), blurRadius: 24, spreadRadius: 2)],
            ),
            child: Center(child: Icon(PhosphorIcons.forkKnife(), size: 42, color: _kTextSec.withValues(alpha: 0.5))),
          ),
          const SizedBox(height: 18),
          Text('لا توجد تجارب بعد', style: _tj(17, FontWeight.w800, Colors.white)),
          const SizedBox(height: 6),
          Text('كن أول من يشارك تجربته', style: _tj(13, FontWeight.w400, _kTextSec)),
          const SizedBox(height: 26),
          GestureDetector(
            onTap: () async {
              await add_exp.loadLibrary();
              if (!mounted) return;
              await Navigator.of(context).push(_fadeSlideRoute(add_exp.AddExperienceScreen()));
              _loadData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kOrange, Color(0xFFFF7A1A)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _kOrange.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: Text('+ أضف تجربة', style: _tj(14, FontWeight.w800, Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ── HERO BANNER ────────────────────────────────────────────────────────────

  Widget _buildBanner(Map<String, dynamic> exp) {
    return AnimatedBuilder(
      animation: _ambientCtrl,
      builder: (_, child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.4 + _ambientCtrl.value * 0.4, -1),
            end: Alignment(0.4 - _ambientCtrl.value * 0.4, 1),
            colors: [
              Color.lerp(const Color(0xFF1A2A40), const Color(0xFF1D3055), _ambientCtrl.value)!,
              Color.lerp(_kDark, const Color(0xFF0F1E2E), _ambientCtrl.value * 0.4)!,
            ],
          ),
        ),
        child: child,
      ),
      child: Column(
        children: [
          Text('أي شيء', textAlign: TextAlign.center,
              style: _tj(28, FontWeight.w900, Colors.white, height: 1.1)),
          const SizedBox(height: 5),
          Text('بس مو أي مطعم!', textAlign: TextAlign.center,
              style: _tj(17, FontWeight.w800, _kOrange, height: 1.2)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _currentIndex = 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(AppStrings.searchHint,
                        style: _tj(13, FontWeight.w400, _kTextSec),
                        textDirection: TextDirection.rtl),
                  ),
                  Icon(PhosphorIcons.magnifyingGlass(), color: _kTextSec, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MOOD SECTION ──────────────────────────────────────────────────────────

  static const _kMoods = [
    ('هادئ',             'هادئ'),
    ('جلسات خارجية',     'جلسات خارجية'),
    ('شبابي',            'شبابي'),
    ('رومانسي',          'رومانسي'),
    ('عائلي',            'عائلي'),
    ('للعمل',            'للعمل'),
  ];

  Widget _buildMoodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(
                  color: _kOrange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(AppStrings.moodToday,
                  style: _tj(13, FontWeight.w800, Colors.white)),
              if (_selectedMood != null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _selectedMood = null),
                  child: Text('إلغاء',
                      style: _tj(11, FontWeight.w600, _kTextSec)),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _kMoods.length,
            itemBuilder: (context, i) {
              final label = _kMoods[i].$1;
              final key   = _kMoods[i].$2;
              final active = _selectedMood == key;
              return GestureDetector(
                onTap: () => setState(
                    () => _selectedMood = active ? null : key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: active
                        ? _kOrange
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: active
                          ? _kOrange
                          : Colors.white.withValues(alpha: 0.1),
                      width: 0.8,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: _kOrange.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    label,
                    style: _tj(
                      12,
                      active ? FontWeight.w700 : FontWeight.w500,
                      active ? Colors.white : _kTextSec,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_selectedMood != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'الأفضل في $_selectedMood',
              style: _tj(12, FontWeight.w700, _kOrange),
            ),
          ),
        ],
      ],
    );
  }

  // ── CATEGORIES ─────────────────────────────────────────────────────────────

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text('التصنيفات', style: _tj(12, FontWeight.w600, _kTextSec)),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categories.length,
            itemBuilder: (context, i) {
              final cat    = _categories[i];
              final active = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? _kOrange : _kCardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: active ? _kOrange : Colors.white.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                    boxShadow: active
                        ? [BoxShadow(color: _kOrange.withValues(alpha: 0.38), blurRadius: 14, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_catIcon[_categories[i]] ?? PhosphorIconsRegular.forkKnife,
                          size: 13, color: active ? Colors.white : _kTextSec),
                      const SizedBox(width: 5),
                      Text(cat,
                          style: _tj(12, active ? FontWeight.w700 : FontWeight.w500,
                              active ? Colors.white : _kTextSec)),
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

  // ── "تثق بتجاربهم" — latest experiences from people the user follows ───────

  Widget _buildTrustedSection() {
    if (_followingExperiences.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('تثق بتجاربهم',
                  style: _tj(15, FontWeight.w800, Colors.white)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FollowingFeedScreen()),
                ),
                child: Text('عرض المزيد ‹',
                    style: _tj(12, FontWeight.w600, _kOrange)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            physics: const BouncingScrollPhysics(),
            itemCount: _followingExperiences.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final exp = _followingExperiences[i];
              return SizedBox(
                width: 150, // 150 × 236 ≈ the grid card's 0.62 aspect ratio
                child: ExperienceCard(
                  experience: exp,
                  onTap: () => _openExp(exp),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── BOTTOM NAVIGATION ──────────────────────────────────────────────────────

  PhosphorIconData _navIcon(int index, bool active) {
    final s = active ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular;
    switch (index) {
      case 0:  return PhosphorIcons.house(s);
      case 1:  return PhosphorIcons.magnifyingGlass(s);
      case 3:  return PhosphorIcons.mapPin(s);
      case 4:  return PhosphorIcons.user(s);
      default: return PhosphorIcons.user(s);
    }
  }

  Widget _buildBottomNav() {
    final labels = [
      AppStrings.home,
      AppStrings.explore,
      '',
      'الخريطة',
      AppStrings.profile,
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111C2B),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 24, offset: const Offset(0, -4)),
          BoxShadow(color: _kOrange.withValues(alpha: 0.05), blurRadius: 32, offset: const Offset(0, -10)),
        ],
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07), width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(labels.length, (i) {
              if (i == 2) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await add_exp.loadLibrary();
                      if (!mounted) return;
                      await Navigator.of(context).push(_fadeSlideRoute(add_exp.AddExperienceScreen()));
                      _loadData();
                    },
                    child: Center(
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_kOrange, Color(0xFFFF7A1A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: _kOrange.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                );
              }
              final active = _currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _selectTab(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: active ? _kOrange.withValues(alpha: 0.13) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: AnimatedScale(
                              scale: active ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: Icon(_navIcon(i, active), size: 24, color: active ? _kOrange : _kTextSec),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(labels[i],
                          style: _tj(9, active ? FontWeight.w700 : FontWeight.w400, active ? _kOrange : _kTextSec)),
                      const SizedBox(height: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: active ? 4 : 0,
                        height: active ? 4 : 0,
                        decoration: BoxDecoration(
                          color: _kOrange,
                          shape: BoxShape.circle,
                          boxShadow: active ? [BoxShadow(color: _kOrange.withValues(alpha: 0.6), blurRadius: 5)] : [],
                        ),
                      ),
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

  // ── PAGE TRANSITION ────────────────────────────────────────────────────────

  PageRoute<T> _fadeSlideRoute<T>(Widget screen) => PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => screen,
    transitionsBuilder: (_, animation, __, child) {
      if (kIsWeb) return FadeTransition(opacity: animation, child: child);
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  );

  // ── SHIMMER LOADING ────────────────────────────────────────────────────────

  Widget _buildShimmerGrid() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 80, 14, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.62,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => _buildShimmerCard(),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerCard() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, __) {
        final t = _shimmerController.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment(t * 4 - 2, 0),
              end: Alignment(t * 4, 0),
              colors: const [
                Color(0xFF1E2D45),
                Color(0xFF243558),
                Color(0xFF1E2D45),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Staggered card animation ───────────────────────────────────────────────────

class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AnimatedCard({required this.child, required this.delay});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.075),
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
