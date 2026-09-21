-- 012: Users structure — active users / blocked users / user orders / block RPCs.
-- Apply AFTER 011. Does NOT modify 008–011 files.

-- ---------------------------------------------------------------------------
-- User account action audit (disable / enable)
-- ---------------------------------------------------------------------------
create table if not exists public.admin_account_action_history (
  id uuid primary key default gen_random_uuid(),
  target_user_id uuid not null,
  action text not null check (action in ('disabled', 'enabled')),
  reason text,
  reviewed_by uuid not null,
  created_at timestamptz not null default now()
);

create index if not exists admin_account_action_history_target_idx
  on public.admin_account_action_history (target_user_id, created_at desc);

alter table public.admin_account_action_history enable row level security;

drop policy if exists "admin_account_action_history_admin_select"
  on public.admin_account_action_history;
create policy "admin_account_action_history_admin_select"
  on public.admin_account_action_history
  for select
  to authenticated
  using (public.is_dashboard_admin());

create or replace function public._insert_account_action(
  p_target uuid,
  p_action text,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.admin_account_action_history (
    target_user_id, action, reason, reviewed_by
  ) values (
    p_target,
    p_action,
    nullif(trim(coalesce(p_reason, '')), ''),
    auth.uid()
  );
end;
$$;

revoke all on function public._insert_account_action(uuid, text, text) from public;

-- ---------------------------------------------------------------------------
-- Stats
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
    'delivery_orders_total', (select count(*)::int from public.delivery_orders)
  ) into result;

  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- List non-blocked users
-- ---------------------------------------------------------------------------
drop function if exists public.admin_list_users(text);

create or replace function public.admin_list_users()
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
    and p.account_status <> 'disabled'
  order by p.created_at desc;
end;
$$;

revoke all on function public.admin_list_users() from public;
grant execute on function public.admin_list_users() to authenticated;

-- ---------------------------------------------------------------------------
-- List blocked users
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_blocked_users()
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
    and p.account_status = 'disabled'
  order by p.updated_at desc;
end;
$$;

revoke all on function public.admin_list_blocked_users() from public;
grant execute on function public.admin_list_blocked_users() to authenticated;

-- ---------------------------------------------------------------------------
-- Disable / enable user
-- ---------------------------------------------------------------------------
create or replace function public.admin_disable_user(
  p_user_id uuid,
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

  if p_user_id is null then
    raise exception 'user id required' using errcode = '22023';
  end if;

  if auth.uid() = p_user_id then
    raise exception 'لا يمكن حظر حسابك الإداري من اللوحة' using errcode = 'P0001';
  end if;

  reason_clean := trim(coalesce(p_reason, ''));
  if reason_clean = '' then
    raise exception 'سبب الحظر مطلوب' using errcode = '22023';
  end if;

  if exists (
    select 1 from public.dashboard_admins a where a.user_id = p_user_id
  ) then
    raise exception 'لا يمكن حظر حساب مرتبط بصلاحيات لوحة الإدارة'
      using errcode = 'P0001';
  end if;

  update public.profiles
  set
    account_status = 'disabled',
    updated_at = now()
  where id = p_user_id
    and account_type = 'user'
    and account_status <> 'disabled'
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'المستخدم غير موجود أو محظور مسبقاً' using errcode = 'P0001';
  end if;

  perform public._insert_account_action(p_user_id, 'disabled', reason_clean);
  return updated_row;
end;
$$;

create or replace function public.admin_enable_user(p_user_id uuid)
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
  where id = p_user_id
    and account_type = 'user'
    and account_status = 'disabled'
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'المستخدم غير محظور أو غير موجود' using errcode = 'P0001';
  end if;

  perform public._insert_account_action(p_user_id, 'enabled', null);
  return updated_row;
end;
$$;

revoke all on function public.admin_disable_user(uuid, text) from public;
revoke all on function public.admin_enable_user(uuid) from public;
grant execute on function public.admin_disable_user(uuid, text) to authenticated;
grant execute on function public.admin_enable_user(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- User delivery orders (full read fields for detail modal)
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_user_orders(p_limit int default 150)
returns table (
  id uuid,
  user_id uuid,
  user_full_name text,
  user_phone text,
  order_type_name text,
  details text,
  status text,
  delivery_fee_iqd numeric,
  coupon_code text,
  coupon_discount_iqd numeric,
  destination_type text,
  destination_lat double precision,
  destination_lng double precision,
  destination_address text,
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
  lim := greatest(1, least(coalesce(p_limit, 150), 500));

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
    o.coupon_code,
    o.coupon_discount_iqd,
    o.destination_type,
    o.destination_lat,
    o.destination_lng,
    o.destination_address,
    o.created_at,
    o.expires_at
  from public.delivery_orders o
  left join public.profiles p on p.id = o.user_id
  order by o.created_at desc
  limit lim;
end;
$$;

revoke all on function public.admin_list_user_orders(int) from public;
grant execute on function public.admin_list_user_orders(int) to authenticated;

-- ---------------------------------------------------------------------------
-- Permanent delete prepare: user OR captain (shared by Edge Function)
-- ---------------------------------------------------------------------------
create or replace function public.admin_prepare_account_deletion(
  p_user_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := auth.uid();
  prof public.profiles;
  order_count int;
  reason_clean text;
  masked text;
begin
  perform public.require_dashboard_admin();

  if p_user_id is null then
    raise exception 'user id required' using errcode = '22023';
  end if;

  if caller = p_user_id then
    raise exception 'لا يمكن حذف حسابك الإداري من اللوحة'
      using errcode = 'P0001';
  end if;

  select * into prof from public.profiles where id = p_user_id;
  if prof.id is null then
    raise exception 'الحساب غير موجود' using errcode = 'P0001';
  end if;

  if prof.account_type not in ('user', 'captain') then
    raise exception 'نوع الحساب غير مدعوم للحذف' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.dashboard_admins a where a.user_id = p_user_id
  ) then
    raise exception 'لا يمكن حذف حساب مرتبط بصلاحيات لوحة الإدارة'
      using errcode = 'P0001';
  end if;

  select count(*)::int into order_count
  from public.delivery_orders
  where user_id = p_user_id;

  if order_count > 0 then
    raise exception
      'لا يمكن حذف هذا الحساب لوجود طلبات أو سجلات مرتبطة به. يمكنك حظر الحساب بدلاً من ذلك.'
      using errcode = 'P0001';
  end if;

  reason_clean := nullif(trim(coalesce(p_reason, '')), '');
  masked := case
    when prof.phone is null or length(regexp_replace(prof.phone, '\D', '', 'g')) < 6
      then '***'
    else
      '+' || left(regexp_replace(prof.phone, '\D', '', 'g'), 4)
      || '******'
      || right(regexp_replace(prof.phone, '\D', '', 'g'), 3)
  end;

  insert into public.admin_user_deletion_audit (
    deleted_user_id,
    masked_phone,
    deleted_by,
    reason
  ) values (
    p_user_id,
    masked,
    caller,
    reason_clean
  );

  return jsonb_build_object(
    'ok', true,
    'user_id', prof.id,
    'account_type', prof.account_type,
    'masked_phone', masked,
    'full_name', prof.full_name,
    'account_status', prof.account_status
  );
end;
$$;

revoke all on function public.admin_prepare_account_deletion(uuid, text) from public;
grant execute on function public.admin_prepare_account_deletion(uuid, text) to authenticated;

-- Keep old captain prepare as thin wrapper for compatibility
create or replace function public.admin_prepare_captain_deletion(
  p_user_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  result jsonb;
begin
  perform public.require_dashboard_admin();
  select * into prof from public.profiles where id = p_user_id;
  if prof.id is null or prof.account_type <> 'captain' then
    raise exception 'يمكن حذف حسابات الكابتن فقط من هذه الواجهة'
      using errcode = 'P0001';
  end if;
  result := public.admin_prepare_account_deletion(p_user_id, p_reason);
  return result;
end;
$$;
