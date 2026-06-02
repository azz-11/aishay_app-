import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  // ── Rate limiting: lock out after repeated failures ──────────────────────
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(seconds: 30);
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;

  bool get _isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  late AnimationController _logoCtrl;
  late AnimationController _formCtrl;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<Offset> _formSlide;
  late Animation<double> _formFade;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _formCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _formCtrl, curve: Curves.easeOutCubic));
    _formFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut),
    );
    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _formCtrl.forward();
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _logoCtrl.dispose();
    _formCtrl.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Block while locked out, refreshing the countdown message.
    if (_isLockedOut) {
      _startLockoutCountdown();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
      );
      // Success — clear any failure state.
      _failedAttempts = 0;
      _lockoutUntil = null;
      _lockoutTimer?.cancel();
      if (mounted) {
        // Clear the welcome/login stack so back doesn't return to auth.
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => false,
        );
      }
    } on AuthException catch (_) {
      _registerFailedAttempt('البريد أو كلمة المرور غير صحيحة');
    } catch (_) {
      _registerFailedAttempt('حدث خطأ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _registerFailedAttempt(String message) {
    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) {
      _lockoutUntil = DateTime.now().add(_lockoutDuration);
      _startLockoutCountdown();
    } else {
      final left = _maxAttempts - _failedAttempts;
      setState(() => _error = '$message (محاولات متبقية: $left)');
    }
  }

  /// Ticks every second, showing the remaining lockout time, then clears it.
  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    void tick() {
      if (!mounted || _lockoutUntil == null) return;
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _lockoutTimer?.cancel();
        _failedAttempts = 0;
        _lockoutUntil = null;
        setState(() => _error = null);
      } else {
        setState(() =>
            _error = 'تم تجاوز عدد المحاولات. حاول بعد $remaining ثانية');
      }
    }

    tick();
    _lockoutTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  @override
  Widget build(BuildContext context) {
    // Allow popping back to the Welcome screen (defensive; the route is pushed
    // on top of Welcome, so it is already poppable).
    return PopScope(
      canPop: true,
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF1A2340),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Back button → returns to the Welcome screen.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: GestureDetector(
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
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 140,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'أي شيء',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFF5D485),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'بس مو أي مطعم.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF26500),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SlideTransition(
                position: _formSlide,
                child: FadeTransition(
                  opacity: _formFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'مرحباً بعودتك',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'سجّل دخولك وشارك تجربتك',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: const Text(
                          'البريد الإلكتروني',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _InputField(
                        controller: _emailController,
                        hint: 'example@email.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: const Text(
                          'كلمة المرور',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _InputField(
                        controller: _passController,
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            'نسيت كلمة المرور؟',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFF26500),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Color(0xFF991B1B), size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 8),
                      _LoginButton(
                        loading: _loading,
                        onTap: _login,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'أو',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: 'ما عندك حساب؟  ',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                            children: [
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () {},
                                  child: const Text(
                                    'سجّل الآن',
                                    style: TextStyle(
                                      color: Color(0xFFF26500),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
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
        textDirection: TextDirection.ltr,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon: Icon(icon,
              color: Colors.white.withValues(alpha: 0.4), size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _LoginButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
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
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'دخول ←',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}