import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditExperienceScreen extends StatefulWidget {
  final Map<String, dynamic> experience;
  const EditExperienceScreen({super.key, required this.experience});

  @override
  State<EditExperienceScreen> createState() => _EditExperienceScreenState();
}

class _EditExperienceScreenState extends State<EditExperienceScreen> {
  late List<double> _ratings;
  late final TextEditingController _descCtrl;
  late final TextEditingController _dishNameCtrl;
  late final TextEditingController _dishPriceCtrl;
  late List<Map<String, dynamic>> _dishes;
  bool _saving = false;

  static const _ratingLabels = [
    '🍽️ الطعام',
    '🤝 الخدمة',
    '🌅 الأجواء',
    '✨ النظافة',
    '💰 القيمة',
  ];
  static const _ratingKeys = [
    'rating_food',
    'rating_service',
    'rating_ambiance',
    'rating_clean',
    'rating_value',
  ];

  @override
  void initState() {
    super.initState();
    final exp = widget.experience;
    _ratings = _ratingKeys
        .map((k) => (exp[k] as num?)?.toDouble() ?? 0.0)
        .toList();
    _descCtrl = TextEditingController(text: exp['description'] ?? '');
    _dishNameCtrl = TextEditingController();
    _dishPriceCtrl = TextEditingController();
    _dishes = [];
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _dishNameCtrl.dispose();
    _dishPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDishes() async {
    if (_dishes.isNotEmpty) return;
    try {
      final res = await Supabase.instance.client
          .from('dishes')
          .select()
          .eq('experience_id', widget.experience['id']);
      if (mounted) {
        setState(() {
          _dishes = List<Map<String, dynamic>>.from(res)
              .map((d) => {'name': d['name'] ?? '', 'price': d['price_sar']?.toString() ?? ''})
              .toList();
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDishes();
  }

  Future<void> _save() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الوصف مطلوب')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final id = widget.experience['id'];
      final updateData = <String, dynamic>{
        'description': _descCtrl.text.trim(),
      };
      for (int i = 0; i < _ratingKeys.length; i++) {
        if (_ratings[i] > 0) updateData[_ratingKeys[i]] = _ratings[i];
      }
      await Supabase.instance.client
          .from('experiences')
          .update(updateData)
          .eq('id', id);

      await Supabase.instance.client.from('dishes').delete().eq('experience_id', id);
      if (_dishes.isNotEmpty) {
        await Supabase.instance.client.from('dishes').insert(_dishes
            .where((d) => (d['name'] as String).isNotEmpty)
            .map((d) => {
                  'experience_id': id,
                  'name': d['name'],
                  if ((d['price'] as String).isNotEmpty)
                    'price_sar': double.tryParse(d['price'] as String),
                })
            .toList());
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2340),
      body: Column(
        children: [
          // APP BAR
          Container(
            color: const Color(0xFF0F1628),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 12,
              left: 8,
              right: 16,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('تعديل التجربة',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                if (_saving)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                else
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF26500),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('حفظ',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),

          // BODY
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // RATINGS
                  const Text('⭐ التقييمات',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 12),
                  ...List.generate(_ratingLabels.length, (i) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_ratingLabels[i],
                                  style: const TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                              if (_ratings[i] > 0)
                                Text('${_ratings[i].toInt()}.0',
                                    style: const TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFC8931A))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (j) {
                              return GestureDetector(
                                onTap: () => setState(() => _ratings[i] = (j + 1).toDouble()),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text('★',
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: j < _ratings[i]
                                            ? const Color(0xFFC8931A)
                                            : Colors.white.withValues(alpha: 0.2),
                                      )),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // DISHES
                  const Text('🍽️ الأطباق',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 10),

                  ..._dishes.map((d) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text('🍽️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(d['name'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                        if ((d['price'] as String).isNotEmpty)
                          Text('${d['price']} ر.س',
                              style: const TextStyle(
                                  color: Color(0xFFF26500), fontWeight: FontWeight.w700, fontSize: 11)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _dishes.remove(d)),
                          child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 16),
                        ),
                      ],
                    ),
                  )),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: [
                        _input(controller: _dishNameCtrl, hint: 'اسم الطبق'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _input(
                                  controller: _dishPriceCtrl,
                                  hint: 'السعر (اختياري)',
                                  keyboardType: TextInputType.number),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                if (_dishNameCtrl.text.isNotEmpty) {
                                  setState(() {
                                    _dishes.add({
                                      'name': _dishNameCtrl.text.trim(),
                                      'price': _dishPriceCtrl.text.trim(),
                                    });
                                    _dishNameCtrl.clear();
                                    _dishPriceCtrl.clear();
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF26500),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // DESCRIPTION
                  const Text('✍️ وصف التجربة',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: TextField(
                      controller: _descCtrl,
                      maxLines: 5,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'شاركنا تجربتك...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
    );
  }
}
