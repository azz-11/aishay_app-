import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home_screen.dart';
import 'onboarding_progress.dart';
import 'taste_match_screen.dart';

const _kDark = Color(0xFF0F1923);
const _kOrange = Color(0xFFF26500);
const _kCardBg = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size, FontWeight weight, Color color,
        {double height = 1.0}) =>
    GoogleFonts.tajawal(
        fontSize: size, fontWeight: weight, color: color, height: height);

const _kCities = [
  'جدة',
  'الرياض',
  'مكة',
  'المدينة',
  'الدمام',
  'الخبر',
  'أبها',
  'تبوك',
  'القصيم',
];

const _kCategories = [
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
];

const _kAmbiance = [
  'هادئ',
  'حيوي',
  'عائلي',
  'رومانسي',
  'فاخر',
  'بسيط',
];

const _kTimes = [
  'صباحاً',
  'ظهراً',
  'عصراً',
  'مساءً',
  'ليلاً',
];

const _kMinCategories = 3;

/// Onboarding Step 3 — city (required) + categories (min 3, required).
class OnboardingPreferencesScreen extends StatefulWidget {
  const OnboardingPreferencesScreen({super.key});

  @override
  State<OnboardingPreferencesScreen> createState() =>
      _OnboardingPreferencesScreenState();
}

class _OnboardingPreferencesScreenState
    extends State<OnboardingPreferencesScreen> {
  String? _city;
  final Set<String> _cats = {};
  final Set<String> _ambiance = {};
  final Set<String> _time = {};
  bool _saving = false;

  bool get _valid =>
      _city != null &&
      _cats.length >= _kMinCategories &&
      _ambiance.isNotEmpty &&
      _time.isNotEmpty;

  Future<void> _finish() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('users').update({
          'city': _city,
          'preferred_categories': _cats.join(','),
          'preferred_ambiance': _ambiance.join(','),
          'preferred_time': _time.join(','),
          'onboarding_completed': true,
        }).eq('id', user.id);
      }
      if (!mounted) return;
      HomeScreen.prefetchFeed();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const TasteMatchScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('[onboarding] finish error: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تعذّر حفظ التفضيلات، حاول مرة أخرى',
                  style: GoogleFonts.tajawal())),
        );
      }
    }
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const Expanded(
                      child: Center(child: OnboardingProgress(current: 2)),
                    ),
                    const SizedBox(width: 38),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Text('ذوقك في الأكل',
                            style: _tj(22, FontWeight.w900, Colors.white)),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text('عشان نرشّح لك أفضل التجارب',
                            style: _tj(13, FontWeight.w400, _kTextSec),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 28),
                      Text('مدينتك',
                          style: _tj(14, FontWeight.w800, Colors.white)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in _kCities)
                            _chip(c, _city == c,
                                onTap: () => setState(() => _city = c)),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Text('تصنيفاتك المفضلة',
                              style: _tj(14, FontWeight.w800, Colors.white)),
                          const SizedBox(width: 8),
                          Text(
                            _cats.length >= _kMinCategories
                                ? '(${_cats.length})'
                                : 'اختر ٣ على الأقل (${_cats.length}/$_kMinCategories)',
                            style: _tj(11, FontWeight.w600, _kTextSec),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in _kCategories)
                            _chip(c, _cats.contains(c), onTap: () {
                              setState(() {
                                if (!_cats.add(c)) _cats.remove(c);
                              });
                            }),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text('الجو الذي تفضّله',
                          style: _tj(14, FontWeight.w800, Colors.white)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in _kAmbiance)
                            _chip(a, _ambiance.contains(a), onTap: () {
                              setState(() {
                                if (!_ambiance.add(a)) _ambiance.remove(a);
                              });
                            }),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text('وقت الزيارة المفضّل',
                          style: _tj(14, FontWeight.w800, Colors.white)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in _kTimes)
                            _chip(t, _time.contains(t), onTap: () {
                              setState(() {
                                if (!_time.add(t)) _time.remove(t);
                              });
                            }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: GestureDetector(
                  onTap: _valid ? _finish : null,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _valid ? 1.0 : 0.4,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_kOrange, Color(0xFFFF7A1A)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _valid
                            ? [
                                BoxShadow(
                                    color: _kOrange.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6)),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Text('ابدأ رحلتك',
                                style: _tj(16, FontWeight.w800, Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, {required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? _kOrange : _kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? _kOrange
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: _tj(13, selected ? FontWeight.w700 : FontWeight.w500,
                selected ? Colors.white : _kTextSec),
          ),
        ),
      );
}
