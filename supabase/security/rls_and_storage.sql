-- ============================================================================
-- aishay app — Row Level Security + Storage policies
-- ============================================================================
-- HOW TO APPLY: paste into Supabase Dashboard → SQL Editor → Run, or apply via
-- the Supabase CLI. This file is the source of truth for the app's RLS posture;
-- keep it in sync with any dashboard changes.
--
-- ⚠️ NOT executed automatically by the app or by CI. A human must run it.
-- ⚠️ Apply on a STAGING project first and exercise register / invite / avatar
--    upload before promoting to production — enabling RLS without the right
--    policies locks those flows out.
--
-- Verified against the Flutter code on 2026-05-31:
--   • invite table is `invitation_codes`  (lib/invite_screen.dart, register_screen.dart)
--   • users rows are INSERTed on register + Google signup (register_screen.dart)
--   • avatars are uploaded to a FLAT path `<uid>.jpg` (lib/edit_profile_screen.dart:72)
-- ============================================================================

-- ── experiences ─────────────────────────────────────────────────────────────
ALTER TABLE experiences ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can read experiences" ON experiences;
DROP POLICY IF EXISTS "users can insert own experiences" ON experiences;
DROP POLICY IF EXISTS "users can update own experiences" ON experiences;
DROP POLICY IF EXISTS "users can delete own experiences" ON experiences;
CREATE POLICY "anyone can read experiences" ON experiences FOR SELECT USING (true);
CREATE POLICY "users can insert own experiences" ON experiences FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own experiences" ON experiences FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own experiences" ON experiences FOR DELETE USING (auth.uid() = user_id);

-- ── users ────────────────────────────────────────────────────────────────────
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can read users" ON users;
DROP POLICY IF EXISTS "users can insert own profile" ON users;
DROP POLICY IF EXISTS "users can update own profile" ON users;
CREATE POLICY "anyone can read users" ON users FOR SELECT USING (true);
-- Required: register + Google signup insert the user's own profile row.
-- CAVEAT: this passes only when a session exists at insert time (auth.uid() is
-- set). If "Confirm email" is ENABLED in Supabase Auth, signUp returns no
-- session, auth.uid() is NULL, and this INSERT is denied — the profile row then
-- has to be created post-confirmation (e.g. a DB trigger on auth.users, or after
-- first login). Disable email confirmation OR add such a trigger if registration
-- fails here.
CREATE POLICY "users can insert own profile" ON users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "users can update own profile" ON users FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ── likes ─────────────────────────────────────────────────────────────────────
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can read likes" ON likes;
DROP POLICY IF EXISTS "users can insert likes" ON likes;
DROP POLICY IF EXISTS "users can delete likes" ON likes;
CREATE POLICY "anyone can read likes" ON likes FOR SELECT USING (true);
CREATE POLICY "users can insert likes" ON likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can delete likes" ON likes FOR DELETE USING (auth.uid() = user_id);

-- ── saves ─────────────────────────────────────────────────────────────────────
ALTER TABLE saves ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can read saves" ON saves;
DROP POLICY IF EXISTS "users can insert saves" ON saves;
DROP POLICY IF EXISTS "users can delete saves" ON saves;
CREATE POLICY "anyone can read saves" ON saves FOR SELECT USING (true);
CREATE POLICY "users can insert saves" ON saves FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can delete saves" ON saves FOR DELETE USING (auth.uid() = user_id);

-- ── comments ──────────────────────────────────────────────────────────────────
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can read comments" ON comments;
DROP POLICY IF EXISTS "users can insert comments" ON comments;
DROP POLICY IF EXISTS "users can delete own comments" ON comments;
CREATE POLICY "anyone can read comments" ON comments FOR SELECT USING (true);
CREATE POLICY "users can insert comments" ON comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can delete own comments" ON comments FOR DELETE USING (auth.uid() = user_id);

-- ── follows ───────────────────────────────────────────────────────────────────
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can read follows" ON follows;
DROP POLICY IF EXISTS "users can follow" ON follows;
DROP POLICY IF EXISTS "users can unfollow" ON follows;
CREATE POLICY "anyone can read follows" ON follows FOR SELECT USING (true);
CREATE POLICY "users can follow" ON follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "users can unfollow" ON follows FOR DELETE USING (auth.uid() = follower_id);

-- ── notifications ─────────────────────────────────────────────────────────────
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users read own notifications" ON notifications;
DROP POLICY IF EXISTS "authenticated users can insert notifications" ON notifications;
DROP POLICY IF EXISTS "users can update own notifications" ON notifications;
CREATE POLICY "users read own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "authenticated users can insert notifications" ON notifications FOR INSERT WITH CHECK (auth.uid() = from_user_id);
CREATE POLICY "users can update own notifications" ON notifications FOR UPDATE USING (auth.uid() = user_id);

-- ── dishes ────────────────────────────────────────────────────────────────────
ALTER TABLE dishes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can read dishes" ON dishes;
DROP POLICY IF EXISTS "users can insert dishes" ON dishes;
CREATE POLICY "anyone can read dishes" ON dishes FOR SELECT USING (true);
CREATE POLICY "users can insert dishes" ON dishes FOR INSERT WITH CHECK (true);

-- ── restaurants ───────────────────────────────────────────────────────────────
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can read restaurants" ON restaurants;
DROP POLICY IF EXISTS "authenticated users can insert restaurants" ON restaurants;
CREATE POLICY "anyone can read restaurants" ON restaurants FOR SELECT USING (true);
CREATE POLICY "authenticated users can insert restaurants" ON restaurants FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ── invitation_codes ──────────────────────────────────────────────────────────
-- The invite screen (unauthenticated) SELECTs by code; register UPDATEs is_used.
-- SELECT/UPDATE are open (USING true) because the invite screen runs before the
-- user has a session. NOTE: this lets anyone flip is_used — acceptable for an
-- invite gate, but tighten with a SECURITY DEFINER RPC if abuse is a concern.
ALTER TABLE invitation_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anyone can read invitation_codes" ON invitation_codes;
DROP POLICY IF EXISTS "anyone can update invitation_codes" ON invitation_codes;
CREATE POLICY "anyone can read invitation_codes" ON invitation_codes FOR SELECT USING (true);
CREATE POLICY "anyone can update invitation_codes" ON invitation_codes FOR UPDATE USING (true);

-- ============================================================================
-- STORAGE policies (buckets: avatars, photos)
-- ============================================================================
-- Avatars are stored FLAT as `<uid>.jpg` at the bucket root (NOT `<uid>/file`),
-- per lib/edit_profile_screen.dart:72. Ownership is therefore the filename stem
-- (`split_part(name,'.',1)`), not a folder. uploadBinary uses upsert:true, so a
-- re-upload is an UPDATE — both INSERT and UPDATE must allow the owner.
DROP POLICY IF EXISTS "users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "anyone can view avatars" ON storage.objects;
DROP POLICY IF EXISTS "users can update own avatar" ON storage.objects;

CREATE POLICY "users can upload own avatar"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'avatars' AND split_part(name, '.', 1) = auth.uid()::text);

CREATE POLICY "anyone can view avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "users can update own avatar"
ON storage.objects FOR UPDATE
USING (bucket_id = 'avatars' AND split_part(name, '.', 1) = auth.uid()::text)
WITH CHECK (bucket_id = 'avatars' AND split_part(name, '.', 1) = auth.uid()::text);

-- Photos: experience images. Any authenticated user may upload; public read.
DROP POLICY IF EXISTS "authenticated users can upload photos" ON storage.objects;
DROP POLICY IF EXISTS "anyone can view photos" ON storage.objects;

CREATE POLICY "authenticated users can upload photos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'photos' AND auth.uid() IS NOT NULL);

CREATE POLICY "anyone can view photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'photos');
