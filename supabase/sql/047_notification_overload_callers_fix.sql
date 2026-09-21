-- 047: Fix ambiguous _insert_user_notification overload callers.
-- Depends on: 031 (7-arg overload), 040 (8-arg overload + live functions), 033, 046.
--
-- Root cause: two overloads exist:
--   (uuid,text,text,text,uuid,uuid,text)
--   (uuid,text,text,text,uuid,uuid,text,text)  -- p_tap_destination default null
-- Positional 7-arg calls match both. Fix: always call 8-arg with named args + p_tap_destination.

-- ---------------------------------------------------------------------------
-- 1) Pool notify helper
-- ---------------------------------------------------------------------------
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
      p_user_id := r.captain_id,
      p_type := 'delivery_order_available'::text,
      p_title := v_title,
      p_body := v_body,
      p_order_id := p_order_id,
      p_support_request_id := NULL::uuid,
      p_dedupe_key := (
        'delivery_order_available:' || v_cycle || ':' || r.captain_id::text
      )::text,
      p_tap_destination := NULL::text
    ) is not null then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) Expire pending orders
-- ---------------------------------------------------------------------------
create or replace function public.expire_pending_delivery_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  r record;
  v_num text;
begin
  for r in
    update public.delivery_orders
    set
      status = 'expired',
      updated_at = now()
    where status = 'pending'
      and captain_id is null
      and expires_at <= now()
    returning id, user_id, request_number
  loop
    v_count := v_count + 1;
    v_num := coalesce(r.request_number::text, '');
    perform public._insert_user_notification(
      p_user_id := r.user_id,
      p_type := 'delivery_order_expired'::text,
      p_title := 'انتهت مدة طلبك'::text,
      p_body := case
        when v_num <> '' then
          'للأسف لم يقبل أي كابتن طلبك رقم ' || v_num || ' خلال المدة المحددة.'
        else
          'للأسف لم يقبل أي كابتن طلبك خلال المدة المحددة.'
      end,
      p_order_id := r.id,
      p_support_request_id := NULL::uuid,
      p_dedupe_key := ('delivery_order_expired:' || r.id::text)::text,
      p_tap_destination := NULL::text
    );
  end loop;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Captain accept
-- ---------------------------------------------------------------------------
create or replace function public.captain_accept_delivery_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  updated_row public.delivery_orders;
  v_num text;
  v_name text;
  v_body text;
  v_event_id uuid;
begin
  prof := public._require_active_captain();

  if not public.captain_has_active_subscription(prof.id) then
    raise exception 'اشتراكك غير فعال. فعّل الاشتراك لتتمكن من قبول الطلبات.'
      using errcode = 'P0001';
  end if;

  if p_order_id is null then
    raise exception 'order id required' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.delivery_orders where id = p_order_id
  ) then
    raise exception 'الطلب لم يعد متاحاً' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.delivery_orders
    where id = p_order_id and expires_at <= now()
  ) then
    raise exception 'انتهت صلاحية هذا الطلب' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.delivery_orders
    where id = p_order_id
      and (status <> 'pending' or captain_id is not null)
  ) then
    raise exception 'تم قبول هذا الطلب من كابتن آخر' using errcode = 'P0001';
  end if;

  update public.delivery_orders
  set
    captain_id = prof.id,
    status = 'active',
    accepted_at = now(),
    updated_at = now()
  where id = p_order_id
    and status = 'pending'
    and captain_id is null
    and expires_at > now()
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'تم قبول هذا الطلب من كابتن آخر' using errcode = 'P0001';
  end if;

  v_event_id := public._insert_delivery_order_event(
    updated_row.id,
    'accepted',
    prof.id,
    null,
    jsonb_build_object('accepted_at', updated_row.accepted_at)
  );

  v_num := coalesce(updated_row.request_number::text, '');
  v_name := nullif(btrim(coalesce(prof.full_name, '')), '');
  if v_name is not null and v_num <> '' then
    v_body := 'وافق الكابتن ' || v_name || ' على طلبك رقم ' || v_num || ' وهو الآن قيد التوصيل.';
  elsif v_num <> '' then
    v_body := 'وافق كابتن على طلبك رقم ' || v_num || ' وهو الآن قيد التوصيل.';
  else
    v_body := 'وافق كابتن على طلبك وهو الآن قيد التوصيل.';
  end if;

  perform public._insert_user_notification(
    p_user_id := updated_row.user_id,
    p_type := 'delivery_order_accepted'::text,
    p_title := 'تم قبول طلبك'::text,
    p_body := v_body,
    p_order_id := updated_row.id,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'delivery_order_accepted:' || updated_row.id::text || ':' ||
      coalesce(v_event_id::text, '')
    )::text,
    p_tap_destination := NULL::text
  );

  return public._captain_order_detail_json(updated_row.id, prof.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Captain complete
-- ---------------------------------------------------------------------------
create or replace function public.captain_complete_delivery_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  existing public.delivery_orders;
  updated_row public.delivery_orders;
  v_num text;
begin
  begin
    prof := public._require_active_captain();
  exception
    when others then
      raise exception 'لا يمكنك إكمال هذا الطلب' using errcode = 'P0001';
  end;

  if p_order_id is null then
    raise exception 'لا يمكنك إكمال هذا الطلب' using errcode = 'P0001';
  end if;

  select * into existing
  from public.delivery_orders
  where id = p_order_id;

  if existing.id is null then
    raise exception 'لا يمكنك إكمال هذا الطلب' using errcode = 'P0001';
  end if;

  if existing.captain_id is distinct from prof.id then
    raise exception 'لا يمكنك إكمال هذا الطلب' using errcode = 'P0001';
  end if;

  if existing.status = 'completed' then
    raise exception 'تم إكمال الطلب مسبقاً' using errcode = 'P0001';
  end if;

  if existing.status is distinct from 'active' then
    raise exception 'هذا الطلب لم يعد جارياً' using errcode = 'P0001';
  end if;

  update public.delivery_orders
  set
    status = 'completed',
    completed_at = now(),
    updated_at = now()
  where id = p_order_id
    and captain_id = prof.id
    and status = 'active'
  returning * into updated_row;

  if updated_row.id is null then
    raise exception 'هذا الطلب لم يعد جارياً' using errcode = 'P0001';
  end if;

  perform public._insert_delivery_order_event(
    updated_row.id,
    'completed',
    prof.id,
    null,
    jsonb_build_object('completed_at', updated_row.completed_at)
  );

  v_num := coalesce(updated_row.request_number::text, '');
  perform public._insert_user_notification(
    p_user_id := updated_row.user_id,
    p_type := 'delivery_order_completed'::text,
    p_title := 'تم تسليم طلبك'::text,
    p_body := case
      when v_num <> '' then 'تم إكمال طلبك رقم ' || v_num || ' بنجاح.'
      else 'تم إكمال طلبك بنجاح.'
    end,
    p_order_id := updated_row.id,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := ('delivery_order_completed:' || updated_row.id::text)::text,
    p_tap_destination := NULL::text
  );

  return public._captain_order_detail_json(updated_row.id, prof.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Captain transfer (040 live body)
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
      'delivery_order_searching_captain:' || updated_row.id::text || ':' ||
      coalesce(v_event_id::text, '')
    )::text,
    p_tap_destination := NULL::text
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

-- ---------------------------------------------------------------------------
-- 6) Captain admin lifecycle + subscription activation
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
    p_user_id := p_captain_id,
    p_type := 'captain_approved'::text,
    p_title := 'تم قبول طلب انضمامك'::text,
    p_body := v_body,
    p_order_id := NULL::uuid,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := ('captain_approved:' || p_captain_id::text)::text,
    p_tap_destination := NULL::text
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
    p_user_id := p_captain_id,
    p_type := 'captain_rejected'::text,
    p_title := 'تم تحديث طلب الانضمام'::text,
    p_body := 'لم يتم قبول طلب انضمامك ككابتن حالياً. يمكنك التواصل مع فريق حاضر للمزيد.'::text,
    p_order_id := NULL::uuid,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := ('captain_rejected:' || p_captain_id::text)::text,
    p_tap_destination := NULL::text
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
    p_user_id := p_captain_id,
    p_type := 'captain_suspended'::text,
    p_title := 'تم إيقاف حساب الكابتن مؤقتاً'::text,
    p_body := 'تم إيقاف حساب الكابتن مؤقتاً. تواصل مع فريق حاضر للمزيد.'::text,
    p_order_id := NULL::uuid,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'captain_suspended:' || p_captain_id::text || ':' ||
      extract(epoch from updated_row.updated_at)::bigint::text
    )::text,
    p_tap_destination := NULL::text
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
    p_user_id := p_captain_id,
    p_type := 'captain_disabled'::text,
    p_title := 'تم تعطيل حساب الكابتن'::text,
    p_body := 'تم تعطيل حساب الكابتن. تواصل مع فريق حاضر للمزيد.'::text,
    p_order_id := NULL::uuid,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'captain_disabled:' || p_captain_id::text || ':' ||
      extract(epoch from updated_row.updated_at)::bigint::text
    )::text,
    p_tap_destination := NULL::text
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
    p_user_id := p_captain_id,
    p_type := 'subscription_activated'::text,
    p_title := 'تم تفعيل اشتراكك'::text,
    p_body := v_body,
    p_order_id := NULL::uuid,
    p_support_request_id := NULL::uuid,
    p_dedupe_key := (
      'subscription_activated:' || p_captain_id::text || ':' || evt || ':' ||
      extract(epoch from ends)::bigint::text
    )::text,
    p_tap_destination := NULL::text
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
-- 7) Support first reply
-- ---------------------------------------------------------------------------
create or replace function public.admin_update_support_request(
  p_id uuid,
  p_status text,
  p_admin_reply text,
  p_admin_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.support_form_submissions;
  v_old_reply text;
  v_reply text;
  v_note text;
  v_num text;
begin
  perform public.require_dashboard_admin();

  if p_status not in ('new', 'in_progress', 'resolved', 'closed') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  select admin_reply into v_old_reply
  from public.support_form_submissions
  where id = p_id;

  if not found then
    raise exception 'support request not found' using errcode = '22023';
  end if;

  v_reply := nullif(btrim(coalesce(p_admin_reply, '')), '');
  v_note := nullif(btrim(coalesce(p_admin_note, '')), '');

  update public.support_form_submissions
    set
      status = p_status,
      admin_reply = v_reply,
      admin_note = v_note,
      handled_by = auth.uid(),
      updated_at = now(),
      replied_at = case
        when v_reply is not null then now()
        else null
      end,
      replied_by = case
        when v_reply is not null then auth.uid()
        else null
      end,
      resolved_at = case
        when p_status in ('resolved', 'closed') then coalesce(resolved_at, now())
        else resolved_at
      end
  where id = p_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'support request not found' using errcode = '22023';
  end if;

  if v_old_reply is null and v_reply is not null then
    v_num := coalesce(v_row.request_number::text, '');
    perform public._insert_user_notification(
      p_user_id := v_row.user_id,
      p_type := 'support_reply'::text,
      p_title := 'رد جديد من فريق حاضر'::text,
      p_body := case
        when v_num <> '' then
          'وصلك رد جديد على طلب الدعم رقم ' || v_num || '.'
        else
          'وصلك رد جديد على طلب الدعم.'
      end,
      p_order_id := NULL::uuid,
      p_support_request_id := v_row.id,
      p_dedupe_key := ('support_reply:' || v_row.id::text)::text,
      p_tap_destination := NULL::text
    );
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'status', v_row.status,
    'admin_reply', v_row.admin_reply,
    'admin_note', v_row.admin_note,
    'replied_at', v_row.replied_at,
    'replied_by', v_row.replied_by,
    'updated_at', v_row.updated_at
  );
end;
$$;
