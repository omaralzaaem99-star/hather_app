-- 030: Auto-expire pending delivery orders (pending → expired)
-- Depends on: 004 (delivery_orders + status check), 015 (available idx / accept),
--             028/029 (JSON helpers). Does NOT modify older migrations.
--
-- CURRENT BEHAVIOR (before this file):
--   Expired pending rows often stayed status='pending' and were only hidden from
--   captains via expires_at > now() filters. This migration sets status='expired'.
--
-- COUPON: redemptions / used_count are NOT reversed on expire (audit-only decision).
--
-- SCHEDULE: uses pg_cron every 5 minutes when the extension is available.
--   If schedule fails, enable Database → Extensions → pg_cron, then re-run the
--   schedule block at the bottom (or call expire_pending_delivery_orders() manually).

-- ---------------------------------------------------------------------------
-- 1) Expire function (atomic, pending + no captain + past expires_at only)
-- ---------------------------------------------------------------------------
create or replace function public.expire_pending_delivery_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  -- Never touches active / completed / cancelled / assigned orders.
  update public.delivery_orders
  set
    status = 'expired',
    updated_at = now()
  where status = 'pending'
    and captain_id is null
    and expires_at <= now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.expire_pending_delivery_orders() is
  'Marks overdue pending delivery orders as expired. Safe for cron; does not reverse coupons.';

revoke all on function public.expire_pending_delivery_orders() from public;
revoke all on function public.expire_pending_delivery_orders() from anon;
revoke all on function public.expire_pending_delivery_orders() from authenticated;
grant execute on function public.expire_pending_delivery_orders() to postgres;
grant execute on function public.expire_pending_delivery_orders() to service_role;

-- Optional: dashboard admins may run manually for catch-up
create or replace function public.admin_expire_pending_delivery_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();
  return public.expire_pending_delivery_orders();
end;
$$;

revoke all on function public.admin_expire_pending_delivery_orders() from public;
revoke all on function public.admin_expire_pending_delivery_orders() from anon;
grant execute on function public.admin_expire_pending_delivery_orders() to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Index for expire job (partial — pending + unassigned)
--    015 already has delivery_orders_available_idx (status, expires_at) WHERE
--    captain_id is null AND status = 'pending'. Ensure it exists.
-- ---------------------------------------------------------------------------
create index if not exists delivery_orders_available_idx
  on public.delivery_orders (status, expires_at)
  where captain_id is null and status = 'pending';

create index if not exists delivery_orders_expire_pending_idx
  on public.delivery_orders (expires_at)
  where status = 'pending' and captain_id is null;

-- ---------------------------------------------------------------------------
-- 3) Defense in depth: keep expires_at guards on list + accept
--    (Reaffirm current 028 logic — no behavior change beyond documentation.)
--    captain_list_available_orders: status=pending AND expires_at > now()
--    captain_accept_delivery_order: UPDATE ... AND expires_at > now()
--    Race: expire only updates pending+null captain+expires_at<=now();
--          accept only updates pending+null captain+expires_at>now();
--          exactly one can win.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 4) Schedule with pg_cron every 5 minutes (best-effort)
-- ---------------------------------------------------------------------------
do $sched$
declare
  jid bigint;
begin
  begin
    create extension if not exists pg_cron;
  exception
    when others then
      raise notice
        '030: pg_cron not available (%). Function expire_pending_delivery_orders() is ready; enable pg_cron in Dashboard → Database → Extensions, then schedule manually.',
        sqlerrm;
      return;
  end;

  -- Remove prior job with same name (idempotent re-apply)
  begin
    for jid in
      select jobid from cron.job where jobname = 'expire-pending-delivery-orders'
    loop
      perform cron.unschedule(jid);
    end loop;
  exception
    when undefined_table then
      raise notice '030: cron.job not found; skip unschedule.';
    when others then
      raise notice '030: unschedule skipped (%).', sqlerrm;
  end;

  begin
    perform cron.schedule(
      'expire-pending-delivery-orders',
      '*/5 * * * *',
      $cron$select public.expire_pending_delivery_orders();$cron$
    );
    raise notice '030: scheduled expire-pending-delivery-orders every 5 minutes.';
  exception
    when others then
      raise notice
        '030: could not schedule cron job (%). Enable pg_cron, then run: select cron.schedule(''expire-pending-delivery-orders'', ''*/5 * * * *'', $c$select public.expire_pending_delivery_orders();$c$);',
        sqlerrm;
  end;
end;
$sched$;
