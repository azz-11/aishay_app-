# Test Results — أي شيء (aishay) app

_Generated: 2026-05-31_

## How to read this

The automated suite lives in `test/app_test.dart`. Run it with:

```bash
flutter test
flutter analyze
```

**Honesty note:** This app talks to Supabase directly from inside its widgets
(`Supabase.instance.client`), with no dependency injection and no fake/mock
client. That means the bulk of the requested checklist — auth, experiences,
likes/saves, follows, notifications, profile edits, search — **cannot be
verified by offline unit tests**. Those flows are implemented in code and they
compile, but "compiles" is not "works". Verifying them for real requires either:

1. an `integration_test/` suite run on a device/emulator against a test Supabase
   project, or
2. refactoring the data access behind an interface so a fake can be injected.

Below, only items proven by a running assertion (or by the analyzer) are marked
✅. Everything that is coded but unproven is ⚠️ — not ✅.

---

## ✅ What works (verified by automation)

| Item | How it's verified |
|------|-------------------|
| **Static analysis is clean** | `flutter analyze` → **0 errors, 0 warnings** |
| **Localization (`AppLocale`)** | Unit tests: Arabic default, English toggle, key fallback |
| **Invite-code validation (empty-code branch)** | Widget test: tapping "تحقق" with an empty field shows `أدخل رمز الدعوة` (runs fully client-side, no backend) |
| **Test suite runs green** | `flutter test` → 4 passed, 28 skipped, 0 failed |

---

## ⚠️ Partially working (implemented in code, NOT verified by tests)

These have real implementations that compile and look correct on review, but no
automated test asserts their runtime behaviour. They are registered as
`skip:`-ped tests in `app_test.dart` as a living checklist. **Verify manually or
via `integration_test` before trusting.**

### Auth
- ⚠️ Invite code checked against `invitation_codes` (the Supabase lookup branch)
- ⚠️ Register with valid invite code (`auth.signUp` + `users` insert + mark code used)
- ⚠️ Login with email/password / ⚠️ login rejects wrong credentials

### Experiences
- ⚠️ Create experience with all fields
- ⚠️ New experience appears in home feed
- ⚠️ Photo upload to storage + URL persistence
- ⚠️ Dishes save with correct data
- ⚠️ Title and `visit_time` persist

### Social
- ⚠️ Like / unlike toggle + ⚠️ persistence on reopen
- ⚠️ Save / unsave toggle + ⚠️ persistence on reopen
- ⚠️ Follow / unfollow + ⚠️ followers count updates

### Notifications
- ⚠️ Notification rows created on like / save / follow / comment
- ⚠️ Tapping a notification navigates to the right screen
  - _Note: navigation handler `_onTapNotification` was added this session and
    compiles; the like/save/comment path fetches the experience from Supabase
    first, so it needs a backend/fake to assert the resulting route._

### Profile
- ⚠️ Profile loads / ⚠️ edit saves name, bio, city / ⚠️ avatar upload
- ⚠️ Followers/following counts display

### Search
- ⚠️ Experiences / Restaurants / Users tabs populate from their tables
- ⚠️ Debounced query filters the active tab
  - _Rewritten this session; logic reviewed but not runtime-tested._

---

## ❌ Gaps / things that need fixing

| # | Issue | Impact | Suggested fix |
|---|-------|--------|---------------|
| 1 | **No integration-test harness & no DI** | The whole checklist above can't be automated | Add `integration_test/` against a test Supabase project, OR put data access behind a repository interface for fakes |
| 2 | **Google Sign-In is not functional yet** | Button throws (red snackbar) on tap | `webClientId` is still the `YOUR_GOOGLE_CLIENT_ID` placeholder; Google provider must be enabled in Supabase + OAuth client/redirect configured in Google Cloud |
| 3 | **135 `info`-level analyzer lints remain** | Cosmetic / future-proofing; not errors | 47× deprecated `withOpacity` → `.withValues()`; 1× deprecated `activeColor` → `activeThumbColor`; 82× `unnecessary_underscores` in callback params |
| 4 | **Stale default `widget_test.dart` removed** | It was the Flutter counter template and failed against this app | Replaced by `test/app_test.dart` (done this session) |
| 5 | **`avg_rating` column dependency (search)** | Restaurants tab errors if the column is absent | Confirm `restaurants.avg_rating` exists in the schema |

---

## Fixes applied this session

- Removed 9 analyzer **warnings** (dead code + redundant casts):
  - unused `_kDark` (`add_experience_screen.dart`), `_cCardBg` (`comments_section.dart`),
    `_stars` (`experience_detail_screen.dart`, `profile_screen.dart`), `_tabIndex` field (`profile_screen.dart`)
  - unnecessary casts in `add_experience_screen.dart` (×3) and `home_screen.dart` (×1)
- Deleted the stale `widget_test.dart` counter template.
- Added `test/app_test.dart` (4 real tests + 28-item skipped checklist).

## Suggested next step

If you want the ⚠️ items turned into real ✅ coverage, the highest-leverage move
is an `integration_test` smoke flow on an emulator: launch → invite → register →
create experience → like → check notification. That single path exercises most
of the checklist against a real (test) backend. I can scaffold it on request.
