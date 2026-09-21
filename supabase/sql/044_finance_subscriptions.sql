-- 044: Finance & subscriptions — ad revenue events + admin finance RPCs.
-- Requires: 043 (home ads open-ended), 014 (captain subscription events).

-- ---------------------------------------------------------------------------
-- 1) Home ad subscription events (revenue snapshot — create only)
-- ---------------------------------------------------------------------------
create table if not exists public.home_ad_subscription_events (
  id uuid primary key default gen_random_uuid(),
  home_ad_id uuid references public.home_ads (id) on delete set null,
  event_type text not null
    check (event_type in ('created', 'renewed')),
  title_ar text,
  pricing_type text not null
    check (pricing_type in ('free', 'paid')),
  amount_iqd integer not null default 0 check (amount_iqd >= 0),
  duration_days integer,
  starts_at timestamptz,
  expires_at timestamptz,
  performed_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists home_ad_subscription_events_created_idx
  on public.home_ad_subscription_events (created_at desc);

create index if not exists home_ad_subscription_events_home_ad_idx
  on public.home_ad_subscription_events (home_ad_id, created_at desc);

alter table public.home_ad_subscription_events enable row level security;
-- No client policies — admin RPCs only.

-- Backfill paid ads created before this migration (one revenue row per ad).
insert into public.home_ad_subscription_events (
  home_ad_id,
  event_type,
  title_ar,
  pricing_type,
  amount_iqd,
  duration_days,
  starts_at,
  expires_at,
  created_at
)
select
  h.id,
  'created',
  h.title_ar,
  h.pricing_type,
  h.price_iqd,
  h.duration_days,
  h.starts_at,
  h.expires_at,
  coalesce(h.created_at, now())
from public.home_ads h
where lower(coalesce(h.pricing_type, 'free')) = 'paid'
  and coalesce(h.price_iqd, 0) > 0
  and not exists (
    select 1
    from public.home_ad_subscription_events e
    where e.home_ad_id = h.id
      and e.event_type = 'created'
  );

create or replace function public._insert_home_ad_subscription_event(
  p_home_ad_id uuid,
  p_event_type text,
  p_title_ar text,
  p_pricing_type text,
  p_amount_iqd integer,
  p_duration_days integer,
  p_starts_at timestamptz,
  p_expires_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(trim(coalesce(p_pricing_type, 'free'))) <> 'paid'
     or coalesce(p_amount_iqd, 0) <= 0 then
    return;
  end if;

  insert into public.home_ad_subscription_events (
    home_ad_id,
    event_type,
    title_ar,
    pricing_type,
    amount_iqd,
    duration_days,
    starts_at,
    expires_at,
    performed_by
  )
  values (
    p_home_ad_id,
    coalesce(nullif(trim(p_event_type), ''), 'created'),
    nullif(trim(coalesce(p_title_ar, '')), ''),
    'paid',
    p_amount_iqd,
    p_duration_days,
    p_starts_at,
    p_expires_at,
    auth.uid()
  );
end;
$$;

create or replace function public._home_ad_subscription_event_on_create()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._insert_home_ad_subscription_event(
    new.id,
    'created',
    new.title_ar,
    new.pricing_type,
    new.price_iqd,
    new.duration_days,
    new.starts_at,
    new.expires_at
  );
  return new;
end;
$$;

drop trigger if exists home_ads_subscription_event_created on public.home_ads;
create trigger home_ads_subscription_event_created
  after insert on public.home_ads
  for each row
  execute function public._home_ad_subscription_event_on_create();

-- ---------------------------------------------------------------------------
-- 2) Date-range helper for finance filters
-- ---------------------------------------------------------------------------
create or replace function public._finance_bounds(
  p_range text,
  p_from date default null,
  p_to date default null
)
returns table (starts_at timestamptz, ends_at timestamptz)
language plpgsql
stable
as $$
declare
  v_range text := lower(trim(coalesce(p_range, 'all')));
  v_start timestamptz;
  v_end timestamptz;
begin
  if v_range = 'custom' then
    if p_from is null or p_to is null then
      raise exception 'نطاق التاريخ المخصص يتطلب تاريخ البداية والنهاية' using errcode = '22023';
    end if;
    if p_to < p_from then
      raise exception 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية' using errcode = '22023';
    end if;
    v_start := (p_from::timestamp at time zone 'utc');
    v_end := ((p_to + 1)::timestamp at time zone 'utc');
  elsif v_range = 'today' then
    v_start := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
    v_end := v_start + interval '1 day';
  elsif v_range = 'month' then
    v_start := date_trunc('month', now() at time zone 'utc') at time zone 'utc';
    v_end := (date_trunc('month', now() at time zone 'utc') + interval '1 month') at time zone 'utc';
  elsif v_range = 'year' then
    v_start := date_trunc('year', now() at time zone 'utc') at time zone 'utc';
    v_end := (date_trunc('year', now() at time zone 'utc') + interval '1 year') at time zone 'utc';
  else
    v_start := null;
    v_end := null;
  end if;

  starts_at := v_start;
  ends_at := v_end;
  return next;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Financial summary (server-side)
-- ---------------------------------------------------------------------------
create or replace function public.admin_finance_summary(
  p_range text default 'all',
  p_from date default null,
  p_to date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  bounds record;
  captain_rev bigint := 0;
  ad_rev bigint := 0;
  active_captain_paid int := 0;
  active_paid_ads int := 0;
begin
  perform public.require_dashboard_admin();

  select * into bounds from public._finance_bounds(p_range, p_from, p_to) limit 1;

  select coalesce(sum(e.amount_iqd), 0)::bigint into captain_rev
  from public.captain_subscription_events e
  where e.amount_iqd > 0
    and e.event_type in ('paid_activated', 'paid_extended')
    and (bounds.starts_at is null or e.created_at >= bounds.starts_at)
    and (bounds.ends_at is null or e.created_at < bounds.ends_at);

  select coalesce(sum(e.amount_iqd), 0)::bigint into ad_rev
  from public.home_ad_subscription_events e
  where e.pricing_type = 'paid'
    and e.amount_iqd > 0
    and (bounds.starts_at is null or e.created_at >= bounds.starts_at)
    and (bounds.ends_at is null or e.created_at < bounds.ends_at);

  select count(*)::int into active_captain_paid
  from public.captain_subscriptions s
  join public.profiles p on p.id = s.captain_id
  where s.subscription_type = 'paid'
    and s.ends_at > now()
    and p.account_status = 'active';

  select count(*)::int into active_paid_ads
  from public.home_ads h
  where h.is_active = true
    and lower(coalesce(h.pricing_type, 'free')) = 'paid'
    and coalesce(h.price_iqd, 0) > 0
    and (h.starts_at is null or h.starts_at <= now())
    and (h.expires_at is null or h.expires_at > now());

  return jsonb_build_object(
    'total_revenue_iqd', captain_rev + ad_rev,
    'captain_revenue_iqd', captain_rev,
    'ad_revenue_iqd', ad_rev,
    'active_captain_paid_count', active_captain_paid,
    'active_paid_ads_count', active_paid_ads,
    'range', lower(trim(coalesce(p_range, 'all')))
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Captain subscription finance list
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
      or p.phone ilike '%' || q || '%'
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

-- ---------------------------------------------------------------------------
-- 5) Home ad subscription finance list (current ads + revenue snapshot)
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_finance_home_ad_subscriptions(
  p_search text default null,
  p_pricing text default null,
  p_status text default null,
  p_range text default 'all',
  p_from date default null,
  p_to date default null
)
returns table (
  home_ad_id uuid,
  title_ar text,
  image_url text,
  pricing_type text,
  price_iqd integer,
  duration_days integer,
  starts_at timestamptz,
  expires_at timestamptz,
  is_active boolean,
  status_label text,
  created_at timestamptz,
  revenue_iqd integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  bounds record;
  q text := trim(coalesce(p_search, ''));
  pr text := lower(trim(coalesce(p_pricing, 'all')));
  st text := lower(trim(coalesce(p_status, 'all')));
begin
  perform public.require_dashboard_admin();

  select * into bounds from public._finance_bounds(p_range, p_from, p_to) limit 1;

  return query
  select
    h.id as home_ad_id,
    h.title_ar,
    h.image_url,
    lower(coalesce(h.pricing_type, 'free')) as pricing_type,
    coalesce(h.price_iqd, 0) as price_iqd,
    h.duration_days,
    h.starts_at,
    h.expires_at,
    h.is_active,
    case
      when not h.is_active then 'stopped'
      when h.starts_at is not null and h.starts_at > now() then 'scheduled'
      when h.expires_at is not null and h.expires_at <= now() then 'expired'
      else 'active'
    end as status_label,
    h.created_at,
    coalesce((
      select sum(ev.amount_iqd)::int
      from public.home_ad_subscription_events ev
      where ev.home_ad_id = h.id
        and ev.pricing_type = 'paid'
        and ev.amount_iqd > 0
    ), 0) as revenue_iqd
  from public.home_ads h
  where (
      q = ''
      or coalesce(h.title_ar, '') ilike '%' || q || '%'
    )
    and (
      pr = 'all'
      or (pr = 'free' and lower(coalesce(h.pricing_type, 'free')) = 'free')
      or (pr = 'paid' and lower(coalesce(h.pricing_type, 'free')) = 'paid')
    )
    and (
      st = 'all'
      or (st = 'stopped' and not h.is_active)
      or (st = 'scheduled' and h.is_active and h.starts_at is not null and h.starts_at > now())
      or (st = 'expired' and h.expires_at is not null and h.expires_at <= now())
      or (st = 'active' and h.is_active
        and (h.starts_at is null or h.starts_at <= now())
        and (h.expires_at is null or h.expires_at > now()))
    )
    and (bounds.starts_at is null or h.created_at >= bounds.starts_at)
    and (bounds.ends_at is null or h.created_at < bounds.ends_at)
  order by h.sort_order asc, h.created_at asc;
end;
$$;

revoke all on function public._insert_home_ad_subscription_event(
  uuid, text, text, text, integer, integer, timestamptz, timestamptz
) from public;
revoke all on function public._finance_bounds(text, date, date) from public;
revoke all on function public.admin_finance_summary(text, date, date) from public;
revoke all on function public.admin_list_finance_captain_subscriptions(text, text, text, date, date) from public;
revoke all on function public.admin_list_finance_home_ad_subscriptions(text, text, text, text, date, date) from public;

grant execute on function public.admin_finance_summary(text, date, date) to authenticated;
grant execute on function public.admin_list_finance_captain_subscriptions(text, text, text, date, date) to authenticated;
grant execute on function public.admin_list_finance_home_ad_subscriptions(text, text, text, text, date, date) to authenticated;
