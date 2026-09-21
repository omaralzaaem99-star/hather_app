-- Mirror of 055_self_account_deletion.sql for supabase db push / migration history.
-- Same contents as supabase/sql/055_self_account_deletion.sql

alter table public.delivery_orders
  alter column user_id drop not null;

do $$
declare
  c_name text;
begin
  select con.conname into c_name
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace nsp on nsp.oid = rel.relnamespace
  where nsp.nspname = 'public'
    and rel.relname = 'delivery_orders'
    and con.contype = 'f'
    and pg_get_constraintdef(con.oid) ilike '%user_id%profiles%';

  if c_name is not null then
    execute format('alter table public.delivery_orders drop constraint %I', c_name);
  end if;
end $$;

alter table public.delivery_orders
  add constraint delivery_orders_user_id_fkey
  foreign key (user_id) references public.profiles (id) on delete set null;

create or replace function public.prepare_my_account_deletion()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  prof public.profiles;
  v_user_active int;
  v_captain_active int;
  v_anonymized int := 0;
  masked text;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.dashboard_admins a where a.user_id = v_uid
  ) then
    raise exception 'لا يمكن حذف حساب مرتبط بصلاحيات لوحة الإدارة'
      using errcode = 'P0001';
  end if;

  select * into prof from public.profiles where id = v_uid;
  if prof.id is null then
    return jsonb_build_object('ok', true, 'already_deleted', true);
  end if;

  select count(*)::int into v_user_active
  from public.delivery_orders
  where user_id = v_uid
    and status in ('pending', 'active');

  if v_user_active > 0 then
    raise exception
      'لا يمكن حذف الحساب أثناء وجود طلب نشط. أكمل أو ألغِ طلبك الحالي أولاً.'
      using errcode = 'P0001';
  end if;

  select count(*)::int into v_captain_active
  from public.delivery_orders
  where captain_id = v_uid
    and status = 'active';

  if v_captain_active > 0 then
    raise exception
      'لا يمكن حذف حساب الكابتن أثناء وجود طلبات نشطة. أكمل الطلبات الحالية أولاً.'
      using errcode = 'P0001';
  end if;

  update public.delivery_orders
  set
    destination_address = null,
    destination_lat = null,
    destination_lng = null,
    details = 'تم حذف الحساب',
    user_id = null,
    updated_at = now()
  where user_id = v_uid
    and status in ('completed', 'cancelled', 'expired');

  get diagnostics v_anonymized = row_count;

  update public.delivery_orders
  set
    captain_id = null,
    updated_at = now()
  where captain_id = v_uid
    and status in ('completed', 'cancelled', 'expired', 'pending');

  delete from public.push_device_tokens where user_id = v_uid;

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
    v_uid,
    masked,
    v_uid,
    'self_service_account_deletion'
  );

  return jsonb_build_object(
    'ok', true,
    'user_id', prof.id,
    'account_type', prof.account_type,
    'masked_phone', masked,
    'orders_anonymized', v_anonymized
  );
end;
$$;

revoke all on function public.prepare_my_account_deletion() from public;
grant execute on function public.prepare_my_account_deletion() to authenticated;
