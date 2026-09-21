-- 042: Home ads — action types, pricing, duration, scheduling.
-- Requires: 041 (home_ads admin + storage_path).

alter table public.home_ads
  add column if not exists action_type text not null default 'none',
  add column if not exists whatsapp_phone text,
  add column if not exists pricing_type text not null default 'free',
  add column if not exists price_iqd integer not null default 0,
  add column if not exists duration_days integer,
  add column if not exists starts_at timestamptz,
  add column if not exists expires_at timestamptz;

alter table public.home_ads
  drop constraint if exists home_ads_action_type_check;

alter table public.home_ads
  add constraint home_ads_action_type_check
    check (action_type in ('none', 'link', 'whatsapp'));

alter table public.home_ads
  drop constraint if exists home_ads_pricing_type_check;

alter table public.home_ads
  add constraint home_ads_pricing_type_check
    check (pricing_type in ('free', 'paid'));

alter table public.home_ads
  drop constraint if exists home_ads_price_iqd_check;

alter table public.home_ads
  add constraint home_ads_price_iqd_check
    check (price_iqd >= 0);

alter table public.home_ads
  drop constraint if exists home_ads_duration_days_check;

alter table public.home_ads
  add constraint home_ads_duration_days_check
    check (duration_days is null or (duration_days >= 30 and duration_days <= 365));

-- Backfill legacy rows that only had link_url.
update public.home_ads
set action_type = 'link'
where trim(coalesce(link_url, '')) <> ''
  and action_type = 'none';

create or replace function public._normalize_home_ad_whatsapp_phone(p_phone text)
returns text
language plpgsql
immutable
as $$
declare
  v_digits text := regexp_replace(trim(coalesce(p_phone, '')), '[^0-9]', '', 'g');
begin
  if v_digits = '' then
    return null;
  end if;

  if v_digits like '964%' and length(v_digits) = 12 then
    v_digits := '0' || substring(v_digits from 4);
  elsif v_digits like '964%' and length(v_digits) = 13 then
    v_digits := substring(v_digits from 4);
    if v_digits not like '0%' then
      v_digits := '0' || v_digits;
    end if;
  elsif v_digits like '7%' and length(v_digits) = 10 then
    v_digits := '0' || v_digits;
  end if;

  if v_digits !~ '^07[0-9]{9}$' then
    raise exception 'رقم واتساب غير صالح' using errcode = '22023';
  end if;

  return v_digits;
end;
$$;

create or replace function public._validate_home_ad_action(
  p_action_type text,
  p_link_url text,
  p_whatsapp_phone text
)
returns void
language plpgsql
immutable
as $$
declare
  v_action text := lower(trim(coalesce(p_action_type, 'none')));
  v_link text;
  v_whatsapp text;
begin
  if v_action not in ('none', 'link', 'whatsapp') then
    raise exception 'نوع الإجراء غير صالح' using errcode = '22023';
  end if;

  if v_action = 'none' then
    if trim(coalesce(p_link_url, '')) <> '' or trim(coalesce(p_whatsapp_phone, '')) <> '' then
      raise exception 'لا يمكن إضافة رابط أو واتساب مع بدون إجراء' using errcode = '22023';
    end if;
    return;
  end if;

  if v_action = 'link' then
    v_link := public._validate_home_ad_link_url(p_link_url);
    if v_link is null then
      raise exception 'الرابط مطلوب' using errcode = '22023';
    end if;
    if trim(coalesce(p_whatsapp_phone, '')) <> '' then
      raise exception 'لا يمكن الجمع بين رابط وواتساب' using errcode = '22023';
    end if;
    return;
  end if;

  v_whatsapp := public._normalize_home_ad_whatsapp_phone(p_whatsapp_phone);
  if v_whatsapp is null then
    raise exception 'رقم واتساب مطلوب' using errcode = '22023';
  end if;
  if trim(coalesce(p_link_url, '')) <> '' then
    raise exception 'لا يمكن الجمع بين رابط وواتساب' using errcode = '22023';
  end if;
end;
$$;

create or replace function public._validate_home_ad_pricing(
  p_pricing_type text,
  p_price_iqd integer
)
returns void
language plpgsql
immutable
as $$
declare
  v_pricing text := lower(trim(coalesce(p_pricing_type, 'free')));
  v_price integer := coalesce(p_price_iqd, 0);
begin
  if v_pricing not in ('free', 'paid') then
    raise exception 'نوع الاشتراك غير صالح' using errcode = '22023';
  end if;

  if v_pricing = 'free' then
    if v_price <> 0 then
      raise exception 'الإعلان المجاني لا يحتاج سعراً' using errcode = '22023';
    end if;
    return;
  end if;

  if v_price is null or v_price <= 0 then
    raise exception 'سعر الاشتراك مطلوب للإعلان المدفوع' using errcode = '22023';
  end if;
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
  v_days integer := coalesce(p_duration_days, 0);
begin
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
  v_starts timestamptz := coalesce(p_starts_at, now());
  v_days integer := public._validate_home_ad_duration(p_duration_days);
begin
  starts_at := v_starts;
  expires_at := v_starts + make_interval(days => v_days);
  return next;
end;
$$;

drop policy if exists "home_ads_select_active" on public.home_ads;

create policy "home_ads_select_active"
  on public.home_ads for select to authenticated
  using (
    is_active = true
    and image_url is not null
    and trim(image_url) <> ''
    and (starts_at is null or starts_at <= now())
    and (expires_at is null or expires_at > now())
  );

drop function if exists public.admin_create_home_ad(text, text, text, text, int, boolean);

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
    public._validate_home_ad_duration(p_duration_days),
    v_schedule.starts_at,
    v_schedule.expires_at,
    coalesce(p_sort_order, 0),
    coalesce(p_is_active, true)
  )
  returning * into v_row;

  return v_row;
end;
$$;

drop function if exists public.admin_update_home_ad(uuid, text, text, text, text, int, boolean);

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
    duration_days = public._validate_home_ad_duration(p_duration_days),
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

revoke all on function public._normalize_home_ad_whatsapp_phone(text) from public;
revoke all on function public._validate_home_ad_action(text, text, text) from public;
revoke all on function public._validate_home_ad_pricing(text, integer) from public;
revoke all on function public._validate_home_ad_duration(integer) from public;
revoke all on function public._home_ad_schedule(timestamptz, integer) from public;
revoke all on function public.admin_create_home_ad(
  text, text, text, text, text, text, text, integer, integer, timestamptz, int, boolean
) from public;
revoke all on function public.admin_update_home_ad(
  uuid, text, text, text, text, text, text, text, integer, integer, timestamptz, int, boolean
) from public;

grant execute on function public.admin_create_home_ad(
  text, text, text, text, text, text, text, integer, integer, timestamptz, int, boolean
) to authenticated;
grant execute on function public.admin_update_home_ad(
  uuid, text, text, text, text, text, text, text, integer, integer, timestamptz, int, boolean
) to authenticated;
