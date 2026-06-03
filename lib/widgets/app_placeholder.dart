import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Design tokens (the screens keep these file-private, so we redeclare them here).
const _kDark = Color(0xFF0F1923);
const _kDark2 = Color(0xFF1A2340);
const _kOrange = Color(0xFFF26500);

/// Shared empty-state placeholder for cards / photos that have no image.
///
/// Shows the first letter of [name] over a subtle dark gradient, with a small
/// fork-knife glyph beneath. Pass the same [borderRadius] as the card it fills
/// (use 0 when it sits inside a parent `ClipRRect` that already rounds it).
class AppPlaceholder extends StatelessWidget {
  final String name;
  final double? width;
  final double? height;
  final double borderRadius;

  const AppPlaceholder({
    super.key,
    required this.name,
    this.width,
    this.height,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    // First Unicode code point (safe for Arabic, Latin, and emoji/surrogates).
    final letter = trimmed.isEmpty
        ? ''
        : String.fromCharCode(trimmed.runes.first).toUpperCase();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kDark2, _kDark],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: _kOrange.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (letter.isNotEmpty) ...[
              Text(
                letter,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _kOrange.withValues(alpha: 0.8),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Icon(
              PhosphorIcons.forkKnife(),
              size: 16,
              color: _kOrange.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
