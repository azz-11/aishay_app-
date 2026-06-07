import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/gamification_service.dart';

const _kDark = Color(0xFF0F1923);
const _kDark2 = Color(0xFF1A2340);
const _kOrange = Color(0xFFF26500);
const _kCardBg = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size,
        {FontWeight weight = FontWeight.w400,
        Color color = Colors.white,
        double? height}) =>
    GoogleFonts.tajawal(
        fontSize: size, fontWeight: weight, color: color, height: height);

class AchievementsScreen extends StatefulWidget {
  final String userId;
  const AchievementsScreen({super.key, required this.userId});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _svc = GamificationService();
  bool _loading = true;
  int _expCount = 0;
  List<BadgeStatus> _earned = [];
  List<BadgeStatus> _locked = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      // Single computation pass — awards only on the user's own profile.
      final data = await _svc.refreshAndGet(widget.userId,
          award: me == widget.userId);
      if (!mounted) return;
      setState(() {
        _expCount = data.experienceCount;
        _earned = data.earned;
        _locked = data.locked;
        _loading = false;
      });
      if (data.newlyEarned.isNotEmpty) _celebrate(data.newlyEarned);
    } catch (e) {
      debugPrint('[achievements] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _celebrate(List<BadgeDef> badges) {
    final msg = badges.length == 1
        ? 'حصلت على شارة جديدة: ${badges.first.name}'
        : 'حصلت على ${badges.length} شارات جديدة!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _kOrange,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: _tj(13, weight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = GamificationService.getLevelInfo(_expCount);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kDark,
        appBar: AppBar(
          backgroundColor: _kDark2,
          elevation: 0,
          title: Text('الإنجازات', style: _tj(17, weight: FontWeight.w900)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _kOrange))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _levelCard(level),
                  const SizedBox(height: 20),
                  if (_earned.isEmpty)
                    _emptyState()
                  else ...[
                    _sectionTitle('مكتسبة', _earned.length),
                    const SizedBox(height: 10),
                    _grid(_earned),
                  ],
                  if (_locked.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _sectionTitle('مقفلة', _locked.length),
                    const SizedBox(height: 10),
                    _grid(_locked),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _levelCard(LevelInfo level) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.crown(PhosphorIconsStyle.fill),
                    color: _kOrange, size: 22),
                const SizedBox(width: 8),
                Text(level.name,
                    style: _tj(18, weight: FontWeight.w900, color: _kOrange)),
                const Spacer(),
                Text('$_expCount تجربة', style: _tj(12, color: _kTextSec)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: level.progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation(_kOrange),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              level.nextName != null
                  ? 'المستوى التالي: ${level.nextName} (${level.nextThreshold} تجربة)'
                  : 'وصلت لأعلى مستوى',
              style: _tj(11, color: _kTextSec),
            ),
          ],
        ),
      );

  Widget _sectionTitle(String t, int n) => Row(
        children: [
          Container(width: 3, height: 16, color: _kOrange),
          const SizedBox(width: 8),
          Text(t, style: _tj(14, weight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text('($n)', style: _tj(12, color: _kTextSec)),
        ],
      );

  Widget _grid(List<BadgeStatus> items) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.95,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _badgeCard(items[i]),
      );

  Widget _badgeCard(BadgeStatus b) {
    final earned = b.earned;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: earned
              ? _kOrange.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.06),
          width: earned ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            b.def.icon(
                earned ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular),
            size: 32,
            color: earned ? _kOrange : _kTextSec.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            b.def.name,
            style: _tj(12,
                weight: FontWeight.w800,
                color: earned ? Colors.white : _kTextSec),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            b.def.condition,
            style: _tj(9, color: _kTextSec),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!earned) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: b.progress,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor:
                    AlwaysStoppedAnimation(_kOrange.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() => Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(PhosphorIcons.trophy(),
                size: 56, color: _kTextSec.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text('لا شارات بعد', style: _tj(15, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('أضف تجارب لتكسب شاراتك الأولى',
                style: _tj(12, color: _kTextSec), textAlign: TextAlign.center),
          ],
        ),
      );
}
