-- 046: Admin delivery order actions (transfer, return to search, cancel, assign).
-- Depends on: 033 (delivery_order_events), 040 (notifications), 045 (admin list).

-- ---------------------------------------------------------------------------
-- 1) Event + notification types
-- ---------------------------------------------------------------------------
alter table public.delivery_order_events
  drop constraint if exists delivery_order_events_type_chk;

alter table public.delivery_order_events
  add constraint delivery_order_events_type_chk check (
    event_type in (
      'accepted',
      'customer_no_answer',
      'transferred',
      'completed',
      'admin_transferred_captain',
      'admin_returned_to_search',
      'admin_cancelled',
      'admin_assigned_captain'
    )
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
      'delivery_order_cancelled',
      'delivery_order_assigned',
      'delivery_order_released',
      'support_reply',
      'captain_approved',
      'captain_rejected',
      'captain_suspended',
      'captain_disabled',
      'subscription_activated',
      'admin_broadcast'
    )
  );

-- ---------------------------------------------------------------------------
-- 2) Helpers
-- ---------------------------------------------------------------------------
create or replace function public._admin_validate_eligible_captain(p_captain_id uuid)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
begin
  if p_captain_id is null then
    raise exception 'الكابتن مطلوب' using errcode = '22023';
  end if;

  select * into prof
  from public.profiles
  where id = p_captain_id;

  if prof.id is null then
    raise exception 'الكابتن غير موجود' using errcode = 'P0001';
  end if;

  if not public._captain_is_available_orders_eligible(prof.id) then
    raise exception 'الكابتن غير مؤهل أو اشتراكه غير فعال' using errcode = 'P0001';
  end if;

  return prof;
end;
$$;

create or replace function public._captain_subscription_status_json(p_captain_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  sub public.captain_subscriptions;
begin
  select * into sub
  from public.captain_subscriptions
  where captain_id = p_captain_id;

  if sub.captain_id is null then
    return jsonb_build_object(
      'has_subscription', false,
      'status', 'inactive',
      'label', 'غير فعال',
      'subscription_type', null
    );
  end if;

  if sub.ends_at <= now() then
    return jsonb_build_object(
      'has_subscription', true,
      'status', 'expired',
      'label', 'منتهي',
      'subscription_type', sub.subscription_type,
      'ends_at', sub.ends_at
    );
  end if;

  if sub.subscription_type = 'trial' then
    return jsonb_build_object(
      'has_subscription', true,
      'status', 'trial',
      'label', 'تجريبي',
      'subscription_type', sub.subscription_type,
      'ends_at', sub.ends_at
    );
  end if;

  return jsonb_build_object(
    'has_subscription', true,
    'status', 'active',
    'label', 'فعال',
    'subscription_type', sub.subscription_type,
    'ends_at', sub.ends_at
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Order detail for admin modal
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_user_order_detail(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.delivery_orders;
  user_prof public.profiles;
  captain_prof public.profiles;
  v_events jsonb;
  v_has_cna boolean := false;
  v_cna_at timestamptz;
begin
  perform public.require_dashboard_admin();

  if p_order_id is null then
    raise exception 'معرّف الطلب مطلوب' using errcode = '22023';
  end if;

  select * into o
  from public.delivery_orders
  where id = p_order_id;

  if o.id is null then
    raise exception 'الطلب غير موجود' using errcode = 'P0001';
  end if;

  select * into user_prof
  from public.profiles
  where id = o.user_id;

  if o.captain_id is not null then
    select * into captain_prof
    from public.profiles
    where id = o.captain_id;
  end if;

  select exists (
    select 1
    from public.delivery_order_events e
    where e.order_id = o.id
      and e.event_type = 'customer_no_answer'
  ) into v_has_cna;

  select max(e.created_at) into v_cna_at
  from public.delivery_order_events e
  where e.order_id = o.id
    and e.event_type = 'customer_no_answer';

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'event_type', e.event_type,
        'created_at', e.created_at,
        'actor_name', coalesce(cp.full_name, case
          when e.event_type like 'admin_%' then 'أدمن'
          else 'كابتن'
        end),
        'reason', e.reason,
        'metadata', e.metadata
      )
      order by e.created_at asc
    ),
    '[]'::jsonb
  )
  into v_events
  from public.delivery_order_events e
  left join public.profiles cp on cp.id = e.actor_captain_id
  where e.order_id = o.id;

  return jsonb_build_object(
    'order', jsonb_build_object(
      'id', o.id,
      'request_number', o.request_number,
      'user_id', o.user_id,
      'captain_id', o.captain_id,
      'order_type_name', o.order_type_name,
      'details', o.details,
      'status', o.status,
      'delivery_fee_iqd', o.delivery_fee_iqd,
      'coupon_code', o.coupon_code,
      'coupon_discount_iqd', o.coupon_discount_iqd,
      'destination_type', o.destination_type,
      'destination_lat', o.destination_lat,
      'destination_lng', o.destination_lng,
      'destination_address', o.destination_address,
      'created_at', o.created_at,
      'expires_at', o.expires_at,
      'accepted_at', o.accepted_at,
      'completed_at', o.completed_at,
      'updated_at', o.updated_at
    ),
    'user', jsonb_build_object(
      'full_name', user_prof.full_name,
      'phone', user_prof.phone,
      'account_status', user_prof.account_status
    ),
    'captain', case
      when captain_prof.id is null then null
      else jsonb_build_object(
        'id', captain_prof.id,
        'full_name', captain_prof.full_name,
        'phone', captain_prof.phone,
        'account_status', captain_prof.account_status,
        'account_status_label', case captain_prof.account_status
          when 'active' then 'فعال'
          when 'suspended' then 'موقوف'
          when 'disabled' then 'محظور'
          else captain_prof.account_status
        end,
        'subscription', public._captain_subscription_status_json(captain_prof.id)
      )
    end,
    'events', v_events,
    'has_customer_no_answer', v_has_cna,
    'customer_no_answer_at', v_cna_at
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Eligible captains picker
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_eligible_transfer_captains(
  p_order_id uuid,
  p_search text default null,
  p_limit int default 30
)
returns table (
  captain_id uuid,
  full_name text,
  phone text,
  subscription_label text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  lim int;
  q text := nullif(trim(coalesce(p_search, '')), '');
  v_current uuid;
begin
  perform public.require_dashboard_admin();

  select o.captain_id into v_current
  from public.delivery_orders o
  where o.id = p_order_id;

  lim := greatest(1, least(coalesce(p_limit, 30), 100));

  return query
  select
    p.id as captain_id,
    coalesce(p.full_name, '—') as full_name,
    coalesce(p.phone, '') as phone,
    (public._captain_subscription_status_json(p.id) ->> 'label') as subscription_label
  from public.profiles p
  where public._captain_is_available_orders_eligible(p.id)
    and (v_current is null or p.id <> v_current)
    and (
      q is null
      or coalesce(p.full_name, '') ilike '%' || q || '%'
      or coalesce(p.phone, '') ilike '%' || q || '%'
    )
  order by p.full_name asc nulls last, p.created_at desc
  limit lim;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Admin transfer active order to another captain
-- ---------------------------------------------------------------------------
create or replace function public.admin_transfer_delivery_order(
  p_order_id uuid,
  p_new_captain_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  existing public.delivery_orders;
  updated_row public.delivery_orders;
  old_captain public.profiles;
  new_captain public.profiles;
  v_event_id uuid;
  v_num text;
  v_admin uuid := auth.uid();
begin
  perform public.require_dashboard_admin();

  new_captain := public._admin_validate_eligible_captain(p_new_captain_id);

  select * into existing
  from public.delivery_orders
  where id = p_order_id
  for update;

  if existing.id is null then
    raise exception 'الطلب غير موجود' using errcode = 'P0001';
  end if;

  if existing.status is distinct from 'active' then
    raise exception 'حالة الطلب تغيرت، يرجى تحديث الصفحة.' using errcode = 'P0001';
  end if;

  if existing.captain_id is null then
    raise exception 'لا يوجد كابتن حالي على هذا الطلب' using errcode = 'P0001';
  end if;

  if existing.captain_id = p_new_captain_id then
    raise exception 'اختر كابتناً مختلفاً' using errcode = 'P0001';
  end if;

  if existing.expires_at <= now() then
    raise exception 'انتهت صلاحية هذا الطلب' using errcode = 'P0001';
  end if;

  select * into old_captain
  from public.profiles
  where id = existing.captain_id;

  update public.delivery_orders
  set
    captain_id = p_new_captain_id,
    accepted_at = now(),
    updated_at = now()
  where id = p_order_id
    and status = 'active'
    and captain_id = existing.captain_id
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'حالة الطلب تغيرت، يرجى تحديث الصفحة.' using errcode = 'P0001';
  end if;

  v_event_id := public._insert_delivery_order_event(
    updated_row.id,
    'admin_transferred_captain',
    p_new_captain_id,
    null,
    jsonb_build_object(
      'admin_id', v_admin,
      'old_captain_id', existing.captain_id,
      'new_captain_id', p_new_captain_id,
      'old_captain_name', old_captain.full_name,
      'new_captain_name', new_captain.full_name
    )
  );

  v_num := coalesce(updated_row.request_number::text, '');

  perform public._insert_user_notification(
    p_user_id := updated_row.user_id,
    p_type := 'delivery_order_accepted'::text,
    p_title := 'تم تحديث الكابتن'::text,
    p_body := case
      when v_num <> '' then
        'تم تحويل طلبك رقم ' || v_num || ' إلى كابتن آخر.'
      else
        'تم تحويل طلبك إلى كابتن آخر.'
    end,
    p_order_id := updated_row.id,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'delivery_order_accepted:' || updated_row.id::text || ':admin_transfer:' ||
      coalesce(v_event_id::text, '')
    )::text,
    p_tap_destination := NULL::text
  );

  perform public._insert_user_notification(
    p_user_id := existing.captain_id,
    p_type := 'delivery_order_released'::text,
    p_title := 'تم نقل الطلب'::text,
    p_body := case
      when v_num <> '' then
        'تم نقل الطلب رقم ' || v_num || ' منك إلى كابتن آخر.'
      else
        'تم نقل الطلب منك إلى كابتن آخر.'
    end,
    p_order_id := updated_row.id,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'delivery_order_released:' || updated_row.id::text || ':' ||
      coalesce(v_event_id::text, '')
    )::text,
    p_tap_destination := NULL::text
  );

  perform public._insert_user_notification(
    p_user_id := p_new_captain_id,
    p_type := 'delivery_order_assigned'::text,
    p_title := 'طلب جديد مسند إليك'::text,
    p_body := case
      when v_num <> '' then
        'تم إسناد الطلب رقم ' || v_num || ' إليك من الإدارة.'
      else
        'تم إسناد طلب دلفري إليك من الإدارة.'
    end,
    p_order_id := updated_row.id,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'delivery_order_assigned:' || updated_row.id::text || ':' ||
      coalesce(v_event_id::text, '')
    )::text,
    p_tap_destination := NULL::text
  );

  return jsonb_build_object(
    'ok', true,
    'order_id', updated_row.id,
    'request_number', updated_row.request_number,
    'status', updated_row.status,
    'captain_id', updated_row.captain_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) Admin return active order to captain search pool
-- ---------------------------------------------------------------------------
create or replace function public.admin_return_delivery_order_to_search(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  existing public.delivery_orders;
  updated_row public.delivery_orders;
  v_prev_captain uuid;
  v_prev_accepted timestamptz;
  v_event_id uuid;
  v_num text;
  v_admin uuid := auth.uid();
begin
  perform public.require_dashboard_admin();

  select * into existing
  from public.delivery_orders
  where id = p_order_id
  for update;

  if existing.id is null then
    raise exception 'الطلب غير موجود' using errcode = 'P0001';
  end if;

  if existing.status is distinct from 'active' then
    raise exception 'حالة الطلب تغيرت، يرجى تحديث الصفحة.' using errcode = 'P0001';
  end if;

  if existing.expires_at <= now() then
    raise exception 'انتهت صلاحية هذا الطلب' using errcode = 'P0001';
  end if;

  v_prev_captain := existing.captain_id;
  v_prev_accepted := existing.accepted_at;

  update public.delivery_orders
  set
    status = 'pending',
    captain_id = null,
    accepted_at = null,
    updated_at = now()
  where id = p_order_id
    and status = 'active'
    and expires_at > now()
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'حالة الطلب تغيرت، يرجى تحديث الصفحة.' using errcode = 'P0001';
  end if;

  v_event_id := public._insert_delivery_order_event(
    updated_row.id,
    'admin_returned_to_search',
    v_prev_captain,
    null,
    jsonb_build_object(
      'admin_id', v_admin,
      'previous_captain_id', v_prev_captain,
      'previous_accepted_at', v_prev_accepted
    )
  );

  v_num := coalesce(updated_row.request_number::text, '');

  perform public._insert_user_notification(
    p_user_id := updated_row.user_id,
    p_type := 'delivery_order_searching_captain'::text,
    p_title := 'جاري البحث عن كابتن'::text,
    p_body := case
      when v_num <> '' then
        'يتم البحث عن كابتن آخر لطلبك رقم ' || v_num || '.'
      else
        'يتم البحث عن كابتن آخر لطلبك.'
    end,
    p_order_id := updated_row.id,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'delivery_order_searching_captain:' || updated_row.id::text || ':admin:' ||
      coalesce(v_event_id::text, '')
    )::text,
    p_tap_destination := NULL::text
  );

  if v_prev_captain is not null then
    perform public._insert_user_notification(
      p_user_id := v_prev_captain,
      p_type := 'delivery_order_released'::text,
      p_title := 'تم إعادة الطلب للبحث'::text,
      p_body := case
        when v_num <> '' then
          'تمت إعادة الطلب رقم ' || v_num || ' للبحث عن كابتن آخر.'
        else
          'تمت إعادة الطلب للبحث عن كابتن آخر.'
      end,
      p_order_id := updated_row.id,
      p_support_request_id := NULL::uuid,
      p_dedupe_key := (
        'delivery_order_released:' || updated_row.id::text || ':admin_return:' ||
        coalesce(v_event_id::text, '')
      )::text,
      p_tap_destination := NULL::text
    );
  end if;

  perform public._notify_captains_available_delivery_order(
    updated_row.id,
    v_prev_captain,
    coalesce(v_event_id::text, 'admin_return')
  );

  return jsonb_build_object(
    'ok', true,
    'order_id', updated_row.id,
    'request_number', updated_row.request_number,
    'status', updated_row.status
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7) Admin cancel order
-- ---------------------------------------------------------------------------
create or replace function public.admin_cancel_delivery_order(
  p_order_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  existing public.delivery_orders;
  updated_row public.delivery_orders;
  v_reason text;
  v_event_id uuid;
  v_num text;
  v_captain uuid;
  v_admin uuid := auth.uid();
begin
  perform public.require_dashboard_admin();

  v_reason := nullif(btrim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'سبب الإلغاء مطلوب' using errcode = '22023';
  end if;
  if char_length(v_reason) > 500 then
    raise exception 'سبب الإلغاء طويل جداً' using errcode = '22023';
  end if;

  select * into existing
  from public.delivery_orders
  where id = p_order_id
  for update;

  if existing.id is null then
    raise exception 'الطلب غير موجود' using errcode = 'P0001';
  end if;

  if existing.status in ('completed', 'cancelled', 'expired') then
    raise exception 'لا يمكن إلغاء هذا الطلب' using errcode = 'P0001';
  end if;

  if existing.status not in ('pending', 'active') then
    raise exception 'حالة الطلب تغيرت، يرجى تحديث الصفحة.' using errcode = 'P0001';
  end if;

  v_captain := existing.captain_id;

  update public.delivery_orders
  set
    status = 'cancelled',
    captain_id = null,
    updated_at = now()
  where id = p_order_id
    and status in ('pending', 'active')
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'حالة الطلب تغيرت، يرجى تحديث الصفحة.' using errcode = 'P0001';
  end if;

  v_event_id := public._insert_delivery_order_event(
    updated_row.id,
    'admin_cancelled',
    v_captain,
    v_reason,
    jsonb_build_object('admin_id', v_admin)
  );

  v_num := coalesce(updated_row.request_number::text, '');

  perform public._insert_user_notification(
    p_user_id := updated_row.user_id,
    p_type := 'delivery_order_cancelled'::text,
    p_title := 'تم إلغاء الطلب'::text,
    p_body := case
      when v_num <> '' then
        'تم إلغاء طلبك رقم ' || v_num || '.'
      else
        'تم إلغاء طلبك.'
    end,
    p_order_id := updated_row.id,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'delivery_order_cancelled:' || updated_row.id::text || ':' ||
      coalesce(v_event_id::text, '')
    )::text,
    p_tap_destination := NULL::text
  );

  if v_captain is not null then
    perform public._insert_user_notification(
      p_user_id := v_captain,
      p_type := 'delivery_order_cancelled'::text,
      p_title := 'تم إلغاء الطلب'::text,
      p_body := case
        when v_num <> '' then
          'تم إلغاء الطلب رقم ' || v_num || ' الذي كنت مسنداً إليه.'
        else
          'تم إلغاء الطلب الذي كنت مسنداً إليه.'
      end,
      p_order_id := updated_row.id,
      p_support_request_id := NULL::uuid,
      p_dedupe_key := (
        'delivery_order_cancelled_captain:' || updated_row.id::text || ':' ||
        coalesce(v_event_id::text, '')
      )::text,
      p_tap_destination := NULL::text
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'order_id', updated_row.id,
    'request_number', updated_row.request_number,
    'status', updated_row.status
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 8) Admin assign captain to pending order
-- ---------------------------------------------------------------------------
create or replace function public.admin_assign_delivery_order_captain(
  p_order_id uuid,
  p_captain_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  existing public.delivery_orders;
  updated_row public.delivery_orders;
  captain public.profiles;
  v_event_id uuid;
  v_num text;
  v_name text;
  v_body text;
  v_admin uuid := auth.uid();
begin
  perform public.require_dashboard_admin();

  captain := public._admin_validate_eligible_captain(p_captain_id);

  select * into existing
  from public.delivery_orders
  where id = p_order_id
  for update;

  if existing.id is null then
    raise exception 'الطلب غير موجود' using errcode = 'P0001';
  end if;

  if existing.status is distinct from 'pending' then
    raise exception 'حالة الطلب تغيرت، يرجى تحديث الصفحة.' using errcode = 'P0001';
  end if;

  if existing.captain_id is not null then
    raise exception 'الطلب لديه كابتن بالفعل' using errcode = 'P0001';
  end if;

  if existing.expires_at <= now() then
    raise exception 'انتهت صلاحية هذا الطلب' using errcode = 'P0001';
  end if;

  update public.delivery_orders
  set
    captain_id = p_captain_id,
    status = 'active',
    accepted_at = now(),
    updated_at = now()
  where id = p_order_id
    and status = 'pending'
    and captain_id is null
    and expires_at > now()
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'حالة الطلب تغيرت، يرجى تحديث الصفحة.' using errcode = 'P0001';
  end if;

  v_event_id := public._insert_delivery_order_event(
    updated_row.id,
    'admin_assigned_captain',
    p_captain_id,
    null,
    jsonb_build_object('admin_id', v_admin)
  );

  v_num := coalesce(updated_row.request_number::text, '');
  v_name := nullif(btrim(coalesce(captain.full_name, '')), '');

  if v_name is not null and v_num <> '' then
    v_body := 'تم تعيين الكابتن ' || v_name || ' لطلبك رقم ' || v_num || '.';
  elsif v_num <> '' then
    v_body := 'تم تعيين كابتن لطلبك رقم ' || v_num || '.';
  else
    v_body := 'تم تعيين كابتن لطلبك.';
  end if;

  perform public._insert_user_notification(
    p_user_id := updated_row.user_id,
    p_type := 'delivery_order_accepted'::text,
    p_title := 'تم قبول طلبك'::text,
    p_body := v_body,
    p_order_id := updated_row.id,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'delivery_order_accepted:' || updated_row.id::text || ':admin_assign:' ||
      coalesce(v_event_id::text, '')
    )::text,
    p_tap_destination := NULL::text
  );

  perform public._insert_user_notification(
    p_user_id := p_captain_id,
    p_type := 'delivery_order_assigned'::text,
    p_title := 'طلب جديد مسند إليك'::text,
    p_body := case
      when v_num <> '' then
        'تم إسناد الطلب رقم ' || v_num || ' إليك من الإدارة.'
      else
        'تم إسناد طلب دلفري إليك من الإدارة.'
    end,
    p_order_id := updated_row.id,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'delivery_order_assigned:' || updated_row.id::text || ':' ||
      coalesce(v_event_id::text, '')
    )::text,
    p_tap_destination := NULL::text
  );

  return jsonb_build_object(
    'ok', true,
    'order_id', updated_row.id,
    'request_number', updated_row.request_number,
    'status', updated_row.status,
    'captain_id', updated_row.captain_id
  );
end;
$$;

revoke all on function public._admin_validate_eligible_captain(uuid) from public;
revoke all on function public._captain_subscription_status_json(uuid) from public;
revoke all on function public.admin_get_user_order_detail(uuid) from public;
revoke all on function public.admin_list_eligible_transfer_captains(uuid, text, int) from public;
revoke all on function public.admin_transfer_delivery_order(uuid, uuid) from public;
revoke all on function public.admin_return_delivery_order_to_search(uuid) from public;
revoke all on function public.admin_cancel_delivery_order(uuid, text) from public;
revoke all on function public.admin_assign_delivery_order_captain(uuid, uuid) from public;

grant execute on function public.admin_get_user_order_detail(uuid) to authenticated;
grant execute on function public.admin_list_eligible_transfer_captains(uuid, text, int) to authenticated;
grant execute on function public.admin_transfer_delivery_order(uuid, uuid) to authenticated;
grant execute on function public.admin_return_delivery_order_to_search(uuid) to authenticated;
grant execute on function public.admin_cancel_delivery_order(uuid, text) to authenticated;
grant execute on function public.admin_assign_delivery_order_captain(uuid, uuid) to authenticated;
