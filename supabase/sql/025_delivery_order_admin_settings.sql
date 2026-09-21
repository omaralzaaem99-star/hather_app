-- 025: Delivery order admin settings (durations, fees, coupons) + secure create by option id.
-- Extends EXISTING tables from 004 — does NOT create duplicate coupon/fee/duration tables.
-- Requires: 004, 008 (require_dashboard_admin), 015, 024.

do $$
begin
  if to_regclass('public.order_delete_durations') is null
     or to_regclass('public.delivery_fee_options') is null
     or to_regclass('public.coupons') is null then
    raise exception 'Missing delivery lookup tables — apply 004 first';
  end if;
  if to_regprocedure('public.require_dashboard_admin()') is null then
    raise exception 'Missing require_dashboard_admin — apply 008 first';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1) Extend duration options
-- ---------------------------------------------------------------------------
alter table public.order_delete_durations
  add column if not exists is_default boolean not null default false,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists updated_by uuid references auth.users (id) on delete set null;

create unique index if not exists order_delete_durations_one_default_idx
  on public.order_delete_durations ((is_default))
  where is_default = true;

-- Seed/align recommended set (keep existing rows; soft-deactivate odd presets)
update public.order_delete_durations
set is_active = false, updated_at = now()
where minutes in (30, 120)
  and not exists (
    select 1 from public.delivery_orders o
    where o.delete_after_minutes = order_delete_durations.minutes
  );

insert into public.order_delete_durations (label_ar, minutes, is_active, sort_order, is_default)
select v.label_ar, v.minutes, true, v.sort_order, v.is_default
from (values
  ('ساعة واحدة', 60, 1, false),
  ('3 ساعات', 180, 2, false),
  ('6 ساعات', 360, 3, false),
  ('12 ساعة', 720, 4, false),
  ('24 ساعة', 1440, 5, true)
) as v(label_ar, minutes, sort_order, is_default)
where not exists (
  select 1 from public.order_delete_durations d where d.minutes = v.minutes
);

update public.order_delete_durations d
set
  is_active = true,
  label_ar = case d.minutes
    when 60 then 'ساعة واحدة'
    when 180 then '3 ساعات'
    when 360 then '6 ساعات'
    when 720 then '12 ساعة'
    when 1440 then '24 ساعة'
    else d.label_ar
  end,
  sort_order = case d.minutes
    when 60 then 1
    when 180 then 2
    when 360 then 3
    when 720 then 4
    when 1440 then 5
    else d.sort_order
  end,
  updated_at = now()
where d.minutes in (60, 180, 360, 720, 1440);

update public.order_delete_durations set is_default = false;
update public.order_delete_durations
set is_default = true
where minutes = 1440 and is_active = true;

-- ---------------------------------------------------------------------------
-- 2) Extend fee options
-- ---------------------------------------------------------------------------
alter table public.delivery_fee_options
  add column if not exists is_default boolean not null default false,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists updated_by uuid references auth.users (id) on delete set null;

create unique index if not exists delivery_fee_options_one_default_idx
  on public.delivery_fee_options ((is_default))
  where is_default = true;

-- Keep existing seeded amounts from 004; mark 5000 as default if present
update public.delivery_fee_options set is_default = false;
update public.delivery_fee_options
set is_default = true
where amount_iqd = 5000 and is_active = true;

-- If no default yet, pick lowest active amount
update public.delivery_fee_options o
set is_default = true
where o.id = (
  select id from public.delivery_fee_options
  where is_active = true
  order by sort_order, amount_iqd
  limit 1
)
and not exists (
  select 1 from public.delivery_fee_options where is_default = true
);

-- ---------------------------------------------------------------------------
-- 3) Extend coupons (no second coupons table)
-- ---------------------------------------------------------------------------
alter table public.coupons
  add column if not exists starts_at timestamptz,
  add column if not exists min_delivery_fee_iqd numeric(12, 0) not null default 0
    check (min_delivery_fee_iqd >= 0),
  add column if not exists max_discount_iqd numeric(12, 0)
    check (max_discount_iqd is null or max_discount_iqd > 0),
  add column if not exists max_uses_per_user int
    check (max_uses_per_user is null or max_uses_per_user > 0),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists updated_by uuid references auth.users (id) on delete set null;

create table if not exists public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid not null references public.coupons (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  order_id uuid not null references public.delivery_orders (id) on delete cascade,
  discount_iqd numeric(12, 0) not null check (discount_iqd >= 0),
  created_at timestamptz not null default now(),
  unique (order_id)
);

create index if not exists coupon_redemptions_coupon_user_idx
  on public.coupon_redemptions (coupon_id, user_id);

alter table public.coupon_redemptions enable row level security;

revoke all on table public.coupon_redemptions from public;
revoke all on table public.coupon_redemptions from anon;
revoke all on table public.coupon_redemptions from authenticated;

-- ---------------------------------------------------------------------------
-- 4) Order snapshots
-- ---------------------------------------------------------------------------
alter table public.delivery_orders
  add column if not exists duration_option_id uuid
    references public.order_delete_durations (id) on delete set null,
  add column if not exists fee_option_id uuid
    references public.delivery_fee_options (id) on delete set null,
  add column if not exists coupon_id uuid
    references public.coupons (id) on delete set null,
  add column if not exists delivery_fee_final numeric(12, 0);

update public.delivery_orders
set delivery_fee_final = greatest(delivery_fee_iqd - coupon_discount_iqd, 0)
where delivery_fee_final is null;

alter table public.delivery_orders
  alter column delivery_fee_final set default 0;

-- ---------------------------------------------------------------------------
-- 5) Block client writes on lookup tables (admin RPC only)
-- ---------------------------------------------------------------------------
drop policy if exists "order_delete_durations_insert" on public.order_delete_durations;
drop policy if exists "order_delete_durations_update" on public.order_delete_durations;
drop policy if exists "delivery_fee_options_insert" on public.delivery_fee_options;
drop policy if exists "delivery_fee_options_update" on public.delivery_fee_options;
drop policy if exists "coupons_insert" on public.coupons;
drop policy if exists "coupons_update" on public.coupons;

-- ---------------------------------------------------------------------------
-- 6) Coupon math helper
-- ---------------------------------------------------------------------------
create or replace function public._compute_coupon_discount(
  p_fee numeric,
  p_discount_type text,
  p_discount_value numeric,
  p_max_discount numeric
)
returns numeric
language plpgsql
immutable
as $$
declare
  v_discount numeric(12, 0) := 0;
begin
  if p_fee is null or p_fee < 0 then
    return 0;
  end if;
  if p_discount_type = 'percent' then
    v_discount := round(p_fee * p_discount_value / 100.0);
    if p_max_discount is not null and v_discount > p_max_discount then
      v_discount := p_max_discount;
    end if;
  else
    v_discount := round(p_discount_value);
  end if;
  if v_discount > p_fee then
    v_discount := p_fee;
  end if;
  if v_discount < 0 then
    v_discount := 0;
  end if;
  return v_discount;
end;
$$;

revoke all on function public._compute_coupon_discount(numeric, text, numeric, numeric) from public;

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

  if v_coupon.max_uses is not null and v_coupon.used_count >= v_coupon.max_uses then
    raise exception 'تم الوصول إلى الحد المسموح لاستخدام هذا الكوبون' using errcode = 'P0001';
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

revoke all on function public._validate_coupon_for_fee(text, numeric, uuid) from public;

-- ---------------------------------------------------------------------------
-- 7) App read settings
-- ---------------------------------------------------------------------------
create or replace function public.get_delivery_order_settings()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_durations jsonb;
  v_fees jsonb;
  v_default_duration uuid;
  v_default_fee uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(row_to_json(q)::jsonb order by q.sort_order, q.minutes), '[]'::jsonb)
  into v_durations
  from (
    select id, label_ar, minutes, is_default, sort_order
    from public.order_delete_durations
    where is_active = true
  ) q;

  select coalesce(jsonb_agg(row_to_json(q)::jsonb order by q.sort_order, q.amount_iqd), '[]'::jsonb)
  into v_fees
  from (
    select id, label_ar, amount_iqd, is_default, sort_order
    from public.delivery_fee_options
    where is_active = true
  ) q;

  select id into v_default_duration
  from public.order_delete_durations
  where is_active = true and is_default = true
  limit 1;

  if v_default_duration is null then
    select id into v_default_duration
    from public.order_delete_durations
    where is_active = true
    order by sort_order, minutes
    limit 1;
  end if;

  select id into v_default_fee
  from public.delivery_fee_options
  where is_active = true and is_default = true
  limit 1;

  if v_default_fee is null then
    select id into v_default_fee
    from public.delivery_fee_options
    where is_active = true
    order by sort_order, amount_iqd
    limit 1;
  end if;

  return jsonb_build_object(
    'durations', v_durations,
    'fees', v_fees,
    'default_duration_id', v_default_duration,
    'default_fee_id', v_default_fee
  );
end;
$$;

revoke all on function public.get_delivery_order_settings() from public;
grant execute on function public.get_delivery_order_settings() to authenticated;

-- ---------------------------------------------------------------------------
-- 8) Validate coupon (app)
-- ---------------------------------------------------------------------------
create or replace function public.validate_delivery_coupon(
  p_code text,
  p_fee_option_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fee public.delivery_fee_options;
  v_coupon public.coupons;
  v_discount numeric(12, 0);
  v_final numeric(12, 0);
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_fee_option_id is null then
    raise exception 'اختر أجور التوصيل أولاً' using errcode = '22023';
  end if;

  select * into v_fee
  from public.delivery_fee_options
  where id = p_fee_option_id and is_active = true;
  if v_fee.id is null then
    raise exception 'أجرة التوصيل غير صالحة' using errcode = '22023';
  end if;

  v_coupon := public._validate_coupon_for_fee(p_code, v_fee.amount_iqd, auth.uid());
  v_discount := public._compute_coupon_discount(
    v_fee.amount_iqd,
    v_coupon.discount_type,
    v_coupon.discount_value,
    v_coupon.max_discount_iqd
  );
  v_final := greatest(v_fee.amount_iqd - v_discount, 0);

  return jsonb_build_object(
    'code', v_coupon.code,
    'discount_type', v_coupon.discount_type,
    'discount_value', v_coupon.discount_value,
    'discount_iqd', v_discount,
    'delivery_fee_iqd', v_fee.amount_iqd,
    'delivery_fee_final', v_final
  );
end;
$$;

revoke all on function public.validate_delivery_coupon(text, uuid) from public;
grant execute on function public.validate_delivery_coupon(text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 9) Replace create order — option ids only (drop old signature)
-- ---------------------------------------------------------------------------
drop function if exists public.create_own_delivery_order(
  uuid, text, int, numeric, text, double precision, double precision, text, text
);

create or replace function public.create_own_delivery_order(
  p_order_type_id uuid,
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
  if v_address is not null and length(v_address) > 500 then
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
  uuid, text, uuid, uuid, text, double precision, double precision, text, text
) from public;
grant execute on function public.create_own_delivery_order(
  uuid, text, uuid, uuid, text, double precision, double precision, text, text
) to authenticated;

-- Update detail JSON with fee final
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
    'delivery_fee_final', coalesce(o.delivery_fee_final, greatest(o.delivery_fee_iqd - o.coupon_discount_iqd, 0)),
    'coupon_code', o.coupon_code,
    'destination_type', o.destination_type,
    'destination_lat', o.destination_lat,
    'destination_lng', o.destination_lng,
    'destination_address', o.destination_address,
    'destination_label', public._delivery_destination_label(
      o.destination_type, o.destination_address
    ),
    'delete_after_minutes', o.delete_after_minutes,
    'created_at', o.created_at,
    'expires_at', o.expires_at,
    'accepted_at', o.accepted_at,
    'captain_id', o.captain_id,
    'captain_name', captain.full_name,
    'captain_phone', captain.phone
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 10) Admin duration RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_delivery_durations()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();
  return coalesce((
    select jsonb_agg(row_to_json(q)::jsonb order by q.sort_order, q.minutes)
    from (
      select id, label_ar, minutes, is_active, is_default, sort_order, created_at, updated_at
      from public.order_delete_durations
    ) q
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_upsert_delivery_duration(
  p_id uuid,
  p_label_ar text,
  p_minutes int,
  p_is_active boolean,
  p_sort_order int,
  p_is_default boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.order_delete_durations;
  v_label text := trim(coalesce(p_label_ar, ''));
begin
  perform public.require_dashboard_admin();
  if p_minutes is null or p_minutes <= 0 then
    raise exception 'المدة بالدقائق مطلوبة' using errcode = '22023';
  end if;
  if length(v_label) < 1 then
    raise exception 'اسم المدة مطلوب' using errcode = '22023';
  end if;

  if coalesce(p_is_default, false) then
    update public.order_delete_durations set is_default = false where is_default = true;
  end if;

  if p_id is null then
    insert into public.order_delete_durations (
      label_ar, minutes, is_active, sort_order, is_default, updated_by, updated_at
    ) values (
      v_label, p_minutes, coalesce(p_is_active, true), coalesce(p_sort_order, 0),
      coalesce(p_is_default, false), auth.uid(), now()
    )
    returning * into v_row;
  else
    update public.order_delete_durations
    set
      label_ar = v_label,
      minutes = p_minutes,
      is_active = coalesce(p_is_active, is_active),
      sort_order = coalesce(p_sort_order, sort_order),
      is_default = coalesce(p_is_default, is_default),
      updated_by = auth.uid(),
      updated_at = now()
    where id = p_id
    returning * into v_row;
    if v_row.id is null then
      raise exception 'المدة غير موجودة' using errcode = 'P0001';
    end if;
  end if;

  return row_to_json(v_row)::jsonb;
end;
$$;

create or replace function public.admin_toggle_delivery_duration(
  p_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.order_delete_durations;
begin
  perform public.require_dashboard_admin();
  update public.order_delete_durations
  set
    is_active = coalesce(p_is_active, not is_active),
    is_default = case when coalesce(p_is_active, not is_active) then is_default else false end,
    updated_by = auth.uid(),
    updated_at = now()
  where id = p_id
  returning * into v_row;
  if v_row.id is null then
    raise exception 'المدة غير موجودة' using errcode = 'P0001';
  end if;
  return row_to_json(v_row)::jsonb;
end;
$$;

create or replace function public.admin_set_default_delivery_duration(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.order_delete_durations;
begin
  perform public.require_dashboard_admin();
  update public.order_delete_durations set is_default = false where is_default = true;
  update public.order_delete_durations
  set is_default = true, is_active = true, updated_by = auth.uid(), updated_at = now()
  where id = p_id
  returning * into v_row;
  if v_row.id is null then
    raise exception 'المدة غير موجودة' using errcode = 'P0001';
  end if;
  return row_to_json(v_row)::jsonb;
end;
$$;

revoke all on function public.admin_list_delivery_durations() from public;
revoke all on function public.admin_upsert_delivery_duration(uuid, text, int, boolean, int, boolean) from public;
revoke all on function public.admin_toggle_delivery_duration(uuid, boolean) from public;
revoke all on function public.admin_set_default_delivery_duration(uuid) from public;

grant execute on function public.admin_list_delivery_durations() to authenticated;
grant execute on function public.admin_upsert_delivery_duration(uuid, text, int, boolean, int, boolean) to authenticated;
grant execute on function public.admin_toggle_delivery_duration(uuid, boolean) to authenticated;
grant execute on function public.admin_set_default_delivery_duration(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 11) Admin fee RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_delivery_fees()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();
  return coalesce((
    select jsonb_agg(row_to_json(q)::jsonb order by q.sort_order, q.amount_iqd)
    from (
      select id, label_ar, amount_iqd, is_active, is_default, sort_order, created_at, updated_at
      from public.delivery_fee_options
    ) q
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_upsert_delivery_fee(
  p_id uuid,
  p_label_ar text,
  p_amount_iqd numeric,
  p_is_active boolean,
  p_sort_order int,
  p_is_default boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.delivery_fee_options;
  v_label text := trim(coalesce(p_label_ar, ''));
begin
  perform public.require_dashboard_admin();
  if p_amount_iqd is null or p_amount_iqd < 0 then
    raise exception 'مبلغ الأجرة غير صالح' using errcode = '22023';
  end if;
  if length(v_label) < 1 then
    v_label := trim(to_char(p_amount_iqd, 'FM999,999,999')) || ' د.ع';
  end if;

  if coalesce(p_is_default, false) then
    update public.delivery_fee_options set is_default = false where is_default = true;
  end if;

  if p_id is null then
    insert into public.delivery_fee_options (
      label_ar, amount_iqd, is_active, sort_order, is_default, updated_by, updated_at
    ) values (
      v_label, p_amount_iqd, coalesce(p_is_active, true), coalesce(p_sort_order, 0),
      coalesce(p_is_default, false), auth.uid(), now()
    )
    returning * into v_row;
  else
    update public.delivery_fee_options
    set
      label_ar = v_label,
      amount_iqd = p_amount_iqd,
      is_active = coalesce(p_is_active, is_active),
      sort_order = coalesce(p_sort_order, sort_order),
      is_default = coalesce(p_is_default, is_default),
      updated_by = auth.uid(),
      updated_at = now()
    where id = p_id
    returning * into v_row;
    if v_row.id is null then
      raise exception 'أجرة التوصيل غير موجودة' using errcode = 'P0001';
    end if;
  end if;

  return row_to_json(v_row)::jsonb;
end;
$$;

create or replace function public.admin_toggle_delivery_fee(
  p_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.delivery_fee_options;
begin
  perform public.require_dashboard_admin();
  update public.delivery_fee_options
  set
    is_active = coalesce(p_is_active, not is_active),
    is_default = case when coalesce(p_is_active, not is_active) then is_default else false end,
    updated_by = auth.uid(),
    updated_at = now()
  where id = p_id
  returning * into v_row;
  if v_row.id is null then
    raise exception 'أجرة التوصيل غير موجودة' using errcode = 'P0001';
  end if;
  return row_to_json(v_row)::jsonb;
end;
$$;

create or replace function public.admin_set_default_delivery_fee(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.delivery_fee_options;
begin
  perform public.require_dashboard_admin();
  update public.delivery_fee_options set is_default = false where is_default = true;
  update public.delivery_fee_options
  set is_default = true, is_active = true, updated_by = auth.uid(), updated_at = now()
  where id = p_id
  returning * into v_row;
  if v_row.id is null then
    raise exception 'أجرة التوصيل غير موجودة' using errcode = 'P0001';
  end if;
  return row_to_json(v_row)::jsonb;
end;
$$;

revoke all on function public.admin_list_delivery_fees() from public;
revoke all on function public.admin_upsert_delivery_fee(uuid, text, numeric, boolean, int, boolean) from public;
revoke all on function public.admin_toggle_delivery_fee(uuid, boolean) from public;
revoke all on function public.admin_set_default_delivery_fee(uuid) from public;

grant execute on function public.admin_list_delivery_fees() to authenticated;
grant execute on function public.admin_upsert_delivery_fee(uuid, text, numeric, boolean, int, boolean) to authenticated;
grant execute on function public.admin_toggle_delivery_fee(uuid, boolean) to authenticated;
grant execute on function public.admin_set_default_delivery_fee(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 12) Admin coupon RPCs
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
        id, code, discount_type, discount_value, is_active,
        starts_at, expires_at, max_uses, used_count,
        min_delivery_fee_iqd, max_discount_iqd, max_uses_per_user,
        created_at, updated_at
      from public.coupons
    ) q
  ), '[]'::jsonb);
end;
$$;

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
  v_code text := upper(trim(coalesce(p_code, '')));
  v_type text := lower(trim(coalesce(p_discount_type, '')));
begin
  perform public.require_dashboard_admin();
  if length(v_code) < 2 then
    raise exception 'كود الكوبون مطلوب' using errcode = '22023';
  end if;
  if v_type not in ('percent', 'fixed') then
    raise exception 'نوع الخصم غير صالح' using errcode = '22023';
  end if;
  if p_discount_value is null or p_discount_value <= 0 then
    raise exception 'قيمة الخصم غير صالحة' using errcode = '22023';
  end if;
  if v_type = 'percent' and p_discount_value > 100 then
    raise exception 'نسبة الخصم لا تتجاوز 100' using errcode = '22023';
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
      code = v_code,
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
end;
$$;

create or replace function public.admin_toggle_delivery_coupon(
  p_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.coupons;
begin
  perform public.require_dashboard_admin();
  update public.coupons
  set
    is_active = coalesce(p_is_active, not is_active),
    updated_by = auth.uid(),
    updated_at = now()
  where id = p_id
  returning * into v_row;
  if v_row.id is null then
    raise exception 'الكوبون غير موجود' using errcode = 'P0001';
  end if;
  return row_to_json(v_row)::jsonb;
end;
$$;

revoke all on function public.admin_list_delivery_coupons() from public;
revoke all on function public.admin_upsert_delivery_coupon(
  uuid, text, text, numeric, boolean, timestamptz, timestamptz, int, numeric, numeric, int
) from public;
revoke all on function public.admin_toggle_delivery_coupon(uuid, boolean) from public;

grant execute on function public.admin_list_delivery_coupons() to authenticated;
grant execute on function public.admin_upsert_delivery_coupon(
  uuid, text, text, numeric, boolean, timestamptz, timestamptz, int, numeric, numeric, int
) to authenticated;
grant execute on function public.admin_toggle_delivery_coupon(uuid, boolean) to authenticated;
