-- PREFLIGHT ONLY — read-only. Run in SQL Editor before Phone Auth cutover.
-- Do not modify auth.users from this file.

select 'auth_users_total' as metric, count(*)::bigint as value from auth.users
union all
select 'internal_email_users', count(*)::bigint
  from auth.users
  where email ilike '%@hather.local'
union all
select 'profiles_total', count(*)::bigint from public.profiles
union all
select 'users_with_matching_profile', count(*)::bigint
  from public.profiles p
  join auth.users u on u.id = p.id
union all
select 'duplicate_phones', count(*)::bigint
  from (
    select phone from public.profiles
    group by phone
    having count(*) > 1
  ) d
union all
select 'missing_phone_on_profile', count(*)::bigint
  from public.profiles
  where phone is null or btrim(phone) = ''
union all
select 'internal_email_with_profile_phone', count(*)::bigint
  from auth.users u
  join public.profiles p on p.id = u.id
  where u.email ilike '%@hather.local'
    and p.phone is not null
    and btrim(p.phone) <> '';
