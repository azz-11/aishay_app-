import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExperienceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> experience;
  final VoidCallback? onClose;
  const ExperienceDetailScreen({super.key, required this.experience, this.onClose});

  @override
  State<ExperienceDetailScreen> createState() => _ExperienceDetailScreenState();
}

class _ExperienceDetailScreenState extends State<ExperienceDetailScreen> {
  List<Map<String, dynamic>> _dishes = [];
  bool _liked = false;
  bool _saved = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDishes();
    _likesCount = widget.experience['likes_count'] ?? 0;
  }

  Future<void> _loadDishes() async {
    try {
      final res = await Supabase.instance.client
          .from('dishes')
          .select()
          .eq('experience_id', widget.experience['id']);
      setState(() => _dishes = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    try {
      if (_liked) {
        await Supabase.instance.client.from('likes').insert({
          'user_id': user.id,
          'experience_id': widget.experience['id'],
        });
      } else {
        await Supabase.instance.client
            .from('likes')
            .delete()
            .eq('user_id', user.id)
            .eq('experience_id', widget.experience['id']);
      }
    } catch (_) {}
  }

  double get _avgRating {
    final fields = ['rating_food', 'rating_service', 'rating_ambiance', 'rating_clean', 'rating_value'];
    final vals = fields
        .map((f) => (widget.experience[f] as num?)?.toDouble() ?? 0.0)
        .where((v) => v > 0)
        .toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  String _stars(double r) {
    final full = r.round();
    return '${'★' * full}${'☆' * (5 - full)}';
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.experience;
    final restName = exp['restaurant']?['name_ar'] ?? 'مطعم';
    final city = exp['restaurant']?['city'] ?? '';
    final userName = exp['user']?['display_name'] ?? 'مستخدم';
    final photos = exp['photos'] as List? ?? [];
    final rating = _avgRating;

    return Material(
      color: const Color(0xFFFAF5EE),
      child: Column(
        children: [
          // APP BAR
          Container(
            color: const Color(0xFF1A2340),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 8,
              left: 8,
              right: 16,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(restName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),

          // BODY
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HERO IMAGE - Gallery
if (photos.isNotEmpty)
  SizedBox(
    height: MediaQuery.of(context).size.width * (5 / 4),
    child: Stack(
      children: [
        PageView.builder(
          itemCount: photos.length,
          itemBuilder: (context, index) => Image.network(
            photos[index],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
        ),
        if (photos.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                photos.length,
                (i) => Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  )
else
  SizedBox(
    height: MediaQuery.of(context).size.width * (5 / 4),
    child: _placeholder(),
  ),

                  // INFO CARD
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFF26500),
                              child: Text(
                                userName.isNotEmpty ? userName[0] : 'م',
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(userName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(restName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E))),
                        if (city.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('📍 $city', style: const TextStyle(fontSize: 12, color: Color(0xFF7A6655))),
                        ],
                        const SizedBox(height: 8),
                        if (rating > 0)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2340),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(rating.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFF5D485))),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_stars(rating),
                                        style: const TextStyle(fontSize: 14, color: Color(0xFFF5D485))),
                                    const SizedBox(height: 2),
                                    Text('🔥 $_likesCount يستاهل الزيارة',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFFFFB347), fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // DETAILED RATINGS
                  if (rating > 0)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('⭐ التقييمات التفصيلية',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 12),
                          ...[
                            ['🍽️ الطعام', 'rating_food'],
                            ['🤝 الخدمة', 'rating_service'],
                            ['🌅 الأجواء', 'rating_ambiance'],
                            ['✨ النظافة', 'rating_clean'],
                            ['💰 القيمة', 'rating_value'],
                          ].map((r) {
                            final val = (exp[r[1]] as num?)?.toDouble() ?? 0;
                            if (val == 0) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(width: 80,
                                      child: Text(r[0], style: const TextStyle(fontSize: 11, color: Color(0xFF7A6655)))),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: val / 5,
                                        backgroundColor: const Color(0xFFE4D9CE),
                                        valueColor: const AlwaysStoppedAnimation(Color(0xFFC8931A)),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(val.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // DESCRIPTION
                  if (exp['description'] != null)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('✍️ وصف التجربة',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 8),
            Text(
  exp['description'].toString().trim(),
  style: const TextStyle(
    fontSize: 14,
    color: Color(0xFF7A6655),
    height: 1.8,
  ),
  textAlign: TextAlign.right,
  textDirection: TextDirection.rtl,
),
        ],
      ),
    ),

                  const SizedBox(height: 8),

                  // DISHES
                  if (_dishes.isNotEmpty)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🍽️ الأطباق المطلوبة',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 10),
                          ..._dishes.map((d) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5EE),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE4D9CE)),
                            ),
                            child: Row(
                              children: [
                                const Text('🍽️', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Expanded(child: Text(d['name'] ?? '',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)))),
                                if (d['price_sar'] != null)
                                  Text('${d['price_sar']} ر.س',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFF26500))),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // BOTTOM ACTIONS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE4D9CE))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _toggleLike,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _liked ? const Color(0xFFF26500) : const Color(0xFFFEF0E6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF26500).withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Text(
                          '🔥 يستاهل · $_likesCount',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: _liked ? Colors.white : const Color(0xFFF26500)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => setState(() => _saved = !_saved),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _saved ? const Color(0xFF1A2340) : const Color(0xFFFAF5EE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE4D9CE)),
                    ),
                    child: Text('📍 أود زيارته',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: _saved ? Colors.white : const Color(0xFF1A1A2E))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1A2340), Color(0xFF2A3A5C)],
      ),
    ),
    child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 60))),
  );
}