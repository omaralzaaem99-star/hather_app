-- 007: Remove legacy custom OTP system (after Phone Auth + auth-send-sms is live).
-- SAFE: does not touch auth.users, profiles, delivery_orders, or any user UUIDs.
-- Apply in Supabase SQL Editor after confirming app no longer calls send-otp/verify-otp.

-- ---------------------------------------------------------------------------
-- Pre-drop safety: these objects have no FKs from app tables in this repo.
-- otp_codes / otp_send_log were standalone; is_phone_taken does not depend on them.
-- ---------------------------------------------------------------------------

drop table if exists public.otp_codes cascade;
drop table if exists public.otp_send_log cascade;

drop function if exists public.is_phone_taken(text);

-- ensure_own_profile / convert_profile_to_captain / profiles remain intact.
