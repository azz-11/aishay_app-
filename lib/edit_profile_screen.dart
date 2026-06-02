import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_strings.dart';

const _eDark    = Color(0xFF0F1923);
const _eDark2   = Color(0xFF1A2340);
const _eCardBg  = Color(0xFF1E2D45);
const _eOrange  = Color(0xFFF26500);
const _eTextSec = Color(0xFF94A3B8);

TextStyle _et(double size,
    {FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
    double? height}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color, height: height);

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _cityCtrl;
  XFile? _avatarFile;
  Uint8List? _avatarBytes;
  String? _avatarUrl;
  bool _saving = false;
  String? _focusedField;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.profile['display_name'] ?? widget.profile['username'] ?? '');
    _bioCtrl  = TextEditingController(text: widget.profile['bio'] ?? '');
    _cityCtrl = TextEditingController(text: widget.profile['city'] ?? '');
    _avatarUrl = widget.profile['avatar_url'];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _avatarFile = picked;
        _avatarBytes = bytes;
      });
    }
  }

  Future<String?> _uploadAvatar(String userId) async {
    if (_avatarFile == null || _avatarBytes == null) return _avatarUrl;
    final mime = _avatarFile!.mimeType ?? 'image/jpeg';
    final path = '$userId.jpg';
    await Supabase.instance.client.storage
        .from('avatars')
        .uploadBinary(
          path,
          _avatarBytes!,
          fileOptions: FileOptions(upsert: true, contentType: mime),
        );
    final base = Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
    final clean = base.split('?').first;
    return '$clean?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.nameRequired, style: _et(12)),
          backgroundColor: _eOrange,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final url  = await _uploadAvatar(user.id);
      await Supabase.instance.client.from('users').update({
        'display_name': name,
        'bio':  _bioCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        if (url != null) 'avatar_url': url,
      }).eq('id', user.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.saveFailed}: $e', style: _et(12)),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.profile['display_name'] ?? widget.profile['username'] ?? 'م';

    return Scaffold(
      backgroundColor: _eDark,
      body: Column(
        children: [
          // ── TOP BAR
          Container(
            decoration: const BoxDecoration(
              color: _eDark2,
              border: Border(
                bottom: BorderSide(color: Color(0x14FFFFFF), width: 0.8),
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 14,
              left: 8,
              right: 16,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(AppStrings.editProfile,
                      style: _et(15, weight: FontWeight.w800)),
                ),
                if (_saving)
                  const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: _eOrange, strokeWidth: 2.5),
                  )
                else
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_eOrange, Color(0xFFFF8C33)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _eOrange.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(AppStrings.save,
                          style: _et(13, weight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),

          // ── BODY
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar picker
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 96, height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [_eOrange, Color(0xFFFF7A1A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _eOrange.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.5),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _eDark2,
                              ),
                              child: ClipOval(
                                child: _avatarBytes != null
                                    ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                                    : (_avatarUrl != null
                                        ? Image.network(
                                            _avatarUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _initials(displayName),
                                          )
                                        : _initials(displayName)),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _eOrange,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _eOrange.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(AppStrings.tapToChangePhoto,
                      style: _et(11, color: _eTextSec)),

                  const SizedBox(height: 32),

                  _field('👤 ${AppStrings.name}', _nameCtrl, fieldKey: 'name'),
                  const SizedBox(height: 16),
                  _field('📍 ${AppStrings.city}', _cityCtrl,
                      fieldKey: 'city', hint: AppStrings.cityHintExample),
                  const SizedBox(height: 16),
                  _field('✍️ ${AppStrings.bio}', _bioCtrl,
                      fieldKey: 'bio',
                      maxLines: 4,
                      hint: AppStrings.bioHint),

                  const SizedBox(height: 32),

                  // Save button (also at bottom for convenience)
                  GestureDetector(
                    onTap: _saving ? null : _save,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: _saving
                            ? null
                            : const LinearGradient(
                                colors: [_eOrange, Color(0xFFFF8C33)]),
                        color: _saving
                            ? Colors.white.withValues(alpha: 0.06)
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _saving
                            ? []
                            : [
                                BoxShadow(
                                  color: _eOrange.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(AppStrings.saveChanges,
                                style: _et(15, weight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    String? hint,
    required String fieldKey,
  }) {
    final focused = _focusedField == fieldKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _et(12, weight: FontWeight.w700, color: _eTextSec)),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) {
            setState(() => _focusedField = hasFocus ? fieldKey : null);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _eCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: focused
                    ? _eOrange
                    : Colors.white.withValues(alpha: 0.1),
                width: focused ? 1.4 : 0.8,
              ),
              boxShadow: focused
                  ? [
                      BoxShadow(
                        color: _eOrange.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: TextField(
              controller: ctrl,
              maxLines: maxLines,
              textDirection: TextDirection.rtl,
              style: _et(13),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: _et(12, color: _eTextSec),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _initials(String name) => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'م',
      style: _et(32, weight: FontWeight.w900, color: _eOrange),
    ),
  );
}
