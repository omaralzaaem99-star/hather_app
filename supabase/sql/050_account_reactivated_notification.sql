-- 050: Notify users/captains when admin unblocks or reactivates their account.

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
      'delivery_order_cancelled',
      'delivery_order_assigned',
      'delivery_order_released',
      'support_reply',
      'captain_approved',
      'captain_rejected',
      'captain_suspended',
      'captain_disabled',
      'subscription_activated',
      'admin_broadcast',
      'account_reactivated'
    )
  );

-- ---------------------------------------------------------------------------
-- admin_enable_user — notify on successful unblock (disabled → active)
-- ---------------------------------------------------------------------------
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

  perform public._insert_user_notification(
    p_user_id := p_user_id,
    p_type := 'account_reactivated'::text,
    p_title := 'تم تفعيل حسابك'::text,
    p_body := 'تم فك الحظر عن حسابك ويمكنك الآن استخدام تطبيق حاضر بشكل طبيعي.'::text,
    p_order_id := NULL::uuid,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'account_reactivated:' || p_user_id::text || ':' ||
      extract(epoch from updated_row.updated_at)::bigint::text
    )::text,
    p_tap_destination := 'home'::text
  );

  return updated_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- admin_enable_captain — notify on successful unblock (disabled → active)
-- ---------------------------------------------------------------------------
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

  perform public._insert_user_notification(
    p_user_id := p_captain_id,
    p_type := 'account_reactivated'::text,
    p_title := 'تم تفعيل حسابك'::text,
    p_body := 'تم تفعيل حساب الكابتن الخاص بك ويمكنك الآن استخدام خدمات حاضر.'::text,
    p_order_id := NULL::uuid,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'account_reactivated:' || p_captain_id::text || ':' ||
      extract(epoch from updated_row.updated_at)::bigint::text
    )::text,
    p_tap_destination := 'home'::text
  );

  return updated_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- admin_reactivate_captain — notify on successful reactivation (suspended → active)
-- ---------------------------------------------------------------------------
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

  perform public._insert_user_notification(
    p_user_id := p_captain_id,
    p_type := 'account_reactivated'::text,
    p_title := 'تم تفعيل حسابك'::text,
    p_body := 'تم تفعيل حساب الكابتن الخاص بك ويمكنك الآن استخدام خدمات حاضر.'::text,
    p_order_id := NULL::uuid,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'account_reactivated:' || p_captain_id::text || ':' ||
      extract(epoch from updated_row.updated_at)::bigint::text
    )::text,
    p_tap_destination := 'home'::text
  );

  return updated_row;
end;
$$;
