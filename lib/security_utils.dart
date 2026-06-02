/// Lightweight client-side input hardening helpers.
///
/// IMPORTANT: client-side validation is UX + defense-in-depth only. It can be
/// bypassed trivially (modified client, direct API calls). Authoritative
/// enforcement MUST live in the database: Row Level Security + column
/// constraints. See `supabase/security/rls_and_storage.sql`.
library;

/// Max lengths shared between UI fields and submit-time validation.
const int kMaxTitleLength = 80;
const int kMaxDescriptionLength = 500;
const int kMaxDishNameLength = 50;
const int kMaxNameLength = 50;
const int kMaxUsernameLength = 30;
const int kMaxBioLength = 200;

/// Strips HTML tags and stray angle brackets, then trims.
String sanitizeInput(String input) {
  return input
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'[<>]'), '')
      .trim();
}

/// Sanitizes [input] and hard-caps it to [max] characters.
String sanitizeAndCap(String input, int max) {
  final cleaned = sanitizeInput(input);
  return cleaned.length > max ? cleaned.substring(0, max) : cleaned;
}

final RegExp _emailRegExp = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

/// Basic RFC-ish email shape check (not a full validator).
bool isValidEmail(String email) => _emailRegExp.hasMatch(email.trim());

final RegExp _usernameRegExp = RegExp(r'^[A-Za-z0-9_]+$');

/// Username may contain only letters, numbers and underscores.
bool isValidUsername(String username) =>
    _usernameRegExp.hasMatch(username.trim());

/// Starter profanity list (Arabic + English). Intentionally small — replace
/// with a maintained list or, better, server-side moderation. Matching is a
/// naive case-insensitive substring check.
const List<String> _blockedWords = <String>[
  // English
  'fuck', 'shit', 'bitch', 'asshole', 'cunt',
  // Arabic
  'لعنة', 'حقير', 'وسخ',
];

/// Returns true if [text] contains any blocked word.
bool containsProfanity(String text) {
  final lower = text.toLowerCase();
  return _blockedWords.any((w) => lower.contains(w.toLowerCase()));
}
