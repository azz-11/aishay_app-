import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/date_format_ar.dart';
import 'widgets/app_avatar.dart';
import 'widgets/app_placeholder.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

class AddVisitScreen extends StatefulWidget {
  /// Pre-fill the restaurant (e.g. opened from an experience card).
  final Map<String, dynamic>? restaurant;

  /// When set, the screen edits an existing visit instead of creating one.
  final Map<String, dynamic>? existingVisit;

  const AddVisitScreen({super.key, this.restaurant, this.existingVisit});

  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  final _client = Supabase.instance.client;
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  Map<String, dynamic>? _restaurant;
  DateTime? _date;
  TimeOfDay? _time;

  List<Map<String, dynamic>> _savedRestaurants = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  List<Map<String, dynamic>> _follows = [];
  final Set<String> _invitees = {};

  // Invitees already on the visit (edit mode) — used to diff on save.
  final Set<String> _originalInvitees = {};
  bool _saving = false;

  bool get _isEdit => widget.existingVisit != null;

  @override
  void initState() {
    super.initState();
    final ev = widget.existingVisit;
    if (ev != null) {
      _restaurant = ev['restaurant'] as Map<String, dynamic>?;
      final d = DateTime.tryParse(ev['visit_date']?.toString() ?? '');
      if (d != null) _date = DateTime(d.year, d.month, d.day);
      _time = _parseTime(ev['visit_time']?.toString());
      _noteCtrl.text = ev['note']?.toString() ?? '';
      for (final inv in (ev['invites'] as List? ?? const [])) {
        final id = inv['invitee_id']?.toString();
        if (id != null) {
          _invitees.add(id);
          _originalInvitees.add(id);
        }
      }
    } else {
      _restaurant = widget.restaurant;
    }
    _loadSavedRestaurants();
    _loadFollows();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final p = raw.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _loadSavedRestaurants() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    try {
      final res = await _client
          .from('saves')
          .select(
              'experience:experiences(restaurant:restaurants(id, name_ar, city, cover_image))')
          .eq('user_id', me);
      final byId = <dynamic, Map<String, dynamic>>{};
      for (final row in res as List) {
        final rest = row['experience']?['restaurant'];
        if (rest is Map && rest['id'] != null) {
          byId[rest['id']] = Map<String, dynamic>.from(rest);
        }
      }
      if (mounted) setState(() => _savedRestaurants = byId.values.toList());
    } catch (e) {
      debugPrint('[add_visit] saved restaurants error: $e');
    }
  }

  Future<void> _loadFollows() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    try {
      final f = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', me);
      final ids =
          (f as List).map((r) => r['following_id']).whereType<Object>().toList();
      if (ids.isEmpty) return;
      final users = await _client
          .from('users')
          .select('id, display_name, username, avatar_url')
          .inFilter('id', ids);
      if (mounted) {
        setState(() =>
            _follows = List<Map<String, dynamic>>.from(users as List));
      }
    } catch (e) {
      debugPrint('[add_visit] follows error: $e');
    }
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await _client
          .from('restaurants')
          .select('id, name_ar, city, cover_image')
          .ilike('name_ar', '%$q%')
          .limit(20);
      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(res as List);
          _searching = false;
        });
      }
    } catch (e) {
      debugPrint('[add_visit] search error: $e');
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kOrange,
            surface: _kCardBg,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kOrange,
            surface: _kCardBg,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final me = _client.auth.currentUser?.id;
    if (me == null || _saving) return;
    if (_restaurant == null || _date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('اختر المطعم والتاريخ', style: GoogleFonts.tajawal())),
      );
      return;
    }
    setState(() => _saving = true);
    final note = _noteCtrl.text.trim();
    final payload = {
      'restaurant_id': _restaurant!['id'],
      'visit_date': _fmtDate(_date!),
      'visit_time': _time != null
          ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}:00'
          : null,
      'note': note.isEmpty ? null : note,
    };

    try {
      String visitId;
      if (_isEdit) {
        visitId = widget.existingVisit!['id'].toString();
        await _client.from('visits').update(payload).eq('id', visitId);
      } else {
        final row = await _client
            .from('visits')
            .insert({...payload, 'owner_id': me})
            .select()
            .single();
        visitId = row['id'].toString();
      }

      // Diff invitees (in create mode _originalInvitees is empty → all are new).
      final toAdd = _invitees.difference(_originalInvitees);
      final toRemove = _originalInvitees.difference(_invitees);

      if (toAdd.isNotEmpty) {
        await _client.from('visit_invites').insert([
          for (final uid in toAdd)
            {'visit_id': visitId, 'invitee_id': uid, 'status': 'pending'},
        ]);
        await _client.from('notifications').insert([
          for (final uid in toAdd)
            {
              'user_id': uid,
              'from_user_id': me,
              'type': 'visit_invite',
              'visit_id': visitId,
              'is_read': false,
            },
        ]);
      }
      if (toRemove.isNotEmpty) {
        await _client
            .from('visit_invites')
            .delete()
            .eq('visit_id', visitId)
            .inFilter('invitee_id', toRemove.toList());
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[add_visit] save error: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('تعذّر الحفظ، حاول مجددًا', style: GoogleFonts.tajawal())),
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
        appBar: AppBar(
          backgroundColor: _kDark2,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(_isEdit ? 'تعديل الموعد' : 'موعد جديد',
              style: _tj(17, weight: FontWeight.w900)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _label('المطعم'),
            const SizedBox(height: 8),
            _restaurantPicker(),
            const SizedBox(height: 22),
            _label('التاريخ'),
            const SizedBox(height: 8),
            _pickerTile(
              icon: PhosphorIcons.calendarBlank(),
              text: _date != null ? formatVisitDateAr(_date!) : 'اختر التاريخ',
              filled: _date != null,
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            _label('الوقت (اختياري)'),
            const SizedBox(height: 8),
            _pickerTile(
              icon: PhosphorIcons.clock(),
              text: _time != null
                  ? _time!.format(context)
                  : 'اختر الوقت',
              filled: _time != null,
              onTap: _pickTime,
              onClear: _time != null ? () => setState(() => _time = null) : null,
            ),
            const SizedBox(height: 22),
            _label('ملاحظة (اختياري)'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _noteCtrl,
                maxLength: 200,
                maxLines: 3,
                style: _tj(13),
                decoration: InputDecoration(
                  hintText: 'مثال: نجتمع الساعة ٨ عند المدخل',
                  hintStyle: _tj(12, color: _kTextSec),
                  border: InputBorder.none,
                  counterStyle: _tj(10, color: _kTextSec),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 22),
            _label('دعوة أصدقاء (اختياري)'),
            const SizedBox(height: 8),
            _friendsList(),
            const SizedBox(height: 90),
          ],
        ),
        bottomSheet: _saveBar(),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: _tj(13, weight: FontWeight.w800));

  Widget _restaurantPicker() {
    if (_restaurant != null) {
      final name = _restaurant!['name_ar']?.toString() ?? 'مطعم';
      final cover = _restaurant!['cover_image']?.toString();
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kOrange.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: (cover != null && cover.isNotEmpty)
                    ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
                    : AppPlaceholder(name: name, borderRadius: 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(name,
                    style: _tj(14, weight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            TextButton(
              onPressed: () => setState(() => _restaurant = null),
              child: Text('تغيير',
                  style: _tj(12, weight: FontWeight.w700, color: _kOrange)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_savedRestaurants.isNotEmpty) ...[
          Text('من قائمة "أود زيارته"',
              style: _tj(11, color: _kTextSec)),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _savedRestaurants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final r = _savedRestaurants[i];
                return GestureDetector(
                  onTap: () => setState(() => _restaurant = r),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(r['name_ar']?.toString() ?? 'مطعم',
                        style: _tj(12, weight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: _tj(13),
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'ابحث عن مطعم...',
              hintStyle: _tj(12, color: _kTextSec),
              prefixIcon: const Icon(Icons.search, color: _kTextSec, size: 20),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            ),
          ),
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator(color: _kOrange)),
          ),
        for (final r in _searchResults)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(r['name_ar']?.toString() ?? 'مطعم', style: _tj(13)),
            subtitle: r['city'] != null
                ? Text(r['city'].toString(), style: _tj(11, color: _kTextSec))
                : null,
            onTap: () => setState(() {
              _restaurant = r;
              _searchResults = [];
              _searchCtrl.clear();
            }),
          ),
      ],
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String text,
    required bool filled,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _kOrange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: _tj(13,
                        weight: filled ? FontWeight.w700 : FontWeight.w400,
                        color: filled ? Colors.white : _kTextSec)),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 16, color: _kTextSec),
                ),
            ],
          ),
        ),
      );

  Widget _friendsList() {
    if (_follows.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text('لا تتابع أحدًا بعد',
            style: _tj(12, color: _kTextSec), textAlign: TextAlign.center),
      );
    }
    return Column(
      children: [
        for (final u in _follows) _friendTile(u),
      ],
    );
  }

  Widget _friendTile(Map<String, dynamic> u) {
    final id = u['id'].toString();
    final selected = _invitees.contains(id);
    final name = u['display_name']?.toString() ?? 'مستخدم';
    return GestureDetector(
      onTap: () => setState(() {
        if (!_invitees.add(id)) _invitees.remove(id);
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kOrange.withValues(alpha: 0.15) : _kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _kOrange
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            AppAvatar(
              displayName: name,
              username: (u['username'] ?? '').toString(),
              avatarUrl: u['avatar_url']?.toString(),
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(name,
                    style: _tj(13, weight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? _kOrange : _kTextSec,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveBar() => Container(
        color: _kDark2,
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: GestureDetector(
          onTap: _saving ? null : _save,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_kOrange, Color(0xFFFF7A1A)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(_isEdit ? 'حفظ التعديلات' : 'حفظ الموعد',
                    style: _tj(15, weight: FontWeight.w800)),
          ),
        ),
      );
}
