// Integration (end-to-end) smoke flow for the "أي شيء" (aishay) app.
//
// This drives the REAL app against the REAL Supabase backend. It is NOT a unit
// test and cannot run in plain `flutter test`. Run it on a connected device or
// emulator:
//
//   flutter test integration_test/app_test.dart -d <device>
//   # examples: -d emulator-5554   |   -d windows   |   -d chrome
//
// PREREQUISITES (the test will fail loudly without these — by design):
//   1. A real device/emulator (or `-d chrome` / `-d windows`).
//   2. Network access to the Supabase project configured in lib/main.dart.
//   3. The test user below MUST already exist in Supabase Auth AND have a row in
//      the `users` table. Create it once (Supabase dashboard → Authentication →
//      Add user, or via the app's invite→register flow). This test does not
//      create it — signing a user up programmatically would mutate your prod
//      data and depends on email-confirmation settings.
//   4. The home feed must contain at least one experience (otherwise the
//      "feed loads" / "open detail" steps correctly fail).
//
// NOTE ON pump strategy: the home screen runs repeating animations
// (shimmer / ambient / notification pulse via `..repeat()`), so
// `pumpAndSettle()` never returns once Home is visible. This file uses a
// timed `_pumpUntil` helper instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aishay_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testEmail = 'test@aishay.app';
  const testPassword = 'Test1234!';

  // Pump in small increments until [finder] matches or [timeout] elapses.
  // Returns true if found. Avoids pumpAndSettle (which hangs on Home's
  // repeating animations).
  Future<bool> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> tapWhenVisible(WidgetTester tester, Finder finder) async {
    expect(await pumpUntil(tester, finder), isTrue,
        reason: 'Expected to find: ${finder.description}');
    await tester.ensureVisible(finder.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(finder.first);
    await tester.pump(const Duration(milliseconds: 600));
  }

  tearDown(() async {
    // Leave a clean (logged-out) state so the flow is re-runnable from login.
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {/* Supabase may not be initialized if launch failed */}
  });

  testWidgets('happy-path smoke flow: launch → login → feed → detail → toggles → tabs',
      (tester) async {
    // ── 1. App launches successfully ────────────────────────────────────────
    app.main(); // initializes Supabase + AppLocale, then runApp()
    await tester.pump(const Duration(seconds: 1)); // let Supabase.initialize finish

    // Force a logged-out start: the splash routes straight to Home if a session
    // is already persisted, which would skip the login step. Sign out during the
    // splash's ~3s delay so it routes to the Welcome screen instead.
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}

    // ── 2. Splash navigates to the Welcome screen ───────────────────────────
    final loginEntry = find.text('تسجيل الدخول'); // Welcome screen's login button
    expect(await pumpUntil(tester, loginEntry), isTrue,
        reason: 'Splash should navigate to Welcome screen (login button) when logged out');

    // Welcome → Login screen
    await tapWhenVisible(tester, loginEntry);

    // ── 3. Login with test credentials ──────────────────────────────────────
    expect(await pumpUntil(tester, find.byType(TextField)), isTrue,
        reason: 'Login screen email/password fields should appear');
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2)); // email + password
    await tester.enterText(fields.at(0), testEmail);
    await tester.enterText(fields.at(1), testPassword);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('دخول ←')); // login button
    await tester.pump(const Duration(milliseconds: 600));

    // ── 4. Home feed loads ──────────────────────────────────────────────────
    // The profile tab label ('حسابي') only exists on the Home scaffold's bottom
    // nav, so its presence confirms we reached Home (login succeeded).
    expect(await pumpUntil(tester, find.text('حسابي')), isTrue,
        reason: 'Login should land on Home (bottom nav visible). '
            'If this fails, verify the test user exists in Supabase.');

    // Home feed shows experiences — each card footer renders "<n> يستاهل".
    final firstCard = find.textContaining('يستاهل');
    expect(await pumpUntil(tester, firstCard), isTrue,
        reason: 'Home feed should contain at least one experience card');

    // ── 5. Open an experience detail ────────────────────────────────────────
    await tapWhenVisible(tester, firstCard); // tapping the card opens the detail overlay

    // The detail action row exposes both toggle buttons by label.
    final likeBtn = find.text('يستاهل'); // "worth it" / like
    final saveBtn = find.text('أود زيارته'); // "want to visit" / save
    expect(await pumpUntil(tester, saveBtn), isTrue,
        reason: 'Experience detail (action row) should be visible');

    // ── 6. يستاهل button toggles (tap twice to leave DB state unchanged) ─────
    await tapWhenVisible(tester, likeBtn);
    await tapWhenVisible(tester, likeBtn);

    // ── 7. أود زيارته button toggles ────────────────────────────────────────
    await tapWhenVisible(tester, saveBtn);
    await tapWhenVisible(tester, saveBtn);

    // Close the detail overlay (floating back button uses the caretRight icon).
    final backBtn = find.byIcon(PhosphorIcons.caretRight());
    if (await pumpUntil(tester, backBtn, timeout: const Duration(seconds: 5))) {
      await tester.tap(backBtn.first);
      await tester.pump(const Duration(milliseconds: 600));
    }

    // ── 8. Navigate to the Profile screen ───────────────────────────────────
    await tapWhenVisible(tester, find.text('حسابي'));
    expect(tester.takeException(), isNull);

    // ── 9. Navigate to the Search screen ────────────────────────────────────
    await tapWhenVisible(tester, find.text('استكشاف'));
    expect(tester.takeException(), isNull);

    // ── 10. Navigate to the Notifications screen ────────────────────────────
    await tapWhenVisible(tester, find.text('إشعارات'));
    expect(tester.takeException(), isNull);
  });
}
