import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../l10n/app_strings.dart';
import 'app_placeholder.dart';

const _kDark2 = Color(0xFF1A2340);
const _kOrange = Color(0xFFF26500);
const _kGold = Color(0xFFC8931A);
const _kCardBg = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size, FontWeight weight, Color color,
        {double height = 1.0}) =>
    GoogleFonts.tajawal(
        fontSize: size, fontWeight: weight, color: color, height: height);

/// Reusable restaurant card: photo collage on top, info below.
class RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final List<String> photos;
  final VoidCallback onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.photos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = restaurant['name_ar'] as String? ?? 'مطعم';
    final city = restaurant['city'] as String? ?? '';
    final category = restaurant['category'] as String? ?? '';
    final rating = (restaurant['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final categories = category
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RestaurantCollage(photos: photos, name: name, height: 160),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: _tj(14, FontWeight.w900, Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                            size: 11, color: _kTextSec),
                        const SizedBox(width: 4),
                        Text(city, style: _tj(11, FontWeight.w400, _kTextSec)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  // RTL so "عرض التجارب" sits on the leading (left) side.
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final c in categories.take(2))
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 110),
                                  child: _chip(c, _kOrange,
                                      weight: FontWeight.w600, ellipsis: true),
                                ),
                              if (categories.length > 2)
                                _chip('+${categories.length - 2}', _kOrange,
                                    weight: FontWeight.w700),
                              if (rating > 0) _ratingChip(rating),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(AppStrings.viewExperiences,
                                style: _tj(11, FontWeight.w700, _kOrange)),
                            const SizedBox(width: 2),
                            Icon(PhosphorIcons.caretLeft(),
                                size: 12, color: _kOrange),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color,
          {FontWeight weight = FontWeight.w600, bool ellipsis = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: ellipsis ? TextOverflow.ellipsis : TextOverflow.clip,
            style: _tj(10, weight, color)),
      );

  Widget _ratingChip(double rating) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _kGold.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                size: 10, color: _kGold),
            const SizedBox(width: 3),
            Text(rating.toStringAsFixed(1),
                style: _tj(10, FontWeight.w700, _kGold)),
          ],
        ),
      );
}

/// Photo collage: 1 full · 2 side-by-side · 3 = left full + right stacked ·
/// 4+ = 2×2 (first 4). Falls back to [AppPlaceholder] when there are no photos.
class RestaurantCollage extends StatelessWidget {
  final List<String> photos;
  final String name;
  final double height;

  const RestaurantCollage({
    super.key,
    required this.photos,
    required this.name,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: SizedBox(height: height, width: double.infinity, child: _layout()),
    );
  }

  Widget _layout() {
    final p = photos.take(4).toList();
    switch (p.length) {
      case 0:
        return AppPlaceholder(name: name, borderRadius: 0);
      case 1:
        return _img(p[0]);
      case 2:
        return Row(children: [
          Expanded(child: _img(p[0])),
          const SizedBox(width: 2),
          Expanded(child: _img(p[1])),
        ]);
      case 3:
        return Row(children: [
          Expanded(child: _img(p[0])),
          const SizedBox(width: 2),
          Expanded(
            child: Column(children: [
              Expanded(child: _img(p[1])),
              const SizedBox(height: 2),
              Expanded(child: _img(p[2])),
            ]),
          ),
        ]);
      default: // 4
        return Row(children: [
          Expanded(
            child: Column(children: [
              Expanded(child: _img(p[0])),
              const SizedBox(height: 2),
              Expanded(child: _img(p[2])),
            ]),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(children: [
              Expanded(child: _img(p[1])),
              const SizedBox(height: 2),
              Expanded(child: _img(p[3])),
            ]),
          ),
        ]);
    }
  }

  Widget _img(String url) => CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => const ColoredBox(color: _kDark2),
        errorWidget: (_, __, ___) => AppPlaceholder(name: name, borderRadius: 0),
      );
}
