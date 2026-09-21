-- 035: Coupon audience targeting (all / selected / single) + admin search
-- Requires: 034_admin_coupon_management.sql
-- Extends existing coupons system — no duplicate tables.

-- ---------------------------------------------------------------------------
-- 1) Audience column on coupons
-- ---------------------------------------------------------------------------
alter table public.coupons
  add column if not exists audience_type text not null default 'all'
    check (audience_type in ('all', 'selected', 'single'));

comment on column public.coupons.audience_type is
  'all = any user; selected = users in coupon_users; single = one user in coupon_users';

-- ---------------------------------------------------------------------------
-- 2) Coupon ↔ user relation (no names stored on coupons)
-- ---------------------------------------------------------------------------
create table if not exists public.coupon_users (
  coupon_id uuid not null references public.coupons (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (coupon_id, user_id)
);

create index if not exists coupon_users_user_idx
  on public.coupon_users (user_id);

alter table public.coupon_users enable row level security;

revoke all on table public.coupon_users from public;
revoke all on table public.coupon_users from anon;
revoke all on table public.coupon_users from authenticated;

-- ---------------------------------------------------------------------------
-- 3) Audience validation helper
-- ---------------------------------------------------------------------------
create or replace function public._validate_coupon_audience(
  p_coupon_id uuid,
  p_audience_type text,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := coalesce(p_audience_type, 'all');
begin
  if v_type = 'all' then
    return;
  end if;

  if p_user_id is null then
    raise exception 'هذا الكوبون غير متاح لحسابك' using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.coupon_users cu
    where cu.coupon_id = p_coupon_id
      and cu.user_id = p_user_id
  ) then
    raise exception 'هذا الكوبون غير متاح لحسابك' using errcode = 'P0001';
  end if;
end;
$$;

revoke all on function public._validate_coupon_audience(uuid, text, uuid) from public;

-- ---------------------------------------------------------------------------
-- 4) Coupon validation — audience + existing rules
-- ---------------------------------------------------------------------------
create or replace function public._validate_coupon_for_fee(
  p_code text,
  p_fee_amount numeric,
  p_user_id uuid
)
returns public.coupons
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_coupon public.coupons;
  v_used int;
  v_user_uses int;
begin
  v_code := nullif(upper(trim(coalesce(p_code, ''))), '');
  if v_code is null then
    raise exception 'أدخل كود الخصم' using errcode = '22023';
  end if;

  select * into v_coupon
  from public.coupons
  where code = v_code;

  if v_coupon.id is null or v_coupon.is_active is not true then
    raise exception 'كود الخصم غير صالح' using errcode = 'P0001';
  end if;

  perform public._validate_coupon_audience(v_coupon.id, v_coupon.audience_type, p_user_id);

  if v_coupon.starts_at is not null and v_coupon.starts_at > now() then
    raise exception 'كود الخصم غير صالح' using errcode = 'P0001';
  end if;

  if v_coupon.expires_at is not null and v_coupon.expires_at < now() then
    raise exception 'انتهت صلاحية كود الخصم' using errcode = 'P0001';
  end if;

  v_used := public._coupon_redemption_count(v_coupon.id);

  if v_coupon.max_uses is not null and v_used >= v_coupon.max_uses then
    raise exception 'انتهت صلاحية هذا الكوبون' using errcode = 'P0001';
  end if;

  if p_fee_amount < coalesce(v_coupon.min_delivery_fee_iqd, 0) then
    raise exception 'كود الخصم غير صالح لهذه الأجرة' using errcode = 'P0001';
  end if;

  if p_user_id is not null and v_coupon.max_uses_per_user is not null then
    select count(*)::int into v_user_uses
    from public.coupon_redemptions r
    where r.coupon_id = v_coupon.id and r.user_id = p_user_id;
    if v_user_uses >= v_coupon.max_uses_per_user then
      raise exception 'تم الوصول إلى الحد المسموح لاستخدام هذا الكوبون' using errcode = 'P0001';
    end if;
  end if;

  return v_coupon;
end;
$$;

create or replace function public._validate_coupon_for_fee_locked(
  p_code text,
  p_fee_amount numeric,
  p_user_id uuid
)
returns public.coupons
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_coupon public.coupons;
  v_used int;
  v_user_uses int;
begin
  v_code := nullif(upper(trim(coalesce(p_code, ''))), '');
  if v_code is null then
    raise exception 'أدخل كود الخصم' using errcode = '22023';
  end if;

  select * into v_coupon
  from public.coupons
  where code = v_code
  for update;

  if v_coupon.id is null or v_coupon.is_active is not true then
    raise exception 'كود الخصم غير صالح' using errcode = 'P0001';
  end if;

  perform public._validate_coupon_audience(v_coupon.id, v_coupon.audience_type, p_user_id);

  if v_coupon.starts_at is not null and v_coupon.starts_at > now() then
    raise exception 'كود الخصم غير صالح' using errcode = 'P0001';
  end if;

  if v_coupon.expires_at is not null and v_coupon.expires_at < now() then
    raise exception 'انتهت صلاحية كود الخصم' using errcode = 'P0001';
  end if;

  v_used := public._coupon_redemption_count(v_coupon.id);

  if v_coupon.max_uses is not null and v_used >= v_coupon.max_uses then
    raise exception 'انتهت صلاحية هذا الكوبون' using errcode = 'P0001';
  end if;

  if p_fee_amount < coalesce(v_coupon.min_delivery_fee_iqd, 0) then
    raise exception 'كود الخصم غير صالح لهذه الأجرة' using errcode = 'P0001';
  end if;

  if p_user_id is not null and v_coupon.max_uses_per_user is not null then
    select count(*)::int into v_user_uses
    from public.coupon_redemptions r
    where r.coupon_id = v_coupon.id and r.user_id = p_user_id;
    if v_user_uses >= v_coupon.max_uses_per_user then
      raise exception 'تم الوصول إلى الحد المسموح لاستخدام هذا الكوبون' using errcode = 'P0001';
    end if;
  end if;

  return v_coupon;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Admin: search users for coupon audience picker
-- ---------------------------------------------------------------------------
create or replace function public.admin_search_coupon_users(
  p_query text,
  p_limit int default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_q text := trim(coalesce(p_query, ''));
  v_digits text;
  lim int;
begin
  perform public.require_dashboard_admin();
  lim := greatest(1, least(coalesce(p_limit, 20), 50));

  if length(v_q) < 2 then
    return '[]'::jsonb;
  end if;

  v_digits := regexp_replace(v_q, '\D', '', 'g');

  return coalesce((
    select jsonb_agg(row_to_json(q)::jsonb order by q.full_name, q.phone)
    from (
      select
        p.id,
        p.full_name,
        p.phone
      from public.profiles p
      where p.account_type = 'user'
        and p.account_status <> 'disabled'
        and (
          p.full_name ilike '%' || v_q || '%'
          or (length(v_digits) >= 3 and regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') like '%' || v_digits || '%')
        )
      order by p.full_name nulls last, p.created_at desc
      limit lim
    ) q
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_search_coupon_users(text, int) from public;
grant execute on function public.admin_search_coupon_users(text, int) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Admin: get single coupon with audience users
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_delivery_coupon(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_coupon public.coupons;
  v_used int;
  v_users jsonb;
begin
  perform public.require_dashboard_admin();

  select * into v_coupon from public.coupons where id = p_id;
  if v_coupon.id is null then
    raise exception 'الكوبون غير موجود' using errcode = 'P0001';
  end if;

  v_used := public._coupon_redemption_count(p_id);

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'full_name', p.full_name,
      'phone', p.phone
    ) order by p.full_name
  ), '[]'::jsonb)
  into v_users
  from public.coupon_users cu
  join public.profiles p on p.id = cu.user_id
  where cu.coupon_id = p_id;

  return jsonb_build_object(
    'id', v_coupon.id,
    'code', v_coupon.code,
    'discount_type', v_coupon.discount_type,
    'discount_value', v_coupon.discount_value,
    'is_active', v_coupon.is_active,
    'audience_type', v_coupon.audience_type,
    'audience_users', v_users,
    'audience_count', jsonb_array_length(v_users),
    'starts_at', v_coupon.starts_at,
    'expires_at', v_coupon.expires_at,
    'max_uses', v_coupon.max_uses,
    'used_count', v_used,
    'remaining_uses', case
      when v_coupon.max_uses is not null then greatest(v_coupon.max_uses - v_used, 0)
      else null
    end,
    'status', case
      when v_coupon.max_uses is not null and v_used >= v_coupon.max_uses then 'exhausted'
      when v_coupon.is_active is not true then 'inactive'
      else 'active'
    end,
    'has_redemptions', v_used > 0,
    'min_delivery_fee_iqd', v_coupon.min_delivery_fee_iqd,
    'max_discount_iqd', v_coupon.max_discount_iqd,
    'max_uses_per_user', v_coupon.max_uses_per_user,
    'created_at', v_coupon.created_at,
    'updated_at', v_coupon.updated_at
  );
end;
$$;

revoke all on function public.admin_get_delivery_coupon(uuid) from public;
grant execute on function public.admin_get_delivery_coupon(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Admin list — audience summary
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_delivery_coupons()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();
  return coalesce((
    select jsonb_agg(row_to_json(q)::jsonb order by q.created_at desc)
    from (
      select
        c.id,
        c.code,
        c.discount_type,
        c.discount_value,
        c.is_active,
        c.audience_type,
        coalesce(ac.cnt, 0) as audience_count,
        c.starts_at,
        c.expires_at,
        c.max_uses,
        coalesce(rc.used_count, 0) as used_count,
        case
          when c.max_uses is not null then greatest(c.max_uses - coalesce(rc.used_count, 0), 0)
          else null
        end as remaining_uses,
        case
          when c.max_uses is not null and coalesce(rc.used_count, 0) >= c.max_uses then 'exhausted'
          when c.is_active is not true then 'inactive'
          else 'active'
        end as status,
        coalesce(rc.used_count, 0) > 0 as has_redemptions,
        c.min_delivery_fee_iqd,
        c.max_discount_iqd,
        c.max_uses_per_user,
        c.created_at,
        c.updated_at
      from public.coupons c
      left join (
        select r.coupon_id, count(*)::int as used_count
        from public.coupon_redemptions r
        group by r.coupon_id
      ) rc on rc.coupon_id = c.id
      left join (
        select cu.coupon_id, count(*)::int as cnt
        from public.coupon_users cu
        group by cu.coupon_id
      ) ac on ac.coupon_id = c.id
    ) q
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- 8) Admin upsert — audience + discount validations
-- ---------------------------------------------------------------------------
drop function if exists public.admin_upsert_delivery_coupon(
  uuid, text, text, numeric, boolean, timestamptz, timestamptz, int, numeric, numeric, int
);

create or replace function public.admin_upsert_delivery_coupon(
  p_id uuid,
  p_code text,
  p_discount_type text,
  p_discount_value numeric,
  p_is_active boolean,
  p_starts_at timestamptz,
  p_expires_at timestamptz,
  p_max_uses int,
  p_min_delivery_fee_iqd numeric,
  p_max_discount_iqd numeric,
  p_max_uses_per_user int,
  p_audience_type text default 'all',
  p_audience_user_ids uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.coupons;
  v_existing public.coupons;
  v_code text := upper(trim(coalesce(p_code, '')));
  v_type text := lower(trim(coalesce(p_discount_type, '')));
  v_audience text := lower(trim(coalesce(p_audience_type, 'all')));
  v_used int := 0;
  v_user_ids uuid[];
  v_uid uuid;
begin
  perform public.require_dashboard_admin();

  if length(v_code) < 1 then
    raise exception 'رمز الكوبون مطلوب' using errcode = '22023';
  end if;
  if v_type not in ('percent', 'fixed') then
    raise exception 'نوع الخصم غير صالح' using errcode = '22023';
  end if;
  if p_discount_value is null or p_discount_value <= 0 then
    raise exception 'قيمة الخصم غير صالحة' using errcode = '22023';
  end if;
  if v_type = 'percent' and (p_discount_value < 1 or p_discount_value > 100) then
    raise exception 'نسبة الخصم يجب أن تكون بين 1 و 100' using errcode = '22023';
  end if;
  if v_type = 'fixed' and p_discount_value <> trunc(p_discount_value) then
    raise exception 'مبلغ الخصم يجب أن يكون عدداً صحيحاً بالدينار' using errcode = '22023';
  end if;
  if p_max_uses is null or p_max_uses < 1 then
    raise exception 'عدد الاستخدامات يجب أن يكون 1 على الأقل' using errcode = '22023';
  end if;
  if v_audience not in ('all', 'selected', 'single') then
    raise exception 'نوع الجمهور غير صالح' using errcode = '22023';
  end if;

  v_user_ids := coalesce(p_audience_user_ids, array[]::uuid[]);

  if v_audience = 'all' then
    v_user_ids := array[]::uuid[];
  elsif v_audience = 'single' then
    if array_length(v_user_ids, 1) is distinct from 1 then
      raise exception 'يجب اختيار مستخدم واحد لهذا الكوبون' using errcode = '22023';
    end if;
  elsif v_audience = 'selected' then
    if array_length(v_user_ids, 1) is null or array_length(v_user_ids, 1) < 1 then
      raise exception 'يجب اختيار مستخدم واحد على الأقل' using errcode = '22023';
    end if;
  end if;

  foreach v_uid in array v_user_ids loop
    if not exists (
      select 1 from public.profiles p
      where p.id = v_uid
        and p.account_type = 'user'
        and p.account_status <> 'disabled'
    ) then
      raise exception 'أحد المستخدمين المحددين غير صالح' using errcode = '22023';
    end if;
  end loop;

  if p_id is not null then
    select * into v_existing from public.coupons where id = p_id;
    if v_existing.id is null then
      raise exception 'الكوبون غير موجود' using errcode = 'P0001';
    end if;

    v_used := public._coupon_redemption_count(p_id);

    if p_max_uses < v_used then
      raise exception 'عدد الاستخدامات لا يمكن أن يكون أقل من عدد الاستخدامات الحالية (%)',
        v_used using errcode = '22023';
    end if;

    if v_used > 0 and upper(trim(v_existing.code)) <> v_code then
      raise exception 'لا يمكن تغيير رمز الكوبون بعد بدء استخدامه' using errcode = '22023';
    end if;
  end if;

  if p_id is null then
    insert into public.coupons (
      code, discount_type, discount_value, is_active, audience_type,
      starts_at, expires_at, max_uses,
      min_delivery_fee_iqd, max_discount_iqd, max_uses_per_user,
      updated_by, updated_at
    ) values (
      v_code, v_type, p_discount_value, coalesce(p_is_active, true), v_audience,
      p_starts_at, p_expires_at, p_max_uses,
      coalesce(p_min_delivery_fee_iqd, 0), p_max_discount_iqd, p_max_uses_per_user,
      auth.uid(), now()
    )
    returning * into v_row;
  else
    update public.coupons
    set
      code = case when v_used > 0 then v_existing.code else v_code end,
      discount_type = v_type,
      discount_value = p_discount_value,
      is_active = coalesce(p_is_active, is_active),
      audience_type = v_audience,
      starts_at = p_starts_at,
      expires_at = p_expires_at,
      max_uses = p_max_uses,
      min_delivery_fee_iqd = coalesce(p_min_delivery_fee_iqd, 0),
      max_discount_iqd = p_max_discount_iqd,
      max_uses_per_user = p_max_uses_per_user,
      updated_by = auth.uid(),
      updated_at = now()
    where id = p_id
    returning * into v_row;
    if v_row.id is null then
      raise exception 'الكوبون غير موجود' using errcode = 'P0001';
    end if;
  end if;

  delete from public.coupon_users where coupon_id = v_row.id;

  if v_audience in ('selected', 'single') then
    insert into public.coupon_users (coupon_id, user_id)
    select distinct v_row.id, u
    from unnest(v_user_ids) as u
    on conflict do nothing;
  end if;

  return public.admin_get_delivery_coupon(v_row.id);
exception
  when unique_violation then
    raise exception 'رمز الكوبون مستخدم بالفعل' using errcode = '23505';
end;
$$;

revoke all on function public.admin_upsert_delivery_coupon(
  uuid, text, text, numeric, boolean, timestamptz, timestamptz, int, numeric, numeric, int, text, uuid[]
) from public;
grant execute on function public.admin_upsert_delivery_coupon(
  uuid, text, text, numeric, boolean, timestamptz, timestamptz, int, numeric, numeric, int, text, uuid[]
) to authenticated;
