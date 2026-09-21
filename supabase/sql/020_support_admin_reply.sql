-- 020_support_admin_reply.sql
-- Separate admin_reply (visible to user) from admin_note (admin-only).

alter table public.support_form_submissions
  add column if not exists admin_reply text,
  add column if not exists replied_at timestamptz,
  add column if not exists replied_by uuid references auth.users (id) on delete set null;

-- User detail RPC — never exposes admin_note.
create or replace function public.get_my_support_request_detail(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.support_form_submissions;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_id is null then
    raise exception 'request id required' using errcode = '22023';
  end if;

  select * into v_row
  from public.support_form_submissions s
  where s.id = p_id
    and s.user_id = auth.uid();

  if v_row.id is null then
    raise exception 'support request not found' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'request_number', v_row.request_number,
    'form_title', v_row.form_title,
    'status', v_row.status,
    'payload', v_row.payload,
    'admin_reply', v_row.admin_reply,
    'replied_at', v_row.replied_at,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
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
    'admin_reply', v_row.admin_reply,
    'admin_note', v_row.admin_note,
    'replied_at', v_row.replied_at,
    'replied_by', v_row.replied_by,
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

drop function if exists public.admin_update_support_request(uuid, text, text);

create or replace function public.admin_update_support_request(
  p_id uuid,
  p_status text,
  p_admin_reply text,
  p_admin_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.support_form_submissions;
  v_reply text;
  v_note text;
begin
  perform public.require_dashboard_admin();

  if p_status not in ('new', 'in_progress', 'resolved', 'closed') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  v_reply := nullif(btrim(coalesce(p_admin_reply, '')), '');
  v_note := nullif(btrim(coalesce(p_admin_note, '')), '');

  update public.support_form_submissions
    set
      status = p_status,
      admin_reply = v_reply,
      admin_note = v_note,
      handled_by = auth.uid(),
      updated_at = now(),
      replied_at = case
        when v_reply is not null then now()
        else null
      end,
      replied_by = case
        when v_reply is not null then auth.uid()
        else null
      end,
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
    'admin_reply', v_row.admin_reply,
    'admin_note', v_row.admin_note,
    'replied_at', v_row.replied_at,
    'replied_by', v_row.replied_by,
    'updated_at', v_row.updated_at
  );
end;
$$;

revoke all on function public.get_my_support_request_detail(uuid) from public;
revoke all on function public.admin_get_support_request_detail(uuid) from public;
revoke all on function public.admin_update_support_request(uuid, text, text, text) from public;

grant execute on function public.get_my_support_request_detail(uuid) to authenticated;
grant execute on function public.admin_get_support_request_detail(uuid) to authenticated;
grant execute on function public.admin_update_support_request(uuid, text, text, text) to authenticated;
