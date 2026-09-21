-- 017: Support phone persistence + admin local format fixes
-- Apply AFTER 016_support_settings.sql

-- ---------------------------------------------------------------------------
-- 1) Improve normalization (Arabic digits + common Iraqi formats)
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
  v := translate(v, '٠١٢٣٤٥٦٧٨٩', '0123456789');

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

-- ---------------------------------------------------------------------------
-- 2) Admin update — preserve numbers when toggles OFF; never wipe silently
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
  s_existing public.app_settings;
  v_whatsapp text;
  v_phone text;
  v_email text;
  v_message text;
  v_whatsapp_raw text;
  v_phone_raw text;
  v_email_raw text;
begin
  perform public.require_dashboard_admin();

  if p_whatsapp_enabled is null
    or p_phone_enabled is null
    or p_email_enabled is null then
    raise exception 'enabled flags required' using errcode = '22023';
  end if;

  select * into s_existing from public.app_settings where id = 1;

  v_whatsapp_raw := nullif(btrim(coalesce(p_whatsapp_number, '')), '');
  v_phone_raw := nullif(btrim(coalesce(p_phone_number, '')), '');
  v_email_raw := nullif(lower(btrim(coalesce(p_email_address, ''))), '');
  v_message := nullif(btrim(coalesce(p_support_message, '')), '');

  if v_whatsapp_raw is not null then
    v_whatsapp := public._normalize_iraq_phone_e164(v_whatsapp_raw);
    if v_whatsapp is null then
      raise exception 'invalid iraqi phone number for whatsapp' using errcode = '22023';
    end if;
  else
    v_whatsapp := s_existing.whatsapp_number;
  end if;

  if v_phone_raw is not null then
    v_phone := public._normalize_iraq_phone_e164(v_phone_raw);
    if v_phone is null then
      raise exception 'invalid iraqi phone number for phone' using errcode = '22023';
    end if;
  else
    v_phone := s_existing.phone_number;
  end if;

  if v_email_raw is not null then
    v_email := v_email_raw;
    if v_email !~ '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$' then
      raise exception 'invalid email address' using errcode = '22023';
    end if;
  else
    v_email := s_existing.email_address;
  end if;

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
    v_whatsapp,
    p_phone_enabled,
    v_phone,
    p_email_enabled,
    v_email,
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

revoke all on function public.admin_update_support_settings(
  boolean, text, boolean, text, boolean, text, text
) from public;
grant execute on function public.admin_update_support_settings(
  boolean, text, boolean, text, boolean, text, text
) to authenticated;
