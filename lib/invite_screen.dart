import 'package:flutter/material.dart';
import 'register_screen.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _success = false;

  late AnimationController _fadeCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _fade;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _shake = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _shakeCtrl.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _checkCode() {
    final code = _codeController.text.trim().toUpperCase();
    debugPrint('[invite] _checkCode tapped, code="$code"');

    if (code.isEmpty) {
      setState(() => _error = 'أدخل رمز الدعوة');
      _shakeCtrl.forward(from: 0);
      return;
    }
    // Format check only — the code is validated AND consumed server-side at the
    // registration step (validate_invite / consume_invite RPCs), never here.
    if (!RegExp(r'^AISHAY-[A-Z0-9]+$').hasMatch(code)) {
      setState(() => _error = 'صيغة الرمز غير صحيحة');
      _shakeCtrl.forward(from: 0);
      return;
    }

    setState(() => _error = null);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => RegisterScreen(inviteCode: code),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
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
        child: FadeTransition(
          opacity: _fade,
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
                Image.asset('assets/images/logo.png', width: 100),
                const SizedBox(height: 16),
                const Text(
                  'أي شيء',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF5D485),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 60),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFF26500).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.confirmation_number_outlined,
                        color: Color(0xFFF26500), size: 34),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'عندك دعوة؟',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'التطبيق حالياً بالدعوة فقط\nاطلب رمزك من صديق يستخدم أي شيء',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 36),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) {
                    final offset = _error != null
                        ? 8 *
                            (_shake.value < 0.5
                                ? _shake.value
                                : 1 - _shake.value)
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(offset * 10, 0),
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _success
                          ? const Color(0xFF065F46).withValues(alpha: 0.15)
                          : _error != null
                              ? const Color(0xFF991B1B).withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _success
                            ? const Color(0xFF34D399).withValues(alpha: 0.6)
                            : _error != null
                                ? const Color(0xFFFCA5A5).withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: TextField(
                      controller: _codeController,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        color: _success
                            ? const Color(0xFF34D399)
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'AISHAY-XXXX',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                        prefixIcon: Icon(
                          _success
                              ? Icons.check_circle_outline
                              : Icons.key_outlined,
                          color: _success
                              ? const Color(0xFF34D399)
                              : const Color(0xFFF26500),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onSubmitted: (_) => _checkCode(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_error != null)
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
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_success)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF065F46).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFF34D399).withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Color(0xFF34D399), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'رمز صحيح! جاري الانتقال...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF34D399),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                _CheckButton(
                  loading: _loading,
                  success: _success,
                  onTap: _checkCode,
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: RichText(
                    text: TextSpan(
                      text: 'ما عندك رمز؟  ',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      children: [
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () {},
                            child: const Text(
                              'تواصل معنا',
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
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  final bool loading;
  final bool success;
  final VoidCallback onTap;

  const _CheckButton({
    required this.loading,
    required this.success,
    required this.onTap,
  });

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
              gradient: LinearGradient(
                colors: success
                    ? [const Color(0xFF065F46), const Color(0xFF34D399)]
                    : [const Color(0xFFF26500), const Color(0xFFFF7A1A)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (success
                          ? const Color(0xFF34D399)
                          : const Color(0xFFF26500))
                      .withValues(alpha: 0.4),
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
                  : Text(
                      success ? '✓ رمز صحيح' : 'تحقق من الرمز ←',
                      style: const TextStyle(
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