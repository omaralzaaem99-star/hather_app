-- 056: Dynamic legal documents (privacy policy + terms of use)
-- Public read (anon + authenticated) for published docs only.
-- Admin write via SECURITY DEFINER RPCs (require_dashboard_admin).
-- Does NOT touch app_settings, auth, orders, or subscriptions.

-- ---------------------------------------------------------------------------
-- 1) Table
-- ---------------------------------------------------------------------------
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

-- No direct client write policies. Optional public SELECT for published rows
-- (also exposed via get_legal_document RPC for a stable API).
drop policy if exists legal_documents_select_published on public.legal_documents;
create policy legal_documents_select_published
  on public.legal_documents
  for select
  to anon, authenticated
  using (is_published = true and char_length(trim(content)) > 0);

-- ---------------------------------------------------------------------------
-- 2) Public read RPC (anon + authenticated)
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 3) Admin RPCs
-- ---------------------------------------------------------------------------
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

  -- Never publish empty content (defense in depth).
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

-- ---------------------------------------------------------------------------
-- 4) Seed initial published documents (editable from admin)
-- ---------------------------------------------------------------------------
insert into public.legal_documents (document_type, title, content, content_format, is_published)
values
(
  'privacy_policy',
  'سياسة الخصوصية',
  $md$
# سياسة الخصوصية — تطبيق حاضر

آخر تحديث يمكن تعديله من لوحة الإدارة.

## من نحن
تطبيق **حاضر** منصة خدمات محلية تربط المستخدمين بخدمات التوصيل والنقل.

## البيانات التي قد نجمعها
- بيانات الحساب: الاسم ورقم الهاتف وكلمة المرور/الرمز السري (مشفّرة حسب نظام المصادقة).
- بيانات الطلبات: تفاصيل الطلب، العناوين، الموقع الجغرافي عند الحاجة لإتمام التوصيل.
- بيانات الكابتن: معلومات الحساب وحالة الطلبات والاشتراك عند الانضمام ككابتن.
- بيانات الجهاز والإشعارات: رموز أجهزة الإشعارات (FCM) لإرسال التنبيهات.
- رسائل الدعم الفني عند إرسالها عبر التطبيق.

## كيف نستخدم البيانات
- إنشاء الحساب وتشغيل الخدمة.
- معالجة طلبات التوصيل وإدارتها.
- إرسال الإشعارات المتعلقة بالطلبات والحساب.
- تحسين الأمان ومنع إساءة الاستخدام.
- الرد على طلبات الدعم.

## الجهات التقنية المستخدمة
قد تُعالَج البيانات عبر مزوّدي خدمة ضروريين لتشغيل التطبيق، مثل:
- **Supabase** (قاعدة البيانات والمصادقة)
- **Firebase Cloud Messaging** (الإشعارات)
- مزوّد رسائل SMS/OTP عند تفعيل التحقق عبر الرسائل

## مشاركة البيانات
لا نبيع بياناتك الشخصية. قد تُشارك بيانات ضرورية فقط مع الكباتن أو الأطراف التشغيلية لإتمام الطلب، أو عند الالتزام بمتطلب قانوني.

## الاحتفاظ بالبيانات
نحتفظ بالبيانات طالما الحساب نشط أو طالما يلزم تشغيل الخدمة والسجلات التشغيلية/المحاسبية.

## حذف الحساب
يمكنك طلب حذف حسابك من داخل التطبيق (الحساب ← الخصوصية والأمان ← حذف الحساب).
بعد التحقق الأمني:
- تُحذف بياناتك الشخصية المرتبطة بالحساب.
- قد تُحفظ سجلات الطلبات التشغيلية بعد إزالة أو إخفاء البيانات الشخصية (Anonymize) عند الحاجة للتقارير والإدارة.
- تُحذف رموز الإشعارات المرتبطة بالحساب.

## حقوقك
يمكنك مراجعة بيانات حسابك وتحديثها أو طلب حذف الحساب وفق الآليات المتاحة في التطبيق.

## التواصل
للاستفسارات المتعلقة بالخصوصية استخدم قسم الدعم داخل التطبيق أو تواصل عبر بيانات المطوّر في شاشة «حول التطبيق».

## تحديث هذه السياسة
قد نحدّث هذه السياسة من وقت لآخر. يظهر المحتوى المحدّث مباشرة داخل التطبيق بعد نشره من لوحة الإدارة.
$md$,
  'markdown',
  true
),
(
  'terms_of_use',
  'شروط الاستخدام',
  $md$
# شروط الاستخدام — تطبيق حاضر

باستخدامك لتطبيق **حاضر** فإنك توافق على هذه الشروط.

## وصف الخدمة
حاضر منصة تسهّل طلب خدمات التوصيل والنقل وربط المستخدمين بالكباتن ضمن نطاق الخدمة المتاح.

## قبول الشروط
بإنشاء حساب أو استخدام التطبيق فإنك تقر بقراءة هذه الشروط والموافقة عليها.

## مسؤوليات المستخدم
- تقديم معلومات صحيحة.
- استخدام التطبيق لأغراض مشروعة فقط.
- عدم إساءة استخدام الطلبات أو التواصل مع الكباتن.
- الالتزام بدفع الأجور المتفق عليها داخل التطبيق عند انطباقها.

## مسؤوليات الكابتن
- قبول وتنفيذ الطلبات بحسن نية ومهنية.
- احترام المستخدمين وقوانين المرور والسلامة.
- الالتزام بسياسات الاشتراك وحالة الحساب داخل المنصة.

## الطلبات والأسعار
تظهر تفاصيل الطلب وأجور التوصيل داخل التطبيق قبل أو أثناء إتمام الطلب حسب آلية العرض المعتمدة.

## الإلغاء
يمكن إلغاء الطلب وفق الحالات والقواعد المتاحة في التطبيق. قد تختلف إمكانية الإلغاء حسب حالة الطلب.

## السلوك المحظور
يُحظر الاحتيال، التحرش، انتحال الهوية، إساءة استخدام النظام، أو أي نشاط يضر بالمستخدمين أو المنصة.

## تعليق أو إيقاف الحساب
قد يتم تعليق أو إيقاف الحساب عند مخالفة الشروط أو لأسباب أمنية/تشغيلية.

## اشتراكات الكباتن
قد يتطلب حساب الكابتن اشتراكاً أو فترة تجريبية وفق إعدادات المنصة المعروضة داخل التطبيق. حذف الحساب لا يعني استرداداً تلقائياً للرسوم ما لم يُعلن خلاف ذلك.

## حدود المسؤولية
تُقدَّم الخدمة «كما هي» ضمن الحدود المعقولة. لا تتحمل المنصة المسؤولية عن أضرار غير مباشرة ناتجة عن استخدام الخدمة خارج نطاق السيطرة المعقولة للمشغّل.

## تعديل الشروط
قد نعدّل هذه الشروط من وقت لآخر. يسري المحتوى المحدّث داخل التطبيق بعد نشره من لوحة الإدارة.

## التواصل
للاستفسارات استخدم قسم الدعم داخل التطبيق.
$md$,
  'markdown',
  true
)
on conflict (document_type) do nothing;
