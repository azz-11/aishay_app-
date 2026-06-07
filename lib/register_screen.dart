import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_identity_screen.dart';
import 'security_utils.dart';

class RegisterScreen extends StatefulWidget {
  final String inviteCode;
  const RegisterScreen({super.key, required this.inviteCode});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  int _step = 1;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    debugPrint('[register] _register tapped (invite="${widget.inviteCode}")');
    // Sanitize + validate inputs before hitting the backend.
    final name = sanitizeAndCap(_nameController.text, kMaxNameLength);
    final username = _usernameController.text.trim().toLowerCase();
    final email = _emailController.text.trim();
    final password = _passController.text;

    if (name.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty) {
      debugPrint('[register] validation failed: empty field(s)');
      setState(() => _error = 'يرجى تعبئة جميع الحقول');
      return;
    }
    if (!isValidEmail(email)) {
      debugPrint('[register] validation failed: invalid email "$email"');
      setState(() => _error = 'صيغة البريد الإلكتروني غير صحيحة');
      return;
    }
    if (username.length > kMaxUsernameLength) {
      debugPrint('[register] validation failed: username too long (${username.length})');
      setState(() => _error = 'اسم المستخدم طويل جداً (الحد $kMaxUsernameLength حرفاً)');
      return;
    }
    if (!isValidUsername(username)) {
      debugPrint('[register] validation failed: invalid username "$username"');
      setState(() => _error = 'اسم المستخدم: حروف إنجليزية وأرقام و _ فقط');
      return;
    }
    if (password.length < 8) {
      debugPrint('[register] validation failed: password too short (${password.length})');
      setState(() => _error = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    debugPrint('[register] validation passed (email="$email", username="$username")');

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Step 1 — validate the invite (does NOT consume it).
      debugPrint('[register] validate_invite "${widget.inviteCode}"...');
      final valid = await Supabase.instance.client
          .rpc('validate_invite', params: {'p_code': widget.inviteCode});
      debugPrint('[register] validate_invite → $valid');
      if (valid != true) {
        if (mounted) {
          setState(() {
            _error = 'الكود غير صالح أو مستخدم';
            _loading = false;
          });
        }
        return;
      }

      // Step 2 — create the account (the code stays unused if this fails).
      debugPrint('[register] calling auth.signUp...');
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      debugPrint('[register] signUp returned: user=${res.user?.id}, '
          'session=${res.session != null}');
      if (res.user == null) {
        debugPrint('[register] signUp returned null user — NOT consuming code '
            '(email confirmation likely required — no session yet)');
        return; // finally resets _loading
      }

      // Step 3 — consume the code now that the account exists.
      debugPrint('[register] consume_invite "${widget.inviteCode}"...');
      final consumed = await Supabase.instance.client
          .rpc('consume_invite', params: {'p_code': widget.inviteCode});
      debugPrint('[register] consume_invite → $consumed');
      if (consumed != true) {
        // Lost a race: the code was used between validate and consume. Roll back
        // the just-created session and stop.
        debugPrint('[register] consume failed — signing out and aborting');
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          setState(() => _error = 'حدث خطأ أثناء التسجيل، يرجى المحاولة مرة أخرى');
        }
        return;
      }

      // Step 4 — upsert profile row (a DB trigger may have already created it).
      debugPrint('[register] upserting users row for ${res.user!.id}...');
      final userUpsert = await Supabase.instance.client.from('users').upsert({
        'id': res.user!.id,
        'display_name': name,
        'username': username,
        'language': 'ar',
      }, onConflict: 'id').select();
      debugPrint('[register] users upsert result: $userUpsert');

      debugPrint('[register] success → advancing to step 2');
      if (mounted) setState(() => _step = 2);
    } on AuthException catch (e) {
      debugPrint('[register] AuthException: ${e.message}');
      if (mounted) setState(() => _error = e.message);
    } catch (e, st) {
      debugPrint('[register] ERROR: $e');
      debugPrint('$st');
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    debugPrint('[google] sign-in tapped (invite="${widget.inviteCode}")');
    try {
      // TODO: replace with your Google OAuth Web client ID (from Google Cloud Console).
      const webClientId = 'YOUR_GOOGLE_CLIENT_ID';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: webClientId,
        scopes: ['email'],
      );

      debugPrint('[google] launching account picker...');
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[google] cancelled by user');
        return;
      }
      debugPrint('[google] account selected: ${googleUser.email}');

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;
      debugPrint('[google] tokens: idToken=${idToken != null}, '
          'accessToken=${accessToken != null}');

      if (idToken == null) {
        debugPrint('[google] no idToken returned → aborting');
        return;
      }

      debugPrint('[google] calling auth.signInWithIdToken...');
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Check if user exists in users table, if not create
      final user = Supabase.instance.client.auth.currentUser;
      debugPrint('[google] signed in as ${user?.id}');
      bool isNewGoogleUser = false;
      if (user != null) {
        debugPrint('[google] checking for existing users row...');
        final existing = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();
        debugPrint('[google] existing users row: $existing');

        if (existing == null) {
          isNewGoogleUser = true;
          debugPrint('[google] inserting new users row for ${user.id}...');
          final userInsert = await Supabase.instance.client.from('users').insert({
            'id': user.id,
            'display_name': googleUser.displayName ?? googleUser.email,
            'username': googleUser.email.split('@')[0],
            'avatar_url': googleUser.photoUrl,
            'language': 'ar',
          }).select();
          debugPrint('[google] users insert result: $userInsert');

          // Validate + consume the invite for this new Google account (via the
          // SECURITY DEFINER RPCs, since invitation_codes is now RLS-locked).
          debugPrint('[google] validate_invite "${widget.inviteCode}"...');
          final valid = await Supabase.instance.client
              .rpc('validate_invite', params: {'p_code': widget.inviteCode});
          debugPrint('[google] validate_invite → $valid');
          if (valid == true) {
            final consumed = await Supabase.instance.client
                .rpc('consume_invite', params: {'p_code': widget.inviteCode});
            debugPrint('[google] consume_invite → $consumed');
          }
        }
      }

      if (mounted) {
        if (isNewGoogleUser) {
          debugPrint('[google] new user → onboarding');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => OnboardingIdentityScreen(
                displayName: googleUser.displayName ?? googleUser.email,
                username: googleUser.email.split('@')[0],
              ),
            ),
            (route) => false,
          );
        } else {
          debugPrint('[google] returning user → Home');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e, st) {
      debugPrint('[google] ERROR: $e');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تسجيل الدخول بـ Google: $e',
                style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF1A2340),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: _step == 1 ? _buildForm() : _buildSuccess(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // header
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
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
              const Spacer(),
              Image.asset('assets/images/logo.png', width: 40),
              const Spacer(),
              const SizedBox(width: 38),
            ],
          ),

          const SizedBox(height: 28),

          const Text(
            'إنشاء حساب جديد',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'رمز الدعوة: ${widget.inviteCode}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF34D399),
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          // progress bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF26500), Color(0xFFFF7A1A)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // الاسم
          _buildLabel('الاسم الظاهر'),
          const SizedBox(height: 8),
          _buildInput(
            controller: _nameController,
            hint: 'مثال: عبدالعزيز',
            icon: Icons.person_outline,
          ),

          const SizedBox(height: 16),

          // اليوزر
          _buildLabel('اسم المستخدم'),
          const SizedBox(height: 8),
          _buildInput(
            controller: _usernameController,
            hint: 'username',
            icon: Icons.alternate_email,
            textDirection: TextDirection.ltr,
          ),

          const SizedBox(height: 16),

          // البريد
          _buildLabel('البريد الإلكتروني'),
          const SizedBox(height: 8),
          _buildInput(
            controller: _emailController,
            hint: 'example@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
          ),

          const SizedBox(height: 16),

          // كلمة المرور
          _buildLabel('كلمة المرور'),
          const SizedBox(height: 8),
          _buildInput(
            controller: _passController,
            hint: '8+ أحرف',
            icon: Icons.lock_outline,
            obscure: _obscure,
            textDirection: TextDirection.ltr,
            suffix: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),

          const SizedBox(height: 12),

          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFF991B1B), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF991B1B)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // زر إنشاء الحساب
          _RegisterButton(loading: _loading, onTap: _register),

          const SizedBox(height: 24),

          // ── Divider ──────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'أو تسجيل الدخول بـ',
                  style: GoogleFonts.tajawal(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Google sign-in button ────────────────────────────────────────
          GestureDetector(
            onTap: _signInWithGoogle,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://www.google.com/favicon.ico',
                    width: 20,
                    height: 20,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.g_mobiledata_rounded,
                      color: Color(0xFF4285F4),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'متابعة بـ Google',
                    style: GoogleFonts.tajawal(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              'أهلاً وسهلاً!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تم إنشاء حسابك بنجاح\nمرحباً ${_nameController.text.trim()} 🔥',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 36),
            GestureDetector(
  onTap: () {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OnboardingIdentityScreen(
          displayName: _nameController.text.trim(),
          username: _usernameController.text.trim().toLowerCase(),
        ),
      ),
      (route) => false,
    );
  },
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF26500), Color(0xFFFF7A1A)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF26500).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'ابدأ الاستكشاف 🔥',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    TextDirection textDirection = TextDirection.rtl,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textDirection: textDirection,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon:
              Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _RegisterButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;

  const _RegisterButton({required this.loading, required this.onTap});

  @override
  State<_RegisterButton> createState() => _RegisterButtonState();
}

class _RegisterButtonState extends State<_RegisterButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF26500), Color(0xFFFF7A1A)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF26500).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'أنشئ حسابي 🎉',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}