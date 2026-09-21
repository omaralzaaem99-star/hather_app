-- DEPRECATED for OTPIQ flow.
-- Resend cooldown now uses public.otp_codes (see 003_otp_codes.sql).
-- Keep this file only if you still need legacy AHYXI rate-limit logs.

-- Rate-limit log (legacy). Prefer otp_codes.created_at for cooldown.

create table if not exists public.otp_send_log (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  purpose text not null default 'registration',
  created_at timestamptz not null default now()
);

create index if not exists otp_send_log_phone_created_idx
  on public.otp_send_log (phone, created_at desc);

alter table public.otp_send_log enable row level security;
