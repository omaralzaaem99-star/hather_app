-- 024: Secure user create/get delivery order RPCs (server-owned fields).
-- Requires: 004_delivery_orders, 008 (cancel_own_delivery_order), 015 (captain_id).
-- Does not modify captain_list_available_orders / captain_accept_delivery_order.

do $$
begin
  if to_regclass('public.delivery_orders') is null then
    raise exception 'Missing public.delivery_orders — apply 004 first';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1) Block direct client INSERT — creation goes through RPC only
-- ---------------------------------------------------------------------------
drop policy if exists "delivery_orders_insert_own" on public.delivery_orders;

-- ---------------------------------------------------------------------------
-- 2) Create order (user only) — server sets owner/status/expiry/assignment
-- ---------------------------------------------------------------------------
create or replace function public.create_own_delivery_order(
  p_order_type_id uuid,
  p_details text,
  p_delete_after_minutes int,
  p_delivery_fee_iqd numeric,
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
  v_coupon_code text;
  v_coupon public.coupons;
  v_discount numeric(12, 0) := 0;
  v_order public.delivery_orders;
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
  if length(v_details) < 3 then
    raise exception 'تفاصيل الطلب مطلوبة' using errcode = '22023';
  end if;
  if length(v_details) > 2000 then
    raise exception 'تفاصيل الطلب طويلة جداً' using errcode = '22023';
  end if;

  if p_order_type_id is null then
    raise exception 'نوع الطلب مطلوب' using errcode = '22023';
  end if;

  select * into v_type
  from public.order_types
  where id = p_order_type_id and is_active = true;
  if v_type.id is null then
    raise exception 'نوع الطلب غير صالح' using errcode = '22023';
  end if;

  if p_delete_after_minutes is null or p_delete_after_minutes <= 0 then
    raise exception 'مدة انتهاء الطلب غير صالحة' using errcode = '22023';
  end if;

  select * into v_duration
  from public.order_delete_durations
  where minutes = p_delete_after_minutes and is_active = true
  limit 1;
  if v_duration.id is null then
    raise exception 'مدة انتهاء الطلب غير صالحة' using errcode = '22023';
  end if;

  if p_delivery_fee_iqd is null or p_delivery_fee_iqd < 0 then
    raise exception 'أجرة التوصيل غير صالحة' using errcode = '22023';
  end if;

  select * into v_fee
  from public.delivery_fee_options
  where amount_iqd = p_delivery_fee_iqd and is_active = true
  limit 1;
  if v_fee.id is null then
    raise exception 'أجرة التوصيل غير صالحة' using errcode = '22023';
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
  if v_address is not null and length(v_address) > 500 then
    raise exception 'وصف العنوان طويل جداً' using errcode = '22023';
  end if;

  v_coupon_code := nullif(upper(trim(coalesce(p_coupon_code, ''))), '');
  if v_coupon_code is not null then
    select * into v_coupon
    from public.coupons
    where code = v_coupon_code and is_active = true;
    if v_coupon.id is null then
      raise exception 'كوبون غير صالح' using errcode = '22023';
    end if;
    if v_coupon.expires_at is not null and v_coupon.expires_at < now() then
      raise exception 'انتهت صلاحية الكوبون' using errcode = '22023';
    end if;
    if v_coupon.max_uses is not null and v_coupon.used_count >= v_coupon.max_uses then
      raise exception 'تم استهلاك الكوبون بالكامل' using errcode = '22023';
    end if;
    if v_coupon.discount_type = 'percent' then
      v_discount := round(v_fee.amount_iqd * v_coupon.discount_value / 100.0);
    else
      v_discount := round(v_coupon.discount_value);
    end if;
    if v_discount > v_fee.amount_iqd then
      v_discount := v_fee.amount_iqd;
    end if;
  end if;

  -- Soft double-submit guard (same details within 15s)
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
    delivery_fee_iqd,
    coupon_code,
    coupon_discount_iqd,
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
    v_fee.amount_iqd,
    v_coupon_code,
    v_discount,
    v_dest_type,
    p_destination_lat,
    p_destination_lng,
    v_address,
    'pending',
    null,
    null
  )
  returning * into v_order;

  if v_coupon.id is not null then
    update public.coupons
    set used_count = used_count + 1
    where id = v_coupon.id;
  end if;

  return public._own_delivery_order_json(v_order.id, v_uid);
end;
$$;

revoke all on function public.create_own_delivery_order(
  uuid, text, int, numeric, text, double precision, double precision, text, text
) from public;
grant execute on function public.create_own_delivery_order(
  uuid, text, int, numeric, text, double precision, double precision, text, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Own order JSON helper (includes captain contact after accept)
-- ---------------------------------------------------------------------------
create or replace function public._own_delivery_order_json(
  p_order_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.delivery_orders;
  captain public.profiles;
begin
  select * into o
  from public.delivery_orders
  where id = p_order_id and user_id = p_user_id;

  if o.id is null then
    raise exception 'order not found' using errcode = 'P0001';
  end if;

  if o.captain_id is not null then
    select * into captain from public.profiles where id = o.captain_id;
  end if;

  return jsonb_build_object(
    'id', o.id,
    'order_type_name', o.order_type_name,
    'details', o.details,
    'status', o.status,
    'delivery_fee_iqd', o.delivery_fee_iqd,
    'coupon_discount_iqd', o.coupon_discount_iqd,
    'destination_type', o.destination_type,
    'destination_lat', o.destination_lat,
    'destination_lng', o.destination_lng,
    'destination_address', o.destination_address,
    'destination_label', public._delivery_destination_label(
      o.destination_type, o.destination_address
    ),
    'created_at', o.created_at,
    'expires_at', o.expires_at,
    'accepted_at', o.accepted_at,
    'captain_id', o.captain_id,
    'captain_name', captain.full_name,
    'captain_phone', captain.phone
  );
end;
$$;

revoke all on function public._own_delivery_order_json(uuid, uuid) from public;

create or replace function public.get_own_delivery_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_order_id is null then
    raise exception 'order id required' using errcode = '22023';
  end if;
  return public._own_delivery_order_json(p_order_id, auth.uid());
end;
$$;

revoke all on function public.get_own_delivery_order(uuid) from public;
grant execute on function public.get_own_delivery_order(uuid) to authenticated;
