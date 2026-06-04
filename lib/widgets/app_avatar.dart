import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kOrange = Color(0xFFF26500);

// Fixed palette — index chosen by username.hashCode.abs() % 6 (stable per user).
const List<Color> _avatarPalette = [
  Color(0xFFF26500), // 0 orange
  Color(0xFF1A3A5C), // 1 dark blue
  Color(0xFF1D6B4E), // 2 dark green
  Color(0xFF6B3D1D), // 3 dark brown
  Color(0xFF4A1D6B), // 4 dark purple
  Color(0xFF1D4A6B), // 5 dark teal
];

/// Shared user avatar: shows the photo if available, otherwise the first letter
/// of [displayName] on a palette colour keyed by [username]. Orange ring at all
/// sizes (proportional width); glow only when [showGlow] (profile headers).
class AppAvatar extends StatelessWidget {
  final String displayName;
  final String username;
  final String? avatarUrl;
  final double size;
  final bool showGlow;

  const AppAvatar({
    super.key,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.size = 86,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final ringWidth = size >= 48 ? 2.5 : 1.5;
    final hasPhoto = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _kOrange, width: ringWidth),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: _kOrange.withValues(alpha: 0.35),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => _letter(),
                errorWidget: (_, __, ___) => _letter(),
              )
            : _letter(),
      ),
    );
  }

  Widget _letter() {
    final color = _avatarPalette[username.trim().hashCode.abs() % 6];
    final trimmed = displayName.trim();
    // First Unicode code point (safe for Arabic / Latin / emoji).
    final letter = trimmed.isEmpty
        ? 'م'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return Container(
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.tajawal(
          fontSize: size * 0.33,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}
