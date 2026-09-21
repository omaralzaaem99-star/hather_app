-- 013: Ensure convert_profile_to_captain exists (was missing on live DB).
-- Apply in Supabase SQL Editor AFTER 005–012 as needed.
--
-- Live diagnosis (2026-08-22):
--   POST /rest/v1/rpc/convert_profile_to_captain → PGRST202
--   "Could not find the function public.convert_profile_to_captain"
--   Admin RPCs (008+) exist; 005 was never applied to this project.
--
-- Does NOT change Phone Auth, OTPIQ, admin approval flow, or RLS policies.
-- enforce_profile_secure_columns (006) allows SECURITY DEFINER owners
-- (postgres) to update account_type/status — same pattern as admin_* RPCs.

-- ---------------------------------------------------------------------------
-- Optional diagnostics (read-only; run separately if needed)
-- ---------------------------------------------------------------------------
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args,
--        p.prosecdef as security_definer
-- from pg_proc p
-- join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname = 'convert_profile_to_captain';
--
-- select tgname, pg_get_triggerdef(t.oid)
-- from pg_trigger t
-- join pg_class c on c.oid = t.tgrelid
-- join pg_namespace n on n.oid = c.relnamespace
-- where n.nspname = 'public' and c.relname = 'profiles' and not t.tgisinternal;
--
-- select id, account_type, account_status
-- from public.profiles
-- where id = '<auth-user-uuid>';

create or replace function public.convert_profile_to_captain()
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_row public.profiles;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = 'P0001';
  end if;

  update public.profiles
  set
    account_type = 'captain',
    account_status = 'pending',
    updated_at = now()
  where id = auth.uid()
    and account_type = 'user'
  returning * into updated_row;

  if updated_row.id is null then
    select * into updated_row from public.profiles where id = auth.uid();
    if updated_row.id is null then
      raise exception 'profile not found' using errcode = 'P0001';
    end if;
    -- Idempotent: already a captain (pending/active/suspended/disabled).
    if updated_row.account_type = 'captain' then
      return updated_row;
    end if;
    raise exception 'unable to convert account' using errcode = 'P0001';
  end if;

  return updated_row;
end;
$$;

revoke all on function public.convert_profile_to_captain() from public;
revoke all on function public.convert_profile_to_captain() from anon;
grant execute on function public.convert_profile_to_captain() to authenticated;

-- Refresh PostgREST schema cache so the RPC is visible immediately.
notify pgrst, 'reload schema';
