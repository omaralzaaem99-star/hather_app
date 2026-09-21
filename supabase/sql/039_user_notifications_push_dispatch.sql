-- 039: Automatic push dispatch on user_notifications INSERT
-- Requires: 038 (push_device_tokens), dispatch-notification-push Edge Function
-- Method: AFTER INSERT trigger → pg_net (async) → Edge Function
-- Auth: Vault-generated token (never stored in repo); verified server-side via RPC
-- Does NOT modify user_notifications semantics or insert duplicate rows.

-- ---------------------------------------------------------------------------
-- 1) Extensions
-- ---------------------------------------------------------------------------
create extension if not exists pg_net with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- 2) Vault: internal DB→Edge dispatch token (generated once, idempotent)
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from vault.secrets
    where name = 'hather_db_push_dispatch_token'
  ) then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'hather_db_push_dispatch_token',
      'Internal auth for user_notifications INSERT → dispatch-notification-push via pg_net'
    );
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Verify token (Edge Function only — service_role)
-- ---------------------------------------------------------------------------
create or replace function public.verify_internal_push_dispatch_token(p_token text)
returns boolean
language sql
security definer
set search_path = public, vault
stable
as $$
  select exists (
    select 1
    from vault.decrypted_secrets
    where name = 'hather_db_push_dispatch_token'
      and decrypted_secret = btrim(coalesce(p_token, ''))
      and btrim(coalesce(p_token, '')) <> ''
  );
$$;

revoke all on function public.verify_internal_push_dispatch_token(text) from public;
revoke all on function public.verify_internal_push_dispatch_token(text) from anon;
revoke all on function public.verify_internal_push_dispatch_token(text) from authenticated;
grant execute on function public.verify_internal_push_dispatch_token(text) to service_role;

-- ---------------------------------------------------------------------------
-- 4) Trigger function: enqueue async HTTP to Edge Function
-- ---------------------------------------------------------------------------
create or replace function public._dispatch_user_notification_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_token text;
  v_request_id bigint;
  v_functions_url constant text :=
    'https://gonlutyrhccmdpdwqdhk.supabase.co/functions/v1/dispatch-notification-push';
begin
  select ds.decrypted_secret
  into v_token
  from vault.decrypted_secrets ds
  where ds.name = 'hather_db_push_dispatch_token'
  limit 1;

  if v_token is null or btrim(v_token) = '' then
    raise warning 'hather_db_push_dispatch_token missing — push dispatch skipped';
    return NEW;
  end if;

  select net.http_post(
    url := v_functions_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-hather-db-push-token', v_token
    ),
    body := jsonb_build_object('notification_id', NEW.id::text),
    timeout_milliseconds := 8000
  )
  into v_request_id;

  return NEW;
exception
  when others then
    -- Never block the original user_notifications INSERT on push dispatch failure.
    raise warning 'push dispatch enqueue failed for notification %: %', NEW.id, sqlerrm;
    return NEW;
end;
$$;

revoke all on function public._dispatch_user_notification_push() from public;
revoke all on function public._dispatch_user_notification_push() from anon;
revoke all on function public._dispatch_user_notification_push() from authenticated;

-- ---------------------------------------------------------------------------
-- 5) AFTER INSERT trigger (one dispatch per new notification row)
-- ---------------------------------------------------------------------------
drop trigger if exists user_notifications_push_dispatch_trg on public.user_notifications;

create trigger user_notifications_push_dispatch_trg
  after insert on public.user_notifications
  for each row
  execute function public._dispatch_user_notification_push();

-- ---------------------------------------------------------------------------
-- Notes
-- ---------------------------------------------------------------------------
-- • pg_net queues HTTP asynchronously — INSERT transaction is not blocked.
-- • No Dashboard Database Webhook required.
-- • HATHER_PUSH_WEBHOOK_SECRET (Edge secret) remains supported for manual calls.
-- • Internal DB calls use x-hather-db-push-token from Vault (auto-generated above).
-- • Edge Function must include verify_internal_push_dispatch_token RPC check (deployed).
