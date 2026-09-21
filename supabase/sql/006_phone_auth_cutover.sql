-- 006: Native Phone Auth cutover support
-- Apply in Supabase SQL Editor AFTER enabling Phone Provider + Send SMS Hook.
-- Does NOT delete otp_codes / otp_send_log (rollback safety) — revokes client access.
-- Does NOT modify auth.users IDs.

-- ---------------------------------------------------------------------------
-- 1) Ensure own profile from authenticated phone (server-side phone source)
-- ---------------------------------------------------------------------------
create or replace function public.ensure_own_profile(p_full_name text)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  phone_val text;
  name_val text := nullif(trim(coalesce(p_full_name, '')), '');
  updated_row public.profiles;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  if name_val is null or char_length(name_val) < 2 then
    raise exception 'invalid full_name';
  end if;

  -- Prefer JWT phone claim; fall back to auth.users.phone
  phone_val := nullif(auth.jwt() ->> 'phone', '');
  if phone_val is null then
    select nullif(u.phone, '') into phone_val
    from auth.users u
    where u.id = uid;
  end if;

  if phone_val is null then
    raise exception 'phone missing on auth user';
  end if;

  -- Normalize to +9647XXXXXXXXX when possible
  phone_val := regexp_replace(phone_val, '[^0-9+]', '', 'g');
  if left(phone_val, 1) <> '+' then
    if phone_val ~ '^9647[0-9]{9}$' then
      phone_val := '+' || phone_val;
    elsif phone_val ~ '^07[0-9]{9}$' then
      phone_val := '+964' || substr(phone_val, 2);
    elsif phone_val ~ '^7[0-9]{9}$' then
      phone_val := '+964' || phone_val;
    end if;
  end if;

  insert into public.profiles as p (
    id,
    full_name,
    phone,
    account_type,
    account_status,
    phone_verified,
    created_at,
    updated_at
  )
  values (
    uid,
    name_val,
    phone_val,
    'user',
    'active',
    true,
    now(),
    now()
  )
  on conflict (id) do update
    set
      full_name = excluded.full_name,
      phone = excluded.phone,
      phone_verified = true,
      updated_at = now()
  returning * into updated_row;

  return updated_row;
end;
$$;

revoke all on function public.ensure_own_profile(text) from public;
grant execute on function public.ensure_own_profile(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Harden profiles RLS — clients cannot freely set security fields
-- ---------------------------------------------------------------------------
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_update_full_name_own" on public.profiles;
drop policy if exists "profiles_select_own" on public.profiles;

create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id);

-- Direct client insert disabled — use ensure_own_profile().
-- Update allowed for own row; trigger locks security columns.
create policy "profiles_update_own_safe"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create or replace function public.enforce_profile_secure_columns()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    -- Lock security columns for direct client updates only.
    -- SECURITY DEFINER RPCs (postgres/supabase_admin) may change them.
    if current_user = 'authenticated' then
      new.id := old.id;
      new.phone := old.phone;
      new.account_type := old.account_type;
      new.account_status := old.account_status;
      new.phone_verified := old.phone_verified;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_enforce_secure_columns on public.profiles;
create trigger profiles_enforce_secure_columns
  before update on public.profiles
  for each row
  execute function public.enforce_profile_secure_columns();

-- Note: ensure_own_profile is SECURITY DEFINER and bypasses RLS for upsert.

-- ---------------------------------------------------------------------------
-- 3) Stop public account enumeration via is_phone_taken
-- ---------------------------------------------------------------------------
revoke all on function public.is_phone_taken(text) from public;
revoke all on function public.is_phone_taken(text) from anon;
revoke all on function public.is_phone_taken(text) from authenticated;
-- Keep function definition for emergency/admin use; no client execute.

-- ---------------------------------------------------------------------------
-- 4) Deprecate custom OTP tables (do not DROP yet)
-- ---------------------------------------------------------------------------
-- Ensure RLS on; no policies for anon/authenticated (service role only if needed).
alter table if exists public.otp_codes enable row level security;
alter table if exists public.otp_send_log enable row level security;

comment on table public.otp_codes is
  'DEPRECATED — OTP managed by Supabase Auth. Do not use from app/Edge.';
comment on table public.otp_send_log is
  'DEPRECATED — unused legacy rate-limit log.';

-- ---------------------------------------------------------------------------
-- 5) Preflight helpers (read-only counts for operators)
-- ---------------------------------------------------------------------------
-- Run manually:
--   select count(*) from auth.users;
--   select count(*) from auth.users where email ilike '%@hather.local';
--   select count(*) from public.profiles;
--   select count(*) from public.profiles p
--     join auth.users u on u.id = p.id;
--   select phone, count(*) from public.profiles group by phone having count(*) > 1;
--   select count(*) from public.profiles where phone is null or phone = '';
