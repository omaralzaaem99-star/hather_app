-- 009: Captain disable/enable + permanent-delete safety helpers.
-- Apply AFTER 008_admin_captain_management.sql.
-- Does NOT modify 008 file. Does NOT put SERVICE_ROLE in client.

-- ---------------------------------------------------------------------------
-- DELETE SAFETY AUDIT (documented for operators)
-- ---------------------------------------------------------------------------
-- TABLE: public.profiles
--   FK: id → auth.users(id) ON DELETE CASCADE
--   DATA LOSS: profile row removed when Auth user deleted
--
-- TABLE: public.delivery_orders
--   FK: user_id → profiles(id) ON DELETE CASCADE
--   DATA LOSS: ALL orders of that user would be wiped — BLOCK delete if any exist
--
-- TABLE: public.captain_review_history
--   FK: captain_id → profiles(id) ON DELETE CASCADE
--   FK: reviewed_by → auth.users(id) (NO ACTION / default restrict)
--   DATA LOSS: review rows for captain cascade-deleted; archive summary in
--              admin_user_deletion_audit before Auth delete
--
-- TABLE: public.dashboard_admins
--   FK: user_id → auth.users(id) ON DELETE CASCADE
--   DATA LOSS: admin membership removed — BLOCK deleting dashboard admins
-- ---------------------------------------------------------------------------

-- Expand review history actions
alter table public.captain_review_history
  drop constraint if exists captain_review_history_action_check;

alter table public.captain_review_history
  add constraint captain_review_history_action_check
  check (action in (
    'approved',
    'rejected',
    'suspended',
    'reactivated',
    'disabled',
    'enabled'
  ));

-- Permanent deletion audit (survives Auth/profile delete; no FK to deleted user)
create table if not exists public.admin_user_deletion_audit (
  id uuid primary key default gen_random_uuid(),
  deleted_user_id uuid not null,
  masked_phone text,
  deleted_by uuid not null,
  reason text,
  deleted_at timestamptz not null default now()
);

create index if not exists admin_user_deletion_audit_deleted_at_idx
  on public.admin_user_deletion_audit (deleted_at desc);

alter table public.admin_user_deletion_audit enable row level security;

drop policy if exists "admin_user_deletion_audit_admin_select"
  on public.admin_user_deletion_audit;
create policy "admin_user_deletion_audit_admin_select"
  on public.admin_user_deletion_audit
  for select
  to authenticated
  using (public.is_dashboard_admin());

-- ---------------------------------------------------------------------------
-- Disable / Enable captain
-- ---------------------------------------------------------------------------
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
  return updated_row;
end;
$$;

create or replace function public.admin_enable_captain(p_captain_id uuid)
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
    and account_status = 'disabled'
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'captain not disabled or not found' using errcode = 'P0001';
  end if;

  perform public._insert_captain_review(p_captain_id, 'enabled', null);
  return updated_row;
end;
$$;

revoke all on function public.admin_disable_captain(uuid, text) from public;
revoke all on function public.admin_enable_captain(uuid) from public;
grant execute on function public.admin_disable_captain(uuid, text) to authenticated;
grant execute on function public.admin_enable_captain(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- List / stats: include disabled
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
    'captains_disabled', (
      select count(*)::int from public.profiles
      where account_type = 'captain' and account_status = 'disabled'
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
     and p_status not in ('pending', 'active', 'suspended', 'disabled') then
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

-- ---------------------------------------------------------------------------
-- Prepare permanent delete (dependency checks + audit). Auth delete is Edge-only.
-- ---------------------------------------------------------------------------
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

  if prof.account_type <> 'captain' then
    raise exception 'يمكن حذف حسابات الكابتن فقط من هذه الواجهة'
      using errcode = 'P0001';
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
    'masked_phone', masked,
    'full_name', prof.full_name,
    'account_status', prof.account_status
  );
end;
$$;

revoke all on function public.admin_prepare_captain_deletion(uuid, text) from public;
grant execute on function public.admin_prepare_captain_deletion(uuid, text) to authenticated;
