import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'app_avatar.dart';
import 'app_placeholder.dart';

// Theme tokens (mirror home_screen's library-private constants).
const _kCardBg = Color(0xFF1E2D45);
const _kOrange = Color(0xFFF26500);
const _kGold = Color(0xFFC8931A);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size, FontWeight weight, Color color, {double height = 1.0}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color, height: height);

/// The shared experience card used by the home grid, the "تثق بتجاربهم" strip,
/// and the following-feed screen. Each screen supplies its own [onTap] so it can
/// open the detail view its own way (home overlay vs. Navigator push).
///
/// [scrollController] is optional — when provided (and not on web) the photo gets
/// a subtle parallax tied to that scroll position; pass null to disable it
/// (e.g. inside a horizontal strip).
class ExperienceCard extends StatefulWidget {
  final Map<String, dynamic> experience;
  final VoidCallback onTap;
  final ScrollController? scrollController;

  const ExperienceCard({
    super.key,
    required this.experience,
    required this.onTap,
    this.scrollController,
  });

  @override
  State<ExperienceCard> createState() => _ExperienceCardState();
}

class _ExperienceCardState extends State<ExperienceCard> {
  bool _pressed = false;

  double _avgRating(Map<String, dynamic> exp) {
    const fields = ['rating_food', 'rating_service', 'rating_ambiance', 'rating_clean', 'rating_value'];
    final vals = fields.map((f) => (exp[f] as num?)?.toDouble() ?? 0.0).where((v) => v > 0).toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  Widget _placeholderImg(String name) => AppPlaceholder(name: name, borderRadius: 0);

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

  Widget _photo(String url, String restName) {
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(color: _kCardBg),
      errorWidget: (_, __, ___) => _placeholderImg(restName),
    );
    // Parallax only when a scroll controller is supplied and not on web.
    final sc = widget.scrollController;
    if (kIsWeb || sc == null) return image;
    return AnimatedBuilder(
      animation: sc,
      builder: (_, child) {
        final parallax = sc.hasClients ? -(sc.offset * 0.08).clamp(0.0, 14.0) : 0.0;
        return Transform.translate(offset: Offset(0, parallax), child: child);
      },
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.experience;
    final rating = _avgRating(exp);
    final restName = exp['restaurant']?['name_ar'] ?? 'مطعم';
    final likes = exp['likes_count'] ?? 0;
    final photos = exp['photos'] as List? ?? [];
    final title = (exp['title'] as String? ?? '').trim();
    final desc = (exp['description'] as String? ?? '').trim();
    final preview = title.isNotEmpty ? title : desc;
    final user = exp['user'] as Map<String, dynamic>?;
    final userName = (user?['display_name'] ?? 'مستخدم').toString();
    final userHandle = (user?['username'] ?? '').toString();
    final userAvatar = user?['avatar_url'] as String?;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photo ──────────────────────────────────────────────────────
              Expanded(
                flex: 6,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      photos.isNotEmpty
                          ? _photo(photos[0].toString(), restName)
                          : _placeholderImg(restName),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.88)],
                              stops: const [0.28, 1.0],
                            ),
                          ),
                        ),
                      ),
                      if (rating > 0)
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _kGold,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: _kGold.withValues(alpha: 0.4), blurRadius: 6)],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), size: 9, color: Colors.white),
                                const SizedBox(width: 2),
                                Text(rating.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PhosphorIcons.flame(PhosphorIconsStyle.fill), size: 9, color: _kOrange),
                              const SizedBox(width: 2),
                              Text('$likes', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                      if (preview.isNotEmpty)
                        Positioned(
                          bottom: 8, left: 8, right: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32, height: 3,
                                decoration: BoxDecoration(color: _kOrange, borderRadius: BorderRadius.circular(2)),
                              ),
                              const SizedBox(height: 5),
                              _styledTitle(preview),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // ── Info below photo ─────────────────────────────────────────────
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restName,
                          style: _tj(12, FontWeight.w800, Colors.white, height: 1.2),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if ((exp['visit_time'] as String?) != null &&
                          (exp['visit_time'] as String).isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(exp['visit_time'].toString(), style: _tj(9, FontWeight.w500, _kTextSec)),
                      ],
                      const Spacer(),
                      // Who posted this experience (like count stays on the photo badge).
                      Row(
                        children: [
                          AppAvatar(
                            displayName: userName,
                            username: userHandle,
                            avatarUrl: userAvatar,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(userName,
                                style: _tj(9, FontWeight.w600, _kTextSec),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
