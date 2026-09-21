-- Hather profiles table for auth (registration; OTP comes later).
-- Apply in Supabase SQL Editor. Do NOT run from the Flutter app.
-- Never use service_role in the mobile client.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  phone text not null unique,
  account_type text not null default 'user'
    check (account_type in ('user', 'captain')),
  account_status text not null default 'active'
    check (account_status in ('active', 'pending', 'suspended', 'disabled')),
  phone_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_phone_idx on public.profiles (phone);
create index if not exists profiles_account_type_idx on public.profiles (account_type);

alter table public.profiles enable row level security;

-- Users can read their own profile.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id);

-- Users can insert their own profile row (id must match auth.uid()).
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check (
    auth.uid() = id
    and account_type = 'user'
    and account_status = 'active'
  );

-- Users can update safe fields on their own profile (not account_type/status).
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (
    auth.uid() = id
    and account_type = 'user'
  );

-- Public phone uniqueness check (no profile rows leaked).
create or replace function public.is_phone_taken(p_phone text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where phone = p_phone
  );
$$;

revoke all on function public.is_phone_taken(text) from public;
grant execute on function public.is_phone_taken(text) to anon, authenticated;

-- Optional: keep updated_at fresh.
create or replace function public.set_profiles_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute function public.set_profiles_updated_at();

-- Dashboard notes:
-- 1) Authentication → Providers → Email: enable Email, disable Confirm email.
-- 2) Do NOT enable Phone Provider for login (app uses @hather.local emails).
-- 3) OTP via Edge Functions → OTPIQ (secret OTPIQ_API_TOKEN).
-- 4) Apply 003_otp_codes.sql for OTP storage/verification.
--
-- After signup+OTP verify:
--   Auth user email = 9647...@hather.local
--   profiles.phone = +9647XXXXXXXXX, phone_verified = true

