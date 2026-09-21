-- 043: Home ads — open-ended duration + UTC date-only scheduling.
-- Requires: 042 (subscription/action/duration).

create or replace function public._normalize_home_ad_date(p_ts timestamptz)
returns timestamptz
language sql
immutable
as $$
  select case
    when p_ts is null then
      (date_trunc('day', now() at time zone 'utc') + interval '12 hours') at time zone 'utc'
    else
      (date_trunc('day', p_ts at time zone 'utc') + interval '12 hours') at time zone 'utc'
  end;
$$;

create or replace function public._validate_home_ad_duration(
  p_duration_days integer
)
returns integer
language plpgsql
immutable
as $$
declare
  v_days integer;
begin
  if p_duration_days is null then
    return null;
  end if;

  v_days := p_duration_days;

  if v_days < 30 or v_days > 365 then
    raise exception 'مدة الإعلان يجب أن تكون بين 30 و 365 يوماً' using errcode = '22023';
  end if;

  return v_days;
end;
$$;

create or replace function public._home_ad_schedule(
  p_starts_at timestamptz,
  p_duration_days integer
)
returns table(starts_at timestamptz, expires_at timestamptz)
language plpgsql
immutable
as $$
declare
  v_starts timestamptz := public._normalize_home_ad_date(p_starts_at);
  v_days integer;
begin
  if p_duration_days is null then
    starts_at := v_starts;
    expires_at := null;
    return next;
  end if;

  v_days := public._validate_home_ad_duration(p_duration_days);
  starts_at := v_starts;
  expires_at := v_starts + make_interval(days => v_days);
  return next;
end;
$$;

create or replace function public.admin_create_home_ad(
  p_title_ar text,
  p_image_url text,
  p_storage_path text,
  p_action_type text default 'none',
  p_link_url text default null,
  p_whatsapp_phone text default null,
  p_pricing_type text default 'free',
  p_price_iqd integer default 0,
  p_duration_days integer default 30,
  p_starts_at timestamptz default null,
  p_sort_order int default 0,
  p_is_active boolean default true
)
returns public.home_ads
language plpgsql
security definer
set search_path = public
as $$
declare
  v_image_url text := trim(coalesce(p_image_url, ''));
  v_storage_path text := trim(coalesce(p_storage_path, ''));
  v_action text := lower(trim(coalesce(p_action_type, 'none')));
  v_link text;
  v_whatsapp text;
  v_schedule record;
  v_duration_days integer;
  v_row public.home_ads;
begin
  perform public.require_dashboard_admin();

  if v_image_url = '' then
    raise exception 'صورة الإعلان مطلوبة' using errcode = '22023';
  end if;

  if v_storage_path = '' or v_storage_path !~ '^home-ads/' then
    raise exception 'مسار التخزين غير صالح' using errcode = '22023';
  end if;

  perform public._validate_home_ad_action(v_action, p_link_url, p_whatsapp_phone);
  perform public._validate_home_ad_pricing(p_pricing_type, p_price_iqd);

  v_duration_days := public._validate_home_ad_duration(p_duration_days);

  select * into v_schedule
  from public._home_ad_schedule(p_starts_at, p_duration_days);

  v_link := case when v_action = 'link'
    then public._validate_home_ad_link_url(p_link_url)
    else null end;

  v_whatsapp := case when v_action = 'whatsapp'
    then public._normalize_home_ad_whatsapp_phone(p_whatsapp_phone)
    else null end;

  insert into public.home_ads (
    title_ar,
    image_url,
    storage_path,
    link_url,
    action_type,
    whatsapp_phone,
    pricing_type,
    price_iqd,
    duration_days,
    starts_at,
    expires_at,
    sort_order,
    is_active
  )
  values (
    nullif(trim(coalesce(p_title_ar, '')), ''),
    v_image_url,
    v_storage_path,
    v_link,
    v_action,
    v_whatsapp,
    lower(trim(coalesce(p_pricing_type, 'free'))),
    case
      when lower(trim(coalesce(p_pricing_type, 'free'))) = 'paid'
        then coalesce(p_price_iqd, 0)
      else 0
    end,
    v_duration_days,
    v_schedule.starts_at,
    v_schedule.expires_at,
    coalesce(p_sort_order, 0),
    coalesce(p_is_active, true)
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.admin_update_home_ad(
  p_id uuid,
  p_title_ar text,
  p_image_url text,
  p_storage_path text,
  p_action_type text default 'none',
  p_link_url text default null,
  p_whatsapp_phone text default null,
  p_pricing_type text default 'free',
  p_price_iqd integer default 0,
  p_duration_days integer default 30,
  p_starts_at timestamptz default null,
  p_sort_order int default 0,
  p_is_active boolean default true
)
returns public.home_ads
language plpgsql
security definer
set search_path = public
as $$
declare
  v_image_url text := trim(coalesce(p_image_url, ''));
  v_storage_path text := trim(coalesce(p_storage_path, ''));
  v_action text := lower(trim(coalesce(p_action_type, 'none')));
  v_link text;
  v_whatsapp text;
  v_schedule record;
  v_duration_days integer;
  v_row public.home_ads;
begin
  perform public.require_dashboard_admin();

  if p_id is null then
    raise exception 'معرّف الإعلان مطلوب' using errcode = '22023';
  end if;

  if v_image_url = '' then
    raise exception 'صورة الإعلان مطلوبة' using errcode = '22023';
  end if;

  if v_storage_path = '' or v_storage_path !~ '^home-ads/' then
    raise exception 'مسار التخزين غير صالح' using errcode = '22023';
  end if;

  perform public._validate_home_ad_action(v_action, p_link_url, p_whatsapp_phone);
  perform public._validate_home_ad_pricing(p_pricing_type, p_price_iqd);

  v_duration_days := public._validate_home_ad_duration(p_duration_days);

  select * into v_schedule
  from public._home_ad_schedule(p_starts_at, p_duration_days);

  v_link := case when v_action = 'link'
    then public._validate_home_ad_link_url(p_link_url)
    else null end;

  v_whatsapp := case when v_action = 'whatsapp'
    then public._normalize_home_ad_whatsapp_phone(p_whatsapp_phone)
    else null end;

  update public.home_ads
  set
    title_ar = nullif(trim(coalesce(p_title_ar, '')), ''),
    image_url = v_image_url,
    storage_path = v_storage_path,
    link_url = v_link,
    action_type = v_action,
    whatsapp_phone = v_whatsapp,
    pricing_type = lower(trim(coalesce(p_pricing_type, 'free'))),
    price_iqd = case
      when lower(trim(coalesce(p_pricing_type, 'free'))) = 'paid'
        then coalesce(p_price_iqd, 0)
      else 0
    end,
    duration_days = v_duration_days,
    starts_at = v_schedule.starts_at,
    expires_at = v_schedule.expires_at,
    sort_order = coalesce(p_sort_order, 0),
    is_active = coalesce(p_is_active, true)
  where id = p_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'الإعلان غير موجود' using errcode = 'P0001';
  end if;

  return v_row;
end;
$$;

revoke all on function public._normalize_home_ad_date(timestamptz) from public;
revoke all on function public._validate_home_ad_duration(integer) from public;
revoke all on function public._home_ad_schedule(timestamptz, integer) from public;

grant execute on function public.admin_create_home_ad(
  text, text, text, text, text, text, text, integer, integer, timestamptz, int, boolean
) to authenticated;
grant execute on function public.admin_update_home_ad(
  uuid, text, text, text, text, text, text, text, integer, integer, timestamptz, int, boolean
) to authenticated;
