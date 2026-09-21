-- OTP codes for OTPIQ verification flow.
-- Codes are generated in Edge Function send-otp and checked in verify-otp.
-- Apply in Supabase SQL Editor. Never store OTPIQ API keys in Flutter.

create table if not exists public.otp_codes (
  id uuid primary key default gen_random_uuid(),
  phone_number text not null,
  code text not null,
  purpose text not null default 'registration',
  expires_at timestamptz not null,
  is_used boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists otp_codes_phone_created_idx
  on public.otp_codes (phone_number, created_at desc);

create index if not exists otp_codes_active_idx
  on public.otp_codes (phone_number, is_used, expires_at);

alter table public.otp_codes enable row level security;

-- Only service role (Edge Functions) should access this table.
-- No policies for anon/authenticated.
