-- 057: User-facing copy fixes (notification titles/bodies, legal, order type label)
-- Text/content only. No schema or business-logic changes.


update public.order_types
set name_ar = 'طلب توصيل'
where name_ar = 'طلب دلفري';

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
    v_body := 'يوجد طلب توصيل جديد متاح الآن.';
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
    v_body := v_body || ' تم تفعيل الفترة التجريبية.';
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
    p_title := 'تم إيقاف حسابك مؤقتاً'::text,
    p_body := 'تم إيقاف حسابك مؤقتاً. تواصل مع فريق حاضر للمزيد.'::text,
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
    p_title := 'تم تعطيل حسابك'::text,
    p_body := 'تم تعطيل حسابك. تواصل مع فريق حاضر للمزيد.'::text,
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
      'تم تمديد اشتراكك حتى ' || to_char(ends at time zone 'Asia/Baghdad', 'YYYY/MM/DD') || '.'
    else
      'تم تفعيل اشتراكك حتى ' || to_char(ends at time zone 'Asia/Baghdad', 'YYYY/MM/DD') || '.'
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
    p_body := 'تم تفعيل حسابك ويمكنك الآن استخدام خدمات حاضر.'::text,
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
    p_body := 'تم تفعيل حسابك ويمكنك الآن استخدام خدمات حاضر.'::text,
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
        'تم إسناد طلب توصيل إليك من الإدارة.'
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
    v_body := 'تم تعيين كابتن لطلبك ويمكنك متابعة حالة الطلب من التطبيق.';
  end if;

  perform public._insert_user_notification(
    p_user_id := updated_row.user_id,
    p_type := 'delivery_order_accepted'::text,
    p_title := 'تم تعيين كابتن لطلبك'::text,
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
        'تم إسناد طلب توصيل إليك من الإدارة.'
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

revoke all on function public.admin_approve_captain(uuid) from public;
revoke all on function public.admin_suspend_captain(uuid, text) from public;
revoke all on function public.admin_disable_captain(uuid, text) from public;
revoke all on function public.admin_activate_captain_subscription(uuid, int, bigint, text) from public;
revoke all on function public.admin_enable_captain(uuid) from public;
revoke all on function public.admin_reactivate_captain(uuid) from public;
revoke all on function public.admin_transfer_delivery_order(uuid, uuid) from public;
revoke all on function public.admin_assign_delivery_order_captain(uuid, uuid) from public;

grant execute on function public.admin_approve_captain(uuid) to authenticated;
grant execute on function public.admin_suspend_captain(uuid, text) to authenticated;
grant execute on function public.admin_disable_captain(uuid, text) to authenticated;
grant execute on function public.admin_activate_captain_subscription(uuid, int, bigint, text) to authenticated;
grant execute on function public.admin_enable_captain(uuid) to authenticated;
grant execute on function public.admin_reactivate_captain(uuid) to authenticated;
grant execute on function public.admin_transfer_delivery_order(uuid, uuid) to authenticated;
grant execute on function public.admin_assign_delivery_order_captain(uuid, uuid) to authenticated;

update public.legal_documents
set
  title = 'شروط الاستخدام',
  content = $terms_md_batch2$
# شروط الاستخدام — تطبيق حاضر

**آخر تحديث: 10 سبتمبر 2026**

مرحباً بك في تطبيق **حاضر**.

باستخدامك للتطبيق أو إنشاء حساب فيه، فإنك توافق على الالتزام بشروط الاستخدام الموضحة أدناه. يرجى قراءة هذه الشروط قبل استخدام خدمات التطبيق.

## 1. تعريف الخدمة

تطبيق **حاضر** هو منصة خدمات محلية تساعد المستخدمين على إنشاء طلبات التوصيل وربطهم بالكباتن المتاحين لتنفيذ الطلبات.

يوفر التطبيق الوسائل التقنية اللازمة لإدارة الطلب ومتابعة حالته والتواصل المتعلق بالخدمة.

## 2. إنشاء الحساب

لاستخدام بعض خدمات حاضر، قد يكون من الضروري إنشاء حساب باستخدام المعلومات المطلوبة داخل التطبيق.

يتعهد المستخدم بتقديم معلومات صحيحة وحديثة والمحافظة على سرية بيانات تسجيل الدخول الخاصة به.

يتحمل المستخدم مسؤولية النشاط الذي يتم من خلال حسابه ما لم يبلغ الدعم عن وجود استخدام غير مصرح به.

## 3. استخدام رقم الهاتف

قد يستخدم رقم الهاتف لإنشاء الحساب، والتحقق من الهوية، وإدارة الخدمات المرتبطة بالحساب، وإرسال الإشعارات أو رموز التحقق عند الحاجة.

يجب استخدام رقم هاتف يخص المستخدم أو يحق له استخدامه.

## 4. طلبات التوصيل

عند إنشاء طلب توصيل، يتحمل المستخدم مسؤولية إدخال معلومات صحيحة وكافية، بما في ذلك:

- تفاصيل الطلب.
- موقع أو عنوان الاستلام.
- موقع أو عنوان التسليم.
- أي تعليمات ضرورية لتنفيذ الطلب.

يجب عدم استخدام التطبيق لإرسال أو طلب مواد أو منتجات مخالفة للقانون.

## 5. توفر الكباتن

يعتمد تنفيذ الطلب على توفر كابتن مناسب في المنطقة وفي وقت إنشاء الطلب.

لا يضمن تطبيق حاضر توفر كابتن في جميع الأوقات أو قبول كل طلب يتم إنشاؤه.

قد تنتهي مدة الطلب إذا لم يقبله أي كابتن خلال الفترة المحددة في النظام.

## 6. الكباتن

عند استخدام التطبيق ككابتن، يجب الالتزام بالمعلومات والتعليمات المعتمدة داخل التطبيق.

يتحمل الكابتن مسؤولية تنفيذ الطلبات التي يقبلها وفق تفاصيل الطلب والتعليمات المتاحة له.

يجب التعامل مع المستخدمين والطلبات بصورة مهنية وعدم إساءة استخدام المعلومات التي تظهر للكابتن أثناء تنفيذ الطلب.

## 7. أجور التوصيل

قد تختلف أجور التوصيل حسب:

- موقع الاستلام والتسليم.
- المنطقة.
- نوع الخدمة.
- الإعدادات المعتمدة داخل التطبيق.

يظهر للمستخدم السعر أو أجرة التوصيل حسب النظام المتوفر قبل أو أثناء إنشاء الطلب.

## 8. الدفع

تتم عملية الدفع وفق طريقة الدفع المتاحة والمحددة داخل التطبيق لكل خدمة.

يجب على المستخدم والكابتن الالتزام بالمبلغ والتعليمات الظاهرة للطلب وعدم استخدام التطبيق في معاملات مخالفة للقانون أو غير مرتبطة بالخدمة.

## 9. إلغاء الطلبات

يمكن إلغاء الطلب وفق الحالات والخيارات المتاحة داخل التطبيق.

قد لا يكون الإلغاء متاحاً في بعض المراحل بعد بدء تنفيذ الطلب أو بعد قبول الكابتن له، وفق النظام التشغيلي المعتمد.

## 10. اشتراكات الكباتن

قد تتطلب بعض خدمات الكابتن اشتراكاً وفق النظام المعتمد داخل تطبيق حاضر.

تظهر تفاصيل الاشتراك ومدته وحالته داخل حساب الكابتن.

قد يقدم التطبيق فترات مجانية أو مكافآت أو أيام اشتراك إضافية وفق العروض أو نظام التحفيز المعتمد في ذلك الوقت.

يمكن تعديل خطط أو شروط الاشتراك مستقبلاً، مع عرض المعلومات المحدثة داخل التطبيق.

## 11. الاستخدام الممنوع

يُمنع استخدام تطبيق حاضر في أي نشاط يتضمن:

- تقديم معلومات مزيفة أو مضللة.
- إنشاء طلبات وهمية بقصد الإزعاج أو إساءة الاستخدام.
- محاولة الاحتيال على مستخدم أو كابتن أو إدارة التطبيق.
- استخدام حساب شخص آخر دون إذنه.
- محاولة الوصول غير المصرح به إلى أنظمة التطبيق.
- تعطيل الخدمة أو إساءة استخدام وظائفها.
- استخدام التطبيق لتنفيذ أي نشاط يخالف القوانين المعمول بها.

## 12. تعليق أو إيقاف الحساب

يحق لإدارة حاضر تعليق أو تعطيل الحساب عند وجود أسباب تشغيلية أو أمنية، بما في ذلك إساءة استخدام التطبيق أو مخالفة هذه الشروط.

يمكن إعادة تفعيل الحساب وفق الإجراءات المعتمدة إذا زال سبب التعليق أو الإيقاف.

## 13. الإشعارات

قد يرسل تطبيق حاضر إشعارات تتعلق بـ:

- حالة الطلبات.
- الحساب.
- الخدمات.
- التحديثات المهمة.
- الرسائل التشغيلية أو الإدارية.

يستطيع المستخدم التحكم ببعض إعدادات الإشعارات من إعدادات جهازه، مع العلم أن تعطيل الإشعارات قد يؤثر على استلام تحديثات الطلبات.

## 14. الموقع والعناوين

قد يعتمد تنفيذ خدمات التوصيل على بيانات الموقع أو العناوين التي يقدمها المستخدم.

يتحمل المستخدم مسؤولية التأكد من صحة موقع الاستلام والتسليم والمعلومات المرتبطة بالعنوان.

## 15. الدعم الفني

يمكن للمستخدم التواصل مع الدعم الفني من خلال الوسائل المتوفرة داخل التطبيق عند وجود مشكلة تتعلق بالحساب أو الطلب أو الخدمة.

قد يطلب الدعم معلومات إضافية للتحقق من الحساب أو معالجة المشكلة.

## 16. حذف الحساب

يمكن للمستخدم طلب حذف حسابه من داخل التطبيق من خلال:

**الحساب ← الخصوصية والأمان ← حذف الحساب**

قد يتطلب حذف الحساب التحقق من هوية المستخدم.

إذا كان لدى المستخدم أو الكابتن طلب نشط، فقد يلزم إكمال الطلب أو إلغاؤه قبل تنفيذ عملية حذف الحساب.

بعد إكمال حذف الحساب، لا يمكن استعادة الحساب المحذوف.

تخضع معالجة البيانات بعد الحذف لما هو موضح في **سياسة الخصوصية** الخاصة بتطبيق حاضر، بما في ذلك إمكانية الاحتفاظ ببعض سجلات الطلبات القديمة بعد إزالة أو إخفاء البيانات التي تحدد هوية المستخدم.

## 17. حماية الخدمة

يجوز لنا اتخاذ الإجراءات التقنية والإدارية اللازمة للمحافظة على أمان التطبيق وحماية المستخدمين ومنع الاحتيال أو إساءة الاستخدام.

قد يتم تقييد بعض الوظائف مؤقتاً عند اكتشاف نشاط غير طبيعي أو عند الحاجة لأسباب أمنية.

## 18. حدود الخدمة

نبذل الجهود لتوفير خدمة مستقرة، ولكن قد تتأثر بعض وظائف التطبيق بسبب:

- انقطاع الإنترنت.
- مشاكل خدمات الأطراف التقنية.
- صيانة النظام.
- ظروف خارجة عن السيطرة.
- عدم توفر الكباتن.

لا يمكن ضمان استمرار جميع وظائف التطبيق دون انقطاع في جميع الأوقات.

## 19. سياسة الخصوصية

تخضع معالجة البيانات الشخصية إلى **سياسة الخصوصية** الخاصة بتطبيق حاضر.

يمكن الاطلاع عليها من داخل التطبيق من خلال:

**الحساب ← الخصوصية والأمان ← سياسة الخصوصية**

## 20. تعديل شروط الاستخدام

قد نقوم بتحديث هذه الشروط عند إضافة خدمات جديدة أو تعديل طريقة تشغيل التطبيق أو عند الحاجة لمتطلبات تشغيلية أو قانونية.

ستظهر النسخة المحدثة من شروط الاستخدام داخل تطبيق حاضر مع تاريخ آخر تحديث.

استمرار استخدام التطبيق بعد نشر التعديلات يعني استخدام الخدمة وفق الشروط المحدثة.

## 21. التواصل

للاستفسارات المتعلقة بهذه الشروط، يمكن التواصل معنا من خلال قسم **الدعم الفني** داخل تطبيق حاضر أو من خلال معلومات التواصل الرسمية المعروضة في التطبيق.
$terms_md_batch2$,
  content_format = 'markdown',
  is_published = true,
  updated_at = now()
where document_type = 'terms_of_use';

update public.legal_documents
set
  content = replace(replace(content, 'التوصيل والنقل', 'التوصيل'), '(Anonymize)', 'بعد إزالة أو إخفاء البيانات التي تحدد هوية المستخدم'),
  updated_at = now()
where document_type = 'privacy_policy'
  and (content like '%النقل%' or content like '%Anonymize%');
