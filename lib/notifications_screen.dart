import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'experience_detail_screen.dart';
import 'user_profile_screen.dart';
import 'l10n/app_strings.dart';
import 'utils/date_format_ar.dart';
import 'widgets/app_avatar.dart';

const _kDark = Color(0xFF0F1923);
const _kDark2 = Color(0xFF1A2340);
const _kCardBg = Color(0xFF1E2D45);
const _kOrange = Color(0xFFF26500);
const _kTextSec = Color(0xFF94A3B8);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _realtimeChannel = Supabase.instance.client
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (mounted) _loadNotifications();
          },
        )
        .subscribe();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      final notifications = List<Map<String, dynamic>>.from(res);

      // Batch-fetch from_user details
      final fromIds = notifications
          .map((n) => n['from_user_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      if (fromIds.isNotEmpty) {
        final usersRes = await Supabase.instance.client
            .from('users')
            .select('id, display_name, username, avatar_url')
            .inFilter('id', fromIds);
        final usersMap = <String, Map<String, dynamic>>{};
        for (final u in usersRes as List) {
          usersMap[u['id'].toString()] = Map<String, dynamic>.from(u);
        }
        for (final n in notifications) {
          final fid = n['from_user_id'] as String?;
          if (fid != null) n['from_user'] = usersMap[fid];
        }
      }

      // Batch-fetch experience + restaurant names
      final expIds = notifications
          .map((n) => n['experience_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (expIds.isNotEmpty) {
        final expRes = await Supabase.instance.client
            .from('experiences')
            .select('id, restaurant:restaurants(name_ar)')
            .inFilter('id', expIds);
        final expMap = <dynamic, String>{};
        for (final e in expRes as List) {
          final rest = e['restaurant'];
          final name = rest is Map ? rest['name_ar'] as String? : null;
          if (name != null) expMap[e['id']] = name;
        }
        for (final n in notifications) {
          final eid = n['experience_id'];
          if (eid != null && expMap.containsKey(eid)) {
            n['restaurant_name'] = expMap[eid];
          }
        }
      }

      // Batch-fetch visit details (restaurant + date + my response) for invites.
      final visitIds = notifications
          .where((n) => n['type'] == 'visit_invite')
          .map((n) => n['visit_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (visitIds.isNotEmpty) {
        final visitsRes = await Supabase.instance.client
            .from('visits')
            .select('id, visit_date, restaurant:restaurants(name_ar)')
            .inFilter('id', visitIds);
        final invitesRes = await Supabase.instance.client
            .from('visit_invites')
            .select('visit_id, status')
            .eq('invitee_id', user.id)
            .inFilter('visit_id', visitIds);

        final visitMap = <dynamic, Map<String, dynamic>>{};
        for (final v in visitsRes as List) {
          visitMap[v['id']] = Map<String, dynamic>.from(v);
        }
        final statusMap = <dynamic, String>{};
        for (final inv in invitesRes as List) {
          statusMap[inv['visit_id']] = inv['status']?.toString() ?? 'pending';
        }
        for (final n in notifications) {
          final vid = n['visit_id'];
          if (vid != null && visitMap.containsKey(vid)) {
            final v = visitMap[vid]!;
            n['visit_restaurant'] = v['restaurant']?['name_ar']?.toString();
            n['visit_date_label'] = formatVisitDateStrAr(v['visit_date']?.toString());
            n['visit_status'] = statusMap[vid] ?? 'pending';
          }
        }
      }

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _loading = false;
        });
      }

      // Mark all unread as read
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.loadNotificationsFailed}: $e')),
        );
      }
    }
  }

  Future<void> _onTapNotification(Map<String, dynamic> notif) async {
    final type = notif['type'] as String?;
    final experienceId = notif['experience_id'];
    final fromUserId = notif['from_user_id'] as String?;

    // Mark as read (locally + remotely)
    final notifId = notif['id'];
    if (notifId != null && notif['is_read'] != true) {
      if (mounted) setState(() => notif['is_read'] = true);
      try {
        await Supabase.instance.client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notifId);
      } catch (e) {
        debugPrint('Mark read error: $e');
      }
    }

    if (type == 'like' || type == 'save' || type == 'comment') {
      if (experienceId == null) return;
      try {
        final exp = await Supabase.instance.client
            .from('experiences')
            .select('*, restaurant:restaurants(*), user:users!experiences_user_id_fkey(display_name, username, avatar_url)')
            .eq('id', experienceId)
            .single();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExperienceDetailScreen(
                experience: Map<String, dynamic>.from(exp),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.cantOpenExperience, style: GoogleFonts.tajawal()),
            ),
          );
        }
      }
    } else if (type == 'follow') {
      if (fromUserId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: fromUserId),
          ),
        );
      }
    }
  }

  String _typeText(String type, String? restaurantName) {
    final rest = restaurantName != null
        ? (AppStrings.isArabic ? ' في $restaurantName' : ' at $restaurantName')
        : '';
    switch (type) {
      case 'like':    return '${AppStrings.likedExperience}$rest 🔥';
      case 'comment': return '${AppStrings.commentedOn}$rest 💬';
      case 'save':    return '${AppStrings.savedExperience}$rest 📍';
      case 'follow':  return '${AppStrings.startedFollowing} 👤';
      default:        return AppStrings.isArabic
          ? 'تفاعل مع تجربتك$rest'
          : 'interacted with your experience$rest';
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return AppStrings.justNow;
    if (diff.inMinutes < 60) return AppStrings.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return AppStrings.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return AppStrings.daysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      body: Column(
        children: [
          Container(
            color: _kDark2,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppStrings.notificationsTitle,
                    style: GoogleFonts.tajawal(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                GestureDetector(
                  onTap: _loadNotifications,
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white54, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kOrange))
                : _notifications.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: _kOrange,
                        backgroundColor: _kDark2,
                        onRefresh: _loadNotifications,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          itemCount: _notifications.length,
                          itemBuilder: (_, i) => _buildItem(_notifications[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kCardBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                color: _kTextSec, size: 34),
          ),
          const SizedBox(height: 16),
          Text(AppStrings.noNotifications,
              style: GoogleFonts.tajawal(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text(AppStrings.notificationsHint,
              style: GoogleFonts.tajawal(fontSize: 12, color: _kTextSec),
              textAlign: TextAlign.center),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _loadNotifications,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: _kOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(AppStrings.refresh,
                  style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> notif) {
    final fromUser = notif['from_user'] as Map<String, dynamic>?;
    final name = fromUser?['display_name'] as String? ?? 'مستخدم';
    final avatar = fromUser?['avatar_url'] as String?;
    final isRead = notif['is_read'] == true;
    final type = notif['type'] as String? ?? '';
    final restaurantName = notif['restaurant_name'] as String?;
    final time = _timeAgo(notif['created_at'] as String?);
    final isVisit = type == 'visit_invite';
    final visitStatus = notif['visit_status'] as String?;
    final bodyText = isVisit
        ? 'دعاك لزيارة ${notif['visit_restaurant'] ?? 'مطعم'} يوم ${notif['visit_date_label'] ?? ''}'
        : _typeText(type, restaurantName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTapNotification(notif),
        child: Container(
        decoration: BoxDecoration(
          color: isRead ? _kCardBg : _kCardBg.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          border: isRead
              ? Border.all(color: Colors.white.withValues(alpha: 0.05))
              : Border.all(color: _kOrange.withValues(alpha: 0.35), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Unread dot
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: isRead ? Colors.transparent : _kOrange,
                shape: BoxShape.circle,
              ),
            ),
            // Avatar
            AppAvatar(
              displayName: name,
              username: (fromUser?['username'] ?? '').toString(),
              avatarUrl: avatar,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Directionality(
                textDirection:
                    AppStrings.isArabic ? TextDirection.rtl : TextDirection.ltr,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.5),
                        children: [
                          TextSpan(
                              text: name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                          const TextSpan(text: '  '),
                          TextSpan(
                              text: bodyText,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(time,
                        style: GoogleFonts.tajawal(
                            fontSize: 11, color: _kTextSec)),
                    if (isVisit && visitStatus == 'pending') ...[
                      const SizedBox(height: 10),
                      _inviteButtons(notif),
                    ] else if (isVisit && visitStatus != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        visitStatus == 'accepted' ? 'قبلت الدعوة ✓' : 'اعتذرت',
                        style: GoogleFonts.tajawal(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: visitStatus == 'accepted'
                                ? const Color(0xFF22C55E)
                                : _kTextSec),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _inviteButtons(Map<String, dynamic> notif) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _respondInvite(notif, 'accepted'),
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('قبول',
                  style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => _respondInvite(notif, 'declined'),
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
              ),
              child: Text('رفض',
                  style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFEF4444))),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _respondInvite(Map<String, dynamic> notif, String status) async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final visitId = notif['visit_id'];
    if (me == null || visitId == null) return;
    final prev = notif['visit_status'];
    setState(() => notif['visit_status'] = status); // optimistic
    try {
      await Supabase.instance.client.from('visit_invites').update({
        'status': status,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('visit_id', visitId).eq('invitee_id', me);
    } catch (e) {
      debugPrint('[notifications] respond error: $e');
      if (mounted) {
        setState(() => notif['visit_status'] = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر الإرسال', style: GoogleFonts.tajawal())),
        );
      }
    }
  }
}
