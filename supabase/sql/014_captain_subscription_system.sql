-- 014: Captain subscription system (free trial + paid + settings)
-- Apply AFTER 013_ensure_convert_profile_to_captain.sql
-- Does NOT modify Phone Auth / OTPIQ / convert_profile_to_captain.
-- Extends admin_approve_captain to grant one-time free trial on approval.

-- ---------------------------------------------------------------------------
-- 1) App settings (singleton row)
-- ---------------------------------------------------------------------------
create table if not exists public.app_settings (
  id int primary key default 1 check (id = 1),
  captain_free_trial_enabled boolean not null default true,
  captain_free_trial_days int not null default 7
    check (captain_free_trial_days >= 0 and captain_free_trial_days <= 365),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null
);

insert into public.app_settings (id, captain_free_trial_enabled, captain_free_trial_days)
values (1, true, 7)
on conflict (id) do nothing;

alter table public.app_settings enable row level security;
-- No client policies — access via SECURITY DEFINER RPCs only.

-- ---------------------------------------------------------------------------
-- 2) One-time free trial grant ledger
-- ---------------------------------------------------------------------------
create table if not exists public.captain_trial_grants (
  captain_id uuid primary key references public.profiles (id) on delete cascade,
  granted_at timestamptz not null default now(),
  duration_days int not null check (duration_days > 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  granted_by uuid references auth.users (id) on delete set null,
  check (ends_at > starts_at)
);

create index if not exists captain_trial_grants_granted_at_idx
  on public.captain_trial_grants (granted_at desc);

alter table public.captain_trial_grants enable row level security;

drop policy if exists "captain_trial_grants_select_own" on public.captain_trial_grants;
create policy "captain_trial_grants_select_own"
  on public.captain_trial_grants
  for select
  to authenticated
  using (auth.uid() = captain_id);

-- ---------------------------------------------------------------------------
-- 3) Current subscription (one row per captain)
-- ---------------------------------------------------------------------------
create table if not exists public.captain_subscriptions (
  captain_id uuid primary key references public.profiles (id) on delete cascade,
  subscription_type text not null
    check (subscription_type in ('trial', 'paid')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists captain_subscriptions_ends_at_idx
  on public.captain_subscriptions (ends_at);

alter table public.captain_subscriptions enable row level security;

drop policy if exists "captain_subscriptions_select_own" on public.captain_subscriptions;
create policy "captain_subscriptions_select_own"
  on public.captain_subscriptions
  for select
  to authenticated
  using (auth.uid() = captain_id);

-- ---------------------------------------------------------------------------
-- 4) Subscription event history
-- ---------------------------------------------------------------------------
create table if not exists public.captain_subscription_events (
  id uuid primary key default gen_random_uuid(),
  captain_id uuid not null references public.profiles (id) on delete cascade,
  event_type text not null
    check (event_type in (
      'trial_granted',
      'paid_activated',
      'paid_extended',
      'manual_extension'
    )),
  duration_days int not null check (duration_days > 0),
  amount_iqd bigint not null default 0 check (amount_iqd >= 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  notes text,
  performed_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists captain_subscription_events_captain_idx
  on public.captain_subscription_events (captain_id, created_at desc);

alter table public.captain_subscription_events enable row level security;

drop policy if exists "captain_subscription_events_select_own"
  on public.captain_subscription_events;
create policy "captain_subscription_events_select_own"
  on public.captain_subscription_events
  for select
  to authenticated
  using (auth.uid() = captain_id);

-- ---------------------------------------------------------------------------
-- 5) Server helpers
-- ---------------------------------------------------------------------------
create or replace function public.captain_has_active_subscription(p_captain_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.captain_subscriptions s
    where s.captain_id = p_captain_id
      and s.ends_at > now()
  );
$$;

revoke all on function public.captain_has_active_subscription(uuid) from public;
grant execute on function public.captain_has_active_subscription(uuid) to authenticated;

create or replace function public._captain_subscription_remaining_days(p_ends_at timestamptz)
returns int
language sql
stable
as $$
  select greatest(
    0,
    ceil(extract(epoch from (p_ends_at - now())) / 86400.0)
  )::int;
$$;

-- Internal: grant free trial once, using settings snapshot at call time.
create or replace function public._grant_captain_free_trial(p_captain_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  settings_row public.app_settings;
  starts timestamptz := now();
  ends timestamptz;
  days int;
begin
  select * into settings_row from public.app_settings where id = 1;
  if settings_row.id is null then
    return;
  end if;

  if not settings_row.captain_free_trial_enabled then
    return;
  end if;

  days := settings_row.captain_free_trial_days;
  if days is null or days <= 0 then
    return;
  end if;

  -- One automatic free trial maximum per captain.
  if exists (
    select 1 from public.captain_trial_grants g where g.captain_id = p_captain_id
  ) then
    return;
  end if;

  ends := starts + make_interval(days => days);

  insert into public.captain_trial_grants (
    captain_id, granted_at, duration_days, starts_at, ends_at, granted_by
  ) values (
    p_captain_id, starts, days, starts, ends, auth.uid()
  );

  insert into public.captain_subscriptions (
    captain_id, subscription_type, starts_at, ends_at, updated_at
  ) values (
    p_captain_id, 'trial', starts, ends, starts
  )
  on conflict (captain_id) do update
    set
      subscription_type = excluded.subscription_type,
      starts_at = excluded.starts_at,
      ends_at = excluded.ends_at,
      updated_at = excluded.updated_at;

  insert into public.captain_subscription_events (
    captain_id, event_type, duration_days, amount_iqd,
    starts_at, ends_at, notes, performed_by
  ) values (
    p_captain_id, 'trial_granted', days, 0,
    starts, ends, 'free trial on captain approval', auth.uid()
  );
end;
$$;

revoke all on function public._grant_captain_free_trial(uuid) from public;

-- ---------------------------------------------------------------------------
-- 6) Hook into admin_approve_captain (preserve existing approve behavior)
-- ---------------------------------------------------------------------------
create or replace function public.admin_approve_captain(p_captain_id uuid)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_row public.profiles;
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

  -- Free trial starts only on approval (captain + active), once ever.
  perform public._grant_captain_free_trial(p_captain_id);

  return updated_row;
end;
$$;

revoke all on function public.admin_approve_captain(uuid) from public;
grant execute on function public.admin_approve_captain(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Settings RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_app_settings()
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
    'captain_free_trial_enabled', s.captain_free_trial_enabled,
    'captain_free_trial_days', s.captain_free_trial_days,
    'updated_at', s.updated_at,
    'updated_by', s.updated_by
  );
end;
$$;

create or replace function public.admin_update_captain_subscription_settings(
  p_free_trial_enabled boolean,
  p_free_trial_days integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.app_settings;
  days int;
begin
  perform public.require_dashboard_admin();

  if p_free_trial_enabled is null then
    raise exception 'free_trial_enabled required' using errcode = '22023';
  end if;

  days := coalesce(p_free_trial_days, 0);
  if days < 0 or days > 365 then
    raise exception 'free_trial_days must be between 0 and 365' using errcode = '22023';
  end if;

  insert into public.app_settings (
    id, captain_free_trial_enabled, captain_free_trial_days, updated_at, updated_by
  ) values (
    1, p_free_trial_enabled, days, now(), auth.uid()
  )
  on conflict (id) do update
    set
      captain_free_trial_enabled = excluded.captain_free_trial_enabled,
      captain_free_trial_days = excluded.captain_free_trial_days,
      updated_at = excluded.updated_at,
      updated_by = excluded.updated_by
  returning * into s;

  return jsonb_build_object(
    'captain_free_trial_enabled', s.captain_free_trial_enabled,
    'captain_free_trial_days', s.captain_free_trial_days,
    'updated_at', s.updated_at,
    'updated_by', s.updated_by
  );
end;
$$;

revoke all on function public.admin_get_app_settings() from public;
revoke all on function public.admin_update_captain_subscription_settings(boolean, integer)
  from public;
grant execute on function public.admin_get_app_settings() to authenticated;
grant execute on function public.admin_update_captain_subscription_settings(boolean, integer)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 8) Paid activation / extension
-- ---------------------------------------------------------------------------
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
    -- Extend remaining time — do not discard leftover days.
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

revoke all on function public.admin_activate_captain_subscription(uuid, integer, bigint, text)
  from public;
grant execute on function public.admin_activate_captain_subscription(uuid, integer, bigint, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 9) Enrich captain detail + dashboard stats
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_captain_detail(p_captain_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  history jsonb;
  sub public.captain_subscriptions;
  sub_json jsonb;
  events jsonb;
  remaining int;
  status_text text;
begin
  perform public.require_dashboard_admin();

  select * into prof from public.profiles where id = p_captain_id;
  if prof.id is null then
    raise exception 'profile not found' using errcode = 'P0001';
  end if;

  if prof.account_type <> 'captain'
     and not exists (
       select 1 from public.captain_review_history h where h.captain_id = p_captain_id
     ) then
    raise exception 'not a captain profile' using errcode = 'P0001';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', h.id,
      'action', h.action,
      'reason', h.reason,
      'reviewed_by', h.reviewed_by,
      'created_at', h.created_at
    )
    order by h.created_at desc
  ), '[]'::jsonb)
  into history
  from public.captain_review_history h
  where h.captain_id = p_captain_id;

  select * into sub from public.captain_subscriptions where captain_id = p_captain_id;

  if sub.captain_id is null then
    sub_json := jsonb_build_object(
      'has_subscription', false,
      'status', 'none',
      'subscription_type', null,
      'starts_at', null,
      'ends_at', null,
      'remaining_days', 0
    );
  else
    remaining := public._captain_subscription_remaining_days(sub.ends_at);
    if sub.ends_at > now() then
      status_text := 'active';
    else
      status_text := 'expired';
    end if;

    sub_json := jsonb_build_object(
      'has_subscription', true,
      'status', status_text,
      'subscription_type', sub.subscription_type,
      'starts_at', sub.starts_at,
      'ends_at', sub.ends_at,
      'remaining_days', remaining
    );
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', e.id,
      'event_type', e.event_type,
      'duration_days', e.duration_days,
      'amount_iqd', e.amount_iqd,
      'starts_at', e.starts_at,
      'ends_at', e.ends_at,
      'notes', e.notes,
      'performed_by', e.performed_by,
      'created_at', e.created_at
    )
    order by e.created_at desc
  ), '[]'::jsonb)
  into events
  from public.captain_subscription_events e
  where e.captain_id = p_captain_id;

  return jsonb_build_object(
    'profile', to_jsonb(prof),
    'history', history,
    'subscription', sub_json,
    'subscription_events', events
  );
end;
$$;

revoke all on function public.admin_get_captain_detail(uuid) from public;
grant execute on function public.admin_get_captain_detail(uuid) to authenticated;

create or replace function public.admin_dashboard_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  perform public.require_dashboard_admin();

  select jsonb_build_object(
    'users_total', (
      select count(*)::int from public.profiles
      where account_type = 'user' and account_status <> 'disabled'
    ),
    'users_blocked', (
      select count(*)::int from public.profiles
      where account_type = 'user' and account_status = 'disabled'
    ),
    'captains_pending', (
      select count(*)::int from public.profiles
      where account_type = 'captain' and account_status = 'pending'
    ),
    'captains_active', (
      select count(*)::int from public.profiles
      where account_type = 'captain' and account_status = 'active'
    ),
    'captains_suspended', (
      select count(*)::int from public.profiles
      where account_type = 'captain' and account_status = 'suspended'
    ),
    'captains_disabled', (
      select count(*)::int from public.profiles
      where account_type = 'captain' and account_status = 'disabled'
    ),
    'captains_total', (
      select count(*)::int from public.profiles
      where account_type = 'captain'
        and account_status in ('active', 'suspended', 'disabled')
    ),
    'delivery_orders_total', (select count(*)::int from public.delivery_orders),
    'subscriptions_active', (
      select count(*)::int from public.captain_subscriptions s
      where s.ends_at > now()
    ),
    'subscriptions_trial', (
      select count(*)::int from public.captain_subscriptions s
      where s.subscription_type = 'trial' and s.ends_at > now()
    ),
    'subscriptions_paid', (
      select count(*)::int from public.captain_subscriptions s
      where s.subscription_type = 'paid' and s.ends_at > now()
    ),
    'subscriptions_expired', (
      select count(*)::int from public.captain_subscriptions s
      where s.ends_at <= now()
    )
  ) into result;

  return result;
end;
$$;

revoke all on function public.admin_dashboard_stats() from public;
grant execute on function public.admin_dashboard_stats() to authenticated;

-- ---------------------------------------------------------------------------
-- 10) Flutter: own subscription status
-- ---------------------------------------------------------------------------
create or replace function public.get_my_captain_subscription()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  prof public.profiles;
  sub public.captain_subscriptions;
  remaining int;
  status_text text;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = 'P0001';
  end if;

  select * into prof from public.profiles where id = uid;
  if prof.id is null then
    raise exception 'profile not found' using errcode = 'P0001';
  end if;

  if prof.account_type <> 'captain' then
    return jsonb_build_object(
      'is_captain', false,
      'has_active_subscription', false,
      'subscription_type', null,
      'status', 'none',
      'starts_at', null,
      'ends_at', null,
      'remaining_days', 0
    );
  end if;

  select * into sub from public.captain_subscriptions where captain_id = uid;

  if sub.captain_id is null then
    return jsonb_build_object(
      'is_captain', true,
      'account_status', prof.account_status,
      'has_active_subscription', false,
      'subscription_type', null,
      'status', 'none',
      'starts_at', null,
      'ends_at', null,
      'remaining_days', 0
    );
  end if;

  remaining := public._captain_subscription_remaining_days(sub.ends_at);
  status_text := case when sub.ends_at > now() then 'active' else 'expired' end;

  return jsonb_build_object(
    'is_captain', true,
    'account_status', prof.account_status,
    'has_active_subscription', sub.ends_at > now(),
    'subscription_type', sub.subscription_type,
    'status', status_text,
    'starts_at', sub.starts_at,
    'ends_at', sub.ends_at,
    'remaining_days', remaining
  );
end;
$$;

revoke all on function public.get_my_captain_subscription() from public;
grant execute on function public.get_my_captain_subscription() to authenticated;
