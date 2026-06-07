import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'add_visit_screen.dart';
import 'widgets/visit_card.dart';

const _kDark = Color(0xFF0F1923);
const _kDark2 = Color(0xFF1A2340);
const _kOrange = Color(0xFFF26500);
const _kTextSec = Color(0xFF94A3B8);

const _visitSelect =
    '*, restaurant:restaurants(id, name_ar, cover_image, city), '
    'invites:visit_invites(*, invitee:users(id, display_name, username, avatar_url))';

TextStyle _tj(double size,
        {FontWeight weight = FontWeight.w400,
        Color color = Colors.white,
        double? height}) =>
    GoogleFonts.tajawal(
        fontSize: size, fontWeight: weight, color: color, height: height);

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  bool _listView = false; // false = calendar, true = upcoming list
  List<Map<String, dynamic>> _visits = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _date(Map<String, dynamic> v) {
    final d = DateTime.tryParse((v['visit_date'] ?? '').toString()) ??
        DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  List<Map<String, dynamic>> _visitsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _visits.where((v) => isSameDay(_date(v), key)).toList();
  }

  Future<void> _load() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final owned =
          await _client.from('visits').select(_visitSelect).eq('owner_id', me);
      final invited = await _client
          .from('visit_invites')
          .select('status, visit:visits($_visitSelect)')
          .eq('invitee_id', me)
          .eq('status', 'accepted');

      final byId = <dynamic, Map<String, dynamic>>{};
      for (final v in owned as List) {
        final m = Map<String, dynamic>.from(v);
        m['_isOwner'] = true;
        byId[m['id']] = m;
      }
      for (final row in invited as List) {
        final v = row['visit'];
        if (v is Map) {
          final m = Map<String, dynamic>.from(v);
          m['_isOwner'] = false;
          byId.putIfAbsent(m['id'], () => m);
        }
      }

      final list = byId.values.toList()
        ..sort((a, b) => _date(a).compareTo(_date(b)));
      if (mounted) {
        setState(() {
          _visits = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[visits] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddVisitScreen()),
    );
    _load();
  }

  List<Map<String, dynamic>> get _upcoming {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    return _visits.where((v) => !_date(v).isBefore(todayKey)).toList()
      ..sort((a, b) => _date(a).compareTo(_date(b)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kDark,
        floatingActionButton: FloatingActionButton(
          backgroundColor: _kOrange,
          onPressed: _openAdd,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
        body: Column(
          children: [
            _header(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kOrange))
                  : _listView
                      ? _buildList()
                      : _buildCalendar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
        color: _kDark2,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          bottom: 14,
          left: 16,
          right: 16,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child:
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Text('مواعيدي', style: _tj(17, weight: FontWeight.w900)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _listView = !_listView),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _listView
                      ? PhosphorIcons.calendarBlank()
                      : PhosphorIcons.listBullets(),
                  color: _kOrange,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildCalendar() {
    final dayVisits = _visitsForDay(_selectedDay ?? _focusedDay);
    return Column(
      children: [
        TableCalendar(
          locale: 'ar',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _focusedDay,
          startingDayOfWeek: StartingDayOfWeek.saturday,
          selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
          eventLoader: _visitsForDay,
          availableGestures: AvailableGestures.horizontalSwipe,
          onDaySelected: (selected, focused) => setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          }),
          onPageChanged: (focused) => _focusedDay = focused,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: _tj(15, weight: FontWeight.w800),
            leftChevronIcon: const Icon(Icons.chevron_left, color: _kTextSec),
            rightChevronIcon: const Icon(Icons.chevron_right, color: _kTextSec),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: _tj(11, color: _kTextSec),
            weekendStyle: _tj(11, color: _kTextSec),
          ),
          calendarStyle: CalendarStyle(
            defaultTextStyle: _tj(13),
            weekendTextStyle: _tj(13),
            outsideTextStyle: _tj(13, color: _kTextSec.withValues(alpha: 0.4)),
            todayDecoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: _kOrange,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: _tj(13, weight: FontWeight.w800),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              return Positioned(
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: _kOrange, shape: BoxShape.circle),
                ),
              );
            },
          ),
        ),
        Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
        Expanded(
          child: dayVisits.isEmpty
              ? _empty('لا مواعيد في هذا اليوم')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dayVisits.length,
                  itemBuilder: (_, i) => VisitCard(
                    visit: dayVisits[i],
                    isOwner: dayVisits[i]['_isOwner'] == true,
                    onChanged: _load,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final items = _upcoming;
    if (items.isEmpty) return _empty('لا مواعيد قادمة');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => VisitCard(
        visit: items[i],
        isOwner: items[i]['_isOwner'] == true,
        onChanged: _load,
      ),
    );
  }

  Widget _empty(String text) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.calendarX(),
                size: 52, color: _kTextSec.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(text, style: _tj(14, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('اضغط + لإضافة موعد جديد', style: _tj(12, color: _kTextSec)),
          ],
        ),
      );
}
