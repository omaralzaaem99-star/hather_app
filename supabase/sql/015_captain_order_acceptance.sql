-- 015: Captain order discovery + atomic acceptance.
-- Requires: 004_delivery_orders, 008_admin_captain_management, 014_captain_subscription_system
--
-- Adds captain_id / accepted_at, hardens secure columns, and SECURITY DEFINER RPCs.
-- Captains never get blanket SELECT on delivery_orders — lists go through RPCs only.

do $$
begin
  if to_regclass('public.delivery_orders') is null then
    raise exception 'Missing public.delivery_orders — apply 004 first';
  end if;
  if to_regprocedure('public.captain_has_active_subscription(uuid)') is null then
    raise exception 'Missing captain_has_active_subscription — apply 014 first';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1) Schema
-- ---------------------------------------------------------------------------
alter table public.delivery_orders
  add column if not exists captain_id uuid references public.profiles (id) on delete set null,
  add column if not exists accepted_at timestamptz;

create index if not exists delivery_orders_captain_id_idx
  on public.delivery_orders (captain_id, created_at desc);

create index if not exists delivery_orders_available_idx
  on public.delivery_orders (status, expires_at)
  where captain_id is null and status = 'pending';

-- ---------------------------------------------------------------------------
-- 2) Secure columns — block client tampering with assignment / acceptance
-- ---------------------------------------------------------------------------
create or replace function public.enforce_delivery_order_secure_columns()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and current_user = 'authenticated' then
    new.id := old.id;
    new.user_id := old.user_id;
    new.captain_id := old.captain_id;
    new.accepted_at := old.accepted_at;
    new.delivery_fee_iqd := old.delivery_fee_iqd;
    new.coupon_code := old.coupon_code;
    new.coupon_discount_iqd := old.coupon_discount_iqd;
    new.delete_after_minutes := old.delete_after_minutes;
    new.expires_at := old.expires_at;
    new.created_at := old.created_at;
    new.status := old.status;
    new.order_type_id := old.order_type_id;
    new.order_type_name := old.order_type_name;
    new.details := old.details;
    new.destination_type := old.destination_type;
    new.destination_lat := old.destination_lat;
    new.destination_lng := old.destination_lng;
    new.destination_address := old.destination_address;
  end if;

  if tg_op = 'INSERT' and current_user = 'authenticated' then
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'invalid order owner' using errcode = '42501';
    end if;
    new.status := 'pending';
    new.captain_id := null;
    new.accepted_at := null;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Internal captain validation helpers
-- ---------------------------------------------------------------------------
create or replace function public._require_active_captain()
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select * into prof from public.profiles where id = auth.uid();
  if prof.id is null then
    raise exception 'profile not found' using errcode = 'P0001';
  end if;
  if prof.account_type <> 'captain' then
    raise exception 'captain only' using errcode = 'P0001';
  end if;
  if prof.account_status <> 'active' then
    raise exception 'captain account not active' using errcode = 'P0001';
  end if;

  return prof;
end;
$$;

revoke all on function public._require_active_captain() from public;

create or replace function public._delivery_destination_label(
  p_destination_type text,
  p_destination_address text
)
returns text
language sql
immutable
as $$
  select case
    when p_destination_type = 'map'
      and p_destination_address is not null
      and length(trim(p_destination_address)) > 0
      then trim(p_destination_address)
    when p_destination_type = 'map' then 'موقع على الخريطة'
    else 'موقع العميل الحالي'
  end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Available orders (privacy-safe preview — no user phone/id)
-- ---------------------------------------------------------------------------
create or replace function public.captain_list_available_orders()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  result jsonb;
begin
  prof := public._require_active_captain();

  if not public.captain_has_active_subscription(prof.id) then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_data order by created_at desc), '[]'::jsonb)
  into result
  from (
    select jsonb_build_object(
      'id', o.id,
      'order_type_name', o.order_type_name,
      'details', o.details,
      'destination_label', public._delivery_destination_label(
        o.destination_type, o.destination_address
      ),
      'delivery_fee_iqd', o.delivery_fee_iqd,
      'created_at', o.created_at,
      'expires_at', o.expires_at
    ) as row_data,
    o.created_at
    from public.delivery_orders o
    where o.status = 'pending'
      and o.captain_id is null
      and o.expires_at > now()
  ) q;

  return result;
end;
$$;

revoke all on function public.captain_list_available_orders() from public;
grant execute on function public.captain_list_available_orders() to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Atomic accept — one captain wins the race
-- ---------------------------------------------------------------------------
create or replace function public.captain_accept_delivery_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  updated_row public.delivery_orders;
begin
  prof := public._require_active_captain();

  if not public.captain_has_active_subscription(prof.id) then
    raise exception 'اشتراكك غير فعال. فعّل الاشتراك لتتمكن من قبول الطلبات.'
      using errcode = 'P0001';
  end if;

  if p_order_id is null then
    raise exception 'order id required' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.delivery_orders where id = p_order_id
  ) then
    raise exception 'الطلب لم يعد متاحاً' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.delivery_orders
    where id = p_order_id and expires_at <= now()
  ) then
    raise exception 'انتهت صلاحية هذا الطلب' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.delivery_orders
    where id = p_order_id
      and (status <> 'pending' or captain_id is not null)
  ) then
    raise exception 'تم قبول هذا الطلب من كابتن آخر' using errcode = 'P0001';
  end if;

  update public.delivery_orders
  set
    captain_id = prof.id,
    status = 'active',
    accepted_at = now(),
    updated_at = now()
  where id = p_order_id
    and status = 'pending'
    and captain_id is null
    and expires_at > now()
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'تم قبول هذا الطلب من كابتن آخر' using errcode = 'P0001';
  end if;

  return public._captain_order_detail_json(updated_row.id, prof.id);
end;
$$;

revoke all on function public.captain_accept_delivery_order(uuid) from public;
grant execute on function public.captain_accept_delivery_order(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) My orders
-- ---------------------------------------------------------------------------
create or replace function public.captain_list_my_orders()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  result jsonb;
begin
  prof := public._require_active_captain();

  select coalesce(jsonb_agg(row_data order by sort_ts desc), '[]'::jsonb)
  into result
  from (
    select jsonb_build_object(
      'id', o.id,
      'order_type_name', o.order_type_name,
      'details', o.details,
      'destination_label', public._delivery_destination_label(
        o.destination_type, o.destination_address
      ),
      'delivery_fee_iqd', o.delivery_fee_iqd,
      'status', o.status,
      'created_at', o.created_at,
      'accepted_at', o.accepted_at,
      'expires_at', o.expires_at
    ) as row_data,
    coalesce(o.accepted_at, o.created_at) as sort_ts
    from public.delivery_orders o
    where o.captain_id = prof.id
      and o.status in ('active', 'completed', 'cancelled')
  ) q;

  return result;
end;
$$;

revoke all on function public.captain_list_my_orders() from public;
grant execute on function public.captain_list_my_orders() to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Accepted order detail (ownership enforced)
-- ---------------------------------------------------------------------------
create or replace function public._captain_order_detail_json(
  p_order_id uuid,
  p_captain_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.delivery_orders;
  customer public.profiles;
begin
  select * into o
  from public.delivery_orders
  where id = p_order_id and captain_id = p_captain_id;

  if o.id is null then
    raise exception 'order not found' using errcode = 'P0001';
  end if;

  select * into customer from public.profiles where id = o.user_id;

  return jsonb_build_object(
    'id', o.id,
    'order_type_name', o.order_type_name,
    'details', o.details,
    'status', o.status,
    'delivery_fee_iqd', o.delivery_fee_iqd,
    'coupon_discount_iqd', o.coupon_discount_iqd,
    'destination_type', o.destination_type,
    'destination_label', public._delivery_destination_label(
      o.destination_type, o.destination_address
    ),
    'destination_lat', o.destination_lat,
    'destination_lng', o.destination_lng,
    'destination_address', o.destination_address,
    'created_at', o.created_at,
    'accepted_at', o.accepted_at,
    'expires_at', o.expires_at,
    'customer_name', customer.full_name,
    'customer_phone', customer.phone
  );
end;
$$;

revoke all on function public._captain_order_detail_json(uuid, uuid) from public;

create or replace function public.captain_get_my_order_detail(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
begin
  prof := public._require_active_captain();

  if p_order_id is null then
    raise exception 'order id required' using errcode = '22023';
  end if;

  return public._captain_order_detail_json(p_order_id, prof.id);
end;
$$;

revoke all on function public.captain_get_my_order_detail(uuid) from public;
grant execute on function public.captain_get_my_order_detail(uuid) to authenticated;
