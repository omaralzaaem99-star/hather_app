-- 023: Treat phone as registered only when confirmed or profile exists.
-- Fixes false PHONE_REGISTERED after signUp before OTP verification completes.
-- Apply on Supabase after 021/022.

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

  -- Incomplete signUp (auth.users row, phone not confirmed, no profile) is NOT registered.
  select exists (
    select 1
    from auth.users u
    where u.phone is not null
      and u.phone_confirmed_at is not null
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

revoke all on function public.resolve_login_phone_status(text) from public;

grant execute on function public.resolve_login_phone_status(text) to anon;
grant execute on function public.resolve_login_phone_status(text) to authenticated;
