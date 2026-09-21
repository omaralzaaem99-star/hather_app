-- 034: Admin coupon management — usage limits, race-safe redemption, admin RPC fixes
-- Requires: 025 (coupons + coupon_redemptions), 027 (create_own_delivery_order), 026 (admin RPCs)
-- Does NOT modify prior migration files.

-- ---------------------------------------------------------------------------
-- 1) Coupon usage helpers (source of truth = coupon_redemptions)
-- ---------------------------------------------------------------------------
create or replace function public._coupon_redemption_count(p_coupon_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.coupon_redemptions r
  where r.coupon_id = p_coupon_id;
$$;

revoke all on function public._coupon_redemption_count(uuid) from public;

create or replace function public._sync_coupon_used_count(p_coupon_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.coupons c
  set
    used_count = public._coupon_redemption_count(p_coupon_id),
    updated_at = now()
  where c.id = p_coupon_id;
end;
$$;

revoke all on function public._sync_coupon_used_count(uuid) from public;

-- ---------------------------------------------------------------------------
-- 2) Validate coupon (preview + shared rules)
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
-- 3) Lock coupon row for atomic redemption at order creation
-- ---------------------------------------------------------------------------
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

revoke all on function public._validate_coupon_for_fee_locked(text, numeric, uuid) from public;

-- ---------------------------------------------------------------------------
-- 4) Race-safe create_own_delivery_order (coupon lock + redemption sync)
-- ---------------------------------------------------------------------------
create or replace function public.create_own_delivery_order(
  p_details text,
  p_duration_option_id uuid,
  p_fee_option_id uuid,
  p_destination_type text,
  p_destination_lat double precision,
  p_destination_lng double precision,
  p_destination_address text default null,
  p_coupon_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_prof public.profiles;
  v_type public.order_types;
  v_duration public.order_delete_durations;
  v_fee public.delivery_fee_options;
  v_details text;
  v_dest_type text;
  v_address text;
  v_coupon public.coupons;
  v_discount numeric(12, 0) := 0;
  v_final numeric(12, 0);
  v_order public.delivery_orders;
  v_has_coupon boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select * into v_prof from public.profiles where id = v_uid;
  if v_prof.id is null then
    raise exception 'profile not found' using errcode = 'P0001';
  end if;
  if v_prof.account_type <> 'user' then
    raise exception 'user accounts only' using errcode = 'P0001';
  end if;
  if v_prof.account_status <> 'active' then
    raise exception 'account not active' using errcode = 'P0001';
  end if;

  v_details := trim(coalesce(p_details, ''));
  if length(v_details) < 1 then
    raise exception 'يرجى كتابة تفاصيل الطلب' using errcode = '22023';
  end if;
  if length(v_details) > 20000 then
    raise exception 'تفاصيل الطلب طويلة جداً' using errcode = '22023';
  end if;

  select * into v_type
  from public.order_types
  where name_ar = 'طلب دلفري' and is_active = true
  order by sort_order
  limit 1;

  if v_type.id is null then
    insert into public.order_types (name_ar, is_active, sort_order)
    values ('طلب دلفري', true, 0)
    returning * into v_type;
  end if;

  if p_duration_option_id is null then
    raise exception 'لا توجد مدة متاحة حالياً.' using errcode = '22023';
  end if;
  select * into v_duration
  from public.order_delete_durations
  where id = p_duration_option_id and is_active = true;
  if v_duration.id is null then
    raise exception 'لا توجد مدة متاحة حالياً.' using errcode = '22023';
  end if;

  if p_fee_option_id is null then
    raise exception 'لا توجد أجور توصيل متاحة حالياً.' using errcode = '22023';
  end if;
  select * into v_fee
  from public.delivery_fee_options
  where id = p_fee_option_id and is_active = true;
  if v_fee.id is null then
    raise exception 'لا توجد أجور توصيل متاحة حالياً.' using errcode = '22023';
  end if;

  v_dest_type := lower(trim(coalesce(p_destination_type, '')));
  if v_dest_type not in ('current', 'map') then
    raise exception 'نوع الوجهة غير صالح' using errcode = '22023';
  end if;
  if p_destination_lat is null or p_destination_lng is null then
    raise exception 'موقع التوصيل مطلوب' using errcode = '22023';
  end if;
  if p_destination_lat < -90 or p_destination_lat > 90
     or p_destination_lng < -180 or p_destination_lng > 180 then
    raise exception 'إحداثيات الموقع غير صالحة' using errcode = '22023';
  end if;

  v_address := nullif(trim(coalesce(p_destination_address, '')), '');
  if v_address is not null and length(v_address) > 2000 then
    raise exception 'وصف العنوان طويل جداً' using errcode = '22023';
  end if;

  if nullif(trim(coalesce(p_coupon_code, '')), '') is not null then
    v_coupon := public._validate_coupon_for_fee_locked(p_coupon_code, v_fee.amount_iqd, v_uid);
    v_discount := public._compute_coupon_discount(
      v_fee.amount_iqd,
      v_coupon.discount_type,
      v_coupon.discount_value,
      v_coupon.max_discount_iqd
    );
    v_has_coupon := true;
  end if;

  v_final := greatest(v_fee.amount_iqd - v_discount, 0);

  if exists (
    select 1
    from public.delivery_orders o
    where o.user_id = v_uid
      and o.status = 'pending'
      and o.details = v_details
      and o.created_at > now() - interval '15 seconds'
  ) then
    raise exception 'طلب مشابه قيد الإرسال، انتظر قليلاً' using errcode = 'P0001';
  end if;

  insert into public.delivery_orders (
    user_id,
    order_type_id,
    order_type_name,
    details,
    delete_after_minutes,
    expires_at,
    duration_option_id,
    fee_option_id,
    delivery_fee_iqd,
    coupon_id,
    coupon_code,
    coupon_discount_iqd,
    delivery_fee_final,
    destination_type,
    destination_lat,
    destination_lng,
    destination_address,
    status,
    captain_id,
    accepted_at
  ) values (
    v_uid,
    v_type.id,
    v_type.name_ar,
    v_details,
    v_duration.minutes,
    now() + make_interval(mins => v_duration.minutes),
    v_duration.id,
    v_fee.id,
    v_fee.amount_iqd,
    case when v_has_coupon then v_coupon.id else null end,
    case when v_has_coupon then v_coupon.code else null end,
    v_discount,
    v_final,
    v_dest_type,
    p_destination_lat,
    p_destination_lng,
    v_address,
    'pending',
    null,
    null
  )
  returning * into v_order;

  if v_has_coupon then
    insert into public.coupon_redemptions (coupon_id, user_id, order_id, discount_iqd)
    values (v_coupon.id, v_uid, v_order.id, v_discount);

    perform public._sync_coupon_used_count(v_coupon.id);
  end if;

  return public._own_delivery_order_json(v_order.id, v_uid);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Admin list — all coupons + derived usage/status
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
    ) q
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) Admin upsert — validations + safe edit rules
-- ---------------------------------------------------------------------------
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
  p_max_uses_per_user int
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
  v_used int := 0;
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
  if p_max_uses is null or p_max_uses < 1 then
    raise exception 'عدد الاستخدامات يجب أن يكون 1 على الأقل' using errcode = '22023';
  end if;

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
      code, discount_type, discount_value, is_active,
      starts_at, expires_at, max_uses,
      min_delivery_fee_iqd, max_discount_iqd, max_uses_per_user,
      updated_by, updated_at
    ) values (
      v_code, v_type, p_discount_value, coalesce(p_is_active, true),
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

  return row_to_json(v_row)::jsonb;
exception
  when unique_violation then
    raise exception 'رمز الكوبون مستخدم بالفعل' using errcode = '23505';
end;
$$;

-- ---------------------------------------------------------------------------
-- 7) Sync stored used_count from redemptions (one-time alignment)
-- ---------------------------------------------------------------------------
update public.coupons c
set
  used_count = sub.cnt,
  updated_at = now()
from (
  select
    c2.id,
    coalesce(rc.cnt, 0) as cnt
  from public.coupons c2
  left join (
    select coupon_id, count(*)::int as cnt
    from public.coupon_redemptions
    group by coupon_id
  ) rc on rc.coupon_id = c2.id
) sub
where c.id = sub.id
  and c.used_count is distinct from sub.cnt;
