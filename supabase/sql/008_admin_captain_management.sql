-- 008: Dashboard admins + captain approval RPCs + delivery_orders harden.
-- Apply in Supabase SQL Editor AFTER 001–007 / phone-auth cutover.
-- Does NOT change auth.users UUIDs, passwords, Phone Auth, or auth-send-sms.
-- Does NOT delete profiles or orders.
--
-- REQUIRED BEFORE THIS FILE:
--   001_create_profiles.sql
--   004_delivery_orders.sql
--   005_convert_to_captain.sql (recommended)
--   006_phone_auth_cutover.sql (recommended)

do $$
begin
  if to_regclass('public.profiles') is null then
    raise exception
      'Missing public.profiles — apply supabase/sql/001_create_profiles.sql first';
  end if;
  if to_regclass('public.delivery_orders') is null then
    raise exception
      'Missing public.delivery_orders — apply supabase/sql/004_delivery_orders.sql first, then re-run 008';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) Dashboard admin identity (separate from account_type)
-- ---------------------------------------------------------------------------
create table if not exists public.dashboard_admins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists dashboard_admins_user_idx
  on public.dashboard_admins (user_id)
  where is_active = true;

alter table public.dashboard_admins enable row level security;

-- Clients may only see their own membership row (login gate). No insert/update/delete.
drop policy if exists "dashboard_admins_select_own" on public.dashboard_admins;
create policy "dashboard_admins_select_own"
  on public.dashboard_admins
  for select
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2) Captain review audit history
-- ---------------------------------------------------------------------------
create table if not exists public.captain_review_history (
  id uuid primary key default gen_random_uuid(),
  captain_id uuid not null references public.profiles (id) on delete cascade,
  action text not null
    check (action in ('approved', 'rejected', 'suspended', 'reactivated')),
  reason text,
  reviewed_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create index if not exists captain_review_history_captain_created_idx
  on public.captain_review_history (captain_id, created_at desc);

alter table public.captain_review_history enable row level security;

-- ---------------------------------------------------------------------------
-- 3) is_dashboard_admin() — server-side only; uses auth.uid()
-- ---------------------------------------------------------------------------
create or replace function public.is_dashboard_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.dashboard_admins a
    where a.user_id = auth.uid()
      and a.is_active = true
  );
$$;

revoke all on function public.is_dashboard_admin() from public;
grant execute on function public.is_dashboard_admin() to authenticated;

-- History readable by active dashboard admins only.
drop policy if exists "captain_review_history_admin_select" on public.captain_review_history;
create policy "captain_review_history_admin_select"
  on public.captain_review_history
  for select
  to authenticated
  using (public.is_dashboard_admin());

-- Profiles: admins may SELECT captain rows (for list/detail UI).
-- Secure columns remain locked for direct UPDATE by authenticated (trigger).
drop policy if exists "profiles_admin_select_captains" on public.profiles;
create policy "profiles_admin_select_captains"
  on public.profiles
  for select
  to authenticated
  using (
    public.is_dashboard_admin()
    and account_type = 'captain'
  );

-- Delivery orders: admins may SELECT all (read-only phase).
drop policy if exists "delivery_orders_admin_select" on public.delivery_orders;
create policy "delivery_orders_admin_select"
  on public.delivery_orders
  for select
  to authenticated
  using (public.is_dashboard_admin());

-- ---------------------------------------------------------------------------
-- 4) Internal helper: require admin or raise
-- ---------------------------------------------------------------------------
create or replace function public.require_dashboard_admin()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not public.is_dashboard_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.require_dashboard_admin() from public;

create or replace function public._insert_captain_review(
  p_captain_id uuid,
  p_action text,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.captain_review_history (
    captain_id,
    action,
    reason,
    reviewed_by
  ) values (
    p_captain_id,
    p_action,
    nullif(trim(coalesce(p_reason, '')), ''),
    auth.uid()
  );
end;
$$;

revoke all on function public._insert_captain_review(uuid, text, text) from public;

-- ---------------------------------------------------------------------------
-- 5) Captain management RPCs
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
  return updated_row;
end;
$$;

create or replace function public.admin_reactivate_captain(p_captain_id uuid)
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
    and account_status = 'suspended'
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'captain not suspended or not found' using errcode = 'P0001';
  end if;

  perform public._insert_captain_review(p_captain_id, 'reactivated', null);
  return updated_row;
end;
$$;

revoke all on function public.admin_approve_captain(uuid) from public;
revoke all on function public.admin_reject_captain(uuid, text) from public;
revoke all on function public.admin_suspend_captain(uuid, text) from public;
revoke all on function public.admin_reactivate_captain(uuid) from public;

grant execute on function public.admin_approve_captain(uuid) to authenticated;
grant execute on function public.admin_reject_captain(uuid, text) to authenticated;
grant execute on function public.admin_suspend_captain(uuid, text) to authenticated;
grant execute on function public.admin_reactivate_captain(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Admin read helpers (no service role; auth.uid admin check)
-- ---------------------------------------------------------------------------
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
    'users_total', (select count(*)::int from public.profiles where account_type = 'user'),
    'captains_total', (select count(*)::int from public.profiles where account_type = 'captain'),
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
    'delivery_orders_total', (select count(*)::int from public.delivery_orders)
  ) into result;

  return result;
end;
$$;

create or replace function public.admin_list_captains(p_status text default null)
returns setof public.profiles
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();

  if p_status is not null
     and p_status not in ('pending', 'active', 'suspended') then
    raise exception 'invalid status filter' using errcode = '22023';
  end if;

  return query
  select p.*
  from public.profiles p
  where p.account_type = 'captain'
    and (p_status is null or p.account_status = p_status)
  order by p.created_at desc;
end;
$$;

create or replace function public.admin_get_captain_detail(p_captain_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  history jsonb;
begin
  perform public.require_dashboard_admin();

  select * into prof from public.profiles where id = p_captain_id;
  if prof.id is null then
    raise exception 'profile not found' using errcode = 'P0001';
  end if;

  -- Allow detail for current captains, or anyone with review history.
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

  return jsonb_build_object(
    'profile', to_jsonb(prof),
    'history', history
  );
end;
$$;

create or replace function public.admin_list_delivery_orders(p_limit int default 100)
returns table (
  id uuid,
  user_id uuid,
  user_full_name text,
  user_phone text,
  order_type_name text,
  details text,
  status text,
  delivery_fee_iqd numeric,
  created_at timestamptz,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  lim int;
begin
  perform public.require_dashboard_admin();
  lim := greatest(1, least(coalesce(p_limit, 100), 500));

  return query
  select
    o.id,
    o.user_id,
    p.full_name,
    p.phone,
    o.order_type_name,
    o.details,
    o.status,
    o.delivery_fee_iqd,
    o.created_at,
    o.expires_at
  from public.delivery_orders o
  left join public.profiles p on p.id = o.user_id
  order by o.created_at desc
  limit lim;
end;
$$;

revoke all on function public.admin_dashboard_stats() from public;
revoke all on function public.admin_list_captains(text) from public;
revoke all on function public.admin_get_captain_detail(uuid) from public;
revoke all on function public.admin_list_delivery_orders(int) from public;

grant execute on function public.admin_dashboard_stats() to authenticated;
grant execute on function public.admin_list_captains(text) to authenticated;
grant execute on function public.admin_get_captain_detail(uuid) to authenticated;
grant execute on function public.admin_list_delivery_orders(int) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Harden delivery_orders client updates
-- ---------------------------------------------------------------------------
-- Remove unrestricted owner UPDATE (could change fee/status/expires_at).
drop policy if exists "delivery_orders_update_own" on public.delivery_orders;

-- Defense in depth: lock sensitive columns if any UPDATE policy is added later.
create or replace function public.enforce_delivery_order_secure_columns()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and current_user = 'authenticated' then
    new.id := old.id;
    new.user_id := old.user_id;
    new.delivery_fee_iqd := old.delivery_fee_iqd;
    new.coupon_code := old.coupon_code;
    new.coupon_discount_iqd := old.coupon_discount_iqd;
    new.delete_after_minutes := old.delete_after_minutes;
    new.expires_at := old.expires_at;
    new.created_at := old.created_at;
    -- status / destination / details remain locked for direct client updates too
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
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists delivery_orders_enforce_secure_columns on public.delivery_orders;
create trigger delivery_orders_enforce_secure_columns
  before insert or update on public.delivery_orders
  for each row
  execute function public.enforce_delivery_order_secure_columns();

-- Safe cancel for order owner (future Flutter use). No fee/status abuse.
create or replace function public.cancel_own_delivery_order(p_order_id uuid)
returns public.delivery_orders
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_row public.delivery_orders;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  update public.delivery_orders
  set
    status = 'cancelled',
    updated_at = now()
  where id = p_order_id
    and user_id = auth.uid()
    and status = 'pending'
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'order not cancellable' using errcode = 'P0001';
  end if;

  return updated_row;
end;
$$;

revoke all on function public.cancel_own_delivery_order(uuid) from public;
grant execute on function public.cancel_own_delivery_order(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 8) First admin (manual — do NOT put passwords here)
-- ---------------------------------------------------------------------------
-- After creating an Auth user in Dashboard (email/password):
--
--   insert into public.dashboard_admins (user_id, is_active)
--   values ('<AUTH_USER_UUID>', true)
--   on conflict (user_id) do update set is_active = excluded.is_active;
--
-- Then sign in to hather-admin-dashboard with that email/password.
