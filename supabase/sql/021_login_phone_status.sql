-- 021: Login-flow phone status (post failed sign-in only — rate limited).
-- Returns PHONE_NOT_REGISTERED | PHONE_REGISTERED without exposing user data.
-- Supabase: choose "Run and enable RLS" — table has RLS + no client policies.

create table if not exists public.login_phone_probe_log (
  id bigserial primary key,
  phone_hash text not null,
  created_at timestamptz not null default now()
);

create index if not exists login_phone_probe_log_hash_created_idx
  on public.login_phone_probe_log (phone_hash, created_at desc);

-- Internal audit table: RLS on, no policies for anon/authenticated.
alter table public.login_phone_probe_log enable row level security;

revoke all on table public.login_phone_probe_log from public;
revoke all on table public.login_phone_probe_log from anon;
revoke all on table public.login_phone_probe_log from authenticated;

create or replace function public._assert_login_phone_probe_allowed(p_e164 text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hash text;
  v_count integer;
begin
  if p_e164 is null or btrim(p_e164) = '' then
    raise exception 'phone required' using errcode = '22023';
  end if;

  v_hash := md5(p_e164);

  select count(*)::integer into v_count
  from public.login_phone_probe_log l
  where l.phone_hash = v_hash
    and l.created_at > now() - interval '15 minutes';

  if v_count >= 8 then
    raise exception 'too many login phone checks' using errcode = 'P0001';
  end if;

  insert into public.login_phone_probe_log (phone_hash) values (v_hash);

  delete from public.login_phone_probe_log
  where created_at < now() - interval '24 hours';
end;
$$;

create or replace function public.resolve_login_phone_status(p_phone text)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_e164 text;
  v_registered boolean;
begin
  v_e164 := public._normalize_iraq_phone_e164(p_phone);
  if v_e164 is null then
    raise exception 'invalid phone format' using errcode = '22023';
  end if;

  perform public._assert_login_phone_probe_allowed(v_e164);

  select exists (
    select 1
    from auth.users u
    where u.phone is not null
      and (
        u.phone = v_e164
        or u.phone = replace(v_e164, '+', '')
        or ('+' || u.phone) = v_e164
      )
  ) or exists (
    select 1
    from public.profiles p
    where p.phone is not null
      and (
        p.phone = v_e164
        or p.phone = replace(v_e164, '+', '')
        or ('+' || p.phone) = v_e164
      )
  ) into v_registered;

  if v_registered then
    return 'PHONE_REGISTERED';
  end if;

  return 'PHONE_NOT_REGISTERED';
end;
$$;

revoke all on function public._assert_login_phone_probe_allowed(text) from public;
revoke all on function public.resolve_login_phone_status(text) from public;

grant execute on function public.resolve_login_phone_status(text) to anon;
grant execute on function public.resolve_login_phone_status(text) to authenticated;

grant execute on function public._normalize_iraq_phone_e164(text) to postgres;
grant execute on function public._normalize_iraq_phone_e164(text) to service_role;
