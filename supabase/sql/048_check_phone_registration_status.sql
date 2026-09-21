-- 048: Pre-registration phone status (available | registered | pending_verification).
-- Used before signUp to block confirmed accounts without sending OTP.
-- Returns status only — no user id, name, or account type.

create or replace function public.check_phone_registration_status(p_phone text)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_e164 text;
  v_registered boolean;
  v_pending boolean;
begin
  v_e164 := public._normalize_iraq_phone_e164(p_phone);
  if v_e164 is null then
    raise exception 'invalid phone format' using errcode = '22023';
  end if;

  perform public._assert_login_phone_probe_allowed(v_e164);

  -- Confirmed auth user or any profile row (user / captain / pending captain).
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
    return 'registered';
  end if;

  -- Incomplete signUp: auth.users row exists but phone not confirmed and no profile.
  select exists (
    select 1
    from auth.users u
    where u.phone is not null
      and u.phone_confirmed_at is null
      and (
        u.phone = v_e164
        or u.phone = replace(v_e164, '+', '')
        or ('+' || u.phone) = v_e164
      )
  ) into v_pending;

  if v_pending then
    return 'pending_verification';
  end if;

  return 'available';
end;
$$;

revoke all on function public.check_phone_registration_status(text) from public;

grant execute on function public.check_phone_registration_status(text) to anon;
grant execute on function public.check_phone_registration_status(text) to authenticated;
