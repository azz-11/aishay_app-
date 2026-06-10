import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'experience_detail_screen.dart';
import 'widgets/experience_card.dart';

const _kDark = Color(0xFF0F1923);
const _kDark2 = Color(0xFF1A2340);
const _kOrange = Color(0xFFF26500);
const _kCardBg = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);

// Same projection the home feed uses, so ExperienceCard has everything it needs.
const _kSelectFields =
    'id, title, description, photos, rating_food, rating_service, '
    'rating_ambiance, rating_clean, rating_value, atmosphere, price_range, '
    'visit_time, tags, created_at, user_id, restaurant_id, '
    'restaurant:restaurants(id, name_ar, city, category), '
    'user:users!experiences_user_id_fkey(display_name, username, avatar_url)';

/// Full feed of experiences from everyone the current user follows
/// ("تثق بتجاربهم" → عرض المزيد). Paginated 2-column grid.
class FollowingFeedScreen extends StatefulWidget {
  const FollowingFeedScreen({super.key});

  @override
  State<FollowingFeedScreen> createState() => _FollowingFeedScreenState();
}

class _FollowingFeedScreenState extends State<FollowingFeedScreen> {
  static const _pageSize = 10;
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _experiences = [];
  List<String> _followingIds = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _init() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final follows = await Supabase.instance.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', me);
      _followingIds = (follows as List)
          .map((f) => f['following_id']?.toString())
          .whereType<String>()
          .toList();
    } catch (e) {
      debugPrint('[following] follows error: $e');
    }
    if (_followingIds.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _loadPage(reset: true);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;
    await _loadPage();
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final from = _page * _pageSize;
      final res = await Supabase.instance.client
          .from('experiences')
          .select(_kSelectFields)
          .inFilter('user_id', _followingIds)
          .order('created_at', ascending: false)
          .range(from, from + _pageSize - 1);
      final list = List<Map<String, dynamic>>.from(res);

      // Merge like counts (same approach as the main feed).
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

      if (!mounted) return;
      setState(() {
        if (reset) _experiences.clear();
        _experiences.addAll(list);
        _hasMore = list.length == _pageSize;
        _page++;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('[following] load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _openDetail(Map<String, dynamic> exp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExperienceDetailScreen(experience: exp),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kDark,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _kDark2,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              // RTL: back points to the right.
              child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Text('تثق بتجاربهم',
              style: GoogleFonts.tajawal(
                  fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kOrange));
    }
    if (_experiences.isEmpty) {
      return _buildEmpty();
    }
    return GridView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: _experiences.length,
      itemBuilder: (context, i) {
        final exp = _experiences[i];
        return ExperienceCard(
          experience: exp,
          onTap: () => _openDetail(exp),
          scrollController: _scrollController,
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: _kCardBg, shape: BoxShape.circle),
              child: Icon(PhosphorIcons.usersThree(), color: _kTextSec, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              'ابدأ بمتابعة أشخاص لرؤية تجاربهم هنا',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
