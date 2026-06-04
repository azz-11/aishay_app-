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
    with SingleTickerProviderStateMixin {
  // Process-level guard: the full splash runs ONCE per app open. Any re-mount
  // (hot reload / MaterialApp rebuild) navigates immediately — no repeat.
  static bool _completed = false;

  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // single fade-in
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _boot();
  }

  Future<void> _boot() async {
    // Session is available synchronously after Supabase.initialize().
    final session = Supabase.instance.client.auth.currentSession;

    // Warm-start the feed in parallel with the splash (idempotent).
    if (session != null) {
      HomeScreen.prefetchFeed();
    }

    // First open: 300ms fade-in + 2000ms on-screen = 2300ms, then navigate.
    // Re-mounts skip the wait so the splash never repeats.
    if (!_completed) {
      _completed = true;
      await Future.delayed(const Duration(milliseconds: 2300));
    }
    if (!mounted) return;

    final next = session != null ? const HomeScreen() : const WelcomeScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400), // fade-out
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      // ONE fade-in for all elements together — no phases, no cross-fade.
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 110,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
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
                'بس مو أي مطعم',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'عش تجربة المكان قبل زيارته',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xCCF26500),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
