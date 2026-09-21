-- 029: Captain completes active delivery order (active → completed)
-- Depends on: 015 (captain_id, accept, helpers), 028 (request_number, JSON helpers)
-- Does NOT require subscription for complete (only accept does).

-- ---------------------------------------------------------------------------
-- 1) completed_at column
-- ---------------------------------------------------------------------------
alter table public.delivery_orders
  add column if not exists completed_at timestamptz;

comment on column public.delivery_orders.completed_at is
  'Set when owning captain marks order delivered; null until completed.';

-- ---------------------------------------------------------------------------
-- 2) Secure columns: freeze completed_at for authenticated clients
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
    new.completed_at := old.completed_at;
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
    new.request_number := old.request_number;
  end if;

  if tg_op = 'INSERT' and current_user = 'authenticated' then
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'invalid order owner' using errcode = '42501';
    end if;
    new.status := 'pending';
    new.captain_id := null;
    new.accepted_at := null;
    new.completed_at := null;
    new.request_number := nextval('public.delivery_order_request_number_seq');
  end if;

  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) JSON helpers include completed_at (fee snapshot unchanged)
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
    'request_number', o.request_number,
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
    'completed_at', o.completed_at,
    'captain_id', o.captain_id,
    'captain_name', captain.full_name,
    'captain_phone', captain.phone
  );
end;
$$;

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
    'request_number', o.request_number,
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
    'completed_at', o.completed_at,
    'expires_at', o.expires_at,
    'customer_name', customer.full_name,
    'customer_phone', customer.phone
  );
end;
$$;

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
      'request_number', o.request_number,
      'order_type_name', o.order_type_name,
      'details', o.details,
      'destination_label', public._delivery_destination_label(
        o.destination_type, o.destination_address
      ),
      'delivery_fee_iqd', o.delivery_fee_iqd,
      'status', o.status,
      'created_at', o.created_at,
      'accepted_at', o.accepted_at,
      'completed_at', o.completed_at,
      'expires_at', o.expires_at
    ) as row_data,
    coalesce(o.completed_at, o.accepted_at, o.created_at) as sort_ts
    from public.delivery_orders o
    where o.captain_id = prof.id
      and o.status in ('active', 'completed', 'cancelled')
  ) q;

  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Complete RPC — ownership + active only; NO subscription check
-- ---------------------------------------------------------------------------
create or replace function public.captain_complete_delivery_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  existing public.delivery_orders;
  updated_row public.delivery_orders;
begin
  -- auth + captain + active account (subscription NOT required)
  begin
    prof := public._require_active_captain();
  exception
    when others then
      raise exception 'لا يمكنك إكمال هذا الطلب' using errcode = 'P0001';
  end;

  if p_order_id is null then
    raise exception 'لا يمكنك إكمال هذا الطلب' using errcode = 'P0001';
  end if;

  select * into existing
  from public.delivery_orders
  where id = p_order_id;

  if existing.id is null then
    raise exception 'لا يمكنك إكمال هذا الطلب' using errcode = 'P0001';
  end if;

  if existing.captain_id is distinct from prof.id then
    raise exception 'لا يمكنك إكمال هذا الطلب' using errcode = 'P0001';
  end if;

  if existing.status = 'completed' then
    raise exception 'تم إكمال الطلب مسبقاً' using errcode = 'P0001';
  end if;

  if existing.status is distinct from 'active' then
    raise exception 'هذا الطلب لم يعد جارياً' using errcode = 'P0001';
  end if;

  update public.delivery_orders
  set
    status = 'completed',
    completed_at = now(),
    updated_at = now()
  where id = p_order_id
    and captain_id = prof.id
    and status = 'active'
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'هذا الطلب لم يعد جارياً' using errcode = 'P0001';
  end if;

  -- Fee snapshot columns intentionally untouched.
  return public._captain_order_detail_json(updated_row.id, prof.id);
end;
$$;

revoke all on function public.captain_complete_delivery_order(uuid) from public;
grant execute on function public.captain_complete_delivery_order(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Admin list: expose accepted_at + completed_at for detail display
-- ---------------------------------------------------------------------------
drop function if exists public.admin_list_user_orders(int);

create or replace function public.admin_list_user_orders(p_limit int default 150)
returns table (
  id uuid,
  request_number bigint,
  user_id uuid,
  user_full_name text,
  user_phone text,
  order_type_name text,
  details text,
  status text,
  delivery_fee_iqd numeric,
  coupon_code text,
  coupon_discount_iqd numeric,
  destination_type text,
  destination_lat double precision,
  destination_lng double precision,
  destination_address text,
  created_at timestamptz,
  expires_at timestamptz,
  accepted_at timestamptz,
  completed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  lim int;
begin
  perform public.require_dashboard_admin();
  lim := greatest(1, least(coalesce(p_limit, 150), 500));

  return query
  select
    o.id,
    o.request_number,
    o.user_id,
    p.full_name,
    p.phone,
    o.order_type_name,
    o.details,
    o.status,
    o.delivery_fee_iqd,
    o.coupon_code,
    o.coupon_discount_iqd,
    o.destination_type,
    o.destination_lat,
    o.destination_lng,
    o.destination_address,
    o.created_at,
    o.expires_at,
    o.accepted_at,
    o.completed_at
  from public.delivery_orders o
  left join public.profiles p on p.id = o.user_id
  order by o.created_at desc
  limit lim;
end;
$$;

revoke all on function public.admin_list_user_orders(int) from public;
grant execute on function public.admin_list_user_orders(int) to authenticated;
