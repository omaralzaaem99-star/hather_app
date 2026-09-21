-- HATHER SUPPORT DEMO DATA
-- DEVELOPMENT / TESTING ONLY
-- Remove demo support requests before production launch.
--
-- Apply AFTER 018_support_faq_forms.sql
-- Idempotent: safe to run multiple times (fixed demo UUIDs only).

-- ---------------------------------------------------------------------------
-- Demo UUID namespace (do not reuse outside this seed)
-- ---------------------------------------------------------------------------
-- FAQs:     a1000001-0001-4001-8001-000000000001 .. 009
-- Forms:    b1000001-0001-4001-8001-000000000001 .. 005
-- Fields:   b2000001-0001-4001-8001-000000000001 .. 014
-- Requests: c1000001-0001-4001-8001-000000000001 .. 002

-- ---------------------------------------------------------------------------
-- 1) FAQs (8 active + 1 disabled)
-- ---------------------------------------------------------------------------
insert into public.support_faqs (
  id, question, answer, audience, is_active, sort_order, updated_at
) values
  (
    'a1000001-0001-4001-8001-000000000001',
    'كيف أتواصل مع الدعم الفني؟',
    'يمكنك التواصل مع فريق دعم حاضر من قسم الدعم الفني واختيار إحدى وسائل التواصل المتاحة مثل واتساب أو الاتصال الهاتفي أو البريد الإلكتروني.',
    'both', true, 10, now()
  ),
  (
    'a1000002-0001-4001-8001-000000000002',
    'كيف أرسل طلب دعم؟',
    'ادخل إلى قسم الدعم الفني، اختر نموذج الدعم المناسب، أكمل المعلومات المطلوبة ثم اضغط إرسال.',
    'both', true, 20, now()
  ),
  (
    'a1000003-0001-4001-8001-000000000003',
    'كيف أتابع طلب الدعم الذي أرسلته؟',
    'يمكنك متابعة حالة طلبك من قسم "طلباتي للدعم" داخل صفحة الدعم الفني.',
    'both', true, 30, now()
  ),
  (
    'a1000004-0001-4001-8001-000000000004',
    'كيف ألغي طلب التوصيل؟',
    'إذا كان الطلب ما زال في الحالة التي تسمح بالإلغاء، افتح تفاصيل الطلب واستخدم خيار إلغاء الطلب.',
    'user', true, 40, now()
  ),
  (
    'a1000005-0001-4001-8001-000000000005',
    'ماذا أفعل إذا تأخر طلبي؟',
    'يمكنك فتح نموذج "مشكلة في الطلب" وإرسال تفاصيل المشكلة إلى فريق الدعم لمتابعتها.',
    'user', true, 50, now()
  ),
  (
    'a1000006-0001-4001-8001-000000000006',
    'متى تظهر الطلبات الجديدة للكابتن؟',
    'تظهر الطلبات المتاحة في الصفحة الرئيسية للكابتن عندما يكون حسابه فعالاً واشتراكه يسمح له باستلام الطلبات.',
    'captain', true, 60, now()
  ),
  (
    'a1000007-0001-4001-8001-000000000007',
    'لماذا لا أستطيع قبول طلب؟',
    'قد يكون الطلب قد تم قبوله من كابتن آخر، أو انتهت صلاحيته، أو أن اشتراك الكابتن غير فعال.',
    'captain', true, 70, now()
  ),
  (
    'a1000008-0001-4001-8001-000000000008',
    'أين أجد معلومات اشتراكي؟',
    'توجد معلومات الاشتراك داخل صفحة "حسابي" الخاصة بالكابتن.',
    'captain', true, 80, now()
  ),
  (
    'a1000009-0001-4001-8001-000000000009',
    'هذا سؤال تجريبي معطل',
    'يجب ألا يظهر هذا السؤال داخل التطبيق.',
    'both', false, 999, now()
  )
on conflict (id) do update set
  question = excluded.question,
  answer = excluded.answer,
  audience = excluded.audience,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order,
  updated_at = excluded.updated_at;

-- ---------------------------------------------------------------------------
-- 2) Support forms (4 active + 1 disabled)
-- ---------------------------------------------------------------------------
insert into public.support_forms (
  id, title, description, audience, is_active, sort_order, updated_at
) values
  (
    'b1000001-0001-4001-8001-000000000001',
    'مشكلة في الطلب',
    'إذا واجهتك مشكلة في أحد طلبات التوصيل، أرسل لنا التفاصيل وسيتابع فريق حاضر الطلب.',
    'user', true, 10, now()
  ),
  (
    'b1000002-0001-4001-8001-000000000002',
    'شكوى على كابتن',
    'استخدم هذا النموذج لإرسال شكوى متعلقة بكابتن في أحد طلباتك.',
    'user', true, 20, now()
  ),
  (
    'b1000003-0001-4001-8001-000000000003',
    'مشكلة في حساب الكابتن',
    'أرسل لنا المشكلة التي تواجهها في حساب الكابتن.',
    'captain', true, 30, now()
  ),
  (
    'b1000004-0001-4001-8001-000000000004',
    'اقتراح أو شكوى عامة',
    'شاركنا اقتراحك أو أرسل لنا ملاحظتك لمساعدتنا في تحسين تطبيق حاضر.',
    'both', true, 40, now()
  ),
  (
    'b1000005-0001-4001-8001-000000000005',
    'نموذج تجريبي معطل',
    'نموذج DEMO للاختبار — معطل ولا يظهر في التطبيق.',
    'both', false, 999, now()
  )
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  audience = excluded.audience,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order,
  updated_at = excluded.updated_at;

-- ---------------------------------------------------------------------------
-- 3) Form fields
-- ---------------------------------------------------------------------------
insert into public.support_form_fields (
  id, form_id, field_key, label, field_type, placeholder,
  is_required, sort_order, options, is_active, updated_at
) values
  -- Form 1: مشكلة في الطلب
  (
    'b2000001-0001-4001-8001-000000000001',
    'b1000001-0001-4001-8001-000000000001',
    'order_number', 'رقم الطلب', 'text', 'أدخل رقم الطلب',
    true, 10, null, true, now()
  ),
  (
    'b2000001-0001-4001-8001-000000000002',
    'b1000001-0001-4001-8001-000000000001',
    'issue_type', 'نوع المشكلة', 'select', null,
    true, 20,
    '["تأخير الطلب","الطلب غير مكتمل","مشكلة مع الكابتن","مشكلة في موقع التوصيل","مشكلة أخرى"]'::jsonb,
    true, now()
  ),
  (
    'b2000001-0001-4001-8001-000000000003',
    'b1000001-0001-4001-8001-000000000001',
    'issue_details', 'اشرح المشكلة', 'textarea', 'اكتب تفاصيل المشكلة هنا...',
    true, 30, null, true, now()
  ),
  -- Form 2: شكوى على كابتن
  (
    'b2000002-0001-4001-8001-000000000001',
    'b1000002-0001-4001-8001-000000000002',
    'order_number', 'رقم الطلب', 'text', 'أدخل رقم الطلب',
    true, 10, null, true, now()
  ),
  (
    'b2000002-0001-4001-8001-000000000002',
    'b1000002-0001-4001-8001-000000000002',
    'complaint_reason', 'سبب الشكوى', 'select', null,
    true, 20,
    '["التعامل","التأخير","عدم إكمال الطلب","مشكلة أخرى"]'::jsonb,
    true, now()
  ),
  (
    'b2000002-0001-4001-8001-000000000003',
    'b1000002-0001-4001-8001-000000000002',
    'complaint_details', 'تفاصيل الشكوى', 'textarea', 'اكتب تفاصيل الشكوى...',
    true, 30, null, true, now()
  ),
  -- Form 3: مشكلة في حساب الكابتن
  (
    'b2000003-0001-4001-8001-000000000001',
    'b1000003-0001-4001-8001-000000000003',
    'issue_type', 'نوع المشكلة', 'select', null,
    true, 10,
    '["الاشتراك","الطلبات","حالة الحساب","مشكلة في التطبيق","مشكلة أخرى"]'::jsonb,
    true, now()
  ),
  (
    'b2000003-0001-4001-8001-000000000002',
    'b1000003-0001-4001-8001-000000000003',
    'issue_details', 'تفاصيل المشكلة', 'textarea', 'اشرح المشكلة بالتفصيل...',
    true, 20, null, true, now()
  ),
  -- Form 4: اقتراح أو شكوى عامة
  (
    'b2000004-0001-4001-8001-000000000001',
    'b1000004-0001-4001-8001-000000000004',
    'message_title', 'عنوان الرسالة', 'text', 'أدخل عنواناً مختصراً',
    true, 10, null, true, now()
  ),
  (
    'b2000004-0001-4001-8001-000000000002',
    'b1000004-0001-4001-8001-000000000004',
    'message_type', 'نوع الرسالة', 'select', null,
    true, 20,
    '["اقتراح","شكوى","ملاحظة","أخرى"]'::jsonb,
    true, now()
  ),
  (
    'b2000004-0001-4001-8001-000000000003',
    'b1000004-0001-4001-8001-000000000004',
    'message_details', 'التفاصيل', 'textarea', 'اكتب التفاصيل هنا...',
    true, 30, null, true, now()
  )
on conflict (id) do update set
  form_id = excluded.form_id,
  field_key = excluded.field_key,
  label = excluded.label,
  field_type = excluded.field_type,
  placeholder = excluded.placeholder,
  is_required = excluded.is_required,
  sort_order = excluded.sort_order,
  options = excluded.options,
  is_active = excluded.is_active,
  updated_at = excluded.updated_at;

-- ---------------------------------------------------------------------------
-- 4) Demo support requests (existing profiles only — skip if none)
-- ---------------------------------------------------------------------------
do $$
declare
  v_user_id uuid;
  v_captain_id uuid;
begin
  select p.id into v_user_id
  from public.profiles p
  where p.account_type = 'user'
  order by p.created_at asc nulls last
  limit 1;

  select p.id into v_captain_id
  from public.profiles p
  where p.account_type = 'captain'
  order by p.created_at asc nulls last
  limit 1;

  if v_user_id is not null then
    insert into public.support_form_submissions (
      id,
      form_id,
      user_id,
      account_type,
      form_title,
      payload,
      status,
      admin_note,
      created_at,
      updated_at
    ) values (
      'c1000001-0001-4001-8001-000000000001',
      'b1000001-0001-4001-8001-000000000001',
      v_user_id,
      'user',
      'مشكلة في الطلب',
      jsonb_build_array(
        jsonb_build_object(
          'field_key', 'order_number',
          'label', 'رقم الطلب',
          'field_type', 'text',
          'value', 'TEST-1001'
        ),
        jsonb_build_object(
          'field_key', 'issue_type',
          'label', 'نوع المشكلة',
          'field_type', 'select',
          'value', 'تأخير الطلب'
        ),
        jsonb_build_object(
          'field_key', 'issue_details',
          'label', 'اشرح المشكلة',
          'field_type', 'textarea',
          'value', 'DEMO — هذا طلب دعم تجريبي للتأكد من ظهور الطلب في لوحة الإدارة.'
        )
      ),
      'new',
      null,
      now(),
      now()
    )
    on conflict (id) do update set
      form_id = excluded.form_id,
      user_id = excluded.user_id,
      account_type = excluded.account_type,
      form_title = excluded.form_title,
      payload = excluded.payload,
      status = excluded.status,
      admin_note = excluded.admin_note,
      updated_at = excluded.updated_at;
  end if;

  if v_captain_id is not null then
    insert into public.support_form_submissions (
      id,
      form_id,
      user_id,
      account_type,
      form_title,
      payload,
      status,
      admin_note,
      created_at,
      updated_at
    ) values (
      'c1000002-0001-4001-8001-000000000002',
      'b1000003-0001-4001-8001-000000000003',
      v_captain_id,
      'captain',
      'مشكلة في حساب الكابتن',
      jsonb_build_array(
        jsonb_build_object(
          'field_key', 'issue_type',
          'label', 'نوع المشكلة',
          'field_type', 'select',
          'value', 'الاشتراك'
        ),
        jsonb_build_object(
          'field_key', 'issue_details',
          'label', 'تفاصيل المشكلة',
          'field_type', 'textarea',
          'value', 'DEMO — هذا طلب دعم تجريبي خاص بالكابتن لاختبار لوحة الإدارة.'
        )
      ),
      'in_progress',
      'طلب تجريبي — يمكن حذفه بعد الاختبار.',
      now(),
      now()
    )
    on conflict (id) do update set
      form_id = excluded.form_id,
      user_id = excluded.user_id,
      account_type = excluded.account_type,
      form_title = excluded.form_title,
      payload = excluded.payload,
      status = excluded.status,
      admin_note = excluded.admin_note,
      updated_at = excluded.updated_at;
  end if;
end;
$$;
