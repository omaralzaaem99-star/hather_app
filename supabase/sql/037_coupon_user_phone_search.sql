-- 037: Fix admin coupon user search — Iraqi phone normalization
-- Requires: 035 (admin_search_coupon_users), 017 (_normalize_iraq_phone_e164)
-- Does NOT modify prior applied migrations.

-- ---------------------------------------------------------------------------
-- 1) Phone digit helpers (search-time only — does not mutate profiles.phone)
-- ---------------------------------------------------------------------------
create or replace function public._iraq_phone_digits_only(p_raw text)
returns text
language sql
immutable
as $$
  select regexp_replace(
    translate(btrim(coalesce(p_raw, '')), '٠١٢٣٤٥٦٧٨٩', '0123456789'),
    '\D',
    '',
    'g'
  );
$$;

revoke all on function public._iraq_phone_digits_only(text) from public;

-- National mobile core: 7806560998 (10 digits, no country / leading zero)
create or replace function public._iraq_phone_national_digits(p_raw text)
returns text
language plpgsql
immutable
as $$
declare
  v_e164 text;
  d text;
begin
  if p_raw is null or btrim(p_raw) = '' then
    return null;
  end if;

  v_e164 := public._normalize_iraq_phone_e164(p_raw);
  if v_e164 is not null then
    return substring(v_e164 from 5);
  end if;

  d := public._iraq_phone_digits_only(p_raw);
  if d is null or d = '' then
    return null;
  end if;

  if d like '964%' and length(d) >= 13 then
    return substr(d, 4, 10);
  end if;

  if d like '0%' and length(d) >= 11 then
    return substr(d, 2, 10);
  end if;

  if d ~ '^7\d{9}$' then
    return d;
  end if;

  return null;
end;
$$;

revoke all on function public._iraq_phone_national_digits(text) from public;

-- Normalize admin search input for partial / full phone matching
create or replace function public._iraq_phone_query_key(p_query text)
returns text
language plpgsql
immutable
as $$
declare
  d text;
  nat text;
begin
  d := public._iraq_phone_digits_only(p_query);
  if d is null or d = '' then
    return null;
  end if;

  nat := public._iraq_phone_national_digits(p_query);
  if nat is not null and length(d) >= 10 then
    return nat;
  end if;

  if d like '964%' then
    d := substring(d from 4);
  elsif d like '0%' then
    d := substring(d from 2);
  end if;

  return nullif(d, '');
end;
$$;

revoke all on function public._iraq_phone_query_key(text) from public;

create or replace function public._iraq_phone_matches_search(p_stored text, p_query text)
returns boolean
language plpgsql
immutable
as $$
declare
  v_stored_nat text;
  v_key text;
begin
  v_key := public._iraq_phone_query_key(p_query);
  if v_key is null or length(v_key) < 3 then
    return false;
  end if;

  v_stored_nat := public._iraq_phone_national_digits(p_stored);
  if v_stored_nat is null then
    return false;
  end if;

  return v_stored_nat like '%' || v_key || '%';
end;
$$;

revoke all on function public._iraq_phone_matches_search(text, text) from public;

-- ---------------------------------------------------------------------------
-- 2) Admin coupon user search — name + normalized Iraqi phone
-- ---------------------------------------------------------------------------
create or replace function public.admin_search_coupon_users(
  p_query text,
  p_limit int default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_q text := btrim(coalesce(p_query, ''));
  v_key text;
  lim int;
begin
  perform public.require_dashboard_admin();
  lim := greatest(1, least(coalesce(p_limit, 20), 50));

  if length(v_q) < 2 then
    return '[]'::jsonb;
  end if;

  v_key := public._iraq_phone_query_key(v_q);

  return coalesce((
    select jsonb_agg(row_to_json(q)::jsonb order by q.full_name, q.phone)
    from (
      select
        p.id,
        p.full_name,
        p.phone
      from public.profiles p
      where p.account_type = 'user'
        and p.account_status <> 'disabled'
        and (
          p.full_name ilike '%' || v_q || '%'
          or public._iraq_phone_matches_search(p.phone, v_q)
        )
      order by p.full_name nulls last, p.created_at desc
      limit lim
    ) q
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_search_coupon_users(text, int) from public;
grant execute on function public.admin_search_coupon_users(text, int) to authenticated;
