-- 053: Admin search hardening
-- - User orders: search by captain name/phone (keeps user + request_number)
-- - Finance captain subscriptions: use _iraq_phone_matches_search
-- - Transfer/assign captain picker: use _iraq_phone_matches_search
-- Depends on: 037 (_iraq_phone_matches_search), 051 (_admin_user_order_matches_search),
--             044 (finance lists), 046 (eligible transfer captains).

-- ---------------------------------------------------------------------------
-- 1) User-order search predicate — add captain name/phone
-- ---------------------------------------------------------------------------
drop function if exists public._admin_user_order_matches_search(text, text, bigint, text);

create or replace function public._admin_user_order_matches_search(
  p_user_full_name text,
  p_user_phone text,
  p_captain_full_name text,
  p_captain_phone text,
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

  if coalesce(p_user_full_name, '') ilike '%' || q || '%' then
    return true;
  end if;

  if public._iraq_phone_matches_search(p_user_phone, q) then
    return true;
  end if;

  if coalesce(p_captain_full_name, '') ilike '%' || q || '%' then
    return true;
  end if;

  if public._iraq_phone_matches_search(p_captain_phone, q) then
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

revoke all on function public._admin_user_order_matches_search(text, text, text, text, bigint, text)
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
    left join public.profiles cp on cp.id = o.captain_id
    where public._admin_user_order_matches_search(
      p.full_name,
      p.phone,
      cp.full_name,
      cp.phone,
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
    left join public.profiles cp on cp.id = o.captain_id
    where public._admin_user_order_matches_search(
      p.full_name,
      p.phone,
      cp.full_name,
      cp.phone,
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

-- ---------------------------------------------------------------------------
-- 2) Finance captain subscriptions — normalized phone search
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_finance_captain_subscriptions(
  p_search text default null,
  p_status text default null,
  p_range text default 'all',
  p_from date default null,
  p_to date default null
)
returns table (
  event_id uuid,
  captain_id uuid,
  captain_name text,
  captain_phone text,
  amount_iqd bigint,
  duration_days int,
  starts_at timestamptz,
  ends_at timestamptz,
  status_label text,
  performed_by_label text,
  event_type text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  bounds record;
  q text := trim(coalesce(p_search, ''));
  st text := lower(trim(coalesce(p_status, 'all')));
begin
  perform public.require_dashboard_admin();

  select * into bounds from public._finance_bounds(p_range, p_from, p_to) limit 1;

  return query
  select
    e.id as event_id,
    e.captain_id,
    coalesce(p.full_name, '—') as captain_name,
    coalesce(p.phone, '') as captain_phone,
    e.amount_iqd,
    e.duration_days,
    e.starts_at,
    e.ends_at,
    case
      when e.event_type = 'trial_granted' then 'trial'
      when e.ends_at > now() then 'active'
      else 'expired'
    end as status_label,
    coalesce(
      nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
      'أدمن'
    ) as performed_by_label,
    e.event_type,
    e.created_at
  from public.captain_subscription_events e
  join public.profiles p on p.id = e.captain_id
  left join auth.users u on u.id = e.performed_by
  where (bounds.starts_at is null or e.created_at >= bounds.starts_at)
    and (bounds.ends_at is null or e.created_at < bounds.ends_at)
    and (
      q = ''
      or p.full_name ilike '%' || q || '%'
      or public._iraq_phone_matches_search(p.phone, q)
    )
    and (
      st = 'all'
      or (st = 'trial' and e.event_type = 'trial_granted')
      or (st = 'active' and e.event_type <> 'trial_granted' and e.ends_at > now())
      or (st = 'expired' and e.event_type <> 'trial_granted' and e.ends_at <= now())
      or (st = 'inactive' and false)
    )
  order by e.created_at desc;
end;
$$;

revoke all on function public.admin_list_finance_captain_subscriptions(text, text, text, date, date) from public;
grant execute on function public.admin_list_finance_captain_subscriptions(text, text, text, date, date) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Eligible transfer/assign captains — normalized phone search
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_eligible_transfer_captains(
  p_order_id uuid,
  p_search text default null,
  p_limit int default 30
)
returns table (
  captain_id uuid,
  full_name text,
  phone text,
  subscription_label text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  lim int;
  q text := nullif(trim(coalesce(p_search, '')), '');
  v_current uuid;
begin
  perform public.require_dashboard_admin();

  select o.captain_id into v_current
  from public.delivery_orders o
  where o.id = p_order_id;

  lim := greatest(1, least(coalesce(p_limit, 30), 100));

  return query
  select
    p.id as captain_id,
    coalesce(p.full_name, '—') as full_name,
    coalesce(p.phone, '') as phone,
    (public._captain_subscription_status_json(p.id) ->> 'label') as subscription_label
  from public.profiles p
  where public._captain_is_available_orders_eligible(p.id)
    and (v_current is null or p.id <> v_current)
    and (
      q is null
      or coalesce(p.full_name, '') ilike '%' || q || '%'
      or public._iraq_phone_matches_search(p.phone, q)
    )
  order by p.full_name asc nulls last, p.created_at desc
  limit lim;
end;
$$;

revoke all on function public.admin_list_eligible_transfer_captains(uuid, text, int) from public;
grant execute on function public.admin_list_eligible_transfer_captains(uuid, text, int) to authenticated;
