-- 018: Dynamic FAQ + support forms + submissions
-- Apply AFTER 017_support_phone_fix.sql

-- ---------------------------------------------------------------------------
-- 1) Tables
-- ---------------------------------------------------------------------------
create table if not exists public.support_faqs (
  id uuid primary key default gen_random_uuid(),
  question text not null check (char_length(trim(question)) > 0),
  answer text not null check (char_length(trim(answer)) > 0),
  audience text not null default 'both'
    check (audience in ('both', 'user', 'captain')),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  updated_by uuid references auth.users (id) on delete set null
);

create index if not exists support_faqs_active_sort_idx
  on public.support_faqs (is_active, sort_order, created_at);

create table if not exists public.support_forms (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) > 0),
  description text,
  audience text not null default 'both'
    check (audience in ('both', 'user', 'captain')),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  updated_by uuid references auth.users (id) on delete set null
);

create index if not exists support_forms_active_sort_idx
  on public.support_forms (is_active, sort_order, created_at);

create table if not exists public.support_form_fields (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.support_forms (id) on delete cascade,
  field_key text not null check (field_key ~ '^[a-z][a-z0-9_]{1,63}$'),
  label text not null check (char_length(trim(label)) > 0),
  field_type text not null check (field_type in ('text', 'textarea', 'select')),
  placeholder text,
  is_required boolean not null default false,
  sort_order integer not null default 0,
  options jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (form_id, field_key)
);

create index if not exists support_form_fields_form_sort_idx
  on public.support_form_fields (form_id, sort_order);

create table if not exists public.support_form_submissions (
  id uuid primary key default gen_random_uuid(),
  request_number bigint generated always as identity,
  form_id uuid not null references public.support_forms (id) on delete restrict,
  user_id uuid not null references auth.users (id) on delete cascade,
  account_type text not null check (account_type in ('user', 'captain')),
  form_title text not null,
  payload jsonb not null,
  status text not null default 'new'
    check (status in ('new', 'in_progress', 'resolved', 'closed')),
  admin_note text,
  handled_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists support_form_submissions_user_idx
  on public.support_form_submissions (user_id, created_at desc);

create index if not exists support_form_submissions_status_idx
  on public.support_form_submissions (status, created_at desc);

alter table public.support_faqs enable row level security;
alter table public.support_forms enable row level security;
alter table public.support_form_fields enable row level security;
alter table public.support_form_submissions enable row level security;

-- No broad client policies — RPCs only.

-- ---------------------------------------------------------------------------
-- 2) Helpers
-- ---------------------------------------------------------------------------
create or replace function public._current_support_account_type()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v text;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select p.account_type into v
  from public.profiles p
  where p.id = auth.uid();

  if v = 'captain' then
    return 'captain';
  end if;
  return 'user';
end;
$$;

create or replace function public._support_audience_matches(
  p_audience text,
  p_account_type text
)
returns boolean
language sql
immutable
as $$
  select case
    when p_audience = 'both' then true
    when p_audience = p_account_type then true
    else false
  end;
$$;

create or replace function public._normalize_support_field_key(p_raw text)
returns text
language plpgsql
immutable
as $$
declare
  v text;
begin
  v := lower(regexp_replace(trim(coalesce(p_raw, '')), '[^a-z0-9]+', '_', 'g'));
  v := regexp_replace(v, '^_+|_+$', '', 'g');
  if v = '' then
    return null;
  end if;
  if v !~ '^[a-z]' then
    v := 'f_' || v;
  end if;
  return substring(v from 1 for 64);
end;
$$;

revoke all on function public._current_support_account_type() from public;
revoke all on function public._support_audience_matches(text, text) from public;
revoke all on function public._normalize_support_field_key(text) from public;

-- ---------------------------------------------------------------------------
-- 3) App read RPCs
-- ---------------------------------------------------------------------------
create or replace function public.get_support_faqs()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_account text;
begin
  v_account := public._current_support_account_type();

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', f.id,
          'question', f.question,
          'answer', f.answer,
          'sort_order', f.sort_order
        )
        order by f.sort_order asc, f.created_at asc
      )
      from public.support_faqs f
      where f.is_active = true
        and public._support_audience_matches(f.audience, v_account)
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.get_support_forms()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_account text;
begin
  v_account := public._current_support_account_type();

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', f.id,
          'title', f.title,
          'description', f.description,
          'sort_order', f.sort_order
        )
        order by f.sort_order asc, f.created_at asc
      )
      from public.support_forms f
      where f.is_active = true
        and public._support_audience_matches(f.audience, v_account)
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.get_support_form_detail(p_form_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_account text;
  v_form public.support_forms;
begin
  v_account := public._current_support_account_type();

  select * into v_form
  from public.support_forms f
  where f.id = p_form_id
    and f.is_active = true
    and public._support_audience_matches(f.audience, v_account);

  if v_form.id is null then
    raise exception 'support form not found' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'id', v_form.id,
    'title', v_form.title,
    'description', v_form.description,
    'fields', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ff.id,
            'field_key', ff.field_key,
            'label', ff.label,
            'field_type', ff.field_type,
            'placeholder', ff.placeholder,
            'is_required', ff.is_required,
            'sort_order', ff.sort_order,
            'options', ff.options
          )
          order by ff.sort_order asc, ff.created_at asc
        )
        from public.support_form_fields ff
        where ff.form_id = v_form.id
          and ff.is_active = true
      ),
      '[]'::jsonb
    )
  );
end;
$$;

create or replace function public.my_support_requests()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'request_number', s.request_number,
          'form_title', s.form_title,
          'status', s.status,
          'created_at', s.created_at,
          'updated_at', s.updated_at
        )
        order by s.created_at desc
      )
      from public.support_form_submissions s
      where s.user_id = auth.uid()
    ),
    '[]'::jsonb
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Submit RPC (server-side validation)
-- ---------------------------------------------------------------------------
create or replace function public.submit_support_request(
  p_form_id uuid,
  p_answers jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_account text;
  v_form public.support_forms;
  v_field record;
  v_value text;
  v_payload jsonb := '[]'::jsonb;
  v_submission public.support_form_submissions;
  v_allowed jsonb;
  v_match boolean;
begin
  v_account := public._current_support_account_type();

  if p_form_id is null then
    raise exception 'form id required' using errcode = '22023';
  end if;
  if p_answers is null or jsonb_typeof(p_answers) <> 'object' then
    raise exception 'answers must be a json object' using errcode = '22023';
  end if;

  select * into v_form
  from public.support_forms f
  where f.id = p_form_id
    and f.is_active = true
    and public._support_audience_matches(f.audience, v_account);

  if v_form.id is null then
    raise exception 'support form not available' using errcode = '42501';
  end if;

  for v_field in
    select *
    from public.support_form_fields ff
    where ff.form_id = v_form.id
      and ff.is_active = true
    order by ff.sort_order asc, ff.created_at asc
  loop
    v_value := nullif(btrim(coalesce(p_answers ->> v_field.field_key, '')), '');

    if v_field.is_required and v_value is null then
      raise exception 'required field missing: %', v_field.label using errcode = '22023';
    end if;

    if v_value is not null then
      if v_field.field_type = 'select' then
        v_match := false;
        if v_field.options is not null and jsonb_typeof(v_field.options) = 'array' then
          select exists (
            select 1
            from jsonb_array_elements_text(v_field.options) opt(val)
            where opt.val = v_value
          ) into v_match;
        end if;
        if not v_match then
          raise exception 'invalid option for field: %', v_field.label using errcode = '22023';
        end if;
      end if;

      if char_length(v_value) > 5000 then
        raise exception 'field value too long: %', v_field.label using errcode = '22023';
      end if;

      v_payload := v_payload || jsonb_build_array(
        jsonb_build_object(
          'field_key', v_field.field_key,
          'label', v_field.label,
          'field_type', v_field.field_type,
          'value', v_value
        )
      );
    end if;
  end loop;

  if jsonb_array_length(v_payload) = 0 then
    raise exception 'at least one answer is required' using errcode = '22023';
  end if;

  insert into public.support_form_submissions (
    form_id,
    user_id,
    account_type,
    form_title,
    payload,
    status
  ) values (
    v_form.id,
    auth.uid(),
    v_account,
    v_form.title,
    v_payload,
    'new'
  )
  returning * into v_submission;

  return jsonb_build_object(
    'id', v_submission.id,
    'request_number', v_submission.request_number,
    'form_title', v_submission.form_title,
    'status', v_submission.status,
    'created_at', v_submission.created_at
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Admin FAQ RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_support_faqs()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', f.id,
          'question', f.question,
          'answer', f.answer,
          'audience', f.audience,
          'is_active', f.is_active,
          'sort_order', f.sort_order,
          'created_at', f.created_at,
          'updated_at', f.updated_at
        )
        order by f.sort_order asc, f.created_at asc
      )
      from public.support_faqs f
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.admin_upsert_support_faq(
  p_id uuid,
  p_question text,
  p_answer text,
  p_audience text,
  p_is_active boolean,
  p_sort_order integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.support_faqs;
  v_question text;
  v_answer text;
begin
  perform public.require_dashboard_admin();

  v_question := nullif(btrim(coalesce(p_question, '')), '');
  v_answer := nullif(btrim(coalesce(p_answer, '')), '');

  if v_question is null then
    raise exception 'question required' using errcode = '22023';
  end if;
  if v_answer is null then
    raise exception 'answer required' using errcode = '22023';
  end if;
  if p_audience not in ('both', 'user', 'captain') then
    raise exception 'invalid audience' using errcode = '22023';
  end if;
  if char_length(v_question) > 500 or char_length(v_answer) > 5000 then
    raise exception 'question or answer too long' using errcode = '22023';
  end if;

  if p_id is null then
    insert into public.support_faqs (
      question, answer, audience, is_active, sort_order, created_by, updated_by
    ) values (
      v_question,
      v_answer,
      p_audience,
      coalesce(p_is_active, true),
      coalesce(p_sort_order, 0),
      auth.uid(),
      auth.uid()
    )
    returning * into v_row;
  else
    update public.support_faqs
      set
        question = v_question,
        answer = v_answer,
        audience = p_audience,
        is_active = coalesce(p_is_active, true),
        sort_order = coalesce(p_sort_order, 0),
        updated_at = now(),
        updated_by = auth.uid()
    where id = p_id
    returning * into v_row;

    if v_row.id is null then
      raise exception 'faq not found' using errcode = '22023';
    end if;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'question', v_row.question,
    'answer', v_row.answer,
    'audience', v_row.audience,
    'is_active', v_row.is_active,
    'sort_order', v_row.sort_order,
    'updated_at', v_row.updated_at
  );
end;
$$;

create or replace function public.admin_delete_support_faq(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();
  delete from public.support_faqs where id = p_id;
  return found;
end;
$$;

create or replace function public.admin_set_support_faq_active(
  p_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.support_faqs;
begin
  perform public.require_dashboard_admin();

  update public.support_faqs
    set
      is_active = coalesce(p_is_active, false),
      updated_at = now(),
      updated_by = auth.uid()
  where id = p_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'faq not found' using errcode = '22023';
  end if;

  return jsonb_build_object('id', v_row.id, 'is_active', v_row.is_active);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) Admin form RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_support_forms()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', f.id,
          'title', f.title,
          'description', f.description,
          'audience', f.audience,
          'is_active', f.is_active,
          'sort_order', f.sort_order,
          'field_count', (
            select count(*)
            from public.support_form_fields ff
            where ff.form_id = f.id and ff.is_active = true
          ),
          'submission_count', (
            select count(*)
            from public.support_form_submissions s
            where s.form_id = f.id
          ),
          'updated_at', f.updated_at
        )
        order by f.sort_order asc, f.created_at asc
      )
      from public.support_forms f
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.admin_get_support_form(p_form_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_form public.support_forms;
begin
  perform public.require_dashboard_admin();

  select * into v_form from public.support_forms where id = p_form_id;
  if v_form.id is null then
    raise exception 'form not found' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'id', v_form.id,
    'title', v_form.title,
    'description', v_form.description,
    'audience', v_form.audience,
    'is_active', v_form.is_active,
    'sort_order', v_form.sort_order,
    'fields', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ff.id,
            'field_key', ff.field_key,
            'label', ff.label,
            'field_type', ff.field_type,
            'placeholder', ff.placeholder,
            'is_required', ff.is_required,
            'sort_order', ff.sort_order,
            'options', ff.options,
            'is_active', ff.is_active
          )
          order by ff.sort_order asc, ff.created_at asc
        )
        from public.support_form_fields ff
        where ff.form_id = v_form.id
      ),
      '[]'::jsonb
    )
  );
end;
$$;

create or replace function public.admin_upsert_support_form(
  p_id uuid,
  p_title text,
  p_description text,
  p_audience text,
  p_is_active boolean,
  p_sort_order integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.support_forms;
  v_title text;
begin
  perform public.require_dashboard_admin();

  v_title := nullif(btrim(coalesce(p_title, '')), '');
  if v_title is null then
    raise exception 'form title required' using errcode = '22023';
  end if;
  if p_audience not in ('both', 'user', 'captain') then
    raise exception 'invalid audience' using errcode = '22023';
  end if;

  if p_id is null then
    insert into public.support_forms (
      title, description, audience, is_active, sort_order, created_by, updated_by
    ) values (
      v_title,
      nullif(btrim(coalesce(p_description, '')), ''),
      p_audience,
      coalesce(p_is_active, true),
      coalesce(p_sort_order, 0),
      auth.uid(),
      auth.uid()
    )
    returning * into v_row;
  else
    update public.support_forms
      set
        title = v_title,
        description = nullif(btrim(coalesce(p_description, '')), ''),
        audience = p_audience,
        is_active = coalesce(p_is_active, true),
        sort_order = coalesce(p_sort_order, 0),
        updated_at = now(),
        updated_by = auth.uid()
    where id = p_id
    returning * into v_row;

    if v_row.id is null then
      raise exception 'form not found' using errcode = '22023';
    end if;
  end if;

  return jsonb_build_object('id', v_row.id, 'title', v_row.title);
end;
$$;

create or replace function public.admin_upsert_support_form_field(
  p_id uuid,
  p_form_id uuid,
  p_field_key text,
  p_label text,
  p_field_type text,
  p_placeholder text,
  p_is_required boolean,
  p_sort_order integer,
  p_options jsonb,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.support_form_fields;
  v_key text;
  v_label text;
begin
  perform public.require_dashboard_admin();

  if p_form_id is null then
    raise exception 'form id required' using errcode = '22023';
  end if;

  v_label := nullif(btrim(coalesce(p_label, '')), '');
  if v_label is null then
    raise exception 'field label required' using errcode = '22023';
  end if;
  if p_field_type not in ('text', 'textarea', 'select') then
    raise exception 'invalid field type' using errcode = '22023';
  end if;

  v_key := public._normalize_support_field_key(
    coalesce(nullif(btrim(coalesce(p_field_key, '')), ''), v_label)
  );
  if v_key is null then
    raise exception 'invalid field key' using errcode = '22023';
  end if;

  if p_field_type = 'select' then
    if p_options is null or jsonb_typeof(p_options) <> 'array'
      or jsonb_array_length(p_options) = 0 then
      raise exception 'select field requires options' using errcode = '22023';
    end if;
  end if;

  if p_id is null then
    insert into public.support_form_fields (
      form_id, field_key, label, field_type, placeholder,
      is_required, sort_order, options, is_active
    ) values (
      p_form_id,
      v_key,
      v_label,
      p_field_type,
      nullif(btrim(coalesce(p_placeholder, '')), ''),
      coalesce(p_is_required, false),
      coalesce(p_sort_order, 0),
      case when p_field_type = 'select' then p_options else null end,
      coalesce(p_is_active, true)
    )
    returning * into v_row;
  else
    update public.support_form_fields
      set
        field_key = v_key,
        label = v_label,
        field_type = p_field_type,
        placeholder = nullif(btrim(coalesce(p_placeholder, '')), ''),
        is_required = coalesce(p_is_required, false),
        sort_order = coalesce(p_sort_order, 0),
        options = case when p_field_type = 'select' then p_options else null end,
        is_active = coalesce(p_is_active, true),
        updated_at = now()
    where id = p_id and form_id = p_form_id
    returning * into v_row;

    if v_row.id is null then
      raise exception 'field not found' using errcode = '22023';
    end if;
  end if;

  return jsonb_build_object('id', v_row.id, 'field_key', v_row.field_key);
end;
$$;

create or replace function public.admin_delete_support_form_field(
  p_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_dashboard_admin();
  update public.support_form_fields
    set is_active = false, updated_at = now()
  where id = p_id;
  return found;
end;
$$;

create or replace function public.admin_delete_support_form(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count bigint;
begin
  perform public.require_dashboard_admin();

  select count(*) into v_count
  from public.support_form_submissions s
  where s.form_id = p_id;

  if v_count > 0 then
    update public.support_forms
      set is_active = false, updated_at = now(), updated_by = auth.uid()
    where id = p_id;
    return jsonb_build_object('archived', true, 'message', 'form archived due to existing submissions');
  end if;

  delete from public.support_form_fields where form_id = p_id;
  delete from public.support_forms where id = p_id;
  return jsonb_build_object('deleted', true);
end;
$$;

create or replace function public.admin_set_support_form_active(
  p_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.support_forms;
begin
  perform public.require_dashboard_admin();

  update public.support_forms
    set
      is_active = coalesce(p_is_active, false),
      updated_at = now(),
      updated_by = auth.uid()
  where id = p_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'form not found' using errcode = '22023';
  end if;

  return jsonb_build_object('id', v_row.id, 'is_active', v_row.is_active);
end;
$$;

-- ---------------------------------------------------------------------------
-- 7) Admin submission RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_support_requests(
  p_status text default null,
  p_limit integer default 200
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer;
begin
  perform public.require_dashboard_admin();
  v_limit := greatest(1, least(coalesce(p_limit, 200), 500));

  return coalesce(
    (
      select jsonb_agg(row_data order by created_at desc)
      from (
        select jsonb_build_object(
          'id', s.id,
          'request_number', s.request_number,
          'user_id', s.user_id,
          'full_name', p.full_name,
          'phone', p.phone,
          'account_type', s.account_type,
          'form_title', s.form_title,
          'status', s.status,
          'created_at', s.created_at
        ) as row_data,
        s.created_at
        from public.support_form_submissions s
        join public.profiles p on p.id = s.user_id
        where p_status is null or s.status = p_status
        order by s.created_at desc
        limit v_limit
      ) q
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.admin_get_support_request_detail(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.support_form_submissions;
  v_profile public.profiles;
begin
  perform public.require_dashboard_admin();

  select * into v_row from public.support_form_submissions where id = p_id;
  if v_row.id is null then
    raise exception 'support request not found' using errcode = '22023';
  end if;

  select * into v_profile from public.profiles where id = v_row.user_id;

  return jsonb_build_object(
    'id', v_row.id,
    'request_number', v_row.request_number,
    'form_id', v_row.form_id,
    'form_title', v_row.form_title,
    'account_type', v_row.account_type,
    'status', v_row.status,
    'admin_note', v_row.admin_note,
    'payload', v_row.payload,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at,
    'resolved_at', v_row.resolved_at,
    'user', jsonb_build_object(
      'id', v_profile.id,
      'full_name', v_profile.full_name,
      'phone', v_profile.phone
    )
  );
end;
$$;

create or replace function public.admin_update_support_request(
  p_id uuid,
  p_status text,
  p_admin_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.support_form_submissions;
begin
  perform public.require_dashboard_admin();

  if p_status not in ('new', 'in_progress', 'resolved', 'closed') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  update public.support_form_submissions
    set
      status = p_status,
      admin_note = nullif(btrim(coalesce(p_admin_note, '')), ''),
      handled_by = auth.uid(),
      updated_at = now(),
      resolved_at = case
        when p_status in ('resolved', 'closed') then coalesce(resolved_at, now())
        else resolved_at
      end
  where id = p_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'support request not found' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'status', v_row.status,
    'admin_note', v_row.admin_note,
    'updated_at', v_row.updated_at
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 8) Grants
-- ---------------------------------------------------------------------------
revoke all on function public.get_support_faqs() from public;
revoke all on function public.get_support_forms() from public;
revoke all on function public.get_support_form_detail(uuid) from public;
revoke all on function public.my_support_requests() from public;
revoke all on function public.submit_support_request(uuid, jsonb) from public;

grant execute on function public.get_support_faqs() to authenticated;
grant execute on function public.get_support_forms() to authenticated;
grant execute on function public.get_support_form_detail(uuid) to authenticated;
grant execute on function public.my_support_requests() to authenticated;
grant execute on function public.submit_support_request(uuid, jsonb) to authenticated;

revoke all on function public.admin_list_support_faqs() from public;
revoke all on function public.admin_upsert_support_faq(uuid, text, text, text, boolean, integer) from public;
revoke all on function public.admin_delete_support_faq(uuid) from public;
revoke all on function public.admin_set_support_faq_active(uuid, boolean) from public;
revoke all on function public.admin_list_support_forms() from public;
revoke all on function public.admin_get_support_form(uuid) from public;
revoke all on function public.admin_upsert_support_form(uuid, text, text, text, boolean, integer) from public;
revoke all on function public.admin_upsert_support_form_field(uuid, uuid, text, text, text, text, boolean, integer, jsonb, boolean) from public;
revoke all on function public.admin_delete_support_form_field(uuid) from public;
revoke all on function public.admin_delete_support_form(uuid) from public;
revoke all on function public.admin_set_support_form_active(uuid, boolean) from public;
revoke all on function public.admin_list_support_requests(text, integer) from public;
revoke all on function public.admin_get_support_request_detail(uuid) from public;
revoke all on function public.admin_update_support_request(uuid, text, text) from public;

grant execute on function public.admin_list_support_faqs() to authenticated;
grant execute on function public.admin_upsert_support_faq(uuid, text, text, text, boolean, integer) to authenticated;
grant execute on function public.admin_delete_support_faq(uuid) to authenticated;
grant execute on function public.admin_set_support_faq_active(uuid, boolean) to authenticated;
grant execute on function public.admin_list_support_forms() to authenticated;
grant execute on function public.admin_get_support_form(uuid) to authenticated;
grant execute on function public.admin_upsert_support_form(uuid, text, text, text, boolean, integer) to authenticated;
grant execute on function public.admin_upsert_support_form_field(uuid, uuid, text, text, text, text, boolean, integer, jsonb, boolean) to authenticated;
grant execute on function public.admin_delete_support_form_field(uuid) to authenticated;
grant execute on function public.admin_delete_support_form(uuid) to authenticated;
grant execute on function public.admin_set_support_form_active(uuid, boolean) to authenticated;
grant execute on function public.admin_list_support_requests(text, integer) to authenticated;
grant execute on function public.admin_get_support_request_detail(uuid) to authenticated;
grant execute on function public.admin_update_support_request(uuid, text, text) to authenticated;
