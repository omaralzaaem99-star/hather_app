-- 051: Admin user orders search — phone normalization, name, request_number (# prefix).
-- Depends on: 037 (_iraq_phone_matches_search), 045 (admin_list_user_orders).

-- ---------------------------------------------------------------------------
-- Shared search predicate (phone E.164/local, partial name, request_number / #)
-- ---------------------------------------------------------------------------
create or replace function public._admin_user_order_matches_search(
  p_full_name text,
  p_phone text,
  p_request_number bigint,
  p_search text
)
returns boolean
language plpgsql
immutable
as $$
declare
  q text;
  q_order text;
begin
  q := nullif(btrim(coalesce(p_search, '')), '');
  if q is null then
    return true;
  end if;

  if coalesce(p_full_name, '') ilike '%' || q || '%' then
    return true;
  end if;

  if public._iraq_phone_matches_search(p_phone, q) then
    return true;
  end if;

  q_order := regexp_replace(q, '^#+', '');
  if q_order <> ''
     and p_request_number is not null
     and p_request_number::text ilike '%' || q_order || '%' then
    return true;
  end if;

  return false;
end;
$$;

revoke all on function public._admin_user_order_matches_search(text, text, bigint, text)
  from public;

create or replace function public.admin_list_user_orders(
  p_limit int default 150,
  p_status_filter text default 'all',
  p_search text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  lim int;
  filt text := lower(trim(coalesce(p_status_filter, 'all')));
  q text := nullif(trim(coalesce(p_search, '')), '');
  v_counts jsonb;
  v_orders jsonb;
begin
  perform public.require_dashboard_admin();

  lim := greatest(1, least(coalesce(p_limit, 150), 500));

  if filt not in (
    'all', 'pending', 'active', 'customer_no_answer', 'completed', 'expired', 'cancelled'
  ) then
    raise exception 'فلتر الحالة غير صالح' using errcode = '22023';
  end if;

  with scoped as (
    select
      o.id,
      o.request_number,
      o.user_id,
      p.full_name as user_full_name,
      p.phone as user_phone,
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
      o.completed_at,
      exists (
        select 1
        from public.delivery_order_events e
        where e.order_id = o.id
          and e.event_type = 'customer_no_answer'
      ) as has_customer_no_answer,
      (
        select max(e.created_at)
        from public.delivery_order_events e
        where e.order_id = o.id
          and e.event_type = 'customer_no_answer'
      ) as customer_no_answer_at
    from public.delivery_orders o
    left join public.profiles p on p.id = o.user_id
    where public._admin_user_order_matches_search(
      p.full_name,
      p.phone,
      o.request_number,
      q
    )
  )
  select jsonb_build_object(
    'all', count(*)::int,
    'pending', count(*) filter (where status = 'pending')::int,
    'active', count(*) filter (where status = 'active')::int,
    'customer_no_answer', count(*) filter (where has_customer_no_answer)::int,
    'completed', count(*) filter (where status = 'completed')::int,
    'expired', count(*) filter (where status = 'expired')::int,
    'cancelled', count(*) filter (where status = 'cancelled')::int
  )
  into v_counts
  from scoped;

  with scoped as (
    select
      o.id,
      o.request_number,
      o.user_id,
      p.full_name as user_full_name,
      p.phone as user_phone,
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
      o.completed_at,
      exists (
        select 1
        from public.delivery_order_events e
        where e.order_id = o.id
          and e.event_type = 'customer_no_answer'
      ) as has_customer_no_answer,
      (
        select max(e.created_at)
        from public.delivery_order_events e
        where e.order_id = o.id
          and e.event_type = 'customer_no_answer'
      ) as customer_no_answer_at
    from public.delivery_orders o
    left join public.profiles p on p.id = o.user_id
    where public._admin_user_order_matches_search(
      p.full_name,
      p.phone,
      o.request_number,
      q
    )
  ),
  filtered as (
    select *
    from scoped s
    where
      filt = 'all'
      or (filt = 'pending' and s.status = 'pending')
      or (filt = 'active' and s.status = 'active')
      or (filt = 'customer_no_answer' and s.has_customer_no_answer)
      or (filt = 'completed' and s.status = 'completed')
      or (filt = 'expired' and s.status = 'expired')
      or (filt = 'cancelled' and s.status = 'cancelled')
    order by s.created_at desc
    limit lim
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', f.id,
        'request_number', f.request_number,
        'user_id', f.user_id,
        'user_full_name', f.user_full_name,
        'user_phone', f.user_phone,
        'order_type_name', f.order_type_name,
        'details', f.details,
        'status', f.status,
        'delivery_fee_iqd', f.delivery_fee_iqd,
        'coupon_code', f.coupon_code,
        'coupon_discount_iqd', f.coupon_discount_iqd,
        'destination_type', f.destination_type,
        'destination_lat', f.destination_lat,
        'destination_lng', f.destination_lng,
        'destination_address', f.destination_address,
        'created_at', f.created_at,
        'expires_at', f.expires_at,
        'accepted_at', f.accepted_at,
        'completed_at', f.completed_at,
        'has_customer_no_answer', f.has_customer_no_answer,
        'customer_no_answer_at', f.customer_no_answer_at
      )
      order by f.created_at desc
    ),
    '[]'::jsonb
  )
  into v_orders
  from filtered f;

  return jsonb_build_object(
    'counts', coalesce(v_counts, '{}'::jsonb),
    'orders', coalesce(v_orders, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.admin_list_user_orders(int, text, text) from public;
grant execute on function public.admin_list_user_orders(int, text, text) to authenticated;
