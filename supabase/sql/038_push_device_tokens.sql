-- 038: Push device token registry for FCM device sync.
-- Depends on: auth.users
-- Flutter registers via RPC only; Edge Function reads tokens with service role.

-- ---------------------------------------------------------------------------
-- 1) Table
-- ---------------------------------------------------------------------------
create table if not exists public.push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  installation_id uuid not null,
  fcm_token text not null,
  platform text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint push_device_tokens_platform_chk check (platform in ('android', 'ios')),
  constraint push_device_tokens_installation_id_key unique (installation_id),
  constraint push_device_tokens_fcm_token_key unique (fcm_token)
);

create index if not exists push_device_tokens_user_active_idx
  on public.push_device_tokens (user_id)
  where is_active = true;

alter table public.push_device_tokens enable row level security;

revoke all on table public.push_device_tokens from public;
revoke all on table public.push_device_tokens from anon;
revoke all on table public.push_device_tokens from authenticated;

-- Server-oriented: no client SELECT/INSERT/UPDATE policies.

-- ---------------------------------------------------------------------------
-- 2) Upsert current device (authenticated user only)
-- ---------------------------------------------------------------------------
create or replace function public.upsert_my_push_device(
  p_installation_id uuid,
  p_fcm_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text := btrim(coalesce(p_fcm_token, ''));
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_installation_id is null or v_token = '' then
    raise exception 'installation_id and fcm_token required' using errcode = '22023';
  end if;

  if p_platform not in ('android', 'ios') then
    raise exception 'invalid platform' using errcode = '22023';
  end if;

  -- Same physical token cannot stay active on a different installation.
  update public.push_device_tokens
  set
    is_active = false,
    updated_at = now()
  where fcm_token = v_token
    and installation_id <> p_installation_id;

  insert into public.push_device_tokens (
    user_id,
    installation_id,
    fcm_token,
    platform,
    is_active,
    last_seen_at
  )
  values (
    auth.uid(),
    p_installation_id,
    v_token,
    p_platform,
    true,
    now()
  )
  on conflict (installation_id) do update
  set
    user_id = auth.uid(),
    fcm_token = excluded.fcm_token,
    platform = excluded.platform,
    is_active = true,
    updated_at = now(),
    last_seen_at = now();
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Deactivate on logout (authenticated user only)
-- ---------------------------------------------------------------------------
create or replace function public.deactivate_my_push_device(
  p_installation_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_installation_id is null then
    return;
  end if;

  update public.push_device_tokens
  set
    is_active = false,
    updated_at = now()
  where installation_id = p_installation_id
    and user_id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Server: deactivate invalid FCM token (Edge Function / service role)
-- ---------------------------------------------------------------------------
create or replace function public.deactivate_push_device_token(
  p_fcm_token text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text := btrim(coalesce(p_fcm_token, ''));
  n int;
begin
  if v_token = '' then
    return false;
  end if;

  update public.push_device_tokens
  set
    is_active = false,
    updated_at = now()
  where fcm_token = v_token
    and is_active = true;

  get diagnostics n = row_count;
  return n > 0;
end;
$$;

revoke all on function public.upsert_my_push_device(uuid, text, text) from public;
revoke all on function public.deactivate_my_push_device(uuid) from public;
revoke all on function public.deactivate_push_device_token(text) from public;

grant execute on function public.upsert_my_push_device(uuid, text, text) to authenticated;
grant execute on function public.deactivate_my_push_device(uuid) to authenticated;
grant execute on function public.deactivate_push_device_token(text) to service_role;

-- ---------------------------------------------------------------------------
-- 5) Push dispatch wiring
-- ---------------------------------------------------------------------------
-- Automatic: apply 039_user_notifications_push_dispatch.sql (pg_net + Vault).
-- Manual fallback: call dispatch-notification-push with x-hather-push-webhook-secret.
