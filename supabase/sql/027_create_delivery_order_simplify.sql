-- 027: Simplify create delivery order
-- - Server assigns fixed order type "طلب دلفري" (no client type picker)
-- - Remove p_order_type_id from create_own_delivery_order
-- - Details: required after trim; no 500-char UI limit; keep high abuse ceiling
-- - Address: optional (empty → NULL) — already the case; keep GPS required
-- Requires: 025 (or later create_own_delivery_order signature)
-- Does NOT drop order_types table or mutate historical delivery_orders rows.

-- ---------------------------------------------------------------------------
-- Canonical type for new orders (non-destructive; old types remain)
-- ---------------------------------------------------------------------------
insert into public.order_types (name_ar, is_active, sort_order)
select 'طلب دلفري', true, 0
where not exists (
  select 1 from public.order_types where name_ar = 'طلب دلفري'
);

update public.order_types
set is_active = true, sort_order = 0
where name_ar = 'طلب دلفري';

-- ---------------------------------------------------------------------------
-- Replace create RPC: drop type param from client
-- ---------------------------------------------------------------------------
drop function if exists public.create_own_delivery_order(
  uuid, text, uuid, uuid, text, double precision, double precision, text, text
);

drop function if exists public.create_own_delivery_order(
  text, uuid, uuid, text, double precision, double precision, text, text
);

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
  -- Abuse ceiling only (not a product UX limit like 500)
  if length(v_details) > 20000 then
    raise exception 'تفاصيل الطلب طويلة جداً' using errcode = '22023';
  end if;

  -- Fixed internal type — Flutter no longer sends order type
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

  -- Optional address description → NULL when blank
  v_address := nullif(trim(coalesce(p_destination_address, '')), '');
  if v_address is not null and length(v_address) > 2000 then
    raise exception 'وصف العنوان طويل جداً' using errcode = '22023';
  end if;

  if nullif(trim(coalesce(p_coupon_code, '')), '') is not null then
    v_coupon := public._validate_coupon_for_fee(p_coupon_code, v_fee.amount_iqd, v_uid);
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

    update public.coupons
    set used_count = used_count + 1, updated_at = now()
    where id = v_coupon.id;
  end if;

  return public._own_delivery_order_json(v_order.id, v_uid);
end;
$$;

revoke all on function public.create_own_delivery_order(
  text, uuid, uuid, text, double precision, double precision, text, text
) from public;
grant execute on function public.create_own_delivery_order(
  text, uuid, uuid, text, double precision, double precision, text, text
) to authenticated;
