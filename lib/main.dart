import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_locale.dart';
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

  // Session security: Supabase auto-refreshes tokens. If the session ends
  // (sign-out, deletion, or an unrecoverable refresh failure), force the user
  // back to the entry screen so no authenticated UI lingers.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedOut) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
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
