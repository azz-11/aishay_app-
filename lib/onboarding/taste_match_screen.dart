import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home_screen.dart';
import '../widgets/app_avatar.dart';

const _kDark = Color(0xFF0F1923);
const _kOrange = Color(0xFFF26500);
const _kCardBg = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size, FontWeight weight, Color color,
        {double height = 1.0}) =>
    GoogleFonts.tajawal(
        fontSize: size, fontWeight: weight, color: color, height: height);

class _Match {
  final Map<String, dynamic> user;
  final List<String> reasons; // human bullets, only from real overlaps
  final int score; // total overlap count
  const _Match(this.user, this.reasons, this.score);
}

/// Shown right after onboarding: suggests users with similar taste, explained
/// in plain language (no percentages). "ابدأ الآن" → HomeScreen.
class TasteMatchScreen extends StatefulWidget {
  const TasteMatchScreen({super.key});

  @override
  State<TasteMatchScreen> createState() => _TasteMatchScreenState();
}

class _TasteMatchScreenState extends State<TasteMatchScreen> {
  final _client = Supabase.instance.client;
  List<_Match> _matches = [];
  final Set<String> _followed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Set<String> _split(dynamic v) => (v ?? '')
      .toString()
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();

  Future<void> _load() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      // My own taste.
      final mine = await _client
          .from('users')
          .select('preferred_categories, preferred_ambiance, preferred_time')
          .eq('id', me)
          .maybeSingle();
      final myCats = _split(mine?['preferred_categories']);
      final myAmb = _split(mine?['preferred_ambiance']);
      final myTime = _split(mine?['preferred_time']);

      // Candidate users (exclude self), most recent first.
      final res = await _client
          .from('users')
          .select(
              'id, display_name, username, avatar_url, preferred_categories, preferred_ambiance, preferred_time')
          .neq('id', me)
          .order('created_at', ascending: false)
          .limit(60);
      final candidates = List<Map<String, dynamic>>.from(res);

      final withOverlap = <_Match>[];
      final fillers = <_Match>[]; // 0-overlap, kept as recent-active fallback
      for (final u in candidates) {
        final cOverlap = myCats.intersection(_split(u['preferred_categories']));
        final tOverlap = myTime.intersection(_split(u['preferred_time']));
        final aOverlap = myAmb.intersection(_split(u['preferred_ambiance']));

        final reasons = <String>[];
        if (cOverlap.isNotEmpty) reasons.add('يفضّل: ${cOverlap.join('، ')}');
        if (tOverlap.isNotEmpty) {
          reasons.add('يحب الزيارة ${tOverlap.join('، ')}');
        }
        if (aOverlap.isNotEmpty) {
          reasons.add('يفضّل الأجواء: ${aOverlap.join('، ')}');
        }
        final score = cOverlap.length + tOverlap.length + aOverlap.length;

        if (score > 0) {
          withOverlap.add(_Match(u, reasons, score));
        } else {
          fillers.add(_Match(u, const [], 0));
        }
      }

      // Sort matches by overlap desc (candidates were already recency-ordered,
      // so ties keep the more-recent user first).
      withOverlap.sort((a, b) => b.score.compareTo(a.score));

      final result = <_Match>[...withOverlap];
      // Fill with recent active users if we have fewer than 5 real matches.
      for (final f in fillers) {
        if (result.length >= 5) break;
        result.add(f);
      }

      if (mounted) {
        setState(() {
          _matches = result.take(8).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[taste-match] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _follow(String targetId) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    setState(() => _followed.add(targetId)); // optimistic
    try {
      await _client
          .from('follows')
          .insert({'follower_id': me, 'following_id': targetId});
    } catch (e) {
      debugPrint('[taste-match] follow error: $e');
      if (mounted) setState(() => _followed.remove(targetId));
    }
  }

  void _goHome() {
    HomeScreen.prefetchFeed();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مجرّبون يشبهون ذوقك',
                        style: _tj(22, FontWeight.w900, Colors.white)),
                    const SizedBox(height: 6),
                    Text('تابع من يشاركك الذوق لترى تجارب تناسبك',
                        style: _tj(13, FontWeight.w400, _kTextSec)),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: _kOrange))
                    : _matches.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'لا توجد اقتراحات الآن — ابدأ الاستكشاف!',
                                textAlign: TextAlign.center,
                                style: _tj(14, FontWeight.w600, _kTextSec),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: _matches.length,
                            itemBuilder: (_, i) => _card(_matches[i]),
                          ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: GestureDetector(
                  onTap: _goHome,
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_kOrange, Color(0xFFFF7A1A)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: _kOrange.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Center(
                      child: Text('ابدأ الآن',
                          style: _tj(16, FontWeight.w800, Colors.white)),
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

  Widget _card(_Match m) {
    final u = m.user;
    final id = u['id'].toString();
    final name = u['display_name']?.toString() ?? 'مستخدم';
    final username = (u['username'] ?? '').toString();
    final followed = _followed.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                displayName: name,
                username: username,
                avatarUrl: u['avatar_url']?.toString(),
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: _tj(14, FontWeight.w800, Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (username.isNotEmpty)
                      Text('@$username',
                          style: _tj(11, FontWeight.w500, _kTextSec),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              GestureDetector(
                onTap: followed ? null : () => _follow(id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: followed ? Colors.transparent : _kOrange,
                    borderRadius: BorderRadius.circular(12),
                    border: followed
                        ? Border.all(color: _kTextSec)
                        : null,
                  ),
                  child: Text(
                    followed ? 'تتابعه ✓' : 'متابعة',
                    style: _tj(12, FontWeight.w800,
                        followed ? _kTextSec : Colors.white),
                  ),
                ),
              ),
            ],
          ),
          if (m.reasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('يشبه ذوقك لأنه:',
                style: _tj(12, FontWeight.w800, _kOrange)),
            const SizedBox(height: 6),
            for (final r in m.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: _tj(12, FontWeight.w700, _kTextSec)),
                    Expanded(
                      child: Text(r,
                          style: _tj(12, FontWeight.w500, _kTextSec,
                              height: 1.4)),
                    ),
                  ],
                ),
              ),
          ] else ...[
            const SizedBox(height: 10),
            Text('مجرّب نشط مؤخراً',
                style: _tj(11, FontWeight.w500, _kTextSec)),
          ],
        ],
      ),
    );
  }
}
