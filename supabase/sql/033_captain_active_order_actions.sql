-- 033: Captain active-order actions (no-answer event + transfer to pool)
-- Depends on: 015 accept, 029 complete/detail JSON, 030 expire, 031 notifications
-- Does NOT modify older migration files; CREATE OR REPLACE only.

-- ---------------------------------------------------------------------------
-- 1) Order events (history; does not replace delivery_orders status)
-- ---------------------------------------------------------------------------
create table if not exists public.delivery_order_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.delivery_orders (id) on delete cascade,
  event_type text not null,
  actor_captain_id uuid null references public.profiles (id) on delete set null,
  reason text null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint delivery_order_events_type_chk check (
    event_type in (
      'accepted',
      'customer_no_answer',
      'transferred',
      'completed'
    )
  )
);

create index if not exists delivery_order_events_order_created_idx
  on public.delivery_order_events (order_id, created_at desc);

create index if not exists delivery_order_events_actor_created_idx
  on public.delivery_order_events (actor_captain_id, created_at desc)
  where actor_captain_id is not null;

alter table public.delivery_order_events enable row level security;

revoke all on table public.delivery_order_events from public;
revoke all on table public.delivery_order_events from anon;
revoke all on table public.delivery_order_events from authenticated;

-- No direct client writes; admin/service may read later via RPC if needed.
comment on table public.delivery_order_events is
  'Append-only captain/order lifecycle events. Preserves history when captain_id is cleared on transfer.';

create or replace function public._insert_delivery_order_event(
  p_order_id uuid,
  p_event_type text,
  p_actor_captain_id uuid default null,
  p_reason text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_order_id is null or p_event_type is null then
    return null;
  end if;

  insert into public.delivery_order_events (
    order_id, event_type, actor_captain_id, reason, metadata
  )
  values (
    p_order_id,
    p_event_type,
    p_actor_captain_id,
    nullif(btrim(coalesce(p_reason, '')), ''),
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public._insert_delivery_order_event(uuid, text, uuid, text, jsonb)
  from public;
revoke all on function public._insert_delivery_order_event(uuid, text, uuid, text, jsonb)
  from anon;
revoke all on function public._insert_delivery_order_event(uuid, text, uuid, text, jsonb)
  from authenticated;

-- ---------------------------------------------------------------------------
-- 2) Notification type: searching for another captain (after transfer)
-- ---------------------------------------------------------------------------
alter table public.user_notifications
  drop constraint if exists user_notifications_type_chk;

alter table public.user_notifications
  add constraint user_notifications_type_chk check (
    type in (
      'delivery_order_expired',
      'delivery_order_accepted',
      'delivery_order_completed',
      'delivery_order_searching_captain',
      'support_reply'
    )
  );

-- ---------------------------------------------------------------------------
-- 3) Captain detail JSON: include delivery_fee_final snapshot
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
    'request_number', o.request_number,
    'order_type_name', o.order_type_name,
    'details', o.details,
    'status', o.status,
    'delivery_fee_iqd', o.delivery_fee_iqd,
    'coupon_discount_iqd', o.coupon_discount_iqd,
    'delivery_fee_final', coalesce(
      o.delivery_fee_final,
      greatest(o.delivery_fee_iqd - o.coupon_discount_iqd, 0)
    ),
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

-- ---------------------------------------------------------------------------
-- 4) Accept: history event + re-acceptable notification dedupe
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

  -- Unique per accept cycle so transfer → re-accept can notify again.
  perform public._insert_user_notification(
    updated_row.user_id,
    'delivery_order_accepted',
    'تم قبول طلبك',
    v_body,
    updated_row.id,
    null,
    'delivery_order_accepted:' || updated_row.id::text || ':' || coalesce(v_event_id::text, '')
  );

  return public._captain_order_detail_json(updated_row.id, prof.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Complete: append completed event (status logic unchanged)
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
  v_num text;
begin
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

  perform public._insert_delivery_order_event(
    updated_row.id,
    'completed',
    prof.id,
    null,
    jsonb_build_object('completed_at', updated_row.completed_at)
  );

  v_num := coalesce(updated_row.request_number::text, '');
  perform public._insert_user_notification(
    updated_row.user_id,
    'delivery_order_completed',
    'تم تسليم طلبك',
    case
      when v_num <> '' then 'تم إكمال طلبك رقم ' || v_num || ' بنجاح.'
      else 'تم إكمال طلبك بنجاح.'
    end,
    updated_row.id,
    null,
    'delivery_order_completed:' || updated_row.id::text
  );

  return public._captain_order_detail_json(updated_row.id, prof.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) Customer no answer — event only; status stays active
-- ---------------------------------------------------------------------------
create or replace function public.captain_report_customer_no_answer(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  existing public.delivery_orders;
  v_event_id uuid;
begin
  prof := public._require_active_captain();

  if p_order_id is null then
    raise exception 'لا يمكنك تنفيذ هذا الإجراء' using errcode = 'P0001';
  end if;

  select * into existing
  from public.delivery_orders
  where id = p_order_id
  for update;

  if existing.id is null then
    raise exception 'لا يمكنك تنفيذ هذا الإجراء' using errcode = 'P0001';
  end if;

  if existing.captain_id is distinct from prof.id then
    raise exception 'لا يمكنك تنفيذ هذا الإجراء' using errcode = 'P0001';
  end if;

  if existing.status is distinct from 'active' then
    raise exception 'هذا الطلب لم يعد جارياً' using errcode = 'P0001';
  end if;

  v_event_id := public._insert_delivery_order_event(
    existing.id,
    'customer_no_answer',
    prof.id,
    null,
    '{}'::jsonb
  );

  return jsonb_build_object(
    'ok', true,
    'event_id', v_event_id,
    'order_id', existing.id,
    'status', existing.status
  );
end;
$$;

revoke all on function public.captain_report_customer_no_answer(uuid) from public;
grant execute on function public.captain_report_customer_no_answer(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Transfer: active owner → pending pool (expires_at must still be valid)
-- ---------------------------------------------------------------------------
create or replace function public.captain_transfer_delivery_order(
  p_order_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  existing public.delivery_orders;
  updated_row public.delivery_orders;
  v_reason text;
  v_event_id uuid;
  v_num text;
  v_prev_accepted timestamptz;
begin
  prof := public._require_active_captain();

  v_reason := nullif(btrim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'يجب اختيار سبب التحويل' using errcode = 'P0001';
  end if;
  if char_length(v_reason) > 500 then
    raise exception 'سبب التحويل طويل جداً' using errcode = 'P0001';
  end if;

  if p_order_id is null then
    raise exception 'لا يمكنك تحويل هذا الطلب' using errcode = 'P0001';
  end if;

  select * into existing
  from public.delivery_orders
  where id = p_order_id
  for update;

  if existing.id is null then
    raise exception 'لا يمكنك تحويل هذا الطلب' using errcode = 'P0001';
  end if;

  if existing.captain_id is distinct from prof.id then
    raise exception 'لا يمكنك تحويل هذا الطلب' using errcode = 'P0001';
  end if;

  if existing.status = 'completed' then
    raise exception 'لا يمكن تحويل طلب مكتمل' using errcode = 'P0001';
  end if;

  if existing.status = 'cancelled' then
    raise exception 'لا يمكن تحويل طلب ملغى' using errcode = 'P0001';
  end if;

  if existing.status = 'expired' then
    raise exception 'لا يمكن تحويل طلب منتهي' using errcode = 'P0001';
  end if;

  if existing.status is distinct from 'active' then
    raise exception 'هذا الطلب لم يعد جارياً' using errcode = 'P0001';
  end if;

  -- Expiration safety: never release an already-expired order as pending.
  if existing.expires_at <= now() then
    raise exception 'انتهت صلاحية هذا الطلب ولا يمكن تحويله' using errcode = 'P0001';
  end if;

  v_prev_accepted := existing.accepted_at;

  update public.delivery_orders
  set
    status = 'pending',
    captain_id = null,
    accepted_at = null,
    updated_at = now()
  where id = p_order_id
    and captain_id = prof.id
    and status = 'active'
    and expires_at > now()
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'تعذر تحويل الطلب' using errcode = 'P0001';
  end if;

  v_event_id := public._insert_delivery_order_event(
    updated_row.id,
    'transferred',
    prof.id,
    v_reason,
    jsonb_build_object(
      'from_captain_id', prof.id,
      'previous_accepted_at', v_prev_accepted,
      'transferred_at', now()
    )
  );

  v_num := coalesce(updated_row.request_number::text, '');
  perform public._insert_user_notification(
    updated_row.user_id,
    'delivery_order_searching_captain',
    'جاري البحث عن كابتن',
    case
      when v_num <> '' then
        'يتم البحث عن كابتن آخر لطلبك رقم ' || v_num || '.'
      else
        'يتم البحث عن كابتن آخر لطلبك.'
    end,
    updated_row.id,
    null,
    'delivery_order_searching_captain:' || updated_row.id::text || ':' || coalesce(v_event_id::text, '')
  );

  return jsonb_build_object(
    'ok', true,
    'order_id', updated_row.id,
    'request_number', updated_row.request_number,
    'status', updated_row.status,
    'event_id', v_event_id
  );
end;
$$;

revoke all on function public.captain_transfer_delivery_order(uuid, text) from public;
grant execute on function public.captain_transfer_delivery_order(uuid, text) to authenticated;

comment on function public.captain_transfer_delivery_order(uuid, text) is
  'Owner captain releases active order to pending pool if expires_at > now(); history kept in delivery_order_events.';
