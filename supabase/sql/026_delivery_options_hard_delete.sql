-- 026: Hard-delete delivery options (no activate/deactivate UX).
-- Add = always active. Delete = remove from system when unused.
-- Requires: 025

-- ---------------------------------------------------------------------------
-- Cleanup soft-disabled unused duration presets (30m / 2h)
-- ---------------------------------------------------------------------------
delete from public.order_delete_durations d
where d.is_active = false
  and not exists (
    select 1 from public.delivery_orders o
    where o.duration_option_id = d.id
       or o.delete_after_minutes = d.minutes
  );

-- Ensure remaining options are active when used as catalog
update public.order_delete_durations
set is_active = true, updated_at = now()
where is_active = false
  and not exists (
    select 1 from public.delivery_orders o where o.duration_option_id = order_delete_durations.id
  );

update public.delivery_fee_options
set is_active = true, updated_at = now()
where is_active = false
  and not exists (
    select 1 from public.delivery_orders o where o.fee_option_id = delivery_fee_options.id
  );

-- ---------------------------------------------------------------------------
-- Upsert always forces is_active = true
-- ---------------------------------------------------------------------------
create or replace function public.admin_upsert_delivery_duration(
  p_id uuid,
  p_label_ar text,
  p_minutes int,
  p_is_active boolean,
  p_sort_order int,
  p_is_default boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.order_delete_durations;
  v_label text := trim(coalesce(p_label_ar, ''));
begin
  perform public.require_dashboard_admin();
  if p_minutes is null or p_minutes <= 0 then
    raise exception 'المدة بالدقائق مطلوبة' using errcode = '22023';
  end if;
  if length(v_label) < 1 then
    raise exception 'اسم المدة مطلوب' using errcode = '22023';
  end if;

  if coalesce(p_is_default, false) then
    update public.order_delete_durations set is_default = false where is_default = true;
  end if;

  if p_id is null then
    insert into public.order_delete_durations (
      label_ar, minutes, is_active, sort_order, is_default, updated_by, updated_at
    ) values (
      v_label, p_minutes, true, coalesce(p_sort_order, 0),
      coalesce(p_is_default, false), auth.uid(), now()
    )
    returning * into v_row;
  else
    update public.order_delete_durations
    set
      label_ar = v_label,
      minutes = p_minutes,
      is_active = true,
      sort_order = coalesce(p_sort_order, sort_order),
      is_default = coalesce(p_is_default, is_default),
      updated_by = auth.uid(),
      updated_at = now()
    where id = p_id
    returning * into v_row;
    if v_row.id is null then
      raise exception 'المدة غير موجودة' using errcode = 'P0001';
    end if;
  end if;

  return row_to_json(v_row)::jsonb;
end;
$$;

create or replace function public.admin_upsert_delivery_fee(
  p_id uuid,
  p_label_ar text,
  p_amount_iqd numeric,
  p_is_active boolean,
  p_sort_order int,
  p_is_default boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.delivery_fee_options;
  v_label text := trim(coalesce(p_label_ar, ''));
begin
  perform public.require_dashboard_admin();
  if p_amount_iqd is null or p_amount_iqd < 0 then
    raise exception 'مبلغ الأجرة غير صالح' using errcode = '22023';
  end if;
  if length(v_label) < 1 then
    v_label := trim(to_char(p_amount_iqd, 'FM999,999,999')) || ' د.ع';
  end if;

  if coalesce(p_is_default, false) then
    update public.delivery_fee_options set is_default = false where is_default = true;
  end if;

  if p_id is null then
    insert into public.delivery_fee_options (
      label_ar, amount_iqd, is_active, sort_order, is_default, updated_by, updated_at
    ) values (
      v_label, p_amount_iqd, true, coalesce(p_sort_order, 0),
      coalesce(p_is_default, false), auth.uid(), now()
    )
    returning * into v_row;
  else
    update public.delivery_fee_options
    set
      label_ar = v_label,
      amount_iqd = p_amount_iqd,
      is_active = true,
      sort_order = coalesce(p_sort_order, sort_order),
      is_default = coalesce(p_is_default, is_default),
      updated_by = auth.uid(),
      updated_at = now()
    where id = p_id
    returning * into v_row;
    if v_row.id is null then
      raise exception 'أجرة التوصيل غير موجودة' using errcode = 'P0001';
    end if;
  end if;

  return row_to_json(v_row)::jsonb;
end;
$$;

create or replace function public.admin_upsert_delivery_coupon(
  p_id uuid,
  p_code text,
  p_discount_type text,
  p_discount_value numeric,
  p_is_active boolean,
  p_starts_at timestamptz,
  p_expires_at timestamptz,
  p_max_uses int,
  p_min_delivery_fee_iqd numeric,
  p_max_discount_iqd numeric,
  p_max_uses_per_user int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.coupons;
  v_code text := upper(trim(coalesce(p_code, '')));
  v_type text := lower(trim(coalesce(p_discount_type, '')));
begin
  perform public.require_dashboard_admin();
  if length(v_code) < 2 then
    raise exception 'كود الكوبون مطلوب' using errcode = '22023';
  end if;
  if v_type not in ('percent', 'fixed') then
    raise exception 'نوع الخصم غير صالح' using errcode = '22023';
  end if;
  if p_discount_value is null or p_discount_value <= 0 then
    raise exception 'قيمة الخصم غير صالحة' using errcode = '22023';
  end if;
  if v_type = 'percent' and p_discount_value > 100 then
    raise exception 'نسبة الخصم لا تتجاوز 100' using errcode = '22023';
  end if;

  if p_id is null then
    insert into public.coupons (
      code, discount_type, discount_value, is_active,
      starts_at, expires_at, max_uses,
      min_delivery_fee_iqd, max_discount_iqd, max_uses_per_user,
      updated_by, updated_at
    ) values (
      v_code, v_type, p_discount_value, true,
      p_starts_at, p_expires_at, p_max_uses,
      coalesce(p_min_delivery_fee_iqd, 0), p_max_discount_iqd, p_max_uses_per_user,
      auth.uid(), now()
    )
    returning * into v_row;
  else
    update public.coupons
    set
      code = v_code,
      discount_type = v_type,
      discount_value = p_discount_value,
      is_active = true,
      starts_at = p_starts_at,
      expires_at = p_expires_at,
      max_uses = p_max_uses,
      min_delivery_fee_iqd = coalesce(p_min_delivery_fee_iqd, 0),
      max_discount_iqd = p_max_discount_iqd,
      max_uses_per_user = p_max_uses_per_user,
      updated_by = auth.uid(),
      updated_at = now()
    where id = p_id
    returning * into v_row;
    if v_row.id is null then
      raise exception 'الكوبون غير موجود' using errcode = 'P0001';
    end if;
  end if;

  return row_to_json(v_row)::jsonb;
end;
$$;

-- ---------------------------------------------------------------------------
-- Hard delete RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_delete_delivery_duration(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.order_delete_durations;
begin
  perform public.require_dashboard_admin();

  select * into v_row from public.order_delete_durations where id = p_id;
  if v_row.id is null then
    raise exception 'المدة غير موجودة' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.delivery_orders o
    where o.duration_option_id = p_id
       or o.delete_after_minutes = v_row.minutes
  ) then
    raise exception 'لا يمكن حذف هذه المدة لأنها مستخدمة في طلبات سابقة'
      using errcode = 'P0001';
  end if;

  if v_row.is_default then
    raise exception 'لا يمكن حذف المدة الافتراضية. عيّن مدة أخرى كافتراضية أولاً'
      using errcode = 'P0001';
  end if;

  delete from public.order_delete_durations where id = p_id;
  return jsonb_build_object('deleted', true, 'id', p_id);
end;
$$;

create or replace function public.admin_delete_delivery_fee(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.delivery_fee_options;
begin
  perform public.require_dashboard_admin();

  select * into v_row from public.delivery_fee_options where id = p_id;
  if v_row.id is null then
    raise exception 'أجرة التوصيل غير موجودة' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.delivery_orders o where o.fee_option_id = p_id
  ) then
    raise exception 'لا يمكن حذف هذه الأجرة لأنها مستخدمة في طلبات سابقة'
      using errcode = 'P0001';
  end if;

  if v_row.is_default then
    raise exception 'لا يمكن حذف الأجرة الافتراضية. عيّن أجرة أخرى كافتراضية أولاً'
      using errcode = 'P0001';
  end if;

  delete from public.delivery_fee_options where id = p_id;
  return jsonb_build_object('deleted', true, 'id', p_id);
end;
$$;

create or replace function public.admin_delete_delivery_coupon(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();

  if not exists (select 1 from public.coupons where id = p_id) then
    raise exception 'الكوبون غير موجود' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.coupon_redemptions r where r.coupon_id = p_id
  ) or exists (
    select 1 from public.delivery_orders o where o.coupon_id = p_id
  ) then
    raise exception 'لا يمكن حذف هذا الكوبون لأنه مستخدم في طلبات سابقة'
      using errcode = 'P0001';
  end if;

  delete from public.coupons where id = p_id;
  return jsonb_build_object('deleted', true, 'id', p_id);
end;
$$;

-- List only active catalog rows for admin clarity
create or replace function public.admin_list_delivery_durations()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();
  return coalesce((
    select jsonb_agg(row_to_json(q)::jsonb order by q.sort_order, q.minutes)
    from (
      select id, label_ar, minutes, is_active, is_default, sort_order, created_at, updated_at
      from public.order_delete_durations
      where is_active = true
    ) q
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_list_delivery_fees()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();
  return coalesce((
    select jsonb_agg(row_to_json(q)::jsonb order by q.sort_order, q.amount_iqd)
    from (
      select id, label_ar, amount_iqd, is_active, is_default, sort_order, created_at, updated_at
      from public.delivery_fee_options
      where is_active = true
    ) q
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_list_delivery_coupons()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();
  return coalesce((
    select jsonb_agg(row_to_json(q)::jsonb order by q.created_at desc)
    from (
      select
        id, code, discount_type, discount_value, is_active,
        starts_at, expires_at, max_uses, used_count,
        min_delivery_fee_iqd, max_discount_iqd, max_uses_per_user,
        created_at, updated_at
      from public.coupons
      where is_active = true
    ) q
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_delete_delivery_duration(uuid) from public;
revoke all on function public.admin_delete_delivery_fee(uuid) from public;
revoke all on function public.admin_delete_delivery_coupon(uuid) from public;

grant execute on function public.admin_delete_delivery_duration(uuid) to authenticated;
grant execute on function public.admin_delete_delivery_fee(uuid) to authenticated;
grant execute on function public.admin_delete_delivery_coupon(uuid) to authenticated;
