import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../add_visit_screen.dart';
import '../utils/date_format_ar.dart';
import 'app_avatar.dart';
import 'app_placeholder.dart';

const _kOrange = Color(0xFFF26500);
const _kCardBg = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kAmber = Color(0xFFC8931A);

TextStyle _tj(double size,
        {FontWeight weight = FontWeight.w400,
        Color color = Colors.white,
        double? height}) =>
    GoogleFonts.tajawal(
        fontSize: size, fontWeight: weight, color: color, height: height);

/// A single visit card. [isOwner] true → edit/delete; false → accept/decline.
class VisitCard extends StatefulWidget {
  final Map<String, dynamic> visit;
  final bool isOwner;
  final VoidCallback onChanged;

  const VisitCard({
    super.key,
    required this.visit,
    required this.isOwner,
    required this.onChanged,
  });

  @override
  State<VisitCard> createState() => _VisitCardState();
}

class _VisitCardState extends State<VisitCard> {
  final _client = Supabase.instance.client;
  bool _busy = false;

  Map<String, dynamic> get _visit => widget.visit;

  List<Map<String, dynamic>> get _invites =>
      (_visit['invites'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

  Map<String, dynamic>? get _myInvite {
    final me = _client.auth.currentUser?.id;
    if (me == null) return null;
    for (final inv in _invites) {
      if (inv['invitee_id']?.toString() == me) return inv;
    }
    return null;
  }

  Future<void> _respond(String status) async {
    final me = _client.auth.currentUser?.id;
    if (me == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _client.from('visit_invites').update({
        'status': status,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('visit_id', _visit['id']).eq('invitee_id', me);
      widget.onChanged();
    } catch (e) {
      debugPrint('[visit_card] respond error: $e');
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر الإرسال', style: GoogleFonts.tajawal())),
        );
      }
    }
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddVisitScreen(existingVisit: _visit)),
    );
    widget.onChanged();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _kCardBg,
          title: Text('حذف الموعد', style: _tj(16, weight: FontWeight.w900)),
          content: Text('هل تريد حذف هذا الموعد؟',
              style: _tj(13, color: _kTextSec)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: _tj(13, color: _kTextSec)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('حذف', style: _tj(13, weight: FontWeight.w800, color: _kRed)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || _busy) return;
    setState(() => _busy = true);
    try {
      // Remove invites first (safe even when an ON DELETE CASCADE exists).
      await _client.from('visit_invites').delete().eq('visit_id', _visit['id']);
      await _client.from('visits').delete().eq('id', _visit['id']);
      widget.onChanged();
    } catch (e) {
      debugPrint('[visit_card] delete error: $e');
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر الحذف', style: GoogleFonts.tajawal())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rest = _visit['restaurant'] as Map<String, dynamic>?;
    final name = rest?['name_ar']?.toString() ?? 'مطعم';
    final cover = rest?['cover_image']?.toString();
    final dateLabel = formatVisitDateStrAr(_visit['visit_date']?.toString());
    final timeLabel = formatVisitTimeAr(_visit['visit_time']?.toString());
    final note = _visit['note']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: (cover != null && cover.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              AppPlaceholder(name: name, borderRadius: 0),
                        )
                      : AppPlaceholder(name: name, borderRadius: 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: _tj(14, weight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(PhosphorIcons.calendarBlank(),
                            size: 13, color: _kOrange),
                        const SizedBox(width: 5),
                        Text(dateLabel, style: _tj(12, color: Colors.white)),
                        if (timeLabel != null) ...[
                          const SizedBox(width: 10),
                          Icon(PhosphorIcons.clock(), size: 13, color: _kOrange),
                          const SizedBox(width: 5),
                          Text(timeLabel, style: _tj(12, color: Colors.white)),
                        ],
                      ],
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(note,
                          style: _tj(11, color: _kTextSec, height: 1.4),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_invites.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
            const SizedBox(height: 10),
            _inviteesRow(),
          ],
          const SizedBox(height: 12),
          _actions(),
        ],
      ),
    );
  }

  Widget _inviteesRow() {
    final shown = _invites.take(3).toList();
    final extra = _invites.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final inv in shown)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: AppAvatar(
                  displayName: (inv['invitee']?['display_name'] ?? '').toString(),
                  username: (inv['invitee']?['username'] ?? '').toString(),
                  avatarUrl: inv['invitee']?['avatar_url']?.toString(),
                  size: 30,
                ),
              ),
            if (extra > 0)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('+$extra',
                    style: _tj(12, weight: FontWeight.w800, color: _kTextSec)),
              ),
          ],
        ),
        // Owner sees each invitee's response status.
        if (widget.isOwner) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final inv in _invites)
                _statusChip(
                  (inv['invitee']?['display_name'] ?? 'صديق').toString(),
                  inv['status']?.toString() ?? 'pending',
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _statusChip(String name, String status) {
    final (label, color) = switch (status) {
      'accepted' => ('قبل', _kGreen),
      'declined' => ('اعتذر', _kRed),
      _ => ('بانتظار الرد', _kAmber),
    };
    final first = name.split(' ').first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$first · $label',
          style: _tj(10, weight: FontWeight.w700, color: color)),
    );
  }

  Widget _actions() {
    if (widget.isOwner) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _smallBtn('تعديل', PhosphorIcons.pencilSimple(), _kTextSec, _edit),
          const SizedBox(width: 8),
          _smallBtn('حذف', PhosphorIcons.trash(), _kRed, _delete),
        ],
      );
    }
    final status = _myInvite?['status']?.toString();
    if (status == 'pending') {
      return Row(
        children: [
          Expanded(child: _respondBtn('قبول', _kGreen, filled: true,
              onTap: () => _respond('accepted'))),
          const SizedBox(width: 8),
          Expanded(child: _respondBtn('رفض', _kRed, filled: false,
              onTap: () => _respond('declined'))),
        ],
      );
    }
    final (label, color) = switch (status) {
      'accepted' => ('قبلت الدعوة', _kGreen),
      'declined' => ('اعتذرت', _kRed),
      _ => ('—', _kTextSec),
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(label, style: _tj(12, weight: FontWeight.w700, color: color)),
    );
  }

  Widget _smallBtn(String label, IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: _busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label, style: _tj(12, weight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      );

  Widget _respondBtn(String label, Color color,
          {required bool filled, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: _busy ? null : onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.2),
          ),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: _tj(13,
                      weight: FontWeight.w800,
                      color: filled ? Colors.white : color)),
        ),
      );
}
