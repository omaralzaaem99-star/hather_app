-- 031: User in-app notifications + hide expired from user order list
-- Depends on: 015 accept, 020 support reply, 029 complete, 030 expire
-- Does NOT modify older migration files; CREATE OR REPLACE only.

-- ---------------------------------------------------------------------------
-- 1) Table
-- ---------------------------------------------------------------------------
create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  order_id uuid null references public.delivery_orders (id) on delete set null,
  support_request_id uuid null references public.support_form_submissions (id) on delete set null,
  is_read boolean not null default false,
  read_at timestamptz null,
  created_at timestamptz not null default now(),
  dedupe_key text null,
  constraint user_notifications_type_chk check (
    type in (
      'delivery_order_expired',
      'delivery_order_accepted',
      'delivery_order_completed',
      'support_reply'
    )
  ),
  -- Multiple NULLs allowed; non-null keys unique (cron/retry safe).
  constraint user_notifications_dedupe_key_key unique (dedupe_key)
);

create index if not exists user_notifications_user_created_idx
  on public.user_notifications (user_id, created_at desc);

create index if not exists user_notifications_user_unread_idx
  on public.user_notifications (user_id, is_read)
  where is_read = false;

alter table public.user_notifications enable row level security;

revoke all on table public.user_notifications from public;
revoke all on table public.user_notifications from anon;
revoke all on table public.user_notifications from authenticated;

-- Read own rows only (writes via SECURITY DEFINER RPCs)
drop policy if exists user_notifications_select_own on public.user_notifications;
create policy user_notifications_select_own
  on public.user_notifications
  for select
  to authenticated
  using (user_id = auth.uid());

grant select on table public.user_notifications to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Insert helper (dedupe-safe)
-- ---------------------------------------------------------------------------
create or replace function public._insert_user_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_order_id uuid default null,
  p_support_request_id uuid default null,
  p_dedupe_key text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_user_id is null or p_type is null or p_title is null or p_body is null then
    return null;
  end if;

  insert into public.user_notifications (
    user_id, type, title, body, order_id, support_request_id, dedupe_key
  )
  values (
    p_user_id, p_type, p_title, p_body, p_order_id, p_support_request_id, p_dedupe_key
  )
  on conflict (dedupe_key) do nothing
  returning id into v_id;

  return v_id;
exception
  when unique_violation then
    return null;
end;
$$;

revoke all on function public._insert_user_notification(uuid, text, text, text, uuid, uuid, text)
  from public;
revoke all on function public._insert_user_notification(uuid, text, text, text, uuid, uuid, text)
  from anon;
revoke all on function public._insert_user_notification(uuid, text, text, text, uuid, uuid, text)
  from authenticated;

-- ---------------------------------------------------------------------------
-- 3) User RPCs
-- ---------------------------------------------------------------------------
create or replace function public.get_my_notifications(
  p_limit int default 30,
  p_offset int default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  lim int;
  off int;
  result jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  lim := greatest(1, least(coalesce(p_limit, 30), 50));
  off := greatest(0, coalesce(p_offset, 0));

  select coalesce(jsonb_agg(row_data order by created_at desc), '[]'::jsonb)
  into result
  from (
    select jsonb_build_object(
      'id', n.id,
      'type', n.type,
      'title', n.title,
      'body', n.body,
      'order_id', n.order_id,
      'support_request_id', n.support_request_id,
      'is_read', n.is_read,
      'read_at', n.read_at,
      'created_at', n.created_at
    ) as row_data,
    n.created_at
    from public.user_notifications n
    where n.user_id = auth.uid()
    order by n.created_at desc
    limit lim
    offset off
  ) q;

  return result;
end;
$$;

create or replace function public.get_my_unread_notification_count()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select count(*)::int into n
  from public.user_notifications
  where user_id = auth.uid() and is_read = false;

  return coalesce(n, 0);
end;
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  update public.user_notifications
  set
    is_read = true,
    read_at = coalesce(read_at, now())
  where id = p_notification_id
    and user_id = auth.uid()
  returning id into updated_id;

  return updated_id is not null;
end;
$$;

create or replace function public.mark_all_notifications_read()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  update public.user_notifications
  set
    is_read = true,
    read_at = coalesce(read_at, now())
  where user_id = auth.uid()
    and is_read = false;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.get_my_notifications(int, int) from public;
revoke all on function public.get_my_unread_notification_count() from public;
revoke all on function public.mark_notification_read(uuid) from public;
revoke all on function public.mark_all_notifications_read() from public;

grant execute on function public.get_my_notifications(int, int) to authenticated;
grant execute on function public.get_my_unread_notification_count() to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Expire → notify (replace 030 function)
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
      r.user_id,
      'delivery_order_expired',
      'انتهت مدة طلبك',
      case
        when v_num <> '' then
          'للأسف لم يقبل أي كابتن طلبك رقم ' || v_num || ' خلال المدة المحددة.'
        else
          'للأسف لم يقبل أي كابتن طلبك خلال المدة المحددة.'
      end,
      r.id,
      null,
      'delivery_order_expired:' || r.id::text
    );
  end loop;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Accept → notify
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
    updated_row.user_id,
    'delivery_order_accepted',
    'تم قبول طلبك',
    v_body,
    updated_row.id,
    null,
    'delivery_order_accepted:' || updated_row.id::text
  );

  return public._captain_order_detail_json(updated_row.id, prof.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) Complete → notify
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

  v_num := coalesce(updated_row.request_number::text, '');
  perform public._insert_user_notification(
    updated_row.user_id,
    'delivery_order_completed',
    'تم تسليم طلبك',
    case
      when v_num <> '' then 'تم إكمال طلبك رقم ' || v_num || ' بنجاح.'
      else 'تم إكمال طلبك بنجاح.'
    end,
    updated_row.id,
    null,
    'delivery_order_completed:' || updated_row.id::text
  );

  return public._captain_order_detail_json(updated_row.id, prof.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 7) Support first reply → notify
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

  -- First real reply only (avoid spam on later edits)
  if v_old_reply is null and v_reply is not null then
    v_num := coalesce(v_row.request_number::text, '');
    perform public._insert_user_notification(
      v_row.user_id,
      'support_reply',
      'رد جديد من فريق حاضر',
      case
        when v_num <> '' then
          'وصلك رد جديد على طلب الدعم رقم ' || v_num || '.'
        else
          'وصلك رد جديد على طلب الدعم.'
      end,
      null,
      v_row.id,
      'support_reply:' || v_row.id::text
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
