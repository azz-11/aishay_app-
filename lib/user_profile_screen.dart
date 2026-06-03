import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'experience_detail_screen.dart';
import 'widgets/app_placeholder.dart';

const _upDark    = Color(0xFF0F1923);
const _upDark2   = Color(0xFF1A2340);
const _upCardBg  = Color(0xFF1E2D45);
const _upOrange  = Color(0xFFF26500);
const _upGold    = Color(0xFFC8931A);
const _upTextSec = Color(0xFF94A3B8);

TextStyle _upt(double size,
    {FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
    double? height}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color, height: height);

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _experiences = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadFollowState() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null || me.id == widget.userId) return;
    try {
      final res = await Supabase.instance.client
          .from('follows')
          .select('follower_id')
          .eq('follower_id', me.id)
          .eq('following_id', widget.userId);
      if (mounted) setState(() => _isFollowing = (res as List).isNotEmpty);
    } catch (_) {}
  }

  Future<void> _loadFollowCounts() async {
    try {
      final followersRes = await Supabase.instance.client
          .from('follows')
          .select('follower_id')
          .eq('following_id', widget.userId);
      final followingRes = await Supabase.instance.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', widget.userId);
      if (mounted) {
        setState(() {
          _followersCount = (followersRes as List).length;
          _followingCount = (followingRes as List).length;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null || _followLoading) return;
    setState(() => _followLoading = true);
    final wasFollowing = _isFollowing;
    setState(() => _isFollowing = !wasFollowing);
    try {
      if (!wasFollowing) {
        await Supabase.instance.client.from('follows').upsert({
          'follower_id': me.id,
          'following_id': widget.userId,
        }, onConflict: 'follower_id,following_id');
        try {
          await Supabase.instance.client.from('notifications').insert({
            'user_id': widget.userId,
            'from_user_id': me.id,
            'type': 'follow',
            'is_read': false,
          });
        } catch (e) {
          debugPrint('Notification insert error (follow): $e');
        }
      } else {
        await Supabase.instance.client
            .from('follows')
            .delete()
            .eq('follower_id', me.id)
            .eq('following_id', widget.userId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = wasFollowing);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
      await _loadFollowState();
      await _loadFollowCounts();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', widget.userId)
          .single();

      final experiences = await Supabase.instance.client
          .from('experiences')
          .select('*, restaurant:restaurants(*)')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profile = Map<String, dynamic>.from(profile);
          _experiences = List<Map<String, dynamic>>.from(experiences);
          _loading = false;
        });
        _loadFollowState();
        _loadFollowCounts();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل الملف: $e')),
        );
      }
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

  bool get _isOwnProfile {
    final me = Supabase.instance.client.auth.currentUser;
    return me != null && me.id == widget.userId;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _upDark,
        body: Center(child: CircularProgressIndicator(color: _upOrange)),
      );
    }

    final displayName = _profile?['display_name'] ?? _profile?['username'] ?? 'مستخدم';
    final username    = _profile?['username'] as String? ?? '';
    final bio         = _profile?['bio'] as String? ?? '';
    final city        = _profile?['city'] as String? ?? '';
    final avatar      = _profile?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: _upDark,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: _upDark2,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 28,
                left: 8,
                right: 8,
              ),
              child: Column(
                children: [
                  // Back row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 16),
                        ),
                      ),
                      if (_profile != null)
                        GestureDetector(
                          onTap: _shareProfile,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.share_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Avatar with orange gradient ring
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_upOrange, Color(0xFFFF7A1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _upOrange.withValues(alpha: 0.35),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _upDark2,
                        ),
                        child: ClipOval(
                          child: avatar != null
                              ? CachedNetworkImage(
                                  imageUrl: avatar,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const ColoredBox(color: _upDark2),
                                  errorWidget: (_, __, ___) => _initial(displayName),
                                )
                              : _initial(displayName),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(displayName, style: _upt(19, weight: FontWeight.w900)),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('@$username', style: _upt(12, color: _upTextSec)),
                  ],
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('📍 $city', style: _upt(11, color: _upTextSec)),
                  ],
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(bio,
                          style: _upt(12, color: Colors.white70, height: 1.55),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _stat('${_experiences.length}', 'تجاربي'),
                      _divider(),
                      _stat('$_followersCount', 'يتطلعون لتجاربي'),
                      _divider(),
                      _stat('$_followingCount', 'أتطلع لتجاربهم'),
                    ],
                  ),
                  if (!_isOwnProfile) ...[
                    const SizedBox(height: 22),
                    GestureDetector(
                      onTap: _followLoading ? null : _toggleFollow,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isFollowing
                              ? Colors.white.withValues(alpha: 0.08)
                              : _upOrange,
                          borderRadius: BorderRadius.circular(24),
                          border: _isFollowing
                              ? Border.all(color: Colors.white.withValues(alpha: 0.2))
                              : null,
                          boxShadow: _isFollowing
                              ? []
                              : [
                                  BoxShadow(
                                    color: _upOrange.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                        ),
                        child: _followLoading
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                _isFollowing ? '✓ تتابعه' : '+ متابعة',
                                style: _upt(14, weight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Section header
          if (_experiences.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 3, height: 16,
                      decoration: BoxDecoration(
                        color: _upOrange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('التجارب', style: _upt(14, weight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _upOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_experiences.length}',
                          style: _upt(10, weight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),

          // Experiences list
          _experiences.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🍽️', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text('لا توجد تجارب بعد',
                            style: _upt(14, color: _upTextSec)),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildExpCard(_experiences[i]),
                      childCount: _experiences.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildExpCard(Map<String, dynamic> exp) {
    final restName = exp['restaurant']?['name_ar'] ?? 'مطعم';
    final city     = exp['restaurant']?['city'] as String? ?? '';
    final photos   = exp['photos'] as List? ?? [];
    final rating   = _avgRating(exp);
    final full     = rating.round();
    final stars    = '${'★' * full}${'☆' * (5 - full)}';
    final title    = (exp['title'] as String? ?? '').trim();
    final desc     = exp['description']?.toString() ?? '';
    final preview  = title.isNotEmpty
        ? title
        : (desc.length > 55 ? '${desc.substring(0, 55)}...' : desc);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ExperienceDetailScreen(experience: exp)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _upCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
              child: SizedBox(
                width: 90, height: 90,
                child: photos.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: photos[0].toString(),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ColoredBox(color: _upCardBg),
                        errorWidget: (_, __, ___) =>
                            AppPlaceholder(name: restName, borderRadius: 0),
                      )
                    : AppPlaceholder(name: restName, borderRadius: 0),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restName, style: _upt(13, weight: FontWeight.w900)),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('📍 $city', style: _upt(10, color: _upTextSec)),
                    ],
                    if (rating > 0) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(stars,
                              style: const TextStyle(fontSize: 11, color: _upGold)),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1),
                              style: _upt(10, weight: FontWeight.w800, color: _upGold)),
                        ],
                      ),
                    ],
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(preview,
                          style: _upt(10, color: _upTextSec, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.25), size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Column(
      children: [
        Text(value, style: _upt(20, weight: FontWeight.w900, color: _upOrange)),
        const SizedBox(height: 2),
        Text(label, style: _upt(10, color: _upTextSec, weight: FontWeight.w600)),
      ],
    ),
  );

  Widget _divider() => Container(
    width: 1, height: 30,
    color: Colors.white.withValues(alpha: 0.1),
  );

  Widget _initial(String name) => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'م',
      style: _upt(28, weight: FontWeight.w900, color: _upOrange),
    ),
  );

}
