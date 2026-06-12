import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/app_avatar.dart';

const _cDark    = Color(0xFF0F1923);
const _cDark2   = Color(0xFF1A2340);
const _cOrange  = Color(0xFFF26500);
const _cTextSec = Color(0xFF94A3B8);

TextStyle _ct(double size,
    {FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
    double height = 1.0}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color, height: height);

class CommentsSection extends StatefulWidget {
  final String experienceId;
  final String? experienceOwnerId;
  const CommentsSection({super.key, required this.experienceId, this.experienceOwnerId});

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _inputFocused = false;
  String? _replyingToId; // top-level parent_comment_id to attach to
  String? _replyingToName; // name shown in the "ترد على …" chip

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _inputFocused = _focusNode.hasFocus);
    });
    _loadComments();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final client = Supabase.instance.client;
      final me = client.auth.currentUser?.id;

      final res = await client
          .from('comments')
          .select('*, user:users(display_name, username, avatar_url)')
          .eq('experience_id', widget.experienceId)
          .order('created_at', ascending: true);
      final all = List<Map<String, dynamic>>.from(res);

      // One batched like query for ALL comments (no N+1).
      if (all.isNotEmpty) {
        final ids = all.map((c) => c['id'].toString()).toList();
        final likes = await client
            .from('comment_likes')
            .select('comment_id, user_id')
            .inFilter('comment_id', ids);
        final counts = <String, int>{};
        final mine = <String>{};
        for (final l in likes as List) {
          final cid = l['comment_id'].toString();
          counts[cid] = (counts[cid] ?? 0) + 1;
          if (me != null && l['user_id'].toString() == me) mine.add(cid);
        }
        for (final c in all) {
          final cid = c['id'].toString();
          c['like_count'] = counts[cid] ?? 0;
          c['liked_by_me'] = mine.contains(cid);
        }
      }

      if (mounted) {
        setState(() {
          _comments = all;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Top-level comments (no parent) and the replies grouped under each parent.
  List<Map<String, dynamic>> get _topLevel =>
      _comments.where((c) => c['parent_comment_id'] == null).toList();

  List<Map<String, dynamic>> _repliesOf(String parentId) => _comments
      .where((c) => c['parent_comment_id']?.toString() == parentId)
      .toList();

  Future<void> _toggleCommentLike(Map<String, dynamic> comment) async {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser?.id;
    if (me == null) return;
    final cid = comment['id'].toString();
    final wasLiked = comment['liked_by_me'] == true;
    final prevCount = (comment['like_count'] ?? 0) as int;

    setState(() {
      comment['liked_by_me'] = !wasLiked;
      comment['like_count'] = wasLiked ? prevCount - 1 : prevCount + 1;
    });

    try {
      if (wasLiked) {
        await client
            .from('comment_likes')
            .delete()
            .eq('comment_id', cid)
            .eq('user_id', me);
      } else {
        await client
            .from('comment_likes')
            .insert({'comment_id': cid, 'user_id': me});
      }
    } catch (e) {
      debugPrint('[comments] like toggle error: $e');
      if (mounted) {
        setState(() {
          comment['liked_by_me'] = wasLiked;
          comment['like_count'] = prevCount;
        });
      }
    }
  }

  void _startReply(Map<String, dynamic> comment) {
    // One level deep: replying to a reply attaches to its top-level parent,
    // but the chip shows whoever you tapped رد on.
    final parentId =
        comment['parent_comment_id']?.toString() ?? comment['id'].toString();
    setState(() {
      _replyingToId = parentId;
      _replyingToName = (comment['user']?['display_name'] ?? 'مستخدم').toString();
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() => setState(() {
        _replyingToId = null;
        _replyingToName = null;
      });

  Future<void> _sendComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    final parentId = _replyingToId; // capture before clearing

    setState(() => _sending = true);
    try {
      final res = await client
          .from('comments')
          .insert({
            'experience_id': widget.experienceId,
            'user_id': user.id,
            'content': text,
            if (parentId != null) 'parent_comment_id': parentId,
          })
          .select('*, user:users(display_name, username, avatar_url)')
          .single();

      final inserted = Map<String, dynamic>.from(res)
        ..['like_count'] = 0
        ..['liked_by_me'] = false;

      if (mounted) {
        setState(() {
          _comments.add(inserted);
          _sending = false;
          _replyingToId = null;
          _replyingToName = null;
        });
        _ctrl.clear();
        _focusNode.unfocus();
      }

      if (parentId != null) {
        // Reply → notify the PARENT comment's author.
        final parent = _comments.firstWhere(
          (c) => c['id'].toString() == parentId,
          orElse: () => <String, dynamic>{},
        );
        final parentAuthor = parent['user_id']?.toString();
        if (parentAuthor != null && parentAuthor != user.id) {
          try {
            await client.from('notifications').insert({
              'user_id': parentAuthor,
              'from_user_id': user.id,
              'type': 'comment_reply',
              'experience_id': widget.experienceId,
              'is_read': false,
            });
          } catch (e) {
            debugPrint('Notification insert error (reply): $e');
          }
        }
      } else {
        // Top-level comment → notify the experience owner (existing behavior).
        final ownerId = widget.experienceOwnerId;
        if (ownerId != null && ownerId != user.id) {
          try {
            await client.from('notifications').insert({
              'user_id': ownerId,
              'from_user_id': user.id,
              'type': 'comment',
              'experience_id': widget.experienceId,
              'is_read': false,
            });
          } catch (e) {
            debugPrint('Notification insert error (comment): $e');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إرسال التعليق: $e')),
        );
      }
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cDark2,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(
                  color: _cOrange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text('💬 التعليقات', style: _ct(13, weight: FontWeight.w800)),
              const SizedBox(width: 8),
              if (!_loading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _cOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_comments.length}',
                      style: _ct(10, weight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: _cOrange, strokeWidth: 2),
              ),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'لا توجد تعليقات بعد، كن أول من يعلّق!',
                style: _ct(11, color: _cTextSec),
              ),
            )
          else
            ..._topLevel.map((c) => _buildComment(c)),

          const SizedBox(height: 10),

          // "Replying to …" chip
          if (_replyingToId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _cOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: _cOrange.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('ترد على ${_replyingToName ?? ''}',
                            style: _ct(10,
                                weight: FontWeight.w700, color: _cOrange)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _cancelReply,
                          child:
                              const Icon(Icons.close, size: 13, color: _cOrange),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Input bar
          if (Supabase.instance.client.auth.currentUser != null)
            Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _cDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _inputFocused
                            ? _cOrange
                            : Colors.white.withValues(alpha: 0.1),
                        width: _inputFocused ? 1.4 : 0.8,
                      ),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      style: _ct(12),
                      onSubmitted: (_) => _sendComment(),
                      decoration: InputDecoration(
                        hintText: 'أضف تعليقاً...',
                        hintStyle: _ct(12, color: _cTextSec),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _sendComment,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _sending
                          ? Colors.white.withValues(alpha: 0.08)
                          : _cOrange,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _sending
                          ? []
                          : [
                              BoxShadow(
                                color: _cOrange.withValues(alpha: 0.4),
                                blurRadius: 10,
                              )
                            ],
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildComment(Map<String, dynamic> comment, {bool isReply = false}) {
    final user    = comment['user'] as Map<String, dynamic>?;
    final name    = user?['display_name'] as String? ?? 'مستخدم';
    final avatar  = user?['avatar_url'] as String?;
    final content = comment['content'] ?? '';
    final time    = _timeAgo(comment['created_at']);
    final liked   = comment['liked_by_me'] == true;
    final likes   = (comment['like_count'] ?? 0) as int;
    final cid     = comment['id'].toString();
    // One level deep: replies of a top-level comment only.
    final replies = isReply ? const <Map<String, dynamic>>[] : _repliesOf(cid);

    final loggedIn = Supabase.instance.client.auth.currentUser != null;

    return Padding(
      padding: EdgeInsets.only(bottom: 12, left: isReply ? 42 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                displayName: name,
                username: (user?['username'] ?? '').toString(),
                avatarUrl: avatar,
                size: isReply ? 26 : 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: _ct(11, weight: FontWeight.w800)),
                        const SizedBox(width: 6),
                        Text(time, style: _ct(9, color: _cTextSec)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: _cDark,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(2),
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Text(
                        content,
                        style: _ct(12, color: _cTextSec, height: 1.5),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Actions: like (heart + count) + reply
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _toggleCommentLike(comment),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                liked
                                    ? PhosphorIcons.heart(
                                        PhosphorIconsStyle.fill)
                                    : PhosphorIcons.heart(),
                                size: 14,
                                color: liked ? _cOrange : _cTextSec,
                              ),
                              if (likes > 0) ...[
                                const SizedBox(width: 4),
                                Text('$likes',
                                    style: _ct(10,
                                        weight: FontWeight.w700,
                                        color: liked ? _cOrange : _cTextSec)),
                              ],
                            ],
                          ),
                        ),
                        if (loggedIn) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _startReply(comment),
                            child: Text('رد',
                                style: _ct(10,
                                    weight: FontWeight.w700, color: _cTextSec)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Replies (one level), indented beneath the parent.
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...replies.map((r) => _buildComment(r, isReply: true)),
          ],
        ],
      ),
    );
  }

}
