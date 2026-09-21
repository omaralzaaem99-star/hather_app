-- 041: Home banner ads — Bunny storage_path + admin CRUD RPCs.
-- Requires: 004 (home_ads), 008 (require_dashboard_admin).

alter table public.home_ads
  add column if not exists storage_path text;

comment on column public.home_ads.storage_path is
  'Bunny object path (e.g. home-ads/2026/08/uuid.webp) — used for safe delete/replace.';

create or replace function public._validate_home_ad_link_url(p_link_url text)
returns text
language plpgsql
immutable
as $$
declare
  v_link text := trim(coalesce(p_link_url, ''));
begin
  if v_link = '' then
    return null;
  end if;

  if v_link ~* '^\s*javascript:' or v_link ~* '^\s*data:' then
    raise exception 'رابط غير مسموح' using errcode = '22023';
  end if;

  if v_link !~* '^https://' then
    raise exception 'الرابط يجب أن يبدأ بـ https://' using errcode = '22023';
  end if;

  return v_link;
end;
$$;

create or replace function public.admin_list_home_ads()
returns setof public.home_ads
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();

  return query
  select *
  from public.home_ads
  order by sort_order asc, created_at asc;
end;
$$;

create or replace function public.admin_create_home_ad(
  p_title_ar text,
  p_image_url text,
  p_storage_path text,
  p_link_url text default null,
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
  v_row public.home_ads;
begin
  perform public.require_dashboard_admin();

  if v_image_url = '' then
    raise exception 'صورة الإعلان مطلوبة' using errcode = '22023';
  end if;

  if v_storage_path = '' or v_storage_path !~ '^home-ads/' then
    raise exception 'مسار التخزين غير صالح' using errcode = '22023';
  end if;

  insert into public.home_ads (
    title_ar,
    image_url,
    storage_path,
    link_url,
    sort_order,
    is_active
  )
  values (
    nullif(trim(coalesce(p_title_ar, '')), ''),
    v_image_url,
    v_storage_path,
    public._validate_home_ad_link_url(p_link_url),
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
  p_link_url text default null,
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

  update public.home_ads
  set
    title_ar = nullif(trim(coalesce(p_title_ar, '')), ''),
    image_url = v_image_url,
    storage_path = v_storage_path,
    link_url = public._validate_home_ad_link_url(p_link_url),
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

create or replace function public.admin_toggle_home_ad(
  p_id uuid,
  p_is_active boolean
)
returns public.home_ads
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.home_ads;
begin
  perform public.require_dashboard_admin();

  update public.home_ads
  set is_active = coalesce(p_is_active, false)
  where id = p_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'الإعلان غير موجود' using errcode = 'P0001';
  end if;

  return v_row;
end;
$$;

create or replace function public.admin_delete_home_ad(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_storage_path text;
begin
  perform public.require_dashboard_admin();

  delete from public.home_ads
  where id = p_id
  returning storage_path into v_storage_path;

  if not found then
    raise exception 'الإعلان غير موجود' using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'deleted', true,
    'storage_path', v_storage_path
  );
end;
$$;

revoke all on function public._validate_home_ad_link_url(text) from public;
revoke all on function public.admin_list_home_ads() from public;
revoke all on function public.admin_create_home_ad(text, text, text, text, int, boolean) from public;
revoke all on function public.admin_update_home_ad(uuid, text, text, text, text, int, boolean) from public;
revoke all on function public.admin_toggle_home_ad(uuid, boolean) from public;
revoke all on function public.admin_delete_home_ad(uuid) from public;

grant execute on function public.admin_list_home_ads() to authenticated;
grant execute on function public.admin_create_home_ad(text, text, text, text, int, boolean) to authenticated;
grant execute on function public.admin_update_home_ad(uuid, text, text, text, text, int, boolean) to authenticated;
grant execute on function public.admin_toggle_home_ad(uuid, boolean) to authenticated;
grant execute on function public.admin_delete_home_ad(uuid) to authenticated;
