// Comprehensive test suite + living checklist for the "أي شيء" (aishay) app.
//
// IMPORTANT — read this before assuming green = "everything works":
//
// Most of this app's behaviour (auth, experiences, likes/saves, follows,
// notifications, profile edits, search) runs *inside StatefulWidgets that call
// `Supabase.instance.client` directly*. There is no dependency injection and no
// mock/fake Supabase client wired up, so those flows cannot be exercised by an
// offline `flutter test` unit test. Verifying them for real needs ONE of:
//   1. an `integration_test/` suite run on a device/emulator against a (test)
//      Supabase project, or
//   2. refactoring the data layer behind an interface so a fake can be injected.
//
// Rather than fake green checkmarks, the backend-dependent items below are
// registered as `skip:`-ped tests that document exactly what to verify and how.
// They show up in `flutter test` output as a checklist. The tests that DO run
// (i18n + offline invite-code validation) assert real app code.
//
// See test_results.md for the full status breakdown.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aishay_app/app_locale.dart';
import 'package:aishay_app/invite_screen.dart';

const _needsBackend =
    'Integration behaviour against live Supabase — cover via integration_test '
    'on device or by injecting a fake client. See test_results.md.';

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // i18n — pure, fully unit-testable
  // ───────────────────────────────────────────────────────────────────────────
  group('AppLocale (localization)', () {
    test('defaults to Arabic and resolves Arabic strings', () {
      AppLocale.notifier.value = true;
      expect(AppLocale.isArabic, isTrue);
      expect(AppLocale.t('home'), 'الرئيسية');
      expect(AppLocale.t('profile'), 'حسابي');
      expect(AppLocale.t('notifications'), 'إشعارات');
    });

    test('resolves English strings when toggled to non-Arabic', () {
      AppLocale.notifier.value = false;
      expect(AppLocale.isArabic, isFalse);
      expect(AppLocale.t('home'), 'Home');
      expect(AppLocale.t('explore'), 'Explore');
      AppLocale.notifier.value = true; // restore default for other tests
    });

    test('falls back to the raw key for unknown keys', () {
      AppLocale.notifier.value = true;
      expect(AppLocale.t('this_key_does_not_exist'), 'this_key_does_not_exist');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // AUTH
  // ───────────────────────────────────────────────────────────────────────────
  group('AUTH', () {
    testWidgets('Invite code validation: empty code shows an inline error',
        (tester) async {
      // Use a phone-sized surface; the default 800x600 test window is shorter
      // than any real device and makes this screen's Column overflow.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: InviteScreen()));
      await tester.pumpAndSettle();

      // The invite gate renders.
      expect(find.text('عندك دعوة؟'), findsOneWidget);

      // Tapping "verify" with an empty field must surface a validation error
      // (this branch runs entirely client-side, before any Supabase call).
      await tester.tap(find.text('تحقق من الرمز ←'));
      await tester.pump(); // let setState rebuild
      expect(find.text('أدخل رمز الدعوة'), findsOneWidget);
    });

    test('Invite code validation against invitation_codes table', () {},
        skip: _needsBackend);
    test('User can register with a valid invite code', () {}, skip: _needsBackend);
    test('User can login with email/password', () {}, skip: _needsBackend);
    test('Login fails with wrong credentials', () {}, skip: _needsBackend);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // EXPERIENCES
  // ───────────────────────────────────────────────────────────────────────────
  group('EXPERIENCES', () {
    test('Create experience with all fields', () {}, skip: _needsBackend);
    test('New experience appears in home feed', () {}, skip: _needsBackend);
    test('Photos upload to storage and URLs persist', () {}, skip: _needsBackend);
    test('Dishes save with correct data', () {}, skip: _needsBackend);
    test('Title and visit_time persist correctly', () {}, skip: _needsBackend);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SOCIAL
  // ───────────────────────────────────────────────────────────────────────────
  group('SOCIAL', () {
    test('Like / unlike toggles correctly', () {}, skip: _needsBackend);
    test('Save / unsave toggles correctly', () {}, skip: _needsBackend);
    test('Like state persists on reopen', () {}, skip: _needsBackend);
    test('Save state persists on reopen', () {}, skip: _needsBackend);
    test('Follow / unfollow works', () {}, skip: _needsBackend);
    test('Followers count updates after follow', () {}, skip: _needsBackend);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // NOTIFICATIONS
  // ───────────────────────────────────────────────────────────────────────────
  group('NOTIFICATIONS', () {
    test('Notification created on like', () {}, skip: _needsBackend);
    test('Notification created on save', () {}, skip: _needsBackend);
    test('Notification created on follow', () {}, skip: _needsBackend);
    test('Notification created on comment', () {}, skip: _needsBackend);
    // The navigation handler itself (_onTapNotification) is pure routing logic,
    // but it fetches the experience from Supabase before pushing, so it still
    // needs a backend/fake to assert the resulting route.
    test('Tapping a notification navigates to the correct screen', () {},
        skip: _needsBackend);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // PROFILE
  // ───────────────────────────────────────────────────────────────────────────
  group('PROFILE', () {
    test('Profile loads correctly', () {}, skip: _needsBackend);
    test('Edit profile saves name, bio, city', () {}, skip: _needsBackend);
    test('Avatar upload works', () {}, skip: _needsBackend);
    test('Followers / following counts display correctly', () {},
        skip: _needsBackend);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SEARCH
  // ───────────────────────────────────────────────────────────────────────────
  group('SEARCH', () {
    test('Experiences tab shows experiences', () {}, skip: _needsBackend);
    test('Restaurants tab shows restaurants', () {}, skip: _needsBackend);
    test('Users tab shows users', () {}, skip: _needsBackend);
    test('Search query filters results (debounced)', () {}, skip: _needsBackend);
  });
}
