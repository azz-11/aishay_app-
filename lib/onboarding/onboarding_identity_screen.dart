import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_avatar.dart';
import 'onboarding_progress.dart';
import 'onboarding_preferences_screen.dart';

const _kDark = Color(0xFF0F1923);
const _kOrange = Color(0xFFF26500);
const _kCardBg = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size, FontWeight weight, Color color,
        {double height = 1.0}) =>
    GoogleFonts.tajawal(
        fontSize: size, fontWeight: weight, color: color, height: height);

/// Onboarding Step 2 — profile photo (optional) + bio (optional).
class OnboardingIdentityScreen extends StatefulWidget {
  final String displayName;
  final String username;
  const OnboardingIdentityScreen({
    super.key,
    required this.displayName,
    required this.username,
  });

  @override
  State<OnboardingIdentityScreen> createState() =>
      _OnboardingIdentityScreenState();
}

class _OnboardingIdentityScreenState extends State<OnboardingIdentityScreen> {
  final _picker = ImagePicker();
  final _bioCtrl = TextEditingController();
  Uint8List? _avatarBytes;
  bool _uploading = false;
  bool _saving = false;

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _avatarBytes = bytes;
      _uploading = true;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final mime = picked.mimeType ?? 'image/jpeg';
      final path = '${user.id}.jpg'; // matches avatars RLS (filename stem = uid)
      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: mime),
          );
      final base =
          Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
      final url =
          '${base.split('?').first}?t=${DateTime.now().millisecondsSinceEpoch}';
      await Supabase.instance.client
          .from('users')
          .update({'avatar_url': url}).eq('id', user.id);
      if (mounted) setState(() => _uploading = false);
    } catch (e) {
      debugPrint('[onboarding] avatar upload error: $e');
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر رفع الصورة', style: GoogleFonts.tajawal())),
        );
      }
    }
  }

  Future<void> _next() async {
    final bio = _bioCtrl.text.trim();
    if (bio.isNotEmpty) {
      setState(() => _saving = true);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client
              .from('users')
              .update({'bio': bio}).eq('id', user.id);
        } catch (e) {
          debugPrint('[onboarding] bio save error: $e');
        }
      }
      if (mounted) setState(() => _saving = false);
    }
    _goNext();
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingPreferencesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kDark,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const Expanded(
                      child: Center(child: OnboardingProgress(current: 1)),
                    ),
                    const SizedBox(width: 38),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      Text('عرّفنا بنفسك',
                          style: _tj(22, FontWeight.w900, Colors.white)),
                      const SizedBox(height: 6),
                      Text('صورة ونبذة بسيطة — كلها اختيارية',
                          style: _tj(13, FontWeight.w400, _kTextSec),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: _uploading ? null : _pickAvatar,
                        child: Stack(
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: _avatarBytes != null
                                  ? Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: _kOrange, width: 2.5),
                                      ),
                                      child: ClipOval(
                                        child: Image.memory(_avatarBytes!,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover),
                                      ),
                                    )
                                  : AppAvatar(
                                      displayName: widget.displayName,
                                      username: widget.username,
                                      size: 120,
                                      showGlow: true,
                                    ),
                            ),
                            if (_uploading)
                              const Positioned.fill(
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: _kOrange, strokeWidth: 2.5),
                                ),
                              ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: const BoxDecoration(
                                    color: _kOrange, shape: BoxShape.circle),
                                child: Icon(
                                    PhosphorIcons.camera(
                                        PhosphorIconsStyle.fill),
                                    color: Colors.white,
                                    size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _goNext,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text('تخطّي الآن',
                              style: _tj(12, FontWeight.w600, _kTextSec)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text('نبذة عنك',
                            style: _tj(12, FontWeight.w700, _kTextSec)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: _kCardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: TextField(
                          controller: _bioCtrl,
                          maxLength: 120,
                          maxLines: 3,
                          textDirection: TextDirection.rtl,
                          style: _tj(13, FontWeight.w400, Colors.white),
                          decoration: InputDecoration(
                            hintText: 'أخبرنا عن ذوقك في الطعام...',
                            hintStyle: _tj(12, FontWeight.w400, _kTextSec),
                            border: InputBorder.none,
                            counterStyle: _tj(10, FontWeight.w400, _kTextSec),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: GestureDetector(
                  onTap: _saving ? null : _next,
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_kOrange, Color(0xFFFF7A1A)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: _kOrange.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text('التالي',
                              style: _tj(16, FontWeight.w800, Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
