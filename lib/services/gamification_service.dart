import 'package:flutter/foundation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Level ────────────────────────────────────────────────────────────────────
class LevelInfo {
  final String name;
  final int experienceCount;
  final double progress; // 0..1 toward next tier (1.0 at max)
  final int? nextThreshold; // experience count for next tier (null at max)
  final String? nextName;
  const LevelInfo({
    required this.name,
    required this.experienceCount,
    required this.progress,
    this.nextThreshold,
    this.nextName,
  });
}

// ── Badge metadata ───────────────────────────────────────────────────────────
typedef PhosphorIconBuilder = PhosphorIconData Function([PhosphorIconsStyle]);

class BadgeDef {
  final String key;
  final String name; // Arabic display name
  final PhosphorIconBuilder icon; // call with .fill (earned) / .regular (locked)
  final String condition; // Arabic short condition text
  const BadgeDef(this.key, this.name, this.icon, this.condition);
}

class BadgeStatus {
  final BadgeDef def;
  final bool earned;
  final double progress; // 0..1
  const BadgeStatus(this.def, this.earned, this.progress);
}

class GamificationService {
  final SupabaseClient _db;
  GamificationService([SupabaseClient? client])
      : _db = client ?? Supabase.instance.client;

  // ── Levels (lower-bound thresholds) ─────────────────────────────────────────
  static const List<({int at, String name})> _tiers = [
    (at: 0, name: 'مستكشف'),
    (at: 21, name: 'باحث ذواق'),
    (at: 41, name: 'متذوق'),
    (at: 61, name: 'متذوق خبير'),
    (at: 91, name: 'ذوّيق'),
    (at: 130, name: 'ذوّيق محترف'),
    (at: 150, name: 'أسطورة الذواقة'),
  ];

  static LevelInfo getLevelInfo(int count) {
    var i = 0;
    for (var t = 0; t < _tiers.length; t++) {
      if (count >= _tiers[t].at) i = t;
    }
    final current = _tiers[i];
    if (i == _tiers.length - 1) {
      return LevelInfo(
          name: current.name, experienceCount: count, progress: 1.0);
    }
    final next = _tiers[i + 1];
    final progress =
        ((count - current.at) / (next.at - current.at)).clamp(0.0, 1.0);
    return LevelInfo(
      name: current.name,
      experienceCount: count,
      progress: progress,
      nextThreshold: next.at,
      nextName: next.name,
    );
  }

  // ── Badge catalog (Phosphor icons; no weekly_star) ──────────────────────────
  static final List<BadgeDef> catalog = [
    // Category badges (10+ experiences of that category)
    BadgeDef('asian_expert', 'سفير الآسيوي', PhosphorIcons.bowlFood, '10 تجارب آسيوية'),
    BadgeDef('burger_hunter', 'صيّاد البرغر', PhosphorIcons.hamburger, '10 تجارب برغر'),
    BadgeDef('grill_master', 'صاحب المشاوي', PhosphorIcons.flame, '10 تجارب مشاوي'),
    BadgeDef('cafe_expert', 'راعي الكيف', PhosphorIcons.coffee, '10 تجارب كافيهات'),
    BadgeDef('sushi_samurai', 'سامورائي السوشي', PhosphorIcons.fish, '10 تجارب سوشي'),
    BadgeDef('pizza_expert', 'بيتزايولو', PhosphorIcons.pizza, '10 تجارب بيتزا'),
    BadgeDef('healthy_guard', 'حارس الصحة', PhosphorIcons.leaf, '10 تجارب صحية'),
    BadgeDef('chicken_sheikh', 'شيخ الدجاج', PhosphorIcons.egg, '10 تجارب دجاج'),
    BadgeDef('rice_prince', 'أمير الأرز', PhosphorIcons.bowlFood, '10 تجارب رز'),
    BadgeDef('sea_knight', 'فارس البحر', PhosphorIcons.anchor, '10 تجارب بحرية'),
    BadgeDef('shawarma_king', 'ملك الشاورما', PhosphorIcons.forkKnife, '10 تجارب شاورما'),
    BadgeDef('sweets_judge', 'قاضي الحلو', PhosphorIcons.cake, '10 تجارب حلويات'),
    BadgeDef('steak_companion', 'رفيق الستيك', PhosphorIcons.knife, '10 تجارب ستيك'),
    BadgeDef('mexico_traveler', 'رحّال المكسيك', PhosphorIcons.pepper, '10 تجارب مكسيكية'),
    BadgeDef('india_guest', 'ضيف الهند', PhosphorIcons.cookingPot, '10 تجارب هندية'),
    BadgeDef('italy_son', 'ابن إيطاليا', PhosphorIcons.wine, '10 تجارب إيطالية'),
    BadgeDef('authentic', 'أصيل', PhosphorIcons.houseLine, '10 تجارب أصيلة'),
    // Activity badges
    BadgeDef('first_reviewer', 'أول المجرّبين', PhosphorIcons.medal, 'أول من يضيف تجربة لمطعم'),
    BadgeDef('beloved', 'محبوب الذواقة', PhosphorIcons.heart, '100 يستاهل على تجاربك'),
    BadgeDef('camera_eye', 'عين الكاميرا', PhosphorIcons.camera, '50 صورة مرفوعة'),
    BadgeDef('traveler', 'جوّال', PhosphorIcons.compass, 'تجارب في 3 مدن'),
    BadgeDef('critic', 'ناقد', PhosphorIcons.pencilSimple, '30 تعليق على تجارب الآخرين'),
    BadgeDef('city_explorer', 'مستكشف المدينة', PhosphorIcons.mapPin, '5 مطاعم في نفس المدينة'),
    BadgeDef('trusted_recommender', 'موصي موثوق', PhosphorIcons.handshake, '10 أشخاص حفظوا تجربتك'),
    BadgeDef('precise_rater', 'دقيق التقييم', PhosphorIcons.target, '20 تجربة بتقييم كامل'),
    BadgeDef('loyal', 'وفيّ', PhosphorIcons.arrowsClockwise, 'زيارة نفس المطعم 3 مرات'),
    BadgeDef('pioneer', 'سبّاق', PhosphorIcons.rocketLaunch, 'من أوائل 5 مستخدمين'),
    BadgeDef('social', 'اجتماعي', PhosphorIcons.usersThree, '10 متابعين'),
    BadgeDef('most_inspiring', 'الأكثر إلهاماً', PhosphorIcons.sparkle, 'حفظ تجاربك 50 مرة'),
    BadgeDef('explorer', 'رحّالة', PhosphorIcons.globe, 'تجارب في 5 مدن مختلفة'),
  ];

  static BadgeDef? defFor(String key) {
    for (final b in catalog) {
      if (b.key == key) return b;
    }
    return null;
  }

  // category badge_key → keywords matched against restaurant.category (lowercased)
  static const Map<String, List<String>> _categoryKeywords = {
    'asian_expert': ['آسيوي', 'اسيوي', 'asian', 'نودلز', 'noodle', 'تايلندي', 'صيني', 'chinese', 'thai'],
    'burger_hunter': ['برغر', 'برجر', 'burger'],
    'grill_master': ['مشوي', 'مشويات', 'مشاوي', 'شواء', 'grill', 'bbq'],
    'cafe_expert': ['كافيه', 'كوفي', 'coffee', 'cafe', 'كيف'],
    'sushi_samurai': ['سوشي', 'sushi', 'ياباني', 'japanese'],
    'pizza_expert': ['بيتزا', 'pizza'],
    'healthy_guard': ['صحي', 'healthy', 'سلطة', 'salad', 'دايت'],
    'chicken_sheikh': ['دجاج', 'chicken', 'بروست', 'broast'],
    'rice_prince': ['رز', 'أرز', 'rice', 'كبسة', 'مندي', 'برياني', 'biryani'],
    'sea_knight': ['بحري', 'بحرية', 'seafood', 'سمك', 'fish', 'جمبري', 'shrimp', 'روبيان'],
    'shawarma_king': ['شاورما', 'shawarma'],
    'sweets_judge': ['حلو', 'حلويات', 'حلا', 'sweet', 'dessert', 'كيك', 'cake'],
    'steak_companion': ['ستيك', 'steak', 'لحم', 'لحوم', 'meat'],
    'mexico_traveler': ['مكسيك', 'mexican', 'تاكو', 'taco'],
    'india_guest': ['هندي', 'هند', 'indian'],
    'italy_son': ['إيطالي', 'ايطالي', 'italian', 'باستا', 'pasta'],
    'authentic': ['شعبي', 'تقليدي', 'أصيل', 'اصيل', 'بلدي', 'traditional', 'authentic'],
  };

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Recompute conditions and persist newly-earned badges. Returns the defs
  /// earned on THIS call (for the celebration).
  ///
  /// [full] = false (default) computes only the cheap, experience-derived
  /// badges (+ followers) — used after saving an experience. [full] = true
  /// adds the heavy cross-table badges — used on the achievements screen.
  Future<List<BadgeDef>> checkAndAwardBadges(String userId,
      {bool full = false}) async {
    final progress = await _computeProgress(userId, full: full);
    final met = progress.entries
        .where((e) => e.value >= 1.0)
        .map((e) => e.key)
        .toSet();
    if (met.isEmpty) return [];

    final existing = await _earnedKeys(userId);
    final toAward = met.difference(existing).toList();
    if (toAward.isEmpty) return [];

    try {
      await _db.from('user_badges').upsert(
            toAward.map((k) => {'user_id': userId, 'badge_key': k}).toList(),
            onConflict: 'user_id,badge_key',
            ignoreDuplicates: true,
          );
    } catch (e) {
      debugPrint('[gamification] award error: $e');
      return [];
    }
    return catalog.where((b) => toAward.contains(b.key)).toList();
  }

  /// Earned (from DB) + locked (with 0..1 progress). Always uses the full
  /// computation so locked progress is accurate.
  Future<({List<BadgeStatus> earned, List<BadgeStatus> locked})> getUserBadges(
      String userId) async {
    final progress = await _computeProgress(userId, full: true);
    final earnedKeys = await _earnedKeys(userId);
    final earned = <BadgeStatus>[];
    final locked = <BadgeStatus>[];
    for (final b in catalog) {
      if (earnedKeys.contains(b.key)) {
        earned.add(BadgeStatus(b, true, 1.0));
      } else {
        locked.add(
            BadgeStatus(b, false, (progress[b.key] ?? 0).clamp(0.0, 1.0)));
      }
    }
    return (earned: earned, locked: locked);
  }

  /// Just the earned badge keys (cheap — single query). For the profile header.
  Future<List<String>> earnedBadgeKeys(String userId) async =>
      (await _earnedKeys(userId)).toList();

  Future<Set<String>> _earnedKeys(String userId) async {
    try {
      final res =
          await _db.from('user_badges').select('badge_key').eq('user_id', userId);
      return (res as List).map((r) => r['badge_key'].toString()).toSet();
    } catch (e) {
      debugPrint('[gamification] earnedKeys error: $e');
      return {};
    }
  }

  // ── Metrics → progress per badge key (raw ratio, clamped later) ─────────────
  Future<Map<String, double>> _computeProgress(String userId,
      {required bool full}) async {
    final p = <String, double>{};
    try {
      // ── Cheap: single experiences query ──────────────────────────────────
      final expRes = await _db
          .from('experiences')
          .select('id, restaurant_id, photos, rating_food, rating_service, '
              'rating_ambiance, rating_clean, rating_value, title, description, '
              'atmosphere, price_range, visit_time, created_at, '
              'restaurant:restaurants(category, city)')
          .eq('user_id', userId);
      final exps = List<Map<String, dynamic>>.from(expRes);

      final expIds = exps.map((e) => e['id'].toString()).toList();
      final restIds =
          exps.map((e) => e['restaurant_id']).where((r) => r != null).toList();

      final catCount = <String, int>{};
      final cities = <String>{};
      final restPerCity = <String, Set<String>>{};
      final expPerRest = <String, int>{};
      int photos = 0, preciseCount = 0, completeCount = 0;

      for (final e in exps) {
        final cat = (e['restaurant']?['category'] ?? '').toString().toLowerCase();
        for (final entry in _categoryKeywords.entries) {
          if (entry.value.any((k) => cat.contains(k.toLowerCase()))) {
            catCount[entry.key] = (catCount[entry.key] ?? 0) + 1;
          }
        }
        final city = (e['restaurant']?['city'] ?? '').toString().trim();
        final rid = e['restaurant_id']?.toString();
        if (city.isNotEmpty) {
          cities.add(city);
          if (rid != null) (restPerCity[city] ??= {}).add(rid);
        }
        if (rid != null) expPerRest[rid] = (expPerRest[rid] ?? 0) + 1;

        photos += (e['photos'] as List?)?.length ?? 0;

        const ratings = ['rating_food', 'rating_service', 'rating_ambiance',
            'rating_clean', 'rating_value'];
        final allRatings = ratings.every((f) => ((e[f] as num?) ?? 0) > 0);
        if (allRatings) preciseCount++;
        final allFields = allRatings &&
            (e['title']?.toString().trim().isNotEmpty ?? false) &&
            (e['description']?.toString().trim().isNotEmpty ?? false) &&
            ((e['photos'] as List?)?.isNotEmpty ?? false) &&
            (e['atmosphere']?.toString().trim().isNotEmpty ?? false) &&
            (e['price_range']?.toString().trim().isNotEmpty ?? false) &&
            (e['visit_time']?.toString().trim().isNotEmpty ?? false);
        if (allFields) completeCount++;
      }

      for (final key in _categoryKeywords.keys) {
        p[key] = (catCount[key] ?? 0) / 10.0;
      }
      p['traveler'] = cities.length / 3.0;
      p['explorer'] = cities.length / 5.0;
      final maxRestInCity =
          restPerCity.values.fold<int>(0, (m, s) => s.length > m ? s.length : m);
      p['city_explorer'] = maxRestInCity / 5.0;
      final maxSameRest =
          expPerRest.values.fold<int>(0, (m, c) => c > m ? c : m);
      p['loyal'] = maxSameRest / 3.0;
      p['camera_eye'] = photos / 50.0;
      p['precise_rater'] = preciseCount / 20.0;
      p['complete'] = completeCount / 20.0;

      // followers (social) — cheap single query
      final followers = await _db
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);
      p['social'] = (followers as List).length / 10.0;

      if (!full) return p;

      // ── Heavy: cross-table queries (achievements screen only) ─────────────
      if (expIds.isNotEmpty) {
        final likes = await _db
            .from('likes')
            .select('experience_id')
            .inFilter('experience_id', expIds);
        p['beloved'] = (likes as List).length / 100.0;

        final saves = await _db
            .from('saves')
            .select('user_id')
            .inFilter('experience_id', expIds);
        final savesList = saves as List;
        p['most_inspiring'] = savesList.length / 50.0;
        p['trusted_recommender'] =
            savesList.map((s) => s['user_id'].toString()).toSet().length / 10.0;
      }

      final myComments = await _db
          .from('comments')
          .select('experience:experiences(user_id)')
          .eq('user_id', userId);
      final onOthers = (myComments as List).where((c) {
        final ownerId = c['experience']?['user_id']?.toString();
        return ownerId != null && ownerId != userId;
      }).length;
      p['critic'] = onOthers / 30.0;

      final firstUsers = await _db
          .from('users')
          .select('id')
          .order('created_at', ascending: true)
          .limit(5);
      p['pioneer'] =
          (firstUsers as List).any((u) => u['id'].toString() == userId)
              ? 1.0
              : 0.0;

      if (restIds.isNotEmpty) {
        final all = await _db
            .from('experiences')
            .select('restaurant_id, user_id, created_at')
            .inFilter('restaurant_id', restIds)
            .order('created_at', ascending: true);
        final firstByRest = <String, String>{};
        for (final r in all as List) {
          final rid = r['restaurant_id']?.toString();
          if (rid != null && !firstByRest.containsKey(rid)) {
            firstByRest[rid] = r['user_id'].toString();
          }
        }
        p['first_reviewer'] = firstByRest.values.contains(userId) ? 1.0 : 0.0;
      }
    } catch (e) {
      debugPrint('[gamification] computeProgress error: $e');
    }
    return p;
  }
}
