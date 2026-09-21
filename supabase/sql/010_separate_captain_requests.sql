-- 010: Separate captain requests (pending) from managed captains list.
-- Apply AFTER 009. Does NOT modify 008/009 files or convert_profile_to_captain.

-- ---------------------------------------------------------------------------
-- Stats: captains_total = active + suspended + disabled (excludes pending)
-- captains_pending remains a separate request counter
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
-- Pending conversion requests only
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_captain_requests()
returns setof public.profiles
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();

  return query
  select p.*
  from public.profiles p
  where p.account_type = 'captain'
    and p.account_status = 'pending'
  order by p.updated_at desc, p.created_at desc;
end;
$$;

revoke all on function public.admin_list_captain_requests() from public;
grant execute on function public.admin_list_captain_requests() to authenticated;

-- ---------------------------------------------------------------------------
-- Managed captains: never returns pending
-- p_status null = all of active|suspended|disabled
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_captains(p_status text default null)
returns setof public.profiles
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();

  if p_status is not null
     and p_status not in ('active', 'suspended', 'disabled') then
    raise exception 'invalid status filter — use admin_list_captain_requests for pending'
      using errcode = '22023';
  end if;

  return query
  select p.*
  from public.profiles p
  where p.account_type = 'captain'
    and p.account_status in ('active', 'suspended', 'disabled')
    and (p_status is null or p.account_status = p_status)
  order by p.created_at desc;
end;
$$;
