import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  Future<void> _checkCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'أدخل رمز الدعوة');
      _shakeCtrl.forward(from: 0);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('invitation_codes')
          .select()
          .eq('code', code)
          .eq('is_used', false)
          .maybeSingle();

      if (res == null) {
        setState(() => _error = 'الرمز غير صحيح أو مستخدم مسبقاً');
        _shakeCtrl.forward(from: 0);
      } else {
        setState(() => _success = true);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  RegisterScreen(inviteCode: code),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2340),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 60),
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
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFF26500).withOpacity(0.4),
                    ),
                  ),
                  child: const Center(
                    child: Text('🎟️', style: TextStyle(fontSize: 32)),
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
                          ? const Color(0xFF065F46).withOpacity(0.15)
                          : _error != null
                              ? const Color(0xFF991B1B).withOpacity(0.1)
                              : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _success
                            ? const Color(0xFF34D399).withOpacity(0.6)
                            : _error != null
                                ? const Color(0xFFFCA5A5).withOpacity(0.6)
                                : Colors.white.withOpacity(0.12),
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
                          color: Colors.white.withOpacity(0.25),
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
                      color: const Color(0xFF065F46).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFF34D399).withOpacity(0.5)),
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
                const Spacer(),
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
    );
  }
}

class _CheckButton extends StatefulWidget {
  final bool loading;
  final bool success;
  final VoidCallback onTap;

  const _CheckButton({
    required this.loading,
    required this.success,
    required this.onTap,
  });

  @override
  State<_CheckButton> createState() => _CheckButtonState();
}

class _CheckButtonState extends State<_CheckButton>
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
            gradient: LinearGradient(
              colors: widget.success
                  ? [
                      const Color(0xFF065F46),
                      const Color(0xFF34D399)
                    ]
                  : [
                      const Color(0xFFF26500),
                      const Color(0xFFFF7A1A)
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (widget.success
                        ? const Color(0xFF34D399)
                        : const Color(0xFFF26500))
                    .withOpacity(0.4),
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
                : Text(
                    widget.success
                        ? '✓ رمز صحيح'
                        : 'تحقق من الرمز ←',
                    style: const TextStyle(
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