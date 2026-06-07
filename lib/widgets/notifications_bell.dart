import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../notifications_screen.dart';

const _kOrange = Color(0xFFF26500);

/// Top-bar bell with an unread dot. Self-manages its unread count (initial
/// fetch + realtime) and opens the notifications screen on tap.
class NotificationsBell extends StatefulWidget {
  final Color iconColor;
  final double size;

  /// When true, renders inside a 38×38 translucent rounded box (matches the
  /// profile screen's action buttons).
  final bool boxed;

  const NotificationsBell({
    super.key,
    this.iconColor = Colors.white,
    this.size = 22,
    this.boxed = false,
  });

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  final _client = Supabase.instance.client;
  int _unread = 0;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    try {
      final res = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', me)
          .eq('is_read', false);
      if (mounted) setState(() => _unread = (res as List).length);
    } catch (_) {}
  }

  void _subscribe() {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    _channel = _client
        .channel('bell_$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: me,
          ),
          callback: (_) {
            if (mounted) _load();
          },
        )
        .subscribe();
  }

  Future<void> _open() async {
    setState(() => _unread = 0); // optimistic — opening marks them read
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final Widget bell = widget.boxed
        ? Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(PhosphorIcons.bell(), color: widget.iconColor, size: 18),
          )
        : Icon(PhosphorIcons.bell(), color: widget.iconColor, size: widget.size);

    return GestureDetector(
      onTap: _open,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.all(widget.boxed ? 0 : 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            bell,
            if (_unread > 0)
              Positioned(
                top: widget.boxed ? 2 : -1,
                right: widget.boxed ? 2 : -1,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _kOrange,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF0F1923), width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
