-- MANUAL / DEVELOPMENT CLEANUP SCRIPT
-- DO NOT RUN ON PRODUCTION WITHOUT REVIEW
--
-- 054: Cleanup ALL test/demo delivery orders (data only).
-- Safe scope: delivery_orders + order-linked child rows + order notifications.
-- Does NOT touch: profiles, auth.users, captains, subscriptions, coupons defs,
-- app_settings, ads, FCM devices, support, request_number sequence.
--
-- Run in Supabase SQL Editor as a single script (BEGIN…COMMIT).

begin;

-- ---------------------------------------------------------------------------
-- 0) Discover FK children of delivery_orders (informational)
-- ---------------------------------------------------------------------------
create temporary table _cleanup_fk_map on commit drop as
select
  c.conrelid::regclass::text as child_table,
  a.attname as child_column,
  pg_get_constraintdef(c.oid) as constraint_def
from pg_constraint c
join lateral unnest(c.conkey) with ordinality as cols(attnum, ord) on true
join pg_attribute a
  on a.attrelid = c.conrelid
 and a.attnum = cols.attnum
where c.contype = 'f'
  and c.confrelid = 'public.delivery_orders'::regclass;

-- ---------------------------------------------------------------------------
-- 1) BEFORE counts (stored for after-check)
-- ---------------------------------------------------------------------------
create temporary table _cleanup_before on commit drop as
select
  (select count(*)::bigint from public.delivery_orders) as delivery_orders,
  (select count(*)::bigint from public.delivery_order_events) as delivery_order_events,
  (select count(*)::bigint from public.coupon_redemptions) as coupon_redemptions,
  (select count(*)::bigint from public.user_notifications where order_id is not null)
    as notif_with_order_id,
  (select count(*)::bigint from public.user_notifications where type like 'delivery_order_%')
    as notif_delivery_type,
  (select count(*)::bigint from public.user_notifications
     where order_id is not null or type like 'delivery_order_%') as order_notifications,
  (select count(*)::bigint from public.profiles) as profiles,
  (select count(*)::bigint from auth.users) as auth_users,
  (select count(*)::bigint from public.profiles where account_type = 'captain') as captains,
  (select count(*)::bigint from public.app_settings) as app_settings,
  (select count(*)::bigint from public.coupons) as coupons;

select 'BEFORE' as phase, * from _cleanup_before;
select * from _cleanup_fk_map order by child_table, child_column;

-- ---------------------------------------------------------------------------
-- 2) Delete order notifications first (FK is ON DELETE SET NULL)
-- ---------------------------------------------------------------------------
create temporary table _deleted_order_notifications on commit drop as
select id, type, order_id
from public.user_notifications
where order_id is not null
   or type like 'delivery_order_%';

delete from public.user_notifications n
using _deleted_order_notifications d
where n.id = d.id;

-- ---------------------------------------------------------------------------
-- 3) Delete child rows that may not cascade (belt & suspenders), then orders
-- ---------------------------------------------------------------------------
-- Known CASCADE children: delivery_order_events, coupon_redemptions
-- Explicit delete keeps orphan risk at zero even if FK policy differs live.
delete from public.delivery_order_events;
delete from public.coupon_redemptions;

delete from public.delivery_orders;

-- ---------------------------------------------------------------------------
-- 4) AFTER commit verification — fail hard if anything left / accounts changed
-- ---------------------------------------------------------------------------
do $$
declare
  b record;
  v_orders bigint;
  v_events bigint;
  v_redemptions bigint;
  v_orphan_events bigint;
  v_orphan_redemptions bigint;
  v_notif_left bigint;
  v_profiles_after bigint;
  v_users_after bigint;
  v_captains_after bigint;
  v_settings bigint;
  v_coupons bigint;
begin
  select * into b from _cleanup_before;

  select count(*) into v_orders from public.delivery_orders;
  select count(*) into v_events from public.delivery_order_events;
  select count(*) into v_redemptions from public.coupon_redemptions;

  select count(*) into v_orphan_events
  from public.delivery_order_events e
  left join public.delivery_orders o on o.id = e.order_id
  where o.id is null;

  select count(*) into v_orphan_redemptions
  from public.coupon_redemptions r
  left join public.delivery_orders o on o.id = r.order_id
  where o.id is null;

  select count(*) into v_notif_left
  from public.user_notifications
  where order_id is not null
     or type like 'delivery_order_%';

  select count(*) into v_profiles_after from public.profiles;
  select count(*) into v_users_after from auth.users;
  select count(*) into v_captains_after
    from public.profiles where account_type = 'captain';
  select count(*) into v_settings from public.app_settings;
  select count(*) into v_coupons from public.coupons;

  if v_orders <> 0 then
    raise exception 'CLEANUP FAILED: delivery_orders still = %', v_orders;
  end if;
  if v_events <> 0 or v_orphan_events <> 0 then
    raise exception 'CLEANUP FAILED: delivery_order_events leftover=% orphan=%',
      v_events, v_orphan_events;
  end if;
  if v_redemptions <> 0 or v_orphan_redemptions <> 0 then
    raise exception 'CLEANUP FAILED: coupon_redemptions leftover=% orphan=%',
      v_redemptions, v_orphan_redemptions;
  end if;
  if v_notif_left <> 0 then
    raise exception 'CLEANUP FAILED: order notifications left = %', v_notif_left;
  end if;
  if v_profiles_after <> b.profiles then
    raise exception 'CLEANUP FAILED: profiles changed % -> %', b.profiles, v_profiles_after;
  end if;
  if v_users_after <> b.auth_users then
    raise exception 'CLEANUP FAILED: auth.users changed % -> %', b.auth_users, v_users_after;
  end if;
  if v_captains_after <> b.captains then
    raise exception 'CLEANUP FAILED: captains changed % -> %', b.captains, v_captains_after;
  end if;
  if v_settings <> b.app_settings then
    raise exception 'CLEANUP FAILED: app_settings changed';
  end if;
  if v_coupons <> b.coupons then
    raise exception 'CLEANUP FAILED: coupons changed';
  end if;

  raise notice 'AFTER delivery_orders=%', v_orders;
  raise notice 'AFTER delivery_order_events=%', v_events;
  raise notice 'AFTER coupon_redemptions=%', v_redemptions;
  raise notice 'AFTER order_notifications_left=%', v_notif_left;
  raise notice 'DELETED order_notifications=%', b.order_notifications;
  raise notice 'REQUEST_NUMBER_SEQUENCE: not reset (by design)';
end $$;

select 'AFTER' as phase,
  (select count(*) from public.delivery_orders) as delivery_orders,
  (select count(*) from public.delivery_order_events) as delivery_order_events,
  (select count(*) from public.coupon_redemptions) as coupon_redemptions,
  (select count(*) from public.user_notifications
     where order_id is not null or type like 'delivery_order_%') as order_notifications,
  (select count(*) from _deleted_order_notifications) as order_notifications_deleted,
  (select count(*) from public.profiles) as profiles,
  (select count(*) from auth.users) as auth_users,
  (select count(*) from public.profiles where account_type = 'captain') as captains,
  (select count(*) from public.app_settings) as app_settings,
  (select count(*) from public.coupons) as coupons;

commit;
