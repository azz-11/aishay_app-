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
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _boot();
  }

  Future<void> _boot() async {
    // Session is available synchronously once Supabase.initialize() has run.
    final session = Supabase.instance.client.auth.currentSession;

    // Warm-start the home feed IN PARALLEL with the splash so the data is
    // (close to) ready by the time we navigate — not fetched only afterwards.
    if (session != null) {
      HomeScreen.prefetchFeed();
    }

    // Keep the splash visible for at most ~1s, then navigate.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final next = session != null ? const HomeScreen() : const WelcomeScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
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
    // Single fade-in screen (merged from the old two phases).
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: FadeTransition(
        opacity: _fade,
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
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'عش تجربة المكان قبل زيارته',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    decoration: TextDecoration.none,
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
