import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_visit_screen.dart';
import 'comments_section.dart';
import 'edit_experience_screen.dart';
import 'user_profile_screen.dart';
import 'l10n/app_strings.dart';
import 'widgets/app_placeholder.dart';
import 'widgets/app_avatar.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kDark    = Color(0xFF0F1923);
const _kDark2   = Color(0xFF1A2340);
const _kOrange  = Color(0xFFF26500);
const _kGold    = Color(0xFFC8931A);
const _kCardBg  = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size, FontWeight weight, Color color, {double height = 1.0}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color, height: height);

class ExperienceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> experience;
  final VoidCallback? onClose;
  const ExperienceDetailScreen({super.key, required this.experience, this.onClose});

  @override
  State<ExperienceDetailScreen> createState() => _ExperienceDetailScreenState();
}

class _ExperienceDetailScreenState extends State<ExperienceDetailScreen>
    with TickerProviderStateMixin {
  late Map<String, dynamic> _experience;
  List<Map<String, dynamic>> _dishes = [];
  bool _liked = false;
  bool _saved = false;
  bool _isOwner = false;
  int _likesCount = 0;

  // UI-only state for photo gallery
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  // Button animations
  late AnimationController _likeController;
  late AnimationController _saveController;
  late Animation<double> _likeScale;
  late Animation<double> _saveScale;
  late Animation<double> _saveRotation;
  final GlobalKey _likeButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _experience = Map<String, dynamic>.from(widget.experience);
    _loadDishes();
    _checkUserInteractions();
    _likesCount = _experience['likes_count'] ?? 0;
    _checkOwnership();
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _saveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_likeController);
    _saveScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 60),
    ]).animate(_saveController);
    _saveRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: pi).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: pi, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
    ]).animate(_saveController);
  }

  @override
  void dispose() {
    _likeController.dispose();
    _saveController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ──────────────────────────────────────────────────────

  Future<void> _checkUserInteractions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final experienceId = widget.experience['id'];

    try {
      final likeRes = await Supabase.instance.client
          .from('likes')
          .select('user_id')
          .eq('user_id', user.id)
          .eq('experience_id', experienceId)
          .maybeSingle();

      final saveRes = await Supabase.instance.client
          .from('saves')
          .select('user_id')
          .eq('user_id', user.id)
          .eq('experience_id', experienceId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _liked = likeRes != null;
          _saved = saveRes != null;
        });
      }
    } catch (e) {
      debugPrint('Interaction check error: $e');
    }
  }

  void _checkOwnership() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final expUserId = _experience['user_id']?.toString() ??
        (_experience['user'] as Map<String, dynamic>?)?['id']?.toString();
    setState(() => _isOwner = expUserId != null && expUserId == user.id);
  }

  Future<void> _deleteExperience() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _kCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppStrings.deleteExperienceQ, style: _tj(15, FontWeight.w800, Colors.white)),
          content: Text(
            AppStrings.deleteConfirm,
            style: _tj(13, FontWeight.w400, _kTextSec, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.cancel, style: _tj(13, FontWeight.w600, _kTextSec)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(AppStrings.delete, style: _tj(13, FontWeight.w800, Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client
          .from('experiences')
          .delete()
          .eq('id', _experience['id']);

      if (!mounted) return;
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.deleteFailed}: $e')),
        );
      }
    }
  }

  Future<void> _shareExperience() async {
    final text = 'ألقِ نظرة على تجربتي 👀\nhttps://aishay-app.vercel.app';
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

  Future<void> _openEditExperience() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditExperienceScreen(experience: _experience),
      ),
    );
    if (updated == true) await _reloadExperience();
  }

  Future<void> _reloadExperience() async {
    try {
      final res = await Supabase.instance.client
          .from('experiences')
          .select('*, restaurant:restaurants(*), user:users!experiences_user_id_fkey(display_name, username, avatar_url)')
          .eq('id', _experience['id'])
          .single();
      if (mounted) {
        setState(() {
          _experience = Map<String, dynamic>.from(res);
          _likesCount = _experience['likes_count'] ?? _likesCount;
        });
        _loadDishes();
      }
    } catch (_) {}
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }


  Future<void> _toggleSave() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _saveController.forward(from: 0);
    final wasSaved = _saved;
    setState(() => _saved = !_saved);
    try {
      if (_saved) {
        await Supabase.instance.client.from('saves').upsert({
          'user_id': user.id,
          'experience_id': _experience['id'],
        }, onConflict: 'user_id,experience_id');
        final ownerId = _experience['user_id']?.toString();
        if (ownerId != null) await _insertNotification(ownerId, user.id, 'save');
        if (mounted) _showVisitPlanSheet();
      } else {
        await Supabase.instance.client
            .from('saves')
            .delete()
            .eq('user_id', user.id)
            .eq('experience_id', _experience['id']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saved = wasSaved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.error}: $e')),
        );
      }
    }
  }

  void _showVisitPlanSheet() {
    final restaurant = _experience['restaurant'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2D45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, 18 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Icon(PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill),
                      color: const Color(0xFFF26500), size: 22),
                  const SizedBox(width: 8),
                  Text('أُضيف إلى أود زيارته',
                      style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ],
              ),
              const SizedBox(height: 6),
              Text('هل تريد تحديد موعد للزيارة؟',
                  style: GoogleFonts.tajawal(
                      fontSize: 13, color: const Color(0xFF94A3B8))),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddVisitScreen(
                        restaurant: restaurant is Map
                            ? Map<String, dynamic>.from(restaurant)
                            : null,
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF26500), Color(0xFFFF7A1A)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('حدّد موعد',
                      style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('لاحقاً',
                    style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadDishes() async {
    try {
      final res = await Supabase.instance.client
          .from('dishes')
          .select('id, name, price_sar, photo_url')
          .eq('experience_id', _experience['id']);
      if (mounted) setState(() => _dishes = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  Future<void> _openMap() async {
    final restName = _experience['restaurant']?['name_ar'] ?? 'مطعم';
    final encodedQuery = Uri.encodeQueryComponent(restName.toString());
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedQuery');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.cantOpenMap)),
        );
      }
    }
  }

  void _showLikeFeedback() {
    final overlay = Overlay.of(context);
    final ctx = _likeButtonKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: pos.dx + size.width / 2 - 14,
        top: pos.dy - 8,
        child: _FloatingLikeFeedback(onDone: () => entry.remove()),
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _insertNotification(String ownerId, String userId, String type) async {
    if (ownerId == userId) return;
    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': ownerId,
        'from_user_id': userId,
        'type': type,
        'experience_id': _experience['id'].toString(),
        'is_read': false,
      });
      debugPrint('Notification inserted ($type) → owner: $ownerId');
    } catch (e) {
      debugPrint('Notification insert error ($type): $e');
    }
  }

  Future<void> _toggleLike() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _likeController.forward(from: 0);
    _showLikeFeedback();
    final wasLiked = _liked;
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    try {
      if (_liked) {
        await Supabase.instance.client.from('likes').upsert({
          'user_id': user.id,
          'experience_id': _experience['id'],
        }, onConflict: 'user_id,experience_id');
        final ownerId = _experience['user_id']?.toString();
        if (ownerId != null) await _insertNotification(ownerId, user.id, 'like');
      } else {
        await Supabase.instance.client
            .from('likes')
            .delete()
            .eq('user_id', user.id)
            .eq('experience_id', _experience['id']);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _likesCount += wasLiked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.error}: $e')),
        );
      }
    }
  }

  double get _avgRating {
    final fields = ['rating_food', 'rating_service', 'rating_ambiance', 'rating_clean', 'rating_value'];
    final vals = fields
        .map((f) => (_experience[f] as num?)?.toDouble() ?? 0.0)
        .where((v) => v > 0)
        .toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }


  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final exp       = _experience;
    final restName  = exp['restaurant']?['name_ar'] ?? 'مطعم';
    final city      = exp['restaurant']?['city'] ?? '';
    final userName  = exp['user']?['display_name'] ?? 'مستخدم';
    final photos    = exp['photos'] as List? ?? [];
    final rating    = _avgRating;
    final atmosphere = exp['atmosphere'] as String?;
    final priceRange = exp['price_range'] as String?;

    return Material(
      color: _kDark,
      child: Stack(
        children: [
          // ── SCROLLABLE BODY ───────────────────────────────────────────────
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HERO PHOTO (4:5 aspect ratio, full bleed)
                _buildHeroPhoto(photos),

                // 2. INFO CARD
                _buildInfoCard(exp, restName, city, userName, rating),

                // Thin separator
                Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),

                // 3. ACTION BUTTONS ROW
                _buildActionRow(),

                _sectionGap(),

                // 4. عن التجربة
                if (exp['description'] != null)
                  _buildDescriptionSection(exp),

                if (exp['description'] != null) _sectionGap(),

                // 5. أجواء المكان
                if (atmosphere != null || priceRange != null)
                  _buildAtmosphereSection(atmosphere, priceRange),

                if (atmosphere != null || priceRange != null) _sectionGap(),

                // 6. DETAILED RATINGS
                if (rating > 0) _buildRatingsSection(exp, rating),

                if (rating > 0) _sectionGap(),

                // 7. DISHES
                if (_dishes.isNotEmpty) _buildDishesSection(),

                if (_dishes.isNotEmpty) _sectionGap(),

                // 8. COMMENTS
                CommentsSection(
                  experienceId: exp['id'].toString(),
                  experienceOwnerId: exp['user_id']?.toString(),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),

          // ── FLOATING BACK BUTTON (top-right over photo) ───────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 14,
            child: _appBarAction(PhosphorIcons.caretRight(), () {
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.pop(context);
              }
            }),
          ),

          // ── FLOATING OWNER MENU (top-left over photo) ─────────────────────
          if (_isOwner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 14,
              child: _appBarAction(PhosphorIcons.dotsThreeVertical(), _showOwnerMenu),
            ),
        ],
      ),
    );
  }

  // ── SECTION BUILDERS ───────────────────────────────────────────────────────

  Widget _buildHeroPhoto(List photos) {
    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo or placeholder
            photos.isNotEmpty
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _currentPhotoIndex = i),
                    itemBuilder: (context, index) => index == 0
                        ? Hero(
                            tag: 'exp_photo_${_experience['id']}',
                            child: CachedNetworkImage(
                              imageUrl: photos[index].toString(),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const ColoredBox(color: _kCardBg),
                              errorWidget: (_, __, ___) => AppPlaceholder(
                                name: (_experience['restaurant']?['name_ar'] ?? '').toString(),
                                borderRadius: 0,
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: photos[index].toString(),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ColoredBox(color: _kCardBg),
                            errorWidget: (_, __, ___) => AppPlaceholder(
                              name: (_experience['restaurant']?['name_ar'] ?? '').toString(),
                              borderRadius: 0,
                            ),
                          ),
                  )
                : AppPlaceholder(
                    name: (_experience['restaurant']?['name_ar'] ?? '').toString(),
                    borderRadius: 0,
                  ),

            // Bottom gradient fade into dark
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [_kDark.withValues(alpha: 0.95), Colors.transparent],
                  ),
                ),
              ),
            ),

            // Page indicator dots
            if (photos.length > 1)
              Positioned(
                bottom: 16, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(photos.length, (i) {
                    final active = i == _currentPhotoIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: active ? 22 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: active ? _kOrange : Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      Map<String, dynamic> exp, String restName, String city, String userName, double rating) {
    final category = exp['restaurant']?['category'] as String?;

    return Container(
      color: _kCardBg,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant name + visit time badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(restName, style: _tj(22, FontWeight.w900, Colors.white)),
              ),
              if (exp['visit_time'] != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kDark2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    AppStrings.localizeVisitTime(exp['visit_time'].toString()),
                    style: _tj(11, FontWeight.w600, _kTextSec),
                  ),
                ),
              ],
            ],
          ),

          if (exp['title'] != null && (exp['title'] as String).trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              (exp['title'] as String).trim(),
              style: _tj(20, FontWeight.w700, Colors.white, height: 1.3),
            ),
          ],

          const SizedBox(height: 10),

          // Username row (tappable → profile)
          GestureDetector(
            onTap: () {
              final userId = exp['user_id']?.toString();
              if (userId != null && userId.isNotEmpty) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)));
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppAvatar(
                  displayName: userName,
                  username: (exp['user']?['username'] ?? '').toString(),
                  avatarUrl: exp['user']?['avatar_url']?.toString(),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(userName, style: _tj(12, FontWeight.w600, _kTextSec)),
                const SizedBox(width: 4),
                Icon(PhosphorIcons.caretRight(), size: 14, color: Colors.white.withValues(alpha: 0.3)),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Rating + likes row
          Row(
            children: [
              if (rating > 0) ...[
                Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), size: 15, color: _kGold),
                const SizedBox(width: 5),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFF5D485), Color(0xFFE8A820)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 4),
                Text('/5', style: _tj(12, FontWeight.w400, _kTextSec)),
                const SizedBox(width: 14),
                Container(width: 1, height: 18, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(width: 14),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIcons.flame(PhosphorIconsStyle.fill), size: 11, color: const Color(0xFFFFB347)),
                    const SizedBox(width: 4),
                    Text('$_likesCount ${AppStrings.worthIt}', style: _tj(11, FontWeight.w700, const Color(0xFFFFB347))),
                  ],
                ),
              ),
            ],
          ),

          // Category + city badges
          if (category != null || city.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (category != null)
                  _tagPill(category, border: _kOrange.withValues(alpha: 0.5),
                      bg: _kOrange.withValues(alpha: 0.1), color: _kOrange),
                if (city.isNotEmpty)
                  _tagPill(city),
                if (exp['updated_at'] != null && exp['updated_at'] != exp['created_at'])
                  _tagPill(_formatDate(exp['updated_at'].toString())),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tagPill(String label,
      {Color? border, Color? bg, Color color = _kTextSec}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: bg ?? Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border ?? Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(label, style: _tj(11, FontWeight.w600, color)),
      );

  Widget _buildActionRow() {
    return Container(
      color: _kCardBg,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Row(
        children: [
          _inlineActionBtn(
            widgetKey: _likeButtonKey,
            icon: _liked
                ? PhosphorIcons.flame(PhosphorIconsStyle.fill)
                : PhosphorIcons.flame(),
            label: AppStrings.worthIt,
            active: _liked,
            onTap: _toggleLike,
            scaleAnimation: _likeScale,
          ),
          const SizedBox(width: 8),
          _inlineActionBtn(
            icon: PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
            label: AppStrings.location,
            active: false,
            onTap: _openMap,
          ),
          const SizedBox(width: 8),
          _inlineActionBtn(
            icon: PhosphorIcons.shareNetwork(),
            label: AppStrings.share,
            active: false,
            onTap: _shareExperience,
          ),
          const SizedBox(width: 8),
          _inlineActionBtn(
            icon: _saved
                ? PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill)
                : PhosphorIcons.bookmarkSimple(),
            label: AppStrings.wantToVisit,
            active: _saved,
            onTap: _toggleSave,
            scaleAnimation: _saveScale,
            rotationAnimation: _saveRotation,
          ),
        ],
      ),
    );
  }

  Widget _inlineActionBtn({
    Key? widgetKey,
    required PhosphorIconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    Animation<double>? scaleAnimation,
    Animation<double>? rotationAnimation,
  }) {
    Widget btn = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: active
            ? _kOrange.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? _kOrange.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.08),
          width: active ? 1.2 : 0.8,
        ),
        boxShadow: active
            ? [BoxShadow(color: _kOrange.withValues(alpha: 0.2), blurRadius: 10)]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: active ? _kOrange : _kTextSec),
          const SizedBox(height: 4),
          Text(label,
              style: _tj(10, FontWeight.w700,
                  active ? _kOrange : _kTextSec),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );

    if (rotationAnimation != null) {
      btn = AnimatedBuilder(
        animation: rotationAnimation,
        builder: (_, child) => Transform(
          transform: Matrix4.identity()..rotateY(rotationAnimation.value),
          alignment: Alignment.center,
          child: child,
        ),
        child: btn,
      );
    }

    if (scaleAnimation != null) {
      btn = ScaleTransition(scale: scaleAnimation, child: btn);
    }

    return Expanded(
      child: GestureDetector(
        key: widgetKey,
        onTap: onTap,
        child: btn,
      ),
    );
  }

  Widget _buildDescriptionSection(Map<String, dynamic> exp) {
    return Container(
      color: _kCardBg,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(AppStrings.aboutExperience, _kOrange),
          const SizedBox(height: 12),
          Text(
            exp['description'].toString().trim(),
            style: GoogleFonts.tajawal(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.9,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildAtmosphereSection(String? atmosphere, String? priceRange) {
    final tags = <String>[];
    if (atmosphere != null && atmosphere.isNotEmpty) tags.add(atmosphere);
    if (priceRange != null && priceRange.isNotEmpty) tags.add(priceRange);
    if (tags.isEmpty) return const SizedBox();

    return Container(
      color: _kCardBg,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(AppStrings.atmosphere, _kGold),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _kDark2,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Text(t, style: _tj(12, FontWeight.w600, Colors.white70)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsSection(Map<String, dynamic> exp, double rating) {
    return Container(
      color: _kCardBg,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(AppStrings.detailedRatings, _kGold),
          const SizedBox(height: 16),
          ...[
            [AppStrings.food, 'rating_food'],
            [AppStrings.service, 'rating_service'],
            [AppStrings.ambiance, 'rating_ambiance'],
            [AppStrings.cleanliness, 'rating_clean'],
            [AppStrings.value, 'rating_value'],
          ].map((r) {
            final val = (exp[r[1]] as num?)?.toDouble() ?? 0;
            if (val == 0) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(r[0], style: _tj(11, FontWeight.w500, _kTextSec)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 10,
                        child: Stack(
                          children: [
                            Container(color: Colors.white.withValues(alpha: 0.07)),
                            FractionallySizedBox(
                              alignment: Alignment.centerRight,
                              widthFactor: val / 5,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFB8820F), Color(0xFFE8A820)],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(val.toStringAsFixed(1),
                      style: _tj(12, FontWeight.w800, _kGold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDishesSection() {
    return Container(
      color: _kCardBg,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(AppStrings.orderedDishes, _kGold),
          const SizedBox(height: 12),
          ..._dishes.map((d) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: d['photo_url'] != null && d['photo_url'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: d['photo_url'].toString(),
                            width: 80, height: 80,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(
                              width: 80, height: 80,
                              child: ColoredBox(color: _kDark2),
                            ),
                            errorWidget: (_, __, ___) => SizedBox(
                              width: 80, height: 80,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: AppPlaceholder(
                                  name: (d['name'] ?? '').toString(),
                                  width: 80, height: 80, borderRadius: 0,
                                ),
                              ),
                            ),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 80, height: 80,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: AppPlaceholder(
                                name: (d['name'] ?? '').toString(),
                                width: 80, height: 80, borderRadius: 0,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(d['name'] ?? '',
                      style: _tj(13, FontWeight.w600, Colors.white)),
                ),
                if (d['price_sar'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
                    ),
                    child: Text('${d['price_sar']} ${AppStrings.sar}',
                        style: _tj(11, FontWeight.w800, _kOrange)),
                  ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── UI Helpers ─────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, Color accentColor) => Row(
    children: [
      Container(
        width: 3, height: 18,
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(title, style: _tj(14, FontWeight.w800, Colors.white)),
    ],
  );

  void _showOwnerMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kDark2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              // drag handle
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              _ownerMenuRow(
                icon: PhosphorIcons.pencilSimple(),
                label: AppStrings.editExperience,
                color: Colors.white,
                onTap: () {
                  Navigator.pop(ctx);
                  _openEditExperience();
                },
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              _ownerMenuRow(
                icon: PhosphorIcons.trash(),
                label: AppStrings.deleteExperience,
                color: Colors.red.shade300,
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteExperience();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerMenuRow({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Text(label, style: _tj(14, FontWeight.w600, color)),
            ],
          ),
        ),
      );

  Widget _appBarAction(IconData icon, VoidCallback onTap, {Color? iconColor}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, color: iconColor ?? Colors.white, size: 17),
        ),
      );

  Widget _sectionGap() => Container(height: 6, color: _kDark);
}

// ── Floating "+1" feedback on like ────────────────────────────────────────────

class _FloatingLikeFeedback extends StatefulWidget {
  final VoidCallback onDone;
  const _FloatingLikeFeedback({required this.onDone});

  @override
  State<_FloatingLikeFeedback> createState() => _FloatingLikeFeedbackState();
}

class _FloatingLikeFeedbackState extends State<_FloatingLikeFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _rise;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 1.0, curve: Curves.easeIn)),
    );
    _rise = Tween<double>(begin: 0.0, end: -44.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward().then((_) {
      if (!_done) {
        _done = true;
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _done = true;
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _rise.value),
            child: Opacity(
              opacity: _opacity.value,
              child: Text(
                '+1',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFF26500),
                  shadows: [
                    const Shadow(color: Color(0xFFF26500), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
