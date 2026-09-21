-- 011: Admin users list page (account_type = user only).
-- Apply AFTER 010. Does NOT modify 008/009/010 files.

-- ---------------------------------------------------------------------------
-- Confirm stats: users_total = account_type user only (never captains)
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
    'users_total', (
      select count(*)::int from public.profiles where account_type = 'user'
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
    'delivery_orders_total', (select count(*)::int from public.delivery_orders)
  ) into result;

  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- List app users only (never captains)
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_users(p_status text default null)
returns table (
  id uuid,
  full_name text,
  phone text,
  account_type text,
  account_status text,
  phone_verified boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();

  if p_status is not null
     and p_status not in ('active', 'pending', 'suspended', 'disabled') then
    raise exception 'invalid status filter' using errcode = '22023';
  end if;

  return query
  select
    p.id,
    p.full_name,
    p.phone,
    p.account_type,
    p.account_status,
    p.phone_verified,
    p.created_at,
    p.updated_at
  from public.profiles p
  where p.account_type = 'user'
    and (p_status is null or p.account_status = p_status)
  order by p.created_at desc;
end;
$$;

revoke all on function public.admin_list_users(text) from public;
grant execute on function public.admin_list_users(text) to authenticated;
