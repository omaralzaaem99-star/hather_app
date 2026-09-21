-- 016: Central technical support settings (app_settings extension)
-- Apply AFTER 015_captain_order_acceptance.sql

-- ---------------------------------------------------------------------------
-- 1) Extend app_settings singleton
-- ---------------------------------------------------------------------------
alter table public.app_settings
  add column if not exists whatsapp_enabled boolean not null default false,
  add column if not exists whatsapp_number text,
  add column if not exists phone_enabled boolean not null default false,
  add column if not exists phone_number text,
  add column if not exists email_enabled boolean not null default false,
  add column if not exists email_address text,
  add column if not exists support_message text;

-- ---------------------------------------------------------------------------
-- 2) Phone normalization helper (Iraqi mobile → E.164)
-- ---------------------------------------------------------------------------
create or replace function public._normalize_iraq_phone_e164(p_raw text)
returns text
language plpgsql
immutable
as $$
declare
  v text;
begin
  if p_raw is null or btrim(p_raw) = '' then
    return null;
  end if;

  v := regexp_replace(btrim(p_raw), '[\s\-\(\)]', '', 'g');

  if v like '+%' then
    v := substring(v from 2);
  end if;
  if v like '00%' then
    v := substring(v from 3);
  end if;
  if v like '964%' then
    v := substring(v from 4);
  end if;
  if v like '0%' then
    v := substring(v from 2);
  end if;

  if v ~ '^7\d{9}$' then
    return '+964' || v;
  end if;

  return null;
end;
$$;

revoke all on function public._normalize_iraq_phone_e164(text) from public;

-- ---------------------------------------------------------------------------
-- 3) Admin read support settings
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_support_settings()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.app_settings;
begin
  perform public.require_dashboard_admin();

  select * into s from public.app_settings where id = 1;
  if s.id is null then
    insert into public.app_settings (id) values (1)
    returning * into s;
  end if;

  return jsonb_build_object(
    'whatsapp_enabled', s.whatsapp_enabled,
    'whatsapp_number', s.whatsapp_number,
    'phone_enabled', s.phone_enabled,
    'phone_number', s.phone_number,
    'email_enabled', s.email_enabled,
    'email_address', s.email_address,
    'support_message', s.support_message,
    'updated_at', s.updated_at,
    'updated_by', s.updated_by
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Admin update support settings
-- ---------------------------------------------------------------------------
create or replace function public.admin_update_support_settings(
  p_whatsapp_enabled boolean,
  p_whatsapp_number text,
  p_phone_enabled boolean,
  p_phone_number text,
  p_email_enabled boolean,
  p_email_address text,
  p_support_message text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.app_settings;
  v_whatsapp text;
  v_phone text;
  v_email text;
  v_message text;
begin
  perform public.require_dashboard_admin();

  if p_whatsapp_enabled is null
    or p_phone_enabled is null
    or p_email_enabled is null then
    raise exception 'enabled flags required' using errcode = '22023';
  end if;

  v_whatsapp := public._normalize_iraq_phone_e164(p_whatsapp_number);
  v_phone := public._normalize_iraq_phone_e164(p_phone_number);
  v_email := nullif(lower(btrim(coalesce(p_email_address, ''))), '');
  v_message := nullif(btrim(coalesce(p_support_message, '')), '');

  if p_whatsapp_enabled and v_whatsapp is null then
    raise exception 'whatsapp number required when whatsapp is enabled' using errcode = '22023';
  end if;

  if p_phone_enabled and v_phone is null then
    raise exception 'phone number required when phone is enabled' using errcode = '22023';
  end if;

  if p_email_enabled then
    if v_email is null then
      raise exception 'email required when email is enabled' using errcode = '22023';
    end if;
    if v_email !~ '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$' then
      raise exception 'invalid email address' using errcode = '22023';
    end if;
  end if;

  if v_message is not null and char_length(v_message) > 500 then
    raise exception 'support_message must be at most 500 characters' using errcode = '22023';
  end if;

  insert into public.app_settings (
    id,
    whatsapp_enabled,
    whatsapp_number,
    phone_enabled,
    phone_number,
    email_enabled,
    email_address,
    support_message,
    updated_at,
    updated_by
  ) values (
    1,
    p_whatsapp_enabled,
    case when p_whatsapp_enabled then v_whatsapp else null end,
    p_phone_enabled,
    case when p_phone_enabled then v_phone else null end,
    p_email_enabled,
    case when p_email_enabled then v_email else null end,
    v_message,
    now(),
    auth.uid()
  )
  on conflict (id) do update
    set
      whatsapp_enabled = excluded.whatsapp_enabled,
      whatsapp_number = excluded.whatsapp_number,
      phone_enabled = excluded.phone_enabled,
      phone_number = excluded.phone_number,
      email_enabled = excluded.email_enabled,
      email_address = excluded.email_address,
      support_message = excluded.support_message,
      updated_at = excluded.updated_at,
      updated_by = excluded.updated_by
  returning * into s;

  return jsonb_build_object(
    'whatsapp_enabled', s.whatsapp_enabled,
    'whatsapp_number', s.whatsapp_number,
    'phone_enabled', s.phone_enabled,
    'phone_number', s.phone_number,
    'email_enabled', s.email_enabled,
    'email_address', s.email_address,
    'support_message', s.support_message,
    'updated_at', s.updated_at,
    'updated_by', s.updated_by
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) App read (authenticated users + captains)
-- ---------------------------------------------------------------------------
create or replace function public.get_support_settings()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.app_settings;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select * into s from public.app_settings where id = 1;
  if s.id is null then
    return jsonb_build_object(
      'whatsapp_enabled', false,
      'whatsapp_number', null,
      'phone_enabled', false,
      'phone_number', null,
      'email_enabled', false,
      'email_address', null,
      'support_message', null
    );
  end if;

  return jsonb_build_object(
    'whatsapp_enabled', coalesce(s.whatsapp_enabled, false),
    'whatsapp_number', case
      when s.whatsapp_enabled and s.whatsapp_number is not null then s.whatsapp_number
      else null
    end,
    'phone_enabled', coalesce(s.phone_enabled, false),
    'phone_number', case
      when s.phone_enabled and s.phone_number is not null then s.phone_number
      else null
    end,
    'email_enabled', coalesce(s.email_enabled, false),
    'email_address', case
      when s.email_enabled and s.email_address is not null then s.email_address
      else null
    end,
    'support_message', s.support_message
  );
end;
$$;

revoke all on function public.admin_get_support_settings() from public;
revoke all on function public.admin_update_support_settings(
  boolean, text, boolean, text, boolean, text, text
) from public;
revoke all on function public.get_support_settings() from public;

grant execute on function public.admin_get_support_settings() to authenticated;
grant execute on function public.admin_update_support_settings(
  boolean, text, boolean, text, boolean, text, text
) to authenticated;
grant execute on function public.get_support_settings() to authenticated;
