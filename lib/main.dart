import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_locale.dart';
import 'reset_password_screen.dart';
import 'splash_screen.dart';
import 'welcome_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Fallbacks keep the app building if `.env` is missing (e.g. a fresh clone or
// CI without the file). The anon/publishable key is a client key, not a secret;
// real access control lives in Supabase RLS.
const _fallbackSupabaseUrl = 'https://yhgrbxdgwjnaqximcmbs.supabase.co';
const _fallbackSupabaseAnonKey =
    'sb_publishable_tcp3mca0vyxfNWfdjSaNxA_OrV3HLZn';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use only bundled Tajawal font files — no runtime network fetch
  GoogleFonts.config.allowRuntimeFetching = false;

  // Arabic date symbols for the visit planner calendar (table_calendar).
  await initializeDateFormatting('ar', null);

  // Load secrets from the bundled .env (kept out of source control).
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('main: .env not loaded ($e) — using fallback config');
  }

  await Supabase.initialize(
    url: dotenv.maybeGet('SUPABASE_URL') ?? _fallbackSupabaseUrl,
    anonKey: dotenv.maybeGet('SUPABASE_ANON_KEY') ?? _fallbackSupabaseAnonKey,
  );

  // On Flutter Web the recovery link lands with the token in the URL fragment
  // (#access_token=...&refresh_token=...&type=recovery). Detect it at startup
  // and jump straight to the reset screen instead of booting the normal app
  // (which would otherwise route the established session to Home).
  // Note: setSession() takes the REFRESH token, not the access token.
  if (kIsWeb) {
    final fragment = Uri.base.fragment;
    if (fragment.isNotEmpty) {
      final params = Uri.splitQueryString(fragment);
      if (params['type'] == 'recovery' && params['refresh_token'] != null) {
        await Supabase.instance.client.auth.setSession(
          params['refresh_token']!,
        );
        runApp(const MaterialApp(
          home: ResetPasswordScreen(),
          debugShowCheckedModeBanner: false,
        ));
        return;
      }
    }
  }

  // Session security: Supabase auto-refreshes tokens. If the session ends
  // (sign-out, deletion, or an unrecoverable refresh failure), force the user
  // back to the entry screen so no authenticated UI lingers.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedOut) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } else if (data.event == AuthChangeEvent.passwordRecovery) {
      // The user opened the recovery link from their email and Supabase
      // established a temporary recovery session — let them set a new password.
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      );
    }
  });

  await AppLocale.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLocale.notifier,
      builder: (_, isArabic, __) {
        return MaterialApp(
          title: 'أي شيء',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFF0F1923),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF26500),
              surface: Color(0xFF0F1923),
            ),
          ),
          locale: Locale(isArabic ? 'ar' : 'en', isArabic ? 'SA' : 'US'),
          supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        );
      },
    );
  }
}
