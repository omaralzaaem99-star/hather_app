-- Allow authenticated users to convert their own account to captain (pending review).
-- Apply in Supabase SQL Editor after 001_create_profiles.sql.

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
    raise exception 'not authenticated';
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
      raise exception 'profile not found';
    end if;
    if updated_row.account_type = 'captain' then
      return updated_row;
    end if;
    raise exception 'unable to convert account';
  end if;

  return updated_row;
end;
$$;

revoke all on function public.convert_profile_to_captain() from public;
grant execute on function public.convert_profile_to_captain() to authenticated;
