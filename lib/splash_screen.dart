import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _phase1Ctrl;
  late AnimationController _phase2Ctrl;
  late Animation<double> _phase1Fade;
  late Animation<double> _phase2Fade;

  @override
  void initState() {
    super.initState();
    _phase1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _phase2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _phase1Fade = CurvedAnimation(parent: _phase1Ctrl, curve: Curves.easeIn);
    _phase2Fade = CurvedAnimation(parent: _phase2Ctrl, curve: Curves.easeIn);
    _runSequence();
  }

  Future<void> _runSequence() async {
    // Phase 1: logo + "أي شيء" + "بس.. مو أي مطعم"
    await _phase1Ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 1500));

    // Cross-fade into phase 2
    _phase1Ctrl.reverse();
    await _phase2Ctrl.forward();

    // Phase 2: "عش تجربة المكان قبل زيارته"
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    final nextScreen =
        session != null ? const HomeScreen() : const WelcomeScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _phase1Ctrl.dispose();
    _phase2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: AnimatedBuilder(
        animation: Listenable.merge([_phase1Ctrl, _phase2Ctrl]),
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            // ── Phase 1: logo + أي شيء + بس.. مو أي مطعم ──────────────────
            FadeTransition(
              opacity: _phase1Fade,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 96,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'أي شيء',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'بس.. مو أي مطعم',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF26500),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Phase 2: عش تجربة المكان قبل زيارته ───────────────────────
            FadeTransition(
              opacity: _phase2Fade,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'عش تجربة المكان قبل زيارته',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      decoration: TextDecoration.none,
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
}
