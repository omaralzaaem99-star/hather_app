-- 052: Captain max concurrent active orders — settings, capacity guard, FCM filter.
-- Depends on: 014 (app_settings), 040 (_captain_is_available_orders_eligible),
--             047 (captain_accept_delivery_order), 049 (captain_list_available_orders).

alter table public.app_settings
  add column if not exists captain_max_active_orders integer not null default 1;

alter table public.app_settings
  drop constraint if exists app_settings_captain_max_active_orders_chk;

alter table public.app_settings
  add constraint app_settings_captain_max_active_orders_chk check (
    captain_max_active_orders >= 1
  );

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public._captain_max_active_orders()
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select greatest(
    1,
    coalesce(
      (select s.captain_max_active_orders from public.app_settings s where s.id = 1),
      1
    )
  );
$$;

revoke all on function public._captain_max_active_orders() from public;

create or replace function public._captain_active_order_count(p_captain_id uuid)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::integer
  from public.delivery_orders o
  where o.captain_id = p_captain_id
    and o.status = 'active';
$$;

revoke all on function public._captain_active_order_count(uuid) from public;

create or replace function public._captain_can_accept_more_orders(p_captain_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public._captain_active_order_count(p_captain_id)
    < public._captain_max_active_orders();
$$;

revoke all on function public._captain_can_accept_more_orders(uuid) from public;

-- ---------------------------------------------------------------------------
-- Eligibility — subscription + under active-order capacity
-- ---------------------------------------------------------------------------
create or replace function public._captain_is_available_orders_eligible(p_captain_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_captain_id
      and p.account_type = 'captain'
      and p.account_status = 'active'
      and public.captain_has_active_subscription(p.id)
      and public._captain_can_accept_more_orders(p.id)
  );
$$;

-- ---------------------------------------------------------------------------
-- Captain capacity (Flutter UI)
-- ---------------------------------------------------------------------------
create or replace function public.captain_get_active_order_capacity()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  v_active integer;
  v_max integer;
begin
  prof := public._require_active_captain();
  v_active := public._captain_active_order_count(prof.id);
  v_max := public._captain_max_active_orders();

  return jsonb_build_object(
    'active_count', v_active,
    'max_active_orders', v_max,
    'at_capacity', v_active >= v_max
  );
end;
$$;

revoke all on function public.captain_get_active_order_capacity() from public;
grant execute on function public.captain_get_active_order_capacity() to authenticated;

-- ---------------------------------------------------------------------------
-- Available orders — hide pool when captain is at capacity
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

  if not public._captain_can_accept_more_orders(prof.id) then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_data order by created_at asc), '[]'::jsonb)
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

-- ---------------------------------------------------------------------------
-- Accept — atomic capacity guard inside UPDATE
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
  v_num text;
  v_name text;
  v_body text;
  v_event_id uuid;
  v_active integer;
  v_max integer;
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

  v_active := public._captain_active_order_count(prof.id);
  v_max := public._captain_max_active_orders();
  if v_active >= v_max then
    raise exception
      'لديك الحد الأقصى من الطلبات قيد التنفيذ. أكمل أحد طلباتك لاستلام طلب جديد.'
      using errcode = 'P0001';
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
    and (
      select count(*)::integer
      from public.delivery_orders d
      where d.captain_id = prof.id
        and d.status = 'active'
    ) < v_max
  returning * into updated_row;

  if updated_row.id is null then
    v_active := public._captain_active_order_count(prof.id);
    if v_active >= v_max then
      raise exception
        'لديك الحد الأقصى من الطلبات قيد التنفيذ. أكمل أحد طلباتك لاستلام طلب جديد.'
        using errcode = 'P0001';
    end if;
    raise exception 'تم قبول هذا الطلب من كابتن آخر' using errcode = 'P0001';
  end if;

  v_event_id := public._insert_delivery_order_event(
    updated_row.id,
    'accepted',
    prof.id,
    null,
    jsonb_build_object('accepted_at', updated_row.accepted_at)
  );

  v_num := coalesce(updated_row.request_number::text, '');
  v_name := nullif(btrim(coalesce(prof.full_name, '')), '');
  if v_name is not null and v_num <> '' then
    v_body := 'وافق الكابتن ' || v_name || ' على طلبك رقم ' || v_num || ' وهو الآن قيد التوصيل.';
  elsif v_num <> '' then
    v_body := 'وافق كابتن على طلبك رقم ' || v_num || ' وهو الآن قيد التوصيل.';
  else
    v_body := 'وافق كابتن على طلبك وهو الآن قيد التوصيل.';
  end if;

  perform public._insert_user_notification(
    p_user_id := updated_row.user_id,
    p_type := 'delivery_order_accepted'::text,
    p_title := 'تم قبول طلبك'::text,
    p_body := v_body,
    p_order_id := updated_row.id,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'delivery_order_accepted:' || updated_row.id::text || ':' ||
      coalesce(v_event_id::text, '')
    )::text,
    p_tap_destination := NULL::text
  );

  return public._captain_order_detail_json(updated_row.id, prof.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin — delivery order settings (delivery tab)
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_delivery_order_settings()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.app_settings;
begin
  perform public.require_dashboard_admin();

  select * into s from public.app_settings where id = 1;
  if s.id is null then
    insert into public.app_settings (id) values (1)
    returning * into s;
  end if;

  return jsonb_build_object(
    'captain_max_active_orders', s.captain_max_active_orders,
    'updated_at', s.updated_at,
    'updated_by', s.updated_by
  );
end;
$$;

create or replace function public.admin_update_delivery_order_settings(
  p_captain_max_active_orders integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.app_settings;
  v_max integer;
begin
  perform public.require_dashboard_admin();

  v_max := coalesce(p_captain_max_active_orders, 0);
  if v_max < 1 then
    raise exception 'captain_max_active_orders must be >= 1' using errcode = '22023';
  end if;

  insert into public.app_settings (
    id, captain_max_active_orders, updated_at, updated_by
  ) values (
    1, v_max, now(), auth.uid()
  )
  on conflict (id) do update
    set
      captain_max_active_orders = excluded.captain_max_active_orders,
      updated_at = excluded.updated_at,
      updated_by = excluded.updated_by
  returning * into s;

  return jsonb_build_object(
    'captain_max_active_orders', s.captain_max_active_orders,
    'updated_at', s.updated_at,
    'updated_by', s.updated_by
  );
end;
$$;

revoke all on function public.admin_get_delivery_order_settings() from public;
revoke all on function public.admin_update_delivery_order_settings(integer) from public;
grant execute on function public.admin_get_delivery_order_settings() to authenticated;
grant execute on function public.admin_update_delivery_order_settings(integer) to authenticated;
