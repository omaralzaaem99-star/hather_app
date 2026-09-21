-- 040: Full notification system integration
-- Depends on: 031 (user_notifications), 033 (transfer), 034 (create order), 039 (push dispatch)
-- Central source of truth: public.user_notifications → 039 auto push

-- ---------------------------------------------------------------------------
-- 1) Schema extensions
-- ---------------------------------------------------------------------------
alter table public.user_notifications
  add column if not exists tap_destination text null;

alter table public.user_notifications
  drop constraint if exists user_notifications_tap_destination_chk;

alter table public.user_notifications
  add constraint user_notifications_tap_destination_chk check (
    tap_destination is null
    or tap_destination in ('notifications', 'home', 'none')
  );

alter table public.user_notifications
  drop constraint if exists user_notifications_type_chk;

alter table public.user_notifications
  add constraint user_notifications_type_chk check (
    type in (
      'delivery_order_available',
      'delivery_order_expired',
      'delivery_order_accepted',
      'delivery_order_completed',
      'delivery_order_searching_captain',
      'support_reply',
      'captain_approved',
      'captain_rejected',
      'captain_suspended',
      'captain_disabled',
      'subscription_activated',
      'admin_broadcast'
    )
  );

create table if not exists public.admin_notification_campaigns (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  audience_type text not null,
  tap_destination text not null default 'notifications',
  recipient_count integer not null default 0,
  selected_user_ids uuid[] null,
  idempotency_key text null,
  created_by uuid null references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint admin_notification_campaigns_audience_chk check (
    audience_type in ('all_users', 'all_captains', 'single_user', 'selected_users')
  ),
  constraint admin_notification_campaigns_tap_destination_chk check (
    tap_destination in ('notifications', 'home', 'none')
  ),
  constraint admin_notification_campaigns_title_len_chk check (
    char_length(btrim(title)) between 1 and 100
  ),
  constraint admin_notification_campaigns_body_len_chk check (
    char_length(btrim(body)) between 1 and 500
  )
);

create unique index if not exists admin_notification_campaigns_idempotency_key_uidx
  on public.admin_notification_campaigns (idempotency_key)
  where idempotency_key is not null;

create index if not exists admin_notification_campaigns_created_idx
  on public.admin_notification_campaigns (created_at desc);

alter table public.admin_notification_campaigns enable row level security;
revoke all on table public.admin_notification_campaigns from public;
revoke all on table public.admin_notification_campaigns from anon;
revoke all on table public.admin_notification_campaigns from authenticated;

-- ---------------------------------------------------------------------------
-- 2) Central insert helper (dedupe-safe)
-- ---------------------------------------------------------------------------
create or replace function public._insert_user_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_order_id uuid default null,
  p_support_request_id uuid default null,
  p_dedupe_key text default null,
  p_tap_destination text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_tap text;
begin
  if p_user_id is null or p_type is null or p_title is null or p_body is null then
    return null;
  end if;

  v_tap := nullif(btrim(coalesce(p_tap_destination, '')), '');
  if v_tap is not null and v_tap not in ('notifications', 'home', 'none') then
    v_tap := null;
  end if;

  insert into public.user_notifications (
    user_id,
    type,
    title,
    body,
    order_id,
    support_request_id,
    dedupe_key,
    tap_destination
  )
  values (
    p_user_id,
    p_type,
    btrim(p_title),
    btrim(p_body),
    p_order_id,
    p_support_request_id,
    p_dedupe_key,
    v_tap
  )
  on conflict (dedupe_key) do nothing
  returning id into v_id;

  return v_id;
exception
  when unique_violation then
    return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Captain availability helpers (same rules as captain_list_available_orders)
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
  );
$$;

create or replace function public._delivery_order_is_in_available_pool(p_order_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.delivery_orders o
    where o.id = p_order_id
      and o.status = 'pending'
      and o.captain_id is null
      and o.expires_at > now()
  );
$$;

create or replace function public._delivery_order_availability_cycle_key(
  p_order_id uuid,
  p_event_token text
)
returns text
language sql
immutable
as $$
  select p_order_id::text || ':' || coalesce(nullif(btrim(p_event_token), ''), 'created');
$$;

create or replace function public._notify_captains_available_delivery_order(
  p_order_id uuid,
  p_exclude_captain_id uuid default null,
  p_availability_event_token text default 'created'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.delivery_orders;
  v_cycle text;
  v_title text;
  v_body text;
  v_num text;
  v_count integer := 0;
  r record;
begin
  if not public._delivery_order_is_in_available_pool(p_order_id) then
    return 0;
  end if;

  select * into v_order
  from public.delivery_orders
  where id = p_order_id;

  if v_order.id is null then
    return 0;
  end if;

  v_cycle := public._delivery_order_availability_cycle_key(
    p_order_id,
    p_availability_event_token
  );
  v_num := coalesce(v_order.request_number::text, '');
  v_title := 'طلب جديد متاح';
  if v_num <> '' then
    v_body := 'طلب جديد رقم #' || v_num || ' متاح الآن.';
  else
    v_body := 'يوجد طلب دلفري جديد متاح الآن.';
  end if;

  for r in
    select p.id as captain_id
    from public.profiles p
    where public._captain_is_available_orders_eligible(p.id)
      and (p_exclude_captain_id is null or p.id <> p_exclude_captain_id)
  loop
    if public._insert_user_notification(
      r.captain_id,
      'delivery_order_available',
      v_title,
      v_body,
      p_order_id,
      null,
      'delivery_order_available:' || v_cycle || ':' || r.captain_id::text,
      null
    ) is not null then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

revoke all on function public._captain_is_available_orders_eligible(uuid) from public;
revoke all on function public._delivery_order_is_in_available_pool(uuid) from public;
revoke all on function public._delivery_order_availability_cycle_key(uuid, text) from public;
revoke all on function public._notify_captains_available_delivery_order(uuid, uuid, text) from public;

-- ---------------------------------------------------------------------------
-- 4) Trigger: new pending order + transfer back to pool
-- ---------------------------------------------------------------------------
create or replace function public._trg_notify_available_delivery_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'pending' and new.captain_id is null and new.expires_at > now() then
    perform public._notify_captains_available_delivery_order(
      new.id,
      null,
      'created'
    );
  end if;
  return new;
exception
  when others then
    raise warning 'available order notify failed for %: %', new.id, sqlerrm;
    return new;
end;
$$;

drop trigger if exists delivery_orders_notify_available_trg on public.delivery_orders;

create trigger delivery_orders_notify_available_trg
  after insert on public.delivery_orders
  for each row
  execute function public._trg_notify_available_delivery_order();

-- ---------------------------------------------------------------------------
-- 5) User RPC: include tap_destination
-- ---------------------------------------------------------------------------
create or replace function public.get_my_notifications(
  p_limit int default 30,
  p_offset int default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  lim int;
  off int;
  result jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  lim := greatest(1, least(coalesce(p_limit, 30), 50));
  off := greatest(0, coalesce(p_offset, 0));

  select coalesce(jsonb_agg(row_data order by created_at desc), '[]'::jsonb)
  into result
  from (
    select jsonb_build_object(
      'id', n.id,
      'type', n.type,
      'title', n.title,
      'body', n.body,
      'order_id', n.order_id,
      'support_request_id', n.support_request_id,
      'tap_destination', n.tap_destination,
      'is_read', n.is_read,
      'read_at', n.read_at,
      'created_at', n.created_at
    ) as row_data,
    n.created_at
    from public.user_notifications n
    where n.user_id = auth.uid()
    order by n.created_at desc
    limit lim
    offset off
  ) q;

  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) Captain admin lifecycle notifications
-- ---------------------------------------------------------------------------
create or replace function public.admin_approve_captain(p_captain_id uuid)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_row public.profiles;
  v_sub public.captain_subscriptions;
  v_body text;
begin
  perform public.require_dashboard_admin();

  update public.profiles
  set
    account_status = 'active',
    updated_at = now()
  where id = p_captain_id
    and account_type = 'captain'
    and account_status = 'pending'
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'captain not pending or not found' using errcode = 'P0001';
  end if;

  perform public._insert_captain_review(p_captain_id, 'approved', null);
  perform public._grant_captain_free_trial(p_captain_id);

  select * into v_sub
  from public.captain_subscriptions
  where captain_id = p_captain_id;

  v_body := 'تمت الموافقة على حسابك ككابتن في حاضر.';
  if v_sub.ends_at is not null
    and v_sub.ends_at > now()
    and v_sub.subscription_type = 'trial' then
    v_body := v_body || ' تم تفعيل حساب الكابتن والفترة التجريبية.';
  end if;

  perform public._insert_user_notification(
    p_captain_id,
    'captain_approved',
    'تم قبول طلب انضمامك',
    v_body,
    null,
    null,
    'captain_approved:' || p_captain_id::text
  );

  return updated_row;
end;
$$;

create or replace function public.admin_reject_captain(
  p_captain_id uuid,
  p_reason text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_row public.profiles;
  reason_clean text;
begin
  perform public.require_dashboard_admin();

  reason_clean := trim(coalesce(p_reason, ''));
  if reason_clean = '' then
    raise exception 'rejection reason required' using errcode = '22023';
  end if;

  update public.profiles
  set
    account_type = 'user',
    account_status = 'active',
    updated_at = now()
  where id = p_captain_id
    and account_type = 'captain'
    and account_status = 'pending'
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'captain not pending or not found' using errcode = 'P0001';
  end if;

  perform public._insert_captain_review(p_captain_id, 'rejected', reason_clean);

  perform public._insert_user_notification(
    p_captain_id,
    'captain_rejected',
    'تم تحديث طلب الانضمام',
    'لم يتم قبول طلب انضمامك ككابتن حالياً. يمكنك التواصل مع فريق حاضر للمزيد.',
    null,
    null,
    'captain_rejected:' || p_captain_id::text
  );

  return updated_row;
end;
$$;

create or replace function public.admin_suspend_captain(
  p_captain_id uuid,
  p_reason text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_row public.profiles;
  reason_clean text;
begin
  perform public.require_dashboard_admin();

  reason_clean := trim(coalesce(p_reason, ''));
  if reason_clean = '' then
    raise exception 'suspend reason required' using errcode = '22023';
  end if;

  update public.profiles
  set
    account_status = 'suspended',
    updated_at = now()
  where id = p_captain_id
    and account_type = 'captain'
    and account_status = 'active'
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'captain not active or not found' using errcode = 'P0001';
  end if;

  perform public._insert_captain_review(p_captain_id, 'suspended', reason_clean);

  perform public._insert_user_notification(
    p_captain_id,
    'captain_suspended',
    'تم إيقاف حساب الكابتن مؤقتاً',
    'تم إيقاف حساب الكابتن مؤقتاً. تواصل مع فريق حاضر للمزيد.',
    null,
    null,
    'captain_suspended:' || p_captain_id::text || ':' || extract(epoch from updated_row.updated_at)::bigint::text
  );

  return updated_row;
end;
$$;

create or replace function public.admin_disable_captain(
  p_captain_id uuid,
  p_reason text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_row public.profiles;
  reason_clean text;
begin
  perform public.require_dashboard_admin();

  reason_clean := trim(coalesce(p_reason, ''));
  if reason_clean = '' then
    raise exception 'disable reason required' using errcode = '22023';
  end if;

  update public.profiles
  set
    account_status = 'disabled',
    updated_at = now()
  where id = p_captain_id
    and account_type = 'captain'
    and account_status in ('active', 'suspended', 'pending')
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'captain not found or already disabled' using errcode = 'P0001';
  end if;

  perform public._insert_captain_review(p_captain_id, 'disabled', reason_clean);

  perform public._insert_user_notification(
    p_captain_id,
    'captain_disabled',
    'تم تعطيل حساب الكابتن',
    'تم تعطيل حساب الكابتن. تواصل مع فريق حاضر للمزيد.',
    null,
    null,
    'captain_disabled:' || p_captain_id::text || ':' || extract(epoch from updated_row.updated_at)::bigint::text
  );

  return updated_row;
end;
$$;

create or replace function public.admin_activate_captain_subscription(
  p_captain_id uuid,
  p_duration_days integer,
  p_amount_iqd bigint,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  current_sub public.captain_subscriptions;
  days int;
  amount bigint;
  starts timestamptz;
  ends timestamptz;
  evt text;
  notes_clean text;
  was_active boolean := false;
  v_body text;
begin
  perform public.require_dashboard_admin();

  days := coalesce(p_duration_days, 0);
  if days <= 0 then
    raise exception 'duration_days must be > 0' using errcode = '22023';
  end if;

  amount := coalesce(p_amount_iqd, 0);
  if amount < 0 then
    raise exception 'amount_iqd must be >= 0' using errcode = '22023';
  end if;

  notes_clean := nullif(trim(coalesce(p_notes, '')), '');

  select * into prof from public.profiles where id = p_captain_id;
  if prof.id is null then
    raise exception 'profile not found' using errcode = 'P0001';
  end if;
  if prof.account_type <> 'captain' then
    raise exception 'not a captain profile' using errcode = 'P0001';
  end if;

  select * into current_sub
  from public.captain_subscriptions
  where captain_id = p_captain_id;

  if current_sub.captain_id is not null and current_sub.ends_at > now() then
    was_active := true;
    starts := current_sub.starts_at;
    ends := current_sub.ends_at + make_interval(days => days);
    evt := 'paid_extended';
  else
    starts := now();
    ends := starts + make_interval(days => days);
    evt := 'paid_activated';
  end if;

  insert into public.captain_subscriptions (
    captain_id, subscription_type, starts_at, ends_at, updated_at
  ) values (
    p_captain_id, 'paid', starts, ends, now()
  )
  on conflict (captain_id) do update
    set
      subscription_type = 'paid',
      starts_at = excluded.starts_at,
      ends_at = excluded.ends_at,
      updated_at = now();

  insert into public.captain_subscription_events (
    captain_id, event_type, duration_days, amount_iqd,
    starts_at, ends_at, notes, performed_by
  ) values (
    p_captain_id, evt, days, amount,
    starts, ends, notes_clean, auth.uid()
  );

  v_body := case
    when evt = 'paid_extended' then
      'تم تمديد اشتراك الكابتن حتى ' || to_char(ends at time zone 'Asia/Baghdad', 'YYYY/MM/DD') || '.'
    else
      'تم تفعيل اشتراك الكابتن حتى ' || to_char(ends at time zone 'Asia/Baghdad', 'YYYY/MM/DD') || '.'
  end;

  perform public._insert_user_notification(
    p_captain_id,
    'subscription_activated',
    'تم تفعيل اشتراكك',
    v_body,
    null,
    null,
    'subscription_activated:' || p_captain_id::text || ':' || evt || ':' || extract(epoch from ends)::bigint::text
  );

  return jsonb_build_object(
    'captain_id', p_captain_id,
    'subscription_type', 'paid',
    'status', 'active',
    'starts_at', starts,
    'ends_at', ends,
    'remaining_days', public._captain_subscription_remaining_days(ends),
    'extended_existing', was_active,
    'event_type', evt
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7) Admin manual notifications
-- ---------------------------------------------------------------------------
create or replace function public._admin_notification_audience_users(
  p_audience_type text,
  p_user_ids uuid[] default null
)
returns setof uuid
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_ids uuid[];
begin
  if p_audience_type = 'all_users' then
    return query
    select p.id
    from public.profiles p
    where p.account_type = 'user'
      and p.account_status = 'active';
    return;
  end if;

  if p_audience_type = 'all_captains' then
    return query
    select p.id
    from public.profiles p
    where p.account_type = 'captain'
      and p.account_status = 'active';
    return;
  end if;

  if p_audience_type = 'single_user' then
    v_ids := coalesce(p_user_ids, '{}'::uuid[]);
    if coalesce(array_length(v_ids, 1), 0) <> 1 then
      return;
    end if;
    return query
    select p.id
    from public.profiles p
    where p.id = v_ids[1]
      and p.account_status <> 'disabled';
    return;
  end if;

  if p_audience_type = 'selected_users' then
    v_ids := coalesce(p_user_ids, '{}'::uuid[]);
    if coalesce(array_length(v_ids, 1), 0) = 0 then
      return;
    end if;
    return query
    select distinct p.id
    from public.profiles p
    where p.id = any (v_ids)
      and p.account_status <> 'disabled';
    return;
  end if;
end;
$$;

create or replace function public.admin_preview_notification_audience(
  p_audience_type text,
  p_user_ids uuid[] default null
)
returns integer
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  perform public.require_dashboard_admin();

  if p_audience_type not in ('all_users', 'all_captains', 'single_user', 'selected_users') then
    raise exception 'invalid audience_type' using errcode = '22023';
  end if;

  return (
    select count(*)::int
    from public._admin_notification_audience_users(p_audience_type, p_user_ids) u
  );
end;
$$;

create or replace function public.admin_search_notification_recipients(
  p_query text,
  p_limit integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_q text := btrim(coalesce(p_query, ''));
  lim int;
begin
  perform public.require_dashboard_admin();
  lim := greatest(1, least(coalesce(p_limit, 20), 50));

  if length(v_q) < 2 then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(q)::jsonb order by q.full_name, q.phone)
    from (
      select
        p.id,
        p.full_name,
        p.phone,
        p.account_type
      from public.profiles p
      where p.account_status <> 'disabled'
        and (
          p.full_name ilike '%' || v_q || '%'
          or public._iraq_phone_matches_search(p.phone, v_q)
        )
      order by p.full_name nulls last, p.created_at desc
      limit lim
    ) q
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_send_notification(
  p_audience_type text,
  p_title text,
  p_body text,
  p_tap_destination text default 'notifications',
  p_user_ids uuid[] default null,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text := btrim(coalesce(p_title, ''));
  v_body text := btrim(coalesce(p_body, ''));
  v_tap text := coalesce(nullif(btrim(coalesce(p_tap_destination, '')), ''), 'notifications');
  v_campaign public.admin_notification_campaigns;
  v_existing public.admin_notification_campaigns;
  v_count int := 0;
  v_idem text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
begin
  perform public.require_dashboard_admin();

  if p_audience_type not in ('all_users', 'all_captains', 'single_user', 'selected_users') then
    raise exception 'invalid audience_type' using errcode = '22023';
  end if;

  if char_length(v_title) < 1 or char_length(v_title) > 100 then
    raise exception 'title must be 1-100 characters' using errcode = '22023';
  end if;

  if char_length(v_body) < 1 or char_length(v_body) > 500 then
    raise exception 'body must be 1-500 characters' using errcode = '22023';
  end if;

  if v_tap not in ('notifications', 'home', 'none') then
    raise exception 'invalid tap_destination' using errcode = '22023';
  end if;

  if p_audience_type = 'single_user'
    and coalesce(array_length(p_user_ids, 1), 0) <> 1 then
    raise exception 'single_user requires exactly one user id' using errcode = '22023';
  end if;

  if p_audience_type = 'selected_users'
    and coalesce(array_length(p_user_ids, 1), 0) < 1 then
    raise exception 'selected_users requires at least one user id' using errcode = '22023';
  end if;

  if v_idem is not null then
    select * into v_existing
    from public.admin_notification_campaigns c
    where c.idempotency_key = v_idem;

    if v_existing.id is not null then
      return jsonb_build_object(
        'campaign_id', v_existing.id,
        'recipient_count', v_existing.recipient_count,
        'duplicate', true
      );
    end if;
  end if;

  insert into public.admin_notification_campaigns (
    title,
    body,
    audience_type,
    tap_destination,
    recipient_count,
    selected_user_ids,
    idempotency_key,
    created_by
  )
  values (
    v_title,
    v_body,
    p_audience_type,
    v_tap,
    0,
    case
      when p_audience_type in ('single_user', 'selected_users') then p_user_ids
      else null
    end,
    v_idem,
    auth.uid()
  )
  returning * into v_campaign;

  insert into public.user_notifications (
    user_id,
    type,
    title,
    body,
    dedupe_key,
    tap_destination
  )
  select
    u.id,
    'admin_broadcast',
    v_title,
    v_body,
    'admin_broadcast:' || v_campaign.id::text || ':' || u.id::text,
    v_tap
  from public._admin_notification_audience_users(p_audience_type, p_user_ids) as u(id);

  get diagnostics v_count = row_count;

  update public.admin_notification_campaigns
  set recipient_count = v_count
  where id = v_campaign.id;

  return jsonb_build_object(
    'campaign_id', v_campaign.id,
    'recipient_count', v_count,
    'duplicate', false
  );
end;
$$;

create or replace function public.admin_list_notification_campaigns(
  p_limit integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  lim int;
begin
  perform public.require_dashboard_admin();
  lim := greatest(1, least(coalesce(p_limit, 50), 100));

  return coalesce((
    select jsonb_agg(row_to_json(q)::jsonb order by q.created_at desc)
    from (
      select
        c.id,
        c.title,
        c.body,
        c.audience_type,
        c.tap_destination,
        c.recipient_count,
        c.created_at,
        coalesce(p.full_name, '—') as created_by_name
      from public.admin_notification_campaigns c
      left join public.profiles p on p.id = c.created_by
      order by c.created_at desc
      limit lim
    ) q
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_preview_notification_audience(text, uuid[]) from public;
revoke all on function public.admin_search_notification_recipients(text, integer) from public;
revoke all on function public.admin_send_notification(text, text, text, text, uuid[], text) from public;
revoke all on function public.admin_list_notification_campaigns(integer) from public;

grant execute on function public.admin_preview_notification_audience(text, uuid[]) to authenticated;
grant execute on function public.admin_search_notification_recipients(text, integer) to authenticated;
grant execute on function public.admin_send_notification(text, text, text, text, uuid[], text) to authenticated;
grant execute on function public.admin_list_notification_campaigns(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 8) Transfer → re-notify eligible captains (after event recorded)
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

  perform public._notify_captains_available_delivery_order(
    updated_row.id,
    prof.id,
    coalesce(v_event_id::text, 'transfer')
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
