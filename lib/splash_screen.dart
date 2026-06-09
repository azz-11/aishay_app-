import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_identity_screen.dart';

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

  // One controller spans all staggered entrances (logo → line → tagline).
  // Each element fades in over its own slice via an Interval curve:
  //   logo    0–500ms   → Interval(0.000, 0.333)
  //   line    600–1000ms→ Interval(0.400, 0.667)
  //   tagline 1100–1500ms→Interval(0.733, 1.000)
  late final AnimationController _ctrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _lineFade;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // full stagger window
    )..forward();

    _logoFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.333, curve: Curves.easeOut),
    );
    _lineFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.4, 0.667, curve: Curves.easeOut),
    );
    _taglineFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.733, 1.0, curve: Curves.easeOut),
    );

    _boot();
  }

  Future<void> _boot() async {
    // Session is available synchronously after Supabase.initialize().
    final session = Supabase.instance.client.auth.currentSession;

    // Warm-start the feed + fetch onboarding status in parallel with the splash.
    Future<Map<String, dynamic>?>? userFuture;
    if (session != null) {
      HomeScreen.prefetchFeed();
      userFuture = Supabase.instance.client
          .from('users')
          .select('onboarding_completed, display_name, username')
          .eq('id', session.user.id)
          .maybeSingle();
    }

    // First open: stagger ends at 1500ms, then hold 1800ms = 3300ms total
    // before navigating (the route transition does the 400ms fade-out).
    // Re-mounts skip the wait so the splash never repeats.
    if (!_completed) {
      _completed = true;
      await Future.delayed(const Duration(milliseconds: 3300));
    }
    if (!mounted) return;

    Widget next;
    if (session == null) {
      next = const WelcomeScreen();
    } else {
      Map<String, dynamic>? u;
      try {
        u = await userFuture;
      } catch (e) {
        debugPrint('[splash] onboarding check error: $e');
      }
      // Only an explicit `false` sends a user through onboarding; NULL / true
      // (existing accounts) go straight home.
      if (u != null && u['onboarding_completed'] == false) {
        next = OnboardingIdentityScreen(
          displayName: (u['display_name'] ?? '').toString(),
          username: (u['username'] ?? '').toString(),
        );
      } else {
        next = const HomeScreen();
      }
    }
    if (!mounted) return;
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Logo — fades in first (0–500ms)
            FadeTransition(
              opacity: _logoFade,
              child: Image.asset(
                'assets/images/logo.png',
                width: 110,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 24),

            // 2. "أي شيء · بس مو أي مطعم" — fades in after logo (600–1000ms)
            FadeTransition(
              opacity: _lineFade,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    'أي شيء',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    '  ·  ',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xCCF26500),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    'بس مو أي مطعم',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3. "عش تجربة المكان قبل زيارته" — fades in last (1100–1500ms)
            FadeTransition(
              opacity: _taglineFade,
              child: const Text(
                'عش تجربة المكان قبل زيارته',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xCCF26500),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
