-- MANUAL / DEVELOPMENT CLEANUP SCRIPT
-- DO NOT RUN ON PRODUCTION WITHOUT REVIEW
--
-- DEV ONLY: Remove incomplete phone signups (unconfirmed, no profile).
-- Run in Supabase SQL editor when a test number is stuck after failed OTP.
-- Replace the phone below before running.

-- Preview rows that would be deleted:
-- select u.id, u.phone, u.phone_confirmed_at, u.created_at
-- from auth.users u
-- left join public.profiles p on p.id = u.id
-- where p.id is null
--   and u.phone_confirmed_at is null
--   and u.phone is not null;

delete from auth.users u
where u.phone_confirmed_at is null
  and u.phone is not null
  and not exists (select 1 from public.profiles p where p.id = u.id)
  and (
    u.phone = '+9647756888722'
    or u.phone = '9647756888722'
  );
