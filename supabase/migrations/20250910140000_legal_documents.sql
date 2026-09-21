-- Mirror of supabase/sql/056_legal_documents.sql
-- Dynamic legal documents (privacy policy + terms of use)

create table if not exists public.legal_documents (
  id uuid primary key default gen_random_uuid(),
  document_type text not null
    check (document_type in ('privacy_policy', 'terms_of_use')),
  title text not null check (char_length(trim(title)) > 0),
  content text not null default '',
  content_format text not null default 'markdown'
    check (content_format in ('markdown', 'plain')),
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null,
  constraint legal_documents_type_unique unique (document_type)
);

comment on table public.legal_documents is
  'Single published legal docs per type. Source of truth for app + future public website.';

create index if not exists legal_documents_published_idx
  on public.legal_documents (document_type)
  where is_published = true;

alter table public.legal_documents enable row level security;

drop policy if exists legal_documents_select_published on public.legal_documents;
create policy legal_documents_select_published
  on public.legal_documents
  for select
  to anon, authenticated
  using (is_published = true and char_length(trim(content)) > 0);

create or replace function public.get_legal_document(p_document_type text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := lower(trim(coalesce(p_document_type, '')));
  v_row public.legal_documents;
begin
  if v_type not in ('privacy_policy', 'terms_of_use') then
    raise exception 'invalid document_type' using errcode = '22023';
  end if;

  select * into v_row
  from public.legal_documents d
  where d.document_type = v_type
    and d.is_published = true
    and char_length(trim(d.content)) > 0;

  if v_row.id is null then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'document_type', v_row.document_type,
    'title', v_row.title,
    'content', v_row.content,
    'content_format', v_row.content_format,
    'is_published', v_row.is_published,
    'updated_at', v_row.updated_at
  );
end;
$$;

revoke all on function public.get_legal_document(text) from public;
grant execute on function public.get_legal_document(text) to anon, authenticated;

create or replace function public.admin_get_legal_document(p_document_type text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := lower(trim(coalesce(p_document_type, '')));
  v_row public.legal_documents;
begin
  perform public.require_dashboard_admin();

  if v_type not in ('privacy_policy', 'terms_of_use') then
    raise exception 'invalid document_type' using errcode = '22023';
  end if;

  select * into v_row
  from public.legal_documents d
  where d.document_type = v_type;

  if v_row.id is null then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'document_type', v_row.document_type,
    'title', v_row.title,
    'content', v_row.content,
    'content_format', v_row.content_format,
    'is_published', v_row.is_published,
    'updated_at', v_row.updated_at,
    'updated_by', v_row.updated_by
  );
end;
$$;

revoke all on function public.admin_get_legal_document(text) from public;
grant execute on function public.admin_get_legal_document(text) to authenticated;

create or replace function public.admin_upsert_legal_document(
  p_document_type text,
  p_title text,
  p_content text,
  p_is_published boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := lower(trim(coalesce(p_document_type, '')));
  v_title text := trim(coalesce(p_title, ''));
  v_content text := trim(coalesce(p_content, ''));
  v_publish boolean := coalesce(p_is_published, true);
  v_row public.legal_documents;
begin
  perform public.require_dashboard_admin();

  if v_type not in ('privacy_policy', 'terms_of_use') then
    raise exception 'invalid document_type' using errcode = '22023';
  end if;

  if char_length(v_title) = 0 then
    raise exception 'العنوان مطلوب' using errcode = 'P0001';
  end if;

  if char_length(v_content) = 0 then
    raise exception 'لا يمكن حفظ محتوى فارغ' using errcode = 'P0001';
  end if;

  if v_publish and char_length(v_content) = 0 then
    raise exception 'لا يمكن نشر محتوى فارغ' using errcode = 'P0001';
  end if;

  insert into public.legal_documents as d (
    document_type,
    title,
    content,
    content_format,
    is_published,
    updated_at,
    updated_by
  )
  values (
    v_type,
    v_title,
    v_content,
    'markdown',
    v_publish,
    now(),
    auth.uid()
  )
  on conflict (document_type) do update
    set title = excluded.title,
        content = excluded.content,
        content_format = 'markdown',
        is_published = excluded.is_published,
        updated_at = now(),
        updated_by = auth.uid()
  returning * into v_row;

  return jsonb_build_object(
    'id', v_row.id,
    'document_type', v_row.document_type,
    'title', v_row.title,
    'content', v_row.content,
    'content_format', v_row.content_format,
    'is_published', v_row.is_published,
    'updated_at', v_row.updated_at,
    'updated_by', v_row.updated_by
  );
end;
$$;

revoke all on function public.admin_upsert_legal_document(text, text, text, boolean) from public;
grant execute on function public.admin_upsert_legal_document(text, text, text, boolean) to authenticated;

insert into public.legal_documents (document_type, title, content, content_format, is_published)
values
(
  'privacy_policy',
  'سياسة الخصوصية',
  E'# سياسة الخصوصية — تطبيق حاضر\n\nيمكن تعديل هذا المحتوى من لوحة الإدارة.\n\n## البيانات التي قد نجمعها\n- الاسم ورقم الهاتف وبيانات الحساب\n- بيانات الطلبات والعناوين والموقع عند الحاجة\n- بيانات الكابتن والاشتراك عند الانطباق\n- رموز إشعارات الجهاز (FCM)\n\n## حذف الحساب\nيمكنك حذف حسابك من داخل التطبيق. قد تُحفظ سجلات تشغيلية بعد إخفاء البيانات الشخصية.\n\n## التواصل\nاستخدم قسم الدعم داخل التطبيق.',
  'markdown',
  true
),
(
  'terms_of_use',
  'شروط الاستخدام',
  E'# شروط الاستخدام — تطبيق حاضر\n\nباستخدامك لتطبيق حاضر فإنك توافق على هذه الشروط.\n\n## وصف الخدمة\nمنصة لربط المستخدمين بخدمات التوصيل والنقل.\n\n## مسؤوليات المستخدم والكابتن\nالالتزام بالاستخدام المشروع واحترام الآخرين وقواعد المنصة.\n\n## تعديل الشروط\nقد تُحدَّث الشروط من لوحة الإدارة وتظهر مباشرة داخل التطبيق.',
  'markdown',
  true
)
on conflict (document_type) do nothing;
