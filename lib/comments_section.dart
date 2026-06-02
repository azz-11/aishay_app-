import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final res = await Supabase.instance.client
          .from('comments')
          .select('*, user:users(display_name, avatar_url)')
          .eq('experience_id', widget.experienceId)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _sending = true);
    try {
      final res = await Supabase.instance.client
          .from('comments')
          .insert({
            'experience_id': widget.experienceId,
            'user_id': user.id,
            'content': text,
          })
          .select('*, user:users(display_name, avatar_url)')
          .single();

      if (mounted) {
        setState(() {
          _comments.add(Map<String, dynamic>.from(res));
          _sending = false;
        });
        _ctrl.clear();
        _focusNode.unfocus();
      }

      final ownerId = widget.experienceOwnerId;
      if (ownerId != null && ownerId != user.id) {
        try {
          await Supabase.instance.client.from('notifications').insert({
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
            ..._comments.map((c) => _buildComment(c)),

          const SizedBox(height: 10),

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

  Widget _buildComment(Map<String, dynamic> comment) {
    final user    = comment['user'] as Map<String, dynamic>?;
    final name    = user?['display_name'] as String? ?? 'مستخدم';
    final avatar  = user?['avatar_url'] as String?;
    final content = comment['content'] ?? '';
    final time    = _timeAgo(comment['created_at']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _cOrange.withValues(alpha: 0.15),
              border: Border.all(
                color: _cOrange.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: avatar != null
                ? ClipOval(
                    child: Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initial(name),
                    ),
                  )
                : _initial(name),
          ),
          const SizedBox(width: 10),
          // Bubble
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initial(String name) => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'م',
      style: _ct(12, weight: FontWeight.w900, color: _cOrange),
    ),
  );
}
